const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { db, admin } = require("../config/firebase");

// Configuração padrão
const baseOptions = {
    database: "agenpets",
    region: "southamerica-east1"
};

// --- GATILHO: PROCESSAR COMANDA AO CRIAR VENDA ---
// Este gatilho garante que, quando uma venda é registrada no PDV (client-side),
// a comanda associada e o documento original (agendamento/reserva) sejam atualizados de forma robusta.
// Embora o frontend tente fazer isso, o backend garante a consistência eventual.

exports.onVendaComanda = onDocumentCreated({
    ...baseOptions,
    document: "tenants/{tenantId}/vendas/{vendaId}"
}, async (event) => {
    if (!event.data) return; // Documento deletado

    const venda = event.data.data();
    const tenantId = event.params.tenantId;
    const comandaId = venda.comanda_id;

    // Se não tem comanda associada, ignora (venda avulsa de produtos)
    if (!comandaId) return;

    try {
        const comandaRef = db.collection("tenants").doc(tenantId).collection("comandas").doc(comandaId);
        const comandaSnap = await comandaRef.get();

        if (!comandaSnap.exists) {
            console.error(`Comanda ${comandaId} não encontrada para venda ${event.params.vendaId}`);
            return;
        }

        const comanda = comandaSnap.data();

        // 1. Atualizar Status da Comanda
        if (comanda.status !== 'pago') {
            await comandaRef.update({
                status: 'pago',
                venda_id: event.params.vendaId,
                pago_em: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log(`Comanda ${comandaId} marcada como PAGA.`);
        }

        // 2. Atualizar Documento de Origem (Agendamento, Hotel, Creche)
        const origemCollection = comanda.origem_collection;
        const origemId = comanda.origem_id;

        if (origemCollection && origemId) {
            const origemRef = db.collection("tenants").doc(tenantId).collection(origemCollection).doc(origemId);

            // Verifica se já está concluído para evitar loops ou writes desnecessários
            const origemSnap = await origemRef.get();
            if (origemSnap.exists) {
                const origemData = origemSnap.data();

                // Só atualiza se ainda não estiver concluído/pago
                if (origemData.status !== 'concluido' || origemData.status_pagamento !== 'pago') {
                    await origemRef.update({
                        status: 'concluido',
                        status_pagamento: 'pago',
                        valor_final_cobrado: Number(venda.valor_total || 0),
                        data_pagamento: admin.firestore.FieldValue.serverTimestamp(),
                        metodo_pagamento_final: 'pdv_comanda'
                    });
                    console.log(`Documento origem (${origemCollection}/${origemId}) finalizado.`);
                }
            }
        }

    } catch (e) {
        console.error(`Erro ao processar comanda da venda ${event.params.vendaId}:`, e);
    }
});
