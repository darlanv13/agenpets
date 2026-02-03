const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db, admin } = require("../config/firebase");
const { addDays } = require("date-fns"); // Usando date-fns para consistência

// --- REALIZAR VENDA DE ASSINATURA ---
exports.realizarVendaAssinatura = onCall(async (request) => {
    const { userId, pacoteId, metodoPagamento, tenantId } = request.data;

    if (!userId || !pacoteId || !tenantId) throw new HttpsError("invalid-argument", "Dados incompletos");

    const pacoteRef = db.collection("tenants").doc(tenantId).collection("pacotes").doc(pacoteId);
    const pacoteSnap = await pacoteRef.get();
    if (!pacoteSnap.exists) throw new HttpsError("not-found", "Pacote não encontrado");
    const pacoteData = pacoteSnap.data();

    const userRef = db.collection("users").doc(userId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) throw new HttpsError("not-found", "Cliente não encontrado");

    const batch = db.batch();
    const dataVenda = admin.firestore.FieldValue.serverTimestamp();
    const validadeDate = addDays(new Date(), 30);

    // Registro da Venda
    const vendaRef = db.collection("tenants").doc(tenantId).collection("vendas_assinaturas").doc();
    batch.set(vendaRef, {
        userId, tenantId, user_nome: userSnap.data().nome || "Cliente",
        pacote_nome: pacoteData.nome, pacote_id: pacoteId, valor: Number(pacoteData.preco || 0),
        metodo_pagamento: metodoPagamento, data_venda: dataVenda, status: "pago", origem: "painel_web"
    });

    // Atualiza Voucher do Cliente na Loja
    batch.update(userRef, { assinante_ativo: true, ultima_compra: dataVenda });

    const voucherRef = userRef.collection("vouchers").doc(tenantId);
    const voucherUpdate = { ultima_compra: dataVenda, validade: admin.firestore.Timestamp.fromDate(validadeDate) };

    for (const [key, value] of Object.entries(pacoteData)) {
        if (key.startsWith("vouchers_") && typeof value === "number" && value > 0) {
            const nomeServico = key.replace("vouchers_", "");
            voucherUpdate[nomeServico] = admin.firestore.FieldValue.increment(value);
        }
    }

    batch.set(voucherRef, voucherUpdate, { merge: true });
    await batch.commit();

    return { sucesso: true, validade: validadeDate.toISOString() };
});