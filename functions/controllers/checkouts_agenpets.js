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
            apenasMarcarComoPronto // <--- NOVO PARÂMETRO
        } = request.data;

        if (!agendamentoId) throw new HttpsError('invalid-argument', 'ID obrigatório');

        const agendamentoRef = db.collection('agendamentos').doc(agendamentoId);
        const agendamentoSnap = await agendamentoRef.get();

        if (!agendamentoSnap.exists) throw new HttpsError('not-found', 'Agendamento não encontrado');

        const dadosAgendamento = agendamentoSnap.data();
        const userId = dadosAgendamento.userId;
        const userRef = db.collection('users').doc(userId);
        const userSnap = await userRef.get();
        const userData = userSnap.data() || {};

        // --- CÁLCULO DE VALORES ---
        // Se estiver vindo do status 'pronto', pegamos o valor acumulado até agora.
        // Se não, pegamos o original.
        let valorFinal = (dadosAgendamento.status === 'pronto' || dadosAgendamento.status === 'concluido')
            ? Number(dadosAgendamento.valor_final_cobrado || 0)
            : Number(dadosAgendamento.valor || 0);

        if (isNaN(valorFinal)) valorFinal = 0;

        let vouchersConsumidosLog = dadosAgendamento.vouchers_consumidos || {};
        let usouVoucherBase = dadosAgendamento.usou_voucher || false;
        let houveAlteracaoNoArray = false;
        let listaAssinaturas = userData.voucher_assinatura || [];

        // 1. Processa Vouchers (Geralmente feito pelo Profissional)
        if (vouchersParaUsar && Object.keys(vouchersParaUsar).length > 0) {
            const agora = admin.firestore.Timestamp.now();
            for (const [chaveServico, usar] of Object.entries(vouchersParaUsar)) {
                if (usar === true) {
                    if (vouchersConsumidosLog[chaveServico]) continue;

                    let pacoteIndex = -1;
                    // Busca pacote válido
                    for (let i = 0; i < listaAssinaturas.length; i++) {
                        const pct = listaAssinaturas[i];
                        if (pct.validade_pacote && pct.validade_pacote.seconds > agora.seconds) {
                            if (pct[chaveServico] && pct[chaveServico] > 0) {
                                pacoteIndex = i;
                                break;
                            }
                        }
                    }

                    if (pacoteIndex !== -1) {
                        listaAssinaturas[pacoteIndex][chaveServico] -= 1;
                        houveAlteracaoNoArray = true;
                        vouchersConsumidosLog[chaveServico] = {
                            usado: true,
                            responsavel: responsavel || 'Sistema',
                            data: agora
                        };
                        // Se for serviço principal, zera o valor
                        if ((chaveServico === 'banhos' || chaveServico === 'tosa')) {
                            valorFinal = 0;
                            usouVoucherBase = true;
                        }
                    }
                }
            }
        }

        // 2. Processa Extras
        let todosExtras = dadosAgendamento.extras || [];
        if (extrasIds && extrasIds.length > 0) {
            for (const extraId of extrasIds) {
                const extraDoc = await db.collection('servicos_extras').doc(extraId).get();
                if (extraDoc.exists) {
                    const extraData = extraDoc.data();
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
            // Só data final se for concluído mesmo
            ...(novoStatus === 'concluido' ? { finalizado_em: admin.firestore.FieldValue.serverTimestamp() } : {})
        });

        if (houveAlteracaoNoArray) {
            batch.update(userRef, { voucher_assinatura: listaAssinaturas });
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