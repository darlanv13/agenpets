const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { db, admin } = require("../config/firebase");
const axios = require("axios");

// --- CONFIGURAÇÃO FINAL AGEN PETS ---
const EVOLUTION_URL = "http://34.39.219.1:8080";
const API_KEY = "agenpets_secret_key_2026";
const INSTANCE_NAME = "agenpets_main";

/**
 * Função Auxiliar de Envio (Texto Simples)
 */
async function enviarWhatsApp(telefone, mensagem) {
    // Endpoint para envio de texto da Evolution API v2
    const url = `${EVOLUTION_URL}/message/sendText/${INSTANCE_NAME}`;

    try {
        await axios.post(url, {
            number: telefone.replace(/\D/g, ''), // Remove formatação (ex: +55...)
            options: {
                delay: 1200,
                presence: "composing", // Mostra "digitando..."
                linkPreview: false
            },
            textMessage: {
                text: mensagem
            }
        }, {
            headers: {
                'apikey': API_KEY,
                'Content-Type': 'application/json'
            }
        });
        console.log(`[AgenPets] WhatsApp enviado para ${telefone}`);
    } catch (error) {
        console.error("[AgenPets] Erro no envio:", error.response ? error.response.data : error.message);
    }
}

// --- GATILHO: Confirmação de Agendamento ---
exports.whatsappConfirmacaoAgendamento = onDocumentCreated({
    document: "agendamentos/{id}",
    region: "southamerica-east1",
    database: "agenpets"  // Importante: Aceita o banco mesmo se não chamar (default)
}, async (event) => {
    const agendamento = event.data.data();

    if (agendamento.status === 'agendado') {
        const userDoc = await db.collection('users').doc(agendamento.userId).get();
        const userData = userDoc.data();

        if (userData && userData.telefone) {
            const dataIn = agendamento.data_inicio.toDate();
            const dataFormatada = dataIn.toLocaleDateString('pt-BR');
            const horaFormatada = dataIn.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });

            const msg = `Olá! O agendamento de *${agendamento.pet_nome || "seu pet"}* para o dia ${dataFormatada} às ${horaFormatada} foi confirmado! 🐾`;
            await enviarWhatsApp(userData.telefone, msg);
        }
    }
});