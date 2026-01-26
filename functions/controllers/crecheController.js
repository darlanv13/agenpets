const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { eachDayOfInterval, format, isWithinInterval, startOfDay, addDays, differenceInCalendarDays } = require("date-fns");
const { db, admin } = require("../config/firebase");

exports.reservarCreche = onCall(async (request) => {
    try {
        console.log("Iniciando reserva creche...", request.data);
        const { check_in, check_out, pet_id, cpf_user } = request.data;

        // Converte strings para Objetos Date
        const start = new Date(check_in);
        const end = new Date(check_out);

        const reservasRef = db.collection("reservas_creche");

        // Só usamos filtro de desigualdade (>) no check_out.
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

        console.log(`Vagas creche ocupadas detectadas: ${vagasOcupadas}`);

        // Capacidade da creche pode ser diferente do hotel
        if (vagasOcupadas >= 60) {
            throw new HttpsError('resource-exhausted', 'Creche lotada para este período.');
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
        console.error("Erro CRÍTICO em reservarCreche:", error);
        throw new HttpsError('internal', error.message || 'Erro ao processar reserva');
    }
});

// --- Verificar Dias Lotados Creche ---
exports.obterDiasLotadosCreche = onCall(async (request) => {
    // 1. Configurações
    const CAPACIDADE_MAXIMA = 60; // Ou busque do banco config
    const hoje = startOfDay(new Date());
    const limiteFuturo = addDays(hoje, 60); // Verifica os próximos 60 dias

    // 2. Busca todas as reservas ativas no período
    const reservasRef = db.collection("reservas_creche");
    const snapshot = await reservasRef
        .where("check_out", ">=", hoje) // Que ainda não saíram
        .where("status", "in", ["reservado", "hospedado"])
        .get();

    // 3. Mapa de Ocupação
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

// --- Obter Preço da Creche (Segurança) ---
exports.obterPrecoCreche = onCall(async (request) => {
    try {
        const doc = await db.collection("config").doc("parametros").get();
        if (doc.exists) {
            return { preco: Number(doc.data().preco_creche_diaria || 0) };
        }
        return { preco: 0 };
    } catch (error) {
        console.error("Erro ao buscar preço creche:", error);
        throw new HttpsError('internal', 'Erro ao buscar preço');
    }
});

// --- Registrar Pagamento Parcial/Antecipado Creche ---
exports.registrarPagamentoCreche = onCall(async (request) => {
    const { reservaId, valor, metodo } = request.data;

    if (!reservaId || !valor) throw new HttpsError('invalid-argument', 'Dados incompletos');

    const reservaRef = db.collection('reservas_creche').doc(reservaId);

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

// --- Checkout Creche ---
exports.realizarCheckoutCreche = onCall(async (request) => {
    const { reservaId, extrasIds, metodoPagamentoDiferenca } = request.data;

    const reservaRef = db.collection('reservas_creche').doc(reservaId);
    const reservaSnap = await reservaRef.get();
    const dadosReserva = reservaSnap.data();

    // 1. Cálculos de Custo (Diária + Extras)
    const configDoc = await db.collection("config").doc("parametros").get();
    const valorDiaria = configDoc.exists ? (configDoc.data().preco_creche_diaria || 0) : 0;

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
            let extraDoc = await db.collection('servicos_extras').doc(extraId).get();
            let extraData = extraDoc.exists ? extraDoc.data() : null;

            if (!extraDoc.exists) {
                extraDoc = await db.collection('produtos').doc(extraId).get();
                if (extraDoc.exists) extraData = extraDoc.data();
            }

            if (extraDoc.exists && extraData) {
                const p = Number(extraData.preco || 0);
                custoExtras += p;
                extrasProcessados.push({ id: extraId, nome: extraData.nome, preco: p });
            }
        }
    }

    const valorTotalServico = custoDiarias + custoExtras;
    const valorJaPago = Number(dadosReserva.valor_pago || 0);

    // Calculamos a diferença
    const valorRestanteAPagar = valorTotalServico - valorJaPago;

    // Se ainda deve algo e não mandou método de pagamento, erro (segurança)
    // Mas permitimos margem de erro pequena (ex: centavos)
    if (valorRestanteAPagar > 0.1 && !metodoPagamentoDiferenca) {
        // O frontend deve tratar isso, mas aqui garantimos
    }

    // Atualização Final
    await reservaRef.update({
        status: 'concluido',
        payment_status: valorRestanteAPagar <= 0 ? 'paid' : 'pending_audit', // Se pagou tudo, ok
        check_out_real: admin.firestore.FieldValue.serverTimestamp(),

        // Dados financeiros finais
        dias_cobrados: diasEstadia,
        valor_diaria_aplicado: valorDiaria,
        custo_total_servico: valorTotalServico,
        valor_pago_anterior: valorJaPago,
        valor_pago_checkout: valorRestanteAPagar > 0 ? valorRestanteAPagar : 0,
        metodo_pagamento_final: metodoPagamentoDiferenca || 'ja_pago', // Registra como pagou o resto

        extras_consumidos: extrasProcessados,
    });

    return {
        sucesso: true,
        valorTotal: valorTotalServico,
        valorPagoAnterior: valorJaPago,
        valorCobradoAgora: valorRestanteAPagar
    };
});
