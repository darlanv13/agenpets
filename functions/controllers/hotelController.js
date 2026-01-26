const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { eachDayOfInterval, format, isWithinInterval, startOfDay, addDays } = require("date-fns");
const { db, admin } = require("../config/firebase");

exports.reservarHotel = onCall(async (request) => {
    try {
        console.log("Iniciando reserva...", request.data);
        const { check_in, check_out, pet_id, cpf_user } = request.data;

        // Converte strings para Objetos Date
        const start = new Date(check_in);
        const end = new Date(check_out);

        const reservasRef = db.collection("reservas_hotel");

        // --- AQUI ESTÁ A CORREÇÃO CRÍTICA ---
        // Só usamos filtro de desigualdade (>) no check_out.
        // O índice composto que criamos (status + check_out) serve para isso.
        const snapshot = await reservasRef
            .where("status", "in", ["reservado", "hospedado"])
            .where("check_out", ">", start)
            .get();

        let vagasOcupadas = 0;

        snapshot.forEach(doc => {
            const r = doc.data();
            const rIn = r.check_in.toDate();

            // A filtragem do check_in é feita aqui no código (Javascript), não no banco
            if (rIn < end) {
                vagasOcupadas++;
            }
        });

        console.log(`Vagas ocupadas detectadas: ${vagasOcupadas}`);

        if (vagasOcupadas >= 60) {
            throw new HttpsError('resource-exhausted', 'Hotel lotado para este período.');
        }

        // Criar a reserva
        await reservasRef.add({
            cpf_user,
            pet_id,
            check_in: admin.firestore.Timestamp.fromDate(start),
            check_out: admin.firestore.Timestamp.fromDate(end),
            status: 'reservado',
            payment_status: 'pending',
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            origem: 'app_cliente'
        });

        return { success: true };

    } catch (error) {
        console.error("Erro CRÍTICO em reservarHotel:", error);
        throw new HttpsError('internal', error.message || 'Erro ao processar reserva');
    }
});

// --- NOVA FUNÇÃO: Verificar Dias Lotados ---
exports.obterDiasLotados = onCall(async (request) => {
    // 1. Configurações
    const CAPACIDADE_MAXIMA = 60; // Ou busque do banco config
    const hoje = startOfDay(new Date());
    const limiteFuturo = addDays(hoje, 60); // Verifica os próximos 60 dias

    // 2. Busca todas as reservas ativas no período
    const reservasRef = db.collection("reservas_hotel");
    const snapshot = await reservasRef
        .where("check_out", ">=", hoje) // Que ainda não saíram
        .where("status", "in", ["reservado", "hospedado"])
        .get();

    // 3. Mapa de Ocupação: '2023-10-25' => 12 pets
    let ocupacaoDiaria = {};

    // Inicializa o mapa com 0 para os próximos 60 dias
    const diasNoPeriodo = eachDayOfInterval({ start: hoje, end: limiteFuturo });
    diasNoPeriodo.forEach(dia => {
        ocupacaoDiaria[format(dia, 'yyyy-MM-dd')] = 0;
    });

    // 4. Preenche a ocupação
    snapshot.forEach(doc => {
        const data = doc.data();

        // Converte timestamps para Date
        let start = data.check_in.toDate();
        let end = data.check_out.toDate();

        // Para cada dia da reserva, incrementa no mapa
        // Nota: Só incrementa se o dia estiver dentro do nosso intervalo de análise (hoje até +60)
        try {
            const diasEstadia = eachDayOfInterval({ start: start, end: end });
            diasEstadia.forEach(dia => {
                const diaStr = format(dia, 'yyyy-MM-dd');
                // Se o dia existe no nosso mapa (está nos próximos 60 dias)
                if (ocupacaoDiaria.hasOwnProperty(diaStr)) {
                    ocupacaoDiaria[diaStr]++;
                }
            });
        } catch (e) {
            // Ignora datas inválidas
        }
    });

    // 5. Filtra apenas os dias que atingiram a capacidade
    let diasLotados = [];
    for (const [dia, qtd] of Object.entries(ocupacaoDiaria)) {
        if (qtd >= CAPACIDADE_MAXIMA) {
            diasLotados.push(dia);
        }
    }

    return { dias_lotados: diasLotados };
});

