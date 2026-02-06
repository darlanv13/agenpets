const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { db, admin } = require("../config/firebase");
const { addDays } = require("date-fns");
const EfiPay = require("sdk-node-apis-efi");
const optionsEfi = require("../config/efipay");
const fs = require('fs');
const pixService = require("../services/pixService");

// --- 1. Gerar PIX para Assinatura (Agora com tenantId) ---
exports.gerarPixAssinatura = onCall({ cors: true }, async (request) => {
    // [MUDANÇA] Recebemos o tenantId
    const { cpf_user, pacoteId, tenantId } = request.data;

    if (!cpf_user || !pacoteId || !tenantId) {
        throw new HttpsError("invalid-argument", "CPF, ID do pacote e ID da Loja são obrigatórios.");
    }

    // 1. Busca Configuração da Loja (Chaves de API)
    const configDoc = await db.collection("tenants")
        .doc(tenantId)
        .collection("config")
        .doc("segredos")
        .get();
    const config = configDoc.exists ? configDoc.data() : {};

    // Verifica Gateway selecionado
    if (config.gateway_pagamento === "mercadopago") {
        throw new HttpsError("unimplemented", "Integração com Mercado Pago em desenvolvimento.");
    }

    // Configura credenciais dinâmicas do EfiPay
    const currentOptions = { ...optionsEfi }; // Copia padrão (incluindo certificado)

    if (config.efipay_client_id) {
        if (!config.efipay_client_secret) {
             throw new HttpsError("failed-precondition", "Configuração EfiPay incompleta: Client Secret não encontrado na loja.");
        }
        currentOptions.client_id = config.efipay_client_id;
        currentOptions.client_secret = config.efipay_client_secret;
        // Nota: O certificado ainda será o padrão definido em optionsEfi.
        // Para suporte total a contas diferentes, seria necessário gerenciar múltiplos certificados.
    }

    // Verifica certificado
    if (currentOptions.certificate) {
        if (!fs.existsSync(currentOptions.certificate)) {
            console.error(`Certificado não encontrado em: ${currentOptions.certificate}`);
            throw new HttpsError("failed-precondition", "Certificado EfiPay não configurado no servidor.");
        }
        // Verifica se é um arquivo placeholder (tamanho pequeno ou conteúdo específico)
        const certStats = fs.statSync(currentOptions.certificate);
        if (certStats.size < 100) {
            console.error("Certificado placeholder detectado.");
            throw new HttpsError("failed-precondition", "O certificado PIX não está configurado corretamente (arquivo placeholder detectado). Por favor, faça upload do certificado .p12 válido na pasta functions/certs/.");
        }
    }

    // Busca o pacote (Pode ser global ou da loja, aqui assumindo global para simplificar, mas salvando a venda na loja)
    // /db.collection('tenants').doc(tenantId).collection('pacotes').doc(pacoteId)...
    const pacoteRef = db.collection("tenants").doc(tenantId).collection("pacotes").doc(pacoteId);
    const pacoteSnap = await pacoteRef.get();

    if (!pacoteSnap.exists) {
        throw new HttpsError("not-found", "Pacote não encontrado.");
    }

    const pacoteData = pacoteSnap.data();
    const valor = parseFloat(pacoteData.preco);

    if (isNaN(valor) || valor <= 0) {
        throw new HttpsError("invalid-argument", "Valor do pacote inválido.");
    }

    const nomePacote = pacoteData.nome || "Pacote AgenPet";

    // Extrai Vouchers (Snapshot)
    const vouchersSnapshot = {};
    for (const [key, value] of Object.entries(pacoteData)) {
        if (key.startsWith("vouchers_") && typeof value === "number" && value > 0) {
            // Remove o prefixo 'vouchers_' para ficar limpo no banco (ex: 'banho': 4)
            const nomeServico = key.replace("vouchers_", "");
            vouchersSnapshot[nomeServico] = value;
        }
    }

    // Gera Cobrança na EfiPay
    let pixCopiaCola = ""; let imagemQrcode = ""; let txid = "";

    try {
        const efipay = new EfiPay(currentOptions);
        const cpfLimpo = cpf_user.replace(/\D/g, "");

        // Usa chave PIX da config se existir, senão usa padrão
        const chavePix = config.chave_pix || "client_id_homologacao";

        const bodyPix = {
            calendario: { expiracao: 3600 },
            devedor: { cpf: cpfLimpo, nome: "Cliente AgenPet" },
            valor: { original: valor.toFixed(2) },
            chave: chavePix,
        };

        const cobranca = await efipay.pixCreateImmediateCharge([], bodyPix);
        txid = cobranca.txid;

        const qrCode = await efipay.pixGenerateQRCode({ id: cobranca.loc.id });
        pixCopiaCola = qrCode.qrcode;
        imagemQrcode = qrCode.imagemQrcode;
    } catch (error) {
        console.error("Erro EfiPay:", JSON.stringify(error, null, 2));
        // Tenta extrair a mensagem de erro de várias formas comuns em bibliotecas Node/Axios/Efi
        const msg = error.message ||
                    error.error_description ||
                    (error.error ? error.error.toString() : null) ||
                    (typeof error === 'string' ? error : "Erro desconhecido");

        throw new HttpsError("internal", "Erro ao gerar PIX: " + msg);
    }

    // Salva a Venda 'Pendente' com o ID DA LOJA
    const vendaRef = db.collection("tenants").doc(tenantId).collection("vendas_assinaturas").doc();

    await vendaRef.set({
        userId: cpf_user,
        tenantId: tenantId, // <--- CAMPO CRUCIAL PARA O SAAS
        pacote_id: pacoteId,
        pacote_nome: nomePacote,
        valor: valor,
        txid: txid,
        status: "pendente",
        vouchers_snapshot: vouchersSnapshot,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        metodo_pagamento: "pix",
    });

    return {
        pix_copia_cola: pixCopiaCola,
        imagem_qrcode: imagemQrcode,
        vendaId: vendaRef.id,
        valor: valor,
    };
});

// --- 2. Webhook Unificado (Entrega o voucher na carteira da Loja) ---
exports.webhookPix = onRequest({ cors: true }, async (req, res) => {
    const { pix } = req.body;

    if (!pix || !Array.isArray(pix)) {
        return res.status(400).send("Body inválido");
    }

    try {
        await pixService.processarPixEvents(pix);
        res.status(200).send();
    } catch (e) {
        console.error("Erro no Webhook PIX:", e);
        res.status(500).send("Erro interno");
    }
});
