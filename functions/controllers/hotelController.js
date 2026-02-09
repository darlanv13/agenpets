const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { eachDayOfInterval, format, isWithinInterval, startOfDay, addDays } = require("date-fns");
const { db, admin } = require("../config/firebase");

exports.reservarHotel = onCall(async (request) => {
    try {
        console.log("Iniciando reserva...", request.data);
        const { check_in, check_out, pet_id, cpf_user, tenantId, taxi_dog, endereco_buscar } = request.data;

        if (!tenantId) throw new HttpsError('invalid-argument', 'ID da loja (tenantId) é obrigatório.');

        // Converte strings para Objetos Date
        const start = new Date(check_in);
        const end = new Date(check_out);

        const reservasRef = db.collection("tenants").doc(tenantId).collection("reservas_hotel");

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
            origem: 'app_cliente',
            taxi_dog: !!taxi_dog,
            endereco_buscar: endereco_buscar || null
        });

        return { success: true };

    } catch (error) {
        console.error("Erro CRÍTICO em reservarHotel:", error);
        throw new HttpsError('internal', error.message || 'Erro ao processar reserva');
    }
});

// --- NOVA FUNÇÃO: Verificar Dias Lotados ---
exports.obterDiasLotados = onCall(async (request) => {
    const { tenantId } = request.data;
    if (!tenantId) throw new HttpsError('invalid-argument', 'ID da loja (tenantId) é obrigatório.');

    // 1. Configurações
    const CAPACIDADE_MAXIMA = 60; // Ou busque do banco config
    const hoje = startOfDay(new Date());
    const limiteFuturo = addDays(hoje, 60); // Verifica os próximos 60 dias

    // 2. Busca todas as reservas ativas no período
    const reservasRef = db.collection("tenants").doc(tenantId).collection("reservas_hotel");
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


// --- NOVA FUNÇÃO: Registrar Pagamento Parcial/Antecipado ---
exports.registrarPagamentoHotel = onCall(async (request) => {
    const { reservaId, valor, metodo, tenantId } = request.data;

    if (!reservaId || !valor) throw new HttpsError('invalid-argument', 'Dados incompletos');
    if (!tenantId) throw new HttpsError('invalid-argument', 'ID da loja (tenantId) é obrigatório.');

    const reservaRef = db.collection("tenants").doc(tenantId).collection('reservas_hotel').doc(reservaId);

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

