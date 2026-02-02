const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
// AQUI: Importamos 'db' para manter o padrão do projeto, junto com 'admin' para o messaging
const {db, admin} = require("../config/firebase");

exports.notificarPetPronto = onDocumentUpdated({
  document: "agendamentos/{agendamentoId}",
  region: "southamerica-east1",
  database: "agenpets", // Importante: Aceita o banco mesmo se não chamar (default)
}, async (event) => {
  // Verificação de segurança (documento existe?)
  if (!event.data || !event.data.after.exists) {
    return null;
  }

  const dadosNovos = event.data.after.data();
  const dadosAntigos = event.data.before.data();

  // LÓGICA: Status mudou para 'pronto'?
  if (dadosNovos.status === "pronto" && dadosAntigos.status !== "pronto") {
    const userId = dadosNovos.userId;
    const nomePet = dadosNovos.pet_nome || "seu pet";
    const agendamentoId = event.params.agendamentoId;

    try {
      // PADRÃO MANTIDO: Usando 'db' direto em vez de admin.firestore()
      const userDoc = await db.collection("users").doc(userId).get();
      const userData = userDoc.data();

      if (!userData || !userData.fcmToken) {
        console.log(`Usuário ${userId} sem token.`);
        return null;
      }

      // Monta a notificação
      const payload = {
        notification: {
          title: `🐶 ${nomePet} está pronto!`,
          body: `Tudo limpinho! O banho/tosa acabou e você já pode buscar.`,
          sound: "default",
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          rota: "/minhas_agendas",
          agendamentoId: agendamentoId,
        },
      };

      // Envia (Messaging ainda precisa do admin, pois não é banco de dados)
      await admin.messaging().sendToDevice(userData.fcmToken, payload);
      console.log(`Notificação enviada: ${userId}`);
    } catch (error) {
      console.error("Erro na notificação:", error);
    }
  }
  return null;
});
