const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { db, admin } = require("../config/firebase");
const { addDays } = require("date-fns");
const EfiPay = require("sdk-node-apis-efi");
const optionsEfi = require("../config/efipay");
const fs = require('fs');
const pixService = require("../services/pixService");
const axios = require('axios');

// --- 1. Gerar PIX para Assinatura (Agora com tenantId) ---
exports.gerarPixAssinatura = onCall({ cors: true }, async (request) => {
    // [MUDANÇA] Recebemos o tenantId
    const { cpf_user, pacoteId, tenantId } = request.data;

    if (!cpf_user || !pacoteId || !tenantId) {
        throw new HttpsError("invalid-argument", "CPF, ID do pacote e ID da Loja são obrigatórios.");
    }

    // 1. Busca Configuração da Loja (Chaves de API)
    // Busca configs públicas (para saber o gateway selecionado)
    const paramsDoc = await db.collection("tenants")
        .doc(tenantId)
        .collection("config")
        .doc("parametros")
        .get();
    const params = paramsDoc.exists ? paramsDoc.data() : {};

    const gatewaySelecionado = params.gateway_pagamento || "efipay";

    // Busca segredos
    const segredosDoc = await db.collection("tenants")
        .doc(tenantId)
        .collection("config")
        .doc("segredos")
        .get();
    const config = segredosDoc.exists ? segredosDoc.data() : {};

    // Busca o pacote (Pode ser global ou da loja, aqui assumindo global para simplificar, mas salvando a venda na loja)
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
    const cpfLimpo = cpf_user.replace(/\D/g, "");

    // Extrai Vouchers (Snapshot)
    const vouchersSnapshot = {};
    for (const [key, value] of Object.entries(pacoteData)) {
        if (key.startsWith("vouchers_") && typeof value === "number" && value > 0) {
            // Remove o prefixo 'vouchers_' para ficar limpo no banco (ex: 'banho': 4)
            const nomeServico = key.replace("vouchers_", "");
            vouchersSnapshot[nomeServico] = value;
        }
    }

    let pixCopiaCola = ""; let imagemQrcode = ""; let txid = "";
    let metodoPagamento = "pix";

    // =========================================================================
    // BRANCH: MERCADO PAGO
    // =========================================================================
    if (gatewaySelecionado === "mercadopago") {
        const mpAccessToken = config.mercadopago_access_token;
        if (!mpAccessToken) {
            throw new HttpsError("failed-precondition", "Token do Mercado Pago não configurado na loja.");
        }

        try {
            // Busca e-mail do usuário para preencher o payer (obrigatório/recomendado)
            const userDoc = await db.collection("users").doc(cpf_user).get();
            const emailUser = userDoc.exists ? userDoc.data().email : "cliente@agenpets.com.br";
            const nomeUser = userDoc.exists ? userDoc.data().nome : "Cliente AgenPet";
            const [firstName, ...rest] = nomeUser.split(" ");
            const lastName = rest.join(" ");

            const paymentData = {
                transaction_amount: valor,
                description: nomePacote,
                payment_method_id: "pix",
                payer: {
                    email: emailUser,
                    first_name: firstName,
                    last_name: lastName || "Sobrenome",
                    identification: {
                        type: "CPF",
                        number: cpfLimpo
                    }
                },
                // Opcional: notification_url: `https://.../webhookMercadoPago`
            };

            const response = await axios.post("https://api.mercadopago.com/v1/payments", paymentData, {
                headers: {
                    "Authorization": `Bearer ${mpAccessToken}`,
                    "Content-Type": "application/json",
                    "X-Idempotency-Key": `${tenantId}-${pacoteId}-${Date.now()}`
                }
            });

            const data = response.data;
            txid = data.id.toString(); // Mercado Pago usa o ID numérico como identificador principal

            const qrInfo = data.point_of_interaction?.transaction_data;
            if (qrInfo) {
                pixCopiaCola = qrInfo.qr_code;
                imagemQrcode = qrInfo.qr_code_base64;
            }
            metodoPagamento = "mercadopago_pix";

        } catch (error) {
            console.error("Erro Mercado Pago:", error.response ? error.response.data : error.message);
            const msg = error.response?.data?.message || error.message || "Erro ao criar PIX no Mercado Pago.";
            throw new HttpsError("internal", "Erro Mercado Pago: " + msg);
        }

    }
    // =========================================================================
    // BRANCH: EFIPAY (Padrão)
    // =========================================================================
    else {
        // Configura credenciais dinâmicas do EfiPay
        const currentOptions = { ...optionsEfi }; // Copia padrão (incluindo certificado)

        if (config.efipay_client_id) {
            if (!config.efipay_client_secret) {
                throw new HttpsError("failed-precondition", "Configuração EfiPay incompleta: Client Secret não encontrado na loja.");
            }
            currentOptions.client_id = config.efipay_client_id;
            currentOptions.client_secret = config.efipay_client_secret;
        }

        // Verifica certificado
        if (currentOptions.certificate) {
            if (!fs.existsSync(currentOptions.certificate)) {
                console.error(`Certificado não encontrado em: ${currentOptions.certificate}`);
                throw new HttpsError("failed-precondition", "Certificado EfiPay não configurado no servidor.");
            }
            const certStats = fs.statSync(currentOptions.certificate);
            if (certStats.size < 100) {
                console.error("Certificado placeholder detectado.");
                throw new HttpsError("failed-precondition", "O certificado PIX não está configurado corretamente (arquivo placeholder detectado).");
            }
        }

        try {
            const efipay = new EfiPay(currentOptions);
            // Usa chave PIX da config se existir, senão usa padrão
            // Tenta pegar de segredos (caso tenha migrado) ou parametros (padrão)
            const chavePix = config.chave_pix || params.chave_pix || "client_id_homologacao";

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
            const msg = error.message ||
                        error.error_description ||
                        (error.error ? error.error.toString() : null) ||
                        (typeof error === 'string' ? error : "Erro desconhecido");

            throw new HttpsError("internal", "Erro ao gerar PIX: " + msg);
        }
    }

    // Salva a Venda 'Pendente' com o ID DA LOJA
    const vendaRef = db.collection("tenants").doc(tenantId).collection("vendas_assinaturas").doc();

    await vendaRef.set({
        userId: cpf_user,
        tenantId: tenantId,
        pacote_id: pacoteId,
        pacote_nome: nomePacote,
        valor: valor,
        txid: txid,
        status: "pendente",
        vouchers_snapshot: vouchersSnapshot,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        metodo_pagamento: metodoPagamento,
        gateway: gatewaySelecionado
    });

    return {
        pix_copia_cola: pixCopiaCola,
        imagem_qrcode: imagemQrcode,
        vendaId: vendaRef.id,
        valor: valor,
        gateway: gatewaySelecionado
    };
});