// --- NOVA FUNÇÃO: Checkout Hotel Seguro ---
exports.realizarCheckoutHotel = onCall(async (request) => {
    const { reservaId, extrasIds, metodoPagamento } = request.data;

    if (!reservaId) throw new HttpsError('invalid-argument', 'ID da reserva obrigatório');

    const reservaRef = db.collection('reservas_hotel').doc(reservaId);
    const reservaSnap = await reservaRef.get();

    if (!reservaSnap.exists) throw new HttpsError('not-found', 'Reserva não encontrada');
    const dadosReserva = reservaSnap.data();

    if (dadosReserva.status === 'concluido') throw new HttpsError('failed-precondition', 'Esta estadia já foi finalizada.');

    // 1. Busca Configuração de Preço (Diária)
    const configDoc = await db.collection("config").doc("parametros").get();
    const valorDiaria = configDoc.exists ? (configDoc.data().preco_hotel_diaria || 0) : 0;

    // 2. Calcula Dias de Estadia (Data Atual - Check-in Real)
    // Se não tiver check_in_real (erro de processo), usa o agendado
    const dataCheckIn = dadosReserva.check_in_real ? dadosReserva.check_in_real.toDate() : dadosReserva.check_in.toDate();
    const dataCheckOut = new Date(); // Agora

    let diasEstadia = differenceInCalendarDays(dataCheckOut, dataCheckIn);
    if (diasEstadia < 1) diasEstadia = 1; // Mínimo 1 diária

    let valorTotal = diasEstadia * valorDiaria;

    // 3. Processa Extras (Busca preço real no banco)
    let extrasProcessados = [];
    if (extrasIds && extrasIds.length > 0) {
        for (const extraId of extrasIds) {
            const extraDoc = await db.collection('servicos_extras').doc(extraId).get();
            if (extraDoc.exists) {
                const extraData = extraDoc.data();
                const precoExtra = Number(extraData.preco || 0);

                valorTotal += precoExtra;

                extrasProcessados.push({
                    id: extraId,
                    nome: extraData.nome,
                    preco: precoExtra
                });
            }
        }
    }

    // 4. Atualiza Reserva (Batch)
    await reservaRef.update({
        status: 'concluido',
        payment_status: 'paid',
        check_out_real: admin.firestore.FieldValue.serverTimestamp(),
        metodo_pagamento_final: metodoPagamento,

        // Detalhes Financeiros salvos para histórico
        dias_cobrados: diasEstadia,
        valor_diaria_aplicado: valorDiaria,
        valor_total_final: valorTotal,
        extras_consumidos: extrasProcessados,
    });

    return {
        sucesso: true,
        mensagem: 'Estadia finalizada com sucesso!',
        valorCobrado: valorTotal,
        dias: diasEstadia
    };
});

// --- NOVA FUNÇÃO: Registrar Pagamento Parcial/Antecipado ---
exports.registrarPagamentoHotel = onCall(async (request) => {
    const { reservaId, valor, metodo } = request.data;

    if (!reservaId || !valor) throw new HttpsError('invalid-argument', 'Dados incompletos');

    const reservaRef = db.collection('reservas_hotel').doc(reservaId);

    // Transação para garantir integridade do saldo
    await db.runTransaction(async (t) => {
        const doc = await t.get(reservaRef);
        if (!doc.exists) throw new HttpsError('not-found', 'Reserva não encontrada');

        const data = doc.data();
        const pagoAtual = Number(data.valor_pago || 0);
        const novoTotalPago = pagoAtual + Number(valor);

        // Atualiza saldo e adiciona ao histórico
        t.update(reservaRef, {
            valor_pago: novoTotalPago,
            payment_status: 'partial', // Marca como parcialmente pago
            historico_pagamentos: admin.firestore.FieldValue.arrayUnion({
                valor: Number(valor),
                metodo: metodo,
                data: new Date(),
                tipo: 'adiantamento'
            })
        });
    });

    return { success: true };
});

