const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { db, admin } = require("../config/firebase");
const { addDays } = require("date-fns");
const EfiPay = require("sdk-node-apis-efi");
const optionsEfi = require("../config/efipay");

// --- 1. Gerar PIX para Assinatura (Agora com tenantId) ---
exports.gerarPixAssinatura = onCall(async (request) => {
    // [MUDANÇA] Recebemos o tenantId
    const { cpf_user, pacoteId, tenantId } = request.data;

    if (!cpf_user || !pacoteId || !tenantId) {
        throw new HttpsError('invalid-argument', 'CPF, ID do pacote e ID da Loja são obrigatórios.');
    }

    // Busca o pacote (Pode ser global ou da loja, aqui assumindo global para simplificar, mas salvando a venda na loja)
    ///db.collection('tenants').doc(tenantId).collection('pacotes').doc(pacoteId)...
    const pacoteRef = db.collection('tenants').doc(tenantId).collection('pacotes').doc(pacoteId);
    const pacoteSnap = await pacoteRef.get();

    if (!pacoteSnap.exists) {
        throw new HttpsError('not-found', 'Pacote não encontrado.');
    }

    const pacoteData = pacoteSnap.data();
    const valor = parseFloat(pacoteData.preco);
    const nomePacote = pacoteData.nome || 'Pacote AgenPet';

    // Extrai Vouchers (Snapshot)
    const vouchersSnapshot = {};
    for (const [key, value] of Object.entries(pacoteData)) {
        if (key.startsWith('vouchers_') && typeof value === 'number' && value > 0) {
            // Remove o prefixo 'vouchers_' para ficar limpo no banco (ex: 'banho': 4)
            const nomeServico = key.replace('vouchers_', '');
            vouchersSnapshot[nomeServico] = value;
        }
    }

    // Gera Cobrança na EfiPay
    let pixCopiaCola = '', imagemQrcode = '', txid = '';

    try {
        const efipay = new EfiPay(optionsEfi);
        const cpfLimpo = cpf_user.replace(/\D/g, '');

        const bodyPix = {
            calendario: { expiracao: 3600 },
            devedor: { cpf: cpfLimpo, nome: "Cliente AgenPet" },
            valor: { original: valor.toFixed(2) },
            chave: "client_id_homologacao" // [ATENÇÃO] Use sua chave PIX real aqui
        };

        const cobranca = await efipay.pixCreateImmediateCharge([], bodyPix);
        txid = cobranca.txid;

        const qrCode = await efipay.pixGenerateQRCode({ id: cobranca.loc.id });
        pixCopiaCola = qrCode.qrcode;
        imagemQrcode = qrCode.imagemQrcode;

    } catch (error) {
        console.error("Erro EfiPay:", error);
        throw new HttpsError('internal', 'Erro ao gerar PIX: ' + error.message);
    }

    // Salva a Venda 'Pendente' com o ID DA LOJA
    const vendaRef = db.collection('vendas_assinaturas').doc();

    await vendaRef.set({
        userId: cpf_user,
        tenantId: tenantId, // <--- CAMPO CRUCIAL PARA O SAAS
        pacote_id: pacoteId,
        pacote_nome: nomePacote,
        valor: valor,
        txid: txid,
        status: 'pendente',
        vouchers_snapshot: vouchersSnapshot,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        metodo_pagamento: 'pix'
    });

    return {
        pix_copia_cola: pixCopiaCola,
        imagem_qrcode: imagemQrcode,
        vendaId: vendaRef.id,
        valor: valor
    };
});

// --- 2. Webhook Unificado (Entrega o voucher na carteira da Loja) ---
exports.webhookPix = onRequest(async (req, res) => {
    const { pix } = req.body;

    if (!pix || !Array.isArray(pix)) {
        return res.status(400).send("Body inválido");
    }

    try {
        for (const p of pix) {
            const txid = p.txid;
            console.log(`Recebido PIX txid: ${txid}`);

            // A. Tenta atualizar AGENDAMENTO (Mantém igual)
            const agendamentoSnap = await db.collection('agendamentos').where('txid', '==', txid).get();
            if (!agendamentoSnap.empty) {
                const batch = db.batch();
                agendamentoSnap.forEach(doc => {
                    batch.update(doc.ref, { status: 'agendado' });
                });
                await batch.commit();
                continue;
            }

            // B. Tenta atualizar VENDA DE ASSINATURA/PACOTE
            const vendaSnap = await db.collection('vendas_assinaturas').where('txid', '==', txid).get();
            if (!vendaSnap.empty) {
                const vendaDoc = vendaSnap.docs[0];
                const vendaData = vendaDoc.data();

                if (vendaData.status !== 'pago') {
                    const userId = vendaData.userId;
                    const tenantId = vendaData.tenantId; // Recupera a loja
                    const vouchersSnapshot = vendaData.vouchers_snapshot || {};
                    const dataPagamento = admin.firestore.Timestamp.now();
                    const validadeDate = addDays(new Date(), 30);

                    // [MUDANÇA CRÍTICA] Define a referência para a subcoleção DA LOJA
                    // Caminho: users/{cpf}/vouchers/{tenantId}
                    const userVoucherRef = db.collection('users')
                        .doc(userId)
                        .collection('vouchers')
                        .doc(tenantId);

                    const batch = db.batch();

                    // 1. Atualiza status da venda
                    batch.update(vendaDoc.ref, {
                        status: 'pago',
                        data_pagamento: dataPagamento
                    });

                    // 2. Prepara atualização dos vouchers na loja específica
                    const updatesVoucher = {
                        ultima_compra: dataPagamento,
                        validade: admin.firestore.Timestamp.fromDate(validadeDate)
                    };

                    // Soma os novos vouchers ao saldo existente (Atomicamente)
                    for (const [servico, qtd] of Object.entries(vouchersSnapshot)) {
                        updatesVoucher[servico] = admin.firestore.FieldValue.increment(qtd);
                    }

                    // Usa 'set' com 'merge' para criar o documento se for a 1ª vez nessa loja
                    batch.set(userVoucherRef, updatesVoucher, { merge: true });

                    await batch.commit();
                    console.log(`Venda ${vendaDoc.id} paga. Vouchers entregues na loja ${tenantId}.`);
                }
            }
        }

        res.status(200).send();
    } catch (e) {
        console.error("Erro no Webhook PIX:", e);
        res.status(500).send("Erro interno");
    }
});