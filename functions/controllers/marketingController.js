const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret, defineString } = require("firebase-functions/params");
const { db } = require("../config/firebase");
const { enviarWhatsApp } = require("./notifications_whatsapp");

// --- CONFIGURAÇÃO ---
const metaToken = defineSecret("META_TOKEN");
const phoneNumberId = defineString("PHONE_NUMBER_ID", { default: "1013501445171579" });

/**
 * JOB: Lembrete de Vacinas (Diário às 09:00)
 * Busca vacinas que vencem em 3 dias e avisa o tutor.
 */
exports.enviarLembreteVacinas = onSchedule({
    schedule: "every day 09:00",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
    secrets: [metaToken]
}, async (event) => {
    console.log("Iniciando verificação de vacinas...");

    // Data Alvo: Daqui a 3 dias
    const hoje = new Date();
    const alvo = new Date(hoje);
    alvo.setDate(hoje.getDate() + 3);

    const inicioDia = new Date(alvo);
    inicioDia.setHours(0, 0, 0, 0);

    const fimDia = new Date(alvo);
    fimDia.setHours(23, 59, 59, 999);

    console.log(`Buscando vacinas vencendo em: ${inicioDia.toLocaleDateString()}`);

    try {
        // Busca Global (Collection Group) - Requer Índice Composto se tiver muitos filtros
        // Filtra vacinas com revacinação agendada para o dia alvo
        const snapshot = await db.collectionGroup('vacinas')
            .where('data_revacina', '>=', inicioDia)
            .where('data_revacina', '<=', fimDia)
            .get();

        if (snapshot.empty) {
            console.log("Nenhuma vacina encontrada para o período.");
            return;
        }

        console.log(`Encontradas ${snapshot.size} vacinas vencendo.`);

        let envios = 0;

        for (const doc of snapshot.docs) {
            const vacina = doc.data();

            // Navegar na hierarquia para achar Pet e Tutor
            // Path: users/{userId}/pets/{petId}/vacinas/{vacinaId}
            const vacinaRef = doc.ref;
            const petRef = vacinaRef.parent.parent;
            if (!petRef) continue;

            const userRef = petRef.parent.parent;
            if (!userRef) continue;

            // Otimização: Poderia usar Promise.all para buscar pet e user em paralelo
            const [petSnap, userSnap] = await Promise.all([
                petRef.get(),
                userRef.get()
            ]);

            if (!petSnap.exists || !userSnap.exists) continue;

            const pet = petSnap.data();
            const user = userSnap.data();

            if (user.telefone) {
                // Envia WhatsApp
                // Template esperado: "lembrete_vacina"
                // Parâmetros: {{1}} Nome Tutor, {{2}} Nome Pet, {{3}} Nome Vacina
                await enviarWhatsApp(
                    user.telefone,
                    "lembrete_vacina",
                    [
                        user.nome ? user.nome.split(' ')[0] : "Tutor",
                        pet.nome || "seu pet",
                        vacina.nome || "Vacina"
                    ],
                    metaToken.value(),
                    phoneNumberId.value()
                );
                envios++;
            }
        }
        console.log(`Processamento concluído. ${envios} mensagens enviadas.`);

    } catch (e) {
        console.error("Erro ao processar lembretes de vacina:", e);
    }
});
