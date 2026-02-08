const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db, admin } = require("../config/firebase");

// --- FUNÇÃO OBSOLETA ---
// O Checkout agora é realizado via PDV (Comandas)
// Este arquivo é mantido apenas para evitar quebras de importação antigas, mas a função está desativada.

exports.realizarCheckout = onCall(async (request) => {
    throw new HttpsError('unimplemented', 'Esta função foi descontinuada. Use o PDV.');
});
