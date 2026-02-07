const { db, admin } = require("../config/firebase");
const { addDays } = require("date-fns");

/**
 * Processa lista de eventos PIX (geralmente recebidos via Webhook ou simulação)
 * @param {Array} pixList Lista de objetos pix contendo { txid, ... }
 * @return {Promise<void>}
 */
exports.processarPixEvents = async (pixList) => {
    if (!pixList || !Array.isArray(pixList)) {
        throw new Error("Lista de PIX inválida para processamento.");
    }

    for (const p of pixList) {
        const txid = p.txid;
        const tenantId = p.tenantId; // Pode vir do webhook
        console.log(`Processando PIX txid: ${txid} (Tenant: ${tenantId || 'Desconhecido'})`);

        // A. Tenta atualizar AGENDAMENTO
        let agendamentoSnap;
        if (tenantId) {
            // Busca direta (Mais eficiente e não precisa de índice global)
            agendamentoSnap = await db.collection("tenants").doc(tenantId).collection("agendamentos").where("txid", "==", txid).get();
        } else {
            // Busca global (Fallback - precisa de índice collectionGroup)
            agendamentoSnap = await db.collectionGroup("agendamentos").where("txid", "==", txid).get();
        }

        if (!agendamentoSnap.empty) {
            const batch = db.batch();
            agendamentoSnap.forEach((doc) => {
                batch.update(doc.ref, { status: "agendado" });
            });
            await batch.commit();
            console.log(`Agendamento(s) confirmado(s) para txid: ${txid}`);
            continue; // Se achou agendamento, assume que não é venda de pacote
        }

        // B. Tenta atualizar VENDA DE ASSINATURA/PACOTE
        let vendaSnap;
        if (tenantId) {
            // Busca direta
            vendaSnap = await db.collection("tenants").doc(tenantId).collection("vendas_assinaturas").where("txid", "==", txid).get();
        } else {
            // Busca global
            vendaSnap = await db.collectionGroup("vendas_assinaturas").where("txid", "==", txid).get();
        }

        if (!vendaSnap.empty) {
            const vendaDoc = vendaSnap.docs[0];
            const vendaData = vendaDoc.data();

            if (vendaData.status !== "pago") {
                const userId = vendaData.userId;
                const tenantId = vendaData.tenantId; // Recupera a loja
                const vouchersSnapshot = vendaData.vouchers_snapshot || {};
                const dataPagamento = admin.firestore.Timestamp.now();
                const validadeDate = addDays(new Date(), 30);

                // Caminho: users/{cpf}/vouchers/{tenantId}
                const userVoucherRef = db.collection("users")
                    .doc(userId)
                    .collection("vouchers")
                    .doc(tenantId);

                const batch = db.batch();

                // 1. Atualiza status da venda
                batch.update(vendaDoc.ref, {
                    status: "pago",
                    data_pagamento: dataPagamento,
                });

                // 2. Prepara atualização dos vouchers na loja específica
                const updatesVoucher = {
                    ultima_compra: dataPagamento,
                    validade: admin.firestore.Timestamp.fromDate(validadeDate),
                };

                // Soma os novos vouchers ao saldo existente (Atomicamente)
                for (const [servico, qtd] of Object.entries(vouchersSnapshot)) {
                    updatesVoucher[servico] = admin.firestore.FieldValue.increment(qtd);
                }

                // Usa 'set' com 'merge' para criar o documento se for a 1ª vez nessa loja
                batch.set(userVoucherRef, updatesVoucher, { merge: true });

                await batch.commit();
                console.log(`Venda ${vendaDoc.id} paga. Vouchers entregues na loja ${tenantId}.`);
            } else {
                console.log(`Venda ${vendaDoc.id} já estava paga.`);
            }
        } else {
            console.log(`Nenhum agendamento ou venda encontrada para txid: ${txid}`);
        }
    }
};
