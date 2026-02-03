const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { db, admin } = require("../config/firebase");

// CONFIGURAÇÃO COMUM PARA O BANCO "agenpets"
// Isso garante que o gatilho "escute" o banco correto, e não o (default)
const baseOptions = {
    database: "agenpets", // <--- OBRIGATÓRIO: Nome exato do seu banco
    region: "southamerica-east1"
};

// --- 1. GATILHO: BAIXA DE ESTOQUE AUTOMÁTICA PELA VENDA ---
// Note que agora passamos um OBJETO como primeiro argumento
exports.onVendaCriada = onDocumentCreated({
    ...baseOptions, // Espalha as opções (database e region)
    document: "tenants/{tenantId}/vendas/{vendaId}" // O caminho do documento
}, async (event) => {
    // Se o evento não tiver dados (foi deletado, por exemplo), ignoramos
    if (!event.data) return;

    const venda = event.data.data();
    const tenantId = event.params.tenantId;
    const batch = db.batch();
    const itens = venda.itens || [];

    // Itera sobre os itens da venda
    for (const item of itens) {
        // Cria registro imutável no Kardex (Movimentações)
        const movRef = db.collection("tenants")
            .doc(tenantId)
            .collection("movimentacoes_estoque")
            .doc();

        batch.set(movRef, {
            produto_id: item.id,
            produto_nome: item.nome,
            tipo: "SAIDA",
            motivo: "VENDA",
            qtd: item.qtd,
            venda_id: event.params.vendaId,
            usuario_id: venda.vendedor_codigo || "sistema",
            data: admin.firestore.FieldValue.serverTimestamp(),
        });
    }

    if (itens.length > 0) {
        await batch.commit();
        console.log(`Estoque: Movimentações geradas para venda ${event.params.vendaId}`);
    }
});

// --- 2. GATILHO: MOTOR DE ATUALIZAÇÃO DO SALDO ---
exports.onMovimentacaoCriada = onDocumentCreated({
    ...baseOptions,
    document: "tenants/{tenantId}/movimentacoes_estoque/{movId}"
}, async (event) => {
    if (!event.data) return;

    const mov = event.data.data();
    const tenantId = event.params.tenantId;
    const produtoId = mov.produto_id;

    const produtoRef = db.collection("tenants")
        .doc(tenantId)
        .collection("produtos")
        .doc(produtoId);

    // Se for SAIDA (Venda, Perda), subtrai (-1). Se for ENTRADA, soma (1).
    const fator = mov.tipo === "SAIDA" ? -1 : 1;
    const quantidadeAjuste = mov.qtd * fator;

    // Atualização atômica (segura contra concorrência)
    await produtoRef.update({
        qtd_estoque: admin.firestore.FieldValue.increment(quantidadeAjuste),
        ultima_movimentacao: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Estoque: Saldo atualizado Produto ${produtoId} (${quantidadeAjuste})`);
});