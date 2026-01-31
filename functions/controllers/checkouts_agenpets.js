const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { db, admin } = require("../config/firebase"); // O admin é essencial para datas!
const { addMinutes, format, parse, isSameDay } = require("date-fns"); // date-fns essencial
const EfiPay = require("sdk-node-apis-efi");
const optionsEfi = require("../config/efipay");

function addDays(date, days) {
    var result = new Date(date);
    result.setDate(result.getDate() + days);
    return result;
}

exports.realizarCheckout = onCall(async (request) => {
    try {
        const {
            agendamentoId,
            extrasIds,
            metodoPagamento,
            vouchersParaUsar,
            responsavel,
            apenasMarcarComoPronto, // <--- NOVO PARÂMETRO
            tenantId
        } = request.data;

        if (!agendamentoId) throw new HttpsError('invalid-argument', 'ID obrigatório');
        if (!tenantId) throw new HttpsError('invalid-argument', 'ID da loja (tenantId) é obrigatório.');

        const agendamentoRef = db.collection("tenants").doc(tenantId).collection('agendamentos').doc(agendamentoId);
        const agendamentoSnap = await agendamentoRef.get();

        if (!agendamentoSnap.exists) throw new HttpsError('not-found', 'Agendamento não encontrado');

        const dadosAgendamento = agendamentoSnap.data();
        const userId = dadosAgendamento.userId;
        const userRef = db.collection('users').doc(userId);
        // Não precisamos do userSnap global para vouchers, apenas para logs se quiser

        // Referência dos Vouchers da Loja
        const voucherRef = userRef.collection('vouchers').doc(tenantId);
        const voucherSnap = await voucherRef.get();
        const voucherData = voucherSnap.exists ? voucherSnap.data() : {};

        // --- CÁLCULO DE VALORES ---
        let valorFinal = (dadosAgendamento.status === 'pronto' || dadosAgendamento.status === 'concluido')
            ? Number(dadosAgendamento.valor_final_cobrado || 0)
            : Number(dadosAgendamento.valor || 0);

        if (isNaN(valorFinal)) valorFinal = 0;

        let vouchersConsumidosLog = dadosAgendamento.vouchers_consumidos || {};
        let usouVoucherBase = dadosAgendamento.usou_voucher || false;

        // Batch para atualização de vouchers (separado do update do agendamento se quiser, mas aqui usamos o mesmo batch no final?
        // O código original usava 'batch' lá embaixo. Vamos usar um novo batch ou passar update para o batch final.
        // O código original criava 'batch' APÓS o loop. Vamos acumular os updates.

        const updatesVoucher = {};

        // 1. Processa Vouchers
        if (vouchersParaUsar && Object.keys(vouchersParaUsar).length > 0) {
            const agora = admin.firestore.Timestamp.now();

            // Verifica Validade Geral da Loja
            const validade = voucherData.validade; // Timestamp
            const isValido = validade && validade.seconds > agora.seconds;

            if (isValido) {
                for (const [chaveServico, usar] of Object.entries(vouchersParaUsar)) {
                    if (usar === true) {
                        if (vouchersConsumidosLog[chaveServico]) continue;

                        // Verifica saldo específico (ex: 'banho', 'tosa')
                        const saldo = voucherData[chaveServico] || 0;

                        if (saldo > 0) {
                            // Decrementa
                            updatesVoucher[chaveServico] = admin.firestore.FieldValue.increment(-1);

                            vouchersConsumidosLog[chaveServico] = {
                                usado: true,
                                responsavel: responsavel || 'Sistema',
                                data: agora
                            };

                            // Zera valor se for serviço base
                            if ((chaveServico === 'banho' || chaveServico === 'tosa' || chaveServico === 'banhos' || chaveServico === 'tosas')) {
                                valorFinal = 0;
                                usouVoucherBase = true;
                            }
                        }
                    }
                }
            }
        }

        // 2. Processa Extras
        let todosExtras = dadosAgendamento.extras || [];
        if (extrasIds && extrasIds.length > 0) {
            for (const extraId of extrasIds) {
                let extraDoc = await db.collection("tenants").doc(tenantId).collection('servicos_extras').doc(extraId).get();
                let extraData = extraDoc.exists ? extraDoc.data() : null;

                if (!extraDoc.exists) {
                    extraDoc = await db.collection("tenants").doc(tenantId).collection('produtos').doc(extraId).get();
                    if (extraDoc.exists) extraData = extraDoc.data();
                }

                if (extraDoc.exists && extraData) {
                    let precoRaw = extraData.preco;
                    if (typeof precoRaw === 'string') precoRaw = precoRaw.replace(',', '.');
                    const precoReal = Number(precoRaw || 0);

                    if (!isNaN(precoReal)) {
                        valorFinal += precoReal;
                        todosExtras.push({
                            id: extraId,
                            nome: extraData.nome || 'Item Extra',
                            preco: precoReal,
                            adicionado_por: responsavel || 'Caixa',
                            adicionado_em: admin.firestore.Timestamp.now()
                        });
                    }
                }
            }
        }

        // --- DEFINIÇÃO DE STATUS ---
        // Se apenasMarcarComoPronto for true (App Profissional), o status vira 'pronto'.
        // Caso contrário (Painel Caixa), vira 'concluido'.
        const novoStatus = apenasMarcarComoPronto ? 'pronto' : 'concluido';

        // Pagamento: Se for 'pronto', o pagamento continua 'pendente' (esperando o caixa).
        // Se for 'concluido', verificamos se pagou.
        let statusPagamento = dadosAgendamento.status_pagamento || 'pendente';

        if (!apenasMarcarComoPronto) {
            // Lógica de fechamento final do Caixa
            if (valorFinal <= 0 || (metodoPagamento && metodoPagamento !== 'voucher')) {
                statusPagamento = 'pago';
            }
        }

        const metodoFinal = (valorFinal > 0 && metodoPagamento)
            ? metodoPagamento
            : (dadosAgendamento.metodo_pagamento || 'voucher');

        // Atualiza Banco
        const batch = db.batch();
        batch.update(agendamentoRef, {
            status: novoStatus,
            status_pagamento: statusPagamento,
            metodo_pagamento: metodoFinal,
            valor_final_cobrado: valorFinal,
            vouchers_consumidos: vouchersConsumidosLog,
            extras: todosExtras,
            usou_voucher: usouVoucherBase,
            ...(novoStatus === 'concluido' ? { finalizado_em: admin.firestore.FieldValue.serverTimestamp() } : {})
        });

        // Aplica updates nos vouchers se houver consumo
        if (Object.keys(updatesVoucher).length > 0) {
            batch.update(voucherRef, updatesVoucher);
        }

        await batch.commit();

        return {
            sucesso: true,
            mensagem: apenasMarcarComoPronto ? 'Pet pronto! Enviado para o caixa.' : 'Checkout finalizado!',
            valorCobrado: valorFinal
        };

    } catch (e) {
        console.error("Erro Checkout:", e);
        throw new HttpsError('internal', e.message);
    }
});