// --- ATUALIZADO: Checkout Hotel (Considerando saldo já pago) ---
exports.realizarCheckoutHotel = onCall(async (request) => {
    const { reservaId, extrasIds, metodoPagamentoDiferenca, produtos, pagamentos } = request.data;

    const reservaRef = db.collection('reservas_hotel').doc(reservaId);
    const reservaSnap = await reservaRef.get();
    const dadosReserva = reservaSnap.data();

    // 1. Cálculos de Custo (Diária + Extras)
    const configDoc = await db.collection("config").doc("parametros").get();
    const valorDiaria = configDoc.exists ? (configDoc.data().preco_hotel_diaria || 0) : 0;

    const dataCheckIn = dadosReserva.check_in_real ? dadosReserva.check_in_real.toDate() : dadosReserva.check_in.toDate();
    const dataCheckOut = new Date();

    // date-fns: differenceInCalendarDays
    let diasEstadia = Math.ceil((dataCheckOut - dataCheckIn) / (1000 * 60 * 60 * 24));
    if (diasEstadia < 1) diasEstadia = 1;

    let custoDiarias = diasEstadia * valorDiaria;
    let custoExtras = 0;
    let extrasProcessados = [];

    if (extrasIds && extrasIds.length > 0) {
        for (const extraId of extrasIds) {
            const extraDoc = await db.collection('servicos_extras').doc(extraId).get();
            if (extraDoc.exists) {
                const p = Number(extraDoc.data().preco || 0);
                custoExtras += p;
                extrasProcessados.push({ id: extraId, nome: extraDoc.data().nome, preco: p });
            }
        }
    }

    // --- PROCESSAMENTO DE PRODUTOS ---
    let custoProdutos = 0;
    let produtosConsumidos = [];
    const batch = db.batch();

    if (produtos && produtos.length > 0) {
        for (const item of produtos) {
            if (!item.id || !item.qtd) continue;

            const prodRef = db.collection('produtos').doc(item.id);
            const prodDoc = await prodRef.get();

            if (prodDoc.exists) {
                const prodData = prodDoc.data();
                const p = Number(prodData.preco || 0);
                const qtd = Number(item.qtd);
                const subtotal = p * qtd;

                custoProdutos += subtotal;
                produtosConsumidos.push({
                    id: item.id,
                    nome: prodData.nome,
                    qtd: qtd,
                    precoUnitario: p,
                    subtotal: subtotal
                });

                // Atualiza Estoque
                batch.update(prodRef, {
                    qtd_estoque: admin.firestore.FieldValue.increment(-qtd),
                    qtd_vendida: admin.firestore.FieldValue.increment(qtd)
                });
            }
        }
    }

    const valorTotalServico = custoDiarias + custoExtras + custoProdutos;
    const valorJaPago = Number(dadosReserva.valor_pago || 0);

    // AQUI ESTÁ O SEGULRO: Calculamos a diferença
    const valorRestanteAPagar = valorTotalServico - valorJaPago;

    // Processa Pagamentos (Multiplos ou Legacy)
    let pagamentosFinais = [];
    let totalPagoAgora = 0;

    if (pagamentos && Array.isArray(pagamentos)) {
        pagamentos.forEach(p => {
            totalPagoAgora += Number(p.valor || 0);
            pagamentosFinais.push(p);
        });
    } else if (metodoPagamentoDiferenca) {
        // Legacy: Se mandou um método, assume que pagou a diferença toda
        totalPagoAgora = valorRestanteAPagar > 0 ? valorRestanteAPagar : 0;
        if (totalPagoAgora > 0) {
            pagamentosFinais.push({ metodo: metodoPagamentoDiferenca, valor: totalPagoAgora });
        }
    }

    // Validação: Se devia algo e não pagou o suficiente
    // Tolerância de 0.1
    const saldoFinalDevido = valorRestanteAPagar - totalPagoAgora;
    if (saldoFinalDevido > 0.1) {
       // Opcional: Lançar erro ou marcar como 'pending_audit'
    }

    const metodoFinal = pagamentosFinais.length > 0
        ? pagamentosFinais.map(p => p.metodo).join(', ')
        : (metodoPagamentoDiferenca || 'ja_pago');

    // Atualização Final (Usando Batch)
    batch.update(reservaRef, {
        status: 'concluido',
        payment_status: saldoFinalDevido <= 0.1 ? 'paid' : 'pending_audit',
        check_out_real: admin.firestore.FieldValue.serverTimestamp(),

        // Dados financeiros finais
        dias_cobrados: diasEstadia,
        valor_diaria_aplicado: valorDiaria,
        custo_total_servico: valorTotalServico,
        valor_pago_anterior: valorJaPago,
        valor_pago_checkout: totalPagoAgora, // Valor pago neste checkout
        metodo_pagamento_final: metodoFinal,
        pagamentos_detalhados: pagamentosFinais, // Array completo

        extras_consumidos: extrasProcessados,
        produtos_consumidos: produtosConsumidos, // Salva produtos
    });

    await batch.commit();

    return {
        sucesso: true,
        valorTotal: valorTotalServico,
        valorPagoAnterior: valorJaPago,
        valorCobradoAgora: valorRestanteAPagar
    };
});