const functions = require("firebase-functions");
const { db, admin } = require("../config/firebase");

exports.reservar = functions.region('southamerica-east1').https.onCall(async (data, context) => {
    const { check_in, check_out, pet_id, cpf_user } = data;

    const start = new Date(check_in);
    const end = new Date(check_out);

    // Referência para as reservas
    const reservasRef = db.collection("reservas_hotel");

    // Otimização: Busca apenas reservas que podem conflitar (que terminam depois que você chega)
    const snapshot = await reservasRef
        .where("check_out", ">", start)
        .get();

    let vagasOcupadas = 0;

    // Filtragem fina em memória
    snapshot.forEach(doc => {
        const r = doc.data();
        const rIn = r.check_in.toDate();
        // Se a reserva existente começa antes do meu checkout, há colisão
        if (rIn < end) {
            vagasOcupadas++;
        }
    });

    // Validação de Capacidade (60 vagas)
    if (vagasOcupadas >= 60) {
        throw new functions.https.HttpsError('resource-exhausted', 'Hotel lotado para este período.');
    }

    // Cria a reserva
    await reservasRef.add({
        cpf_user,
        pet_id,
        check_in: admin.firestore.Timestamp.fromDate(start),
        check_out: admin.firestore.Timestamp.fromDate(end),
        status: 'reservado',
        created_at: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, mensagem: "Reserva confirmada!" };
});