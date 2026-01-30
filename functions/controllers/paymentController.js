const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { db, admin } = require("../config/firebase");
const { addDays } = require("date-fns");
const EfiPay = require("sdk-node-apis-efi");
const optionsEfi = require("../config/efipay");

// --- Gerar PIX para Assinatura/Pacotes ---
exports.gerarPixAssinatura = onCall(async (request) => {
    const { cpf_user, pacoteId } = request.data;

    if (!cpf_user || !pacoteId) {
        throw new HttpsError('invalid-argument', 'CPF e ID do pacote são obrigatórios.');
    }

    // 1. Busca dados do Pacote
    const pacoteRef = db.collection('pacotes_assinatura').doc(pacoteId);
    const pacoteSnap = await pacoteRef.get();
    
    if (!pacoteSnap.exists) {
        throw new HttpsError('not-found', 'Pacote não encontrado.');
    }

    const pacoteData = pacoteSnap.data();
    const valor = parseFloat(pacoteData.preco);
    const nomePacote = pacoteData.nome || 'Pacote AgenPet';

    // 2. Extrai Vouchers para Snapshot (Segurança contra mudança de preço/qtd futura)
    const vouchersSnapshot = {};
    for (const [key, value] of Object.entries(pacoteData)) {
        if (key.startsWith('vouchers_') && typeof value === 'number' && value > 0) {
            vouchersSnapshot[key] = value;
        }
    }

    // 3. Gera Cobrança na EfiPay
    let pixCopiaCola = '';
    let imagemQrcode = '';
    let txid = '';

    try {
        const efipay = new EfiPay(optionsEfi);

        // Remove caracteres não numéricos do CPF
        const cpfLimpo = cpf_user.replace(/\D/g, '');

        const bodyPix = {
            calendario: { expiracao: 3600 }, // 1 hora
            devedor: { 
                cpf: cpfLimpo, 
                nome: "Cliente AgenPet" 
            },
            valor: { original: valor.toFixed(2) },
            chave: "client_id_homologacao" // Nota: Em prod, usar chave PIX real cadastrada. Em homolog, o Efi gera.
        };

        // Cria cobrança imediata
        const cobranca = await efipay.pixCreateImmediateCharge([], bodyPix);
        txid = cobranca.txid;

        // Gera QR Code
        const qrCode = await efipay.pixGenerateQRCode({ id: cobranca.loc.id });
        pixCopiaCola = qrCode.qrcode;
        imagemQrcode = qrCode.imagemQrcode;

    } catch (error) {
        console.error("Erro EfiPay:", error);
        throw new HttpsError('internal', 'Erro ao gerar PIX: ' + error.message);
    }

    // 4. Salva a Venda 'Pendente' no Firestore
    const vendaRef = db.collection('vendas_assinaturas').doc();
    
    await vendaRef.set({
        userId: cpf_user,
        pacote_id: pacoteId,
        pacote_nome: nomePacote,
        valor: valor,
        txid: txid,
        status: 'pendente',
        vouchers_snapshot: vouchersSnapshot, // O que será entregue
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

// --- Webhook Unificado (Agendamentos + Assinaturas) ---
exports.webhookPix = onRequest(async (req, res) => {
    const { pix } = req.body;
    
    // Validação básica do body
    if (!pix || !Array.isArray(pix)) {
        return res.status(400).send("Body inválido");
    }

    try {
        for (const p of pix) {
            const txid = p.txid;
            console.log(`Recebido PIX txid: ${txid}`);

            // A. Tenta atualizar AGENDAMENTO
            const agendamentoSnap = await db.collection('agendamentos').where('txid', '==', txid).get();
            if (!agendamentoSnap.empty) {
                const batch = db.batch();
                agendamentoSnap.forEach(doc => {
                    batch.update(doc.ref, { status: 'agendado' });
                });
                await batch.commit();
                console.log(`Agendamento(s) confirmado(s) para txid ${txid}`);
                continue; // Se achou agendamento, pula pra próxima iteração (assume q não é venda de pacote)
            }

            // B. Tenta atualizar VENDA DE ASSINATURA/PACOTE
            const vendaSnap = await db.collection('vendas_assinaturas').where('txid', '==', txid).get();
            if (!vendaSnap.empty) {
                const vendaDoc = vendaSnap.docs[0];
                const vendaData = vendaDoc.data();

                if (vendaData.status !== 'pago') {
                    const userId = vendaData.userId;
                    const vouchersSnapshot = vendaData.vouchers_snapshot || {};
                    const dataPagamento = admin.firestore.Timestamp.now();
                    const validadeDate = addDays(new Date(), 30); // Validade padrão 30 dias

                    // B1. Prepara atualização do User
                    const userRef = db.collection('users').doc(userId);
                    
                    // Objeto para array de histórico de vouchers
                    const novoItemVoucher = {
                        nome_pacote: vendaData.pacote_nome,
                        validade_pacote: admin.firestore.Timestamp.fromDate(validadeDate),
                        data_compra: dataPagamento
                    };

                    // Campos de incremento direto (vouchers_banho, etc.)
                    const updatesUser = {
                        assinante_ativo: true,
                        ultima_compra: dataPagamento,
                        validade_assinatura: admin.firestore.Timestamp.fromDate(validadeDate),
                        voucher_assinatura: admin.firestore.FieldValue.arrayUnion(novoItemVoucher)
                    };

                    // Processa os vouchers do snapshot
                    for (const [key, qtd] of Object.entries(vouchersSnapshot)) {
                        // Adiciona ao objeto do array
                        const nomeServico = key.replace('vouchers_', '');
                        novoItemVoucher[nomeServico] = qtd;

                        // Adiciona ao incremento atômico
                        updatesUser[key] = admin.firestore.FieldValue.increment(qtd);
                    }

                    // B2. Executa Batch
                    const batch = db.batch();
                    
                    // Atualiza venda para pago
                    batch.update(vendaDoc.ref, { 
                        status: 'pago', 
                        data_pagamento: dataPagamento 
                    });

                    // Atualiza usuário com vouchers
                    batch.update(userRef, updatesUser);

                    await batch.commit();
                    console.log(`Venda ${vendaDoc.id} confirmada e vouchers entregues.`);
                }
            }
        }

        res.status(200).send();
    } catch (e) {
        console.error("Erro no Webhook PIX:", e);
        res.status(500).send("Erro interno");
    }
});
