const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { defineSecret, defineString } = require("firebase-functions/params");
const { db } = require("../config/firebase");
const axios = require("axios");

// --- CONFIGURAÇÃO (Segura) ---
// Para configurar o segredo: firebase functions:secrets:set META_TOKEN
const metaToken = defineSecret("META_TOKEN");
// Pode ser configurado via params ou manter default
const phoneNumberId = defineString("PHONE_NUMBER_ID", { default: "1013501445171579" });
const VERSION = "v24.0";

/**
 * GATILHO: Confirmação de Agendamento
 * Dispara quando um agendamento é criado com status 'agendado'.
 */
exports.whatsappConfirmacaoAgendamento = onDocumentCreated({
    document: "agendamentos/{id}",
    region: "southamerica-east1",
    database: "agenpets",
    secrets: [metaToken] // Garante acesso ao segredo
}, async (event) => {
    const agendamento = event.data.data();

    // Filtra agendamentos confirmados (Voucher ou Pagos)
    if (agendamento.status === 'agendado') {
        const userDoc = await db.collection('users').doc(agendamento.userId).get();
        const userData = userDoc.data();

        if (userData && userData.telefone) {
            const dataIn = agendamento.data_inicio.toDate();
            const dataFormatada = dataIn.toLocaleDateString('pt-BR');
            const horaFormatada = dataIn.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });

            // Mensagem amigável de confirmação
            await enviarWhatsApp(
                userData.telefone,
                "confirmacao_agendamento",
                [agendamento.pet_nome || "seu pet", dataFormatada, horaFormatada],
                metaToken.value(),
                phoneNumberId.value()
            );
        }
    }
});

/**
 * GATILHO: Pet Pronto para Buscar
 * Dispara quando o status muda para 'pronto' (vido do seu fluxo de checkout/checklist).
 */
exports.whatsappPetPronto = onDocumentUpdated({
    document: "agendamentos/{id}",
    region: "southamerica-east1",
    database: "agenpets",
    secrets: [metaToken] // Garante acesso ao segredo
}, async (event) => {
    if (!event.data.after.exists) return null;

    const novo = event.data.after.data();
    const antigo = event.data.before.data();

    // Dispara apenas quando o status transita para 'pronto'
    if (novo.status === 'pronto' && antigo.status !== 'pronto') {
        const userDoc = await db.collection('users').doc(novo.userId).get();
        const userData = userDoc.data();

        if (userData && userData.telefone) {
            // Mensagem legal para avisar que o pet terminou o banho/tosa
            await enviarWhatsApp(
                userData.telefone,
                "pet_pronto",
                [novo.pet_nome || "seu pet"],
                metaToken.value(),
                phoneNumberId.value()
            );
        }
    }
});

/**
 * Função Auxiliar de Envio (Axios)
 */
async function enviarWhatsApp(telefone, templateName, parametros, token, phoneId) {
    const url = `https://graph.facebook.com/${VERSION}/${phoneId}/messages`;

    try {
        await axios.post(url, {
            messaging_product: "whatsapp",
            to: telefone.replace(/\D/g, ''), // Limpa o número para conter apenas dígitos
            type: "template",
            template: {
                name: templateName,
                language: { code: "pt_BR" },
                components: [{
                    type: "body",
                    parameters: parametros.map(p => ({ type: "text", text: p }))
                }]
            }
        }, {
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });
        console.log(`WhatsApp enviado: ${templateName}`);
    } catch (error) {
        console.error("Erro WhatsApp API:", error.response ? error.response.data : error.message);
    }
}
