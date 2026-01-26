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
            produtos, // <--- NOVO: Lista de produtos [{id, qtd}]
            pagamentos // <--- NOVO: Lista de pagamentos [{metodo, valor}]
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

        // 3. Processa Produtos (Store Integration)
        let produtosConsumidos = [];
        const batch = db.batch(); // Já usamos batch, vamos aproveitar

        if (produtos && produtos.length > 0) {
            for (const item of produtos) {
                if (!item.id || !item.qtd) continue;

                const prodRef = db.collection('produtos').doc(item.id);
                const prodDoc = await prodRef.get();

                if (prodDoc.exists) {
                    const prodData = prodDoc.data();
                    const preco = Number(prodData.preco || 0);
                    const qtd = Number(item.qtd);

                    const subtotal = preco * qtd;
                    valorFinal += subtotal;

                    produtosConsumidos.push({
                        id: item.id,
                        nome: prodData.nome,
                        qtd: qtd,
                        precoUnitario: preco,
                        subtotal: subtotal,
                        adicionado_em: admin.firestore.Timestamp.now()
                    });

                    // Atualiza Estoque (Decrementa Estoque, Incrementa Vendas)
                    batch.update(prodRef, {
                        qtd_estoque: admin.firestore.FieldValue.increment(-qtd),
                        qtd_vendida: admin.firestore.FieldValue.increment(qtd)
                    });
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
        let totalPago = 0;

        // Processa Pagamentos (Array ou Single Legacy)
        let pagamentosFinais = [];
        if (!apenasMarcarComoPronto) {
            if (pagamentos && Array.isArray(pagamentos)) {
                 pagamentos.forEach(p => {
                     totalPago += Number(p.valor || 0);
                     pagamentosFinais.push(p);
                 });
            } else if (metodoPagamento) {
                // Legacy support
                totalPago = valorFinal; // Assume full payment if single method passed
                pagamentosFinais.push({ metodo: metodoPagamento, valor: valorFinal });
            }

            // Lógica de fechamento final do Caixa
            if (valorFinal <= 0 || totalPago >= (valorFinal - 0.1)) {
                statusPagamento = 'pago';
            }
        }

        const metodoFinal = pagamentosFinais.length > 0
            ? pagamentosFinais.map(p => p.metodo).join(', ')
            : (dadosAgendamento.metodo_pagamento || 'voucher');

        // Atualiza Banco
        // Nota: O batch já foi inicializado acima para produtos
        batch.update(agendamentoRef, {
            status: novoStatus,
            status_pagamento: statusPagamento,
            metodo_pagamento: metodoFinal, // String concatenada para visualização simples
            pagamentos_detalhados: pagamentosFinais, // Array estruturado
            valor_final_cobrado: valorFinal,
            vouchers_consumidos: vouchersConsumidosLog,
            extras: todosExtras,
            produtos_consumidos: produtosConsumidos, // Salva os produtos
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