// --- 2. Webhook Unificado EfiPay ---
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

// --- 3. Webhook Mercado Pago ---
exports.webhookMercadoPago = onRequest({ cors: true }, async (req, res) => {
    // Mercado Pago envia query params ou body dependendo do tipo.
    // Geralmente POST com { action: 'payment.created', data: { id: '...' } } ou 'topic=payment' na query.

    // Verifica se é notificação de pagamento
    const topic = req.query.topic || req.body.type;
    const id = req.query.id || req.body.data?.id;

    if ((topic === 'payment' || req.body.action === 'payment.updated') && id) {
        try {
            // Precisamos buscar o status atualizado do pagamento na API do MP
            // O problema é saber de QUAL loja é esse pagamento para pegar o token correto.
            // Solução Ideal: Webhook URL contendo o tenantId ou buscar em todas as lojas (lento).
            // Solução Pragmática (AgenPets):
            // 1. Busca a venda pelo txid (que salvamos como sendo o ID do MP) em collectionGroup
            const vendaSnap = await db.collectionGroup("vendas_assinaturas").where("txid", "==", id.toString()).get();

            if (vendaSnap.empty) {
                console.log(`Venda MP não encontrada para ID: ${id}`);
                return res.status(200).send(); // Retorna 200 para o MP parar de enviar
            }

            const vendaDoc = vendaSnap.docs[0];
            const vendaData = vendaDoc.data();
            const tenantId = vendaData.tenantId;

            // Busca credencial da loja
            const segredosDoc = await db.collection("tenants").doc(tenantId).collection("config").doc("segredos").get();
            const token = segredosDoc.data()?.mercadopago_access_token;

            if (!token) {
                console.error(`Token MP não encontrado para tenant: ${tenantId}`);
                return res.status(200).send();
            }

            // Consulta API MP
            const mpResponse = await axios.get(`https://api.mercadopago.com/v1/payments/${id}`, {
                headers: { "Authorization": `Bearer ${token}` }
            });

            const status = mpResponse.data.status;

            if (status === 'approved') {
                // Simula evento PIX para aproveitar o serviço existente
                // O serviço espera { txid }
                const eventoSimulado = [{ txid: id.toString() }];
                await pixService.processarPixEvents(eventoSimulado);
            }

            res.status(200).send();
        } catch (e) {
            console.error("Erro Webhook MP:", e);
            res.status(500).send();
        }
    } else {
        // Outros tópicos (merchant_order, etc), ignoramos por enquanto
        res.status(200).send();
    }
});
