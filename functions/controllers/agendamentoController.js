const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { db, admin } = require("../config/firebase");
const optionsEfi = require("../config/efipay");
const EfiPay = require("sdk-node-apis-efi");
const { addMinutes, format, parse } = require("date-fns");


// --- Buscar Horários (Mantido igual) ---
exports.buscarHorarios = onCall(async (request) => {
    const data = request.data;
    const { dataConsulta, servico } = data;

    const configDoc = await db.collection("config").doc("parametros").get();
    const config = configDoc.data();
    const duracaoServico = servico === 'tosa' ? config.tempo_tosa_min : config.tempo_banho_min;

    const prosSnapshot = await db.collection("profissionais")
        .where("habilidades", "array-contains", servico)
        .where("ativo", "==", true)
        .get();

    const profissionais = [];
    prosSnapshot.forEach(doc => profissionais.push({ id: doc.id, ...doc.data() }));

    const startOfDay = new Date(`${dataConsulta}T00:00:00`);
    const endOfDay = new Date(`${dataConsulta}T23:59:59`);

    const agendamentosSnapshot = await db.collection("agendamentos")
        .where("data_inicio", ">=", startOfDay)
        .where("data_inicio", "<=", endOfDay)
        .where("status", "!=", "cancelado")
        .get();

    const agendamentos = [];
    agendamentosSnapshot.forEach(doc => agendamentos.push(doc.data()));

    let horariosDisponiveis = [];
    let horaAtual = parse(config.horario_abertura, 'HH:mm', new Date(`${dataConsulta}T00:00:00`));
    const horaFechamento = parse(config.horario_fechamento, 'HH:mm', new Date(`${dataConsulta}T00:00:00`));

    while (addMinutes(horaAtual, duracaoServico) <= horaFechamento) {
        let slotLivre = false;
        for (const pro of profissionais) {
            const ocupado = agendamentos.some(ag => {
                const agInicio = ag.data_inicio.toDate();
                const agFim = ag.data_fim.toDate();
                const slotInicio = horaAtual;
                const slotFim = addMinutes(horaAtual, duracaoServico);

                return ag.profissional_id === pro.id && (
                    (slotInicio >= agInicio && slotInicio < agFim) ||
                    (slotFim > agInicio && slotFim <= agFim) ||
                    (slotInicio <= agInicio && slotFim >= agFim)
                );
            });
            if (!ocupado) { slotLivre = true; break; }
        }
        if (slotLivre) horariosDisponiveis.push(format(horaAtual, "HH:mm"));
        horaAtual = addMinutes(horaAtual, duracaoServico);
    }

    return { horarios: horariosDisponiveis };
});

// --- NOVA FUNÇÃO: Comprar Assinatura ---
exports.comprarAssinatura = onCall(async (request) => {
    const { cpf_user, tipo_plano } = request.data; // 'pct_banho' ou 'pct_completo'

    // Configuração dos Planos
    const planos = {
        'pct_banho': { nome: "Pacote Banho (4x)", valor: 180.00, qtd: 4, tipo_voucher: 'banho' },
        'pct_completo': { nome: "Pacote Banho & Tosa (4x)", valor: 250.00, qtd: 4, tipo_voucher: 'tosa' }
    };

    const planoSelecionado = planos[tipo_plano];
    if (!planoSelecionado) throw new HttpsError('invalid-argument', 'Plano inválido');

    // Cria intenção de compra
    const compra = {
        cpf_user,
        plano: tipo_plano,
        valor: planoSelecionado.valor,
        status: 'aguardando_pagamento',
        created_at: admin.firestore.FieldValue.serverTimestamp()
    };

    // Gera PIX
    let resposta = {};
    try {
        const efipay = new EfiPay(optionsEfi);
        const bodyPix = {
            calendario: { expiracao: 3600 },
            devedor: { cpf: cpf_user.replace(/\D/g, ''), nome: "Cliente Assinante" },
            valor: { original: planoSelecionado.valor.toFixed(2) },
            chave: "SUA_CHAVE_PIX_AQUI"
        };
        const cobranca = await efipay.pixCreateImmediateCharge([], bodyPix);
        const qrCode = await efipay.pixGenerateQRCode({ id: cobranca.loc.id });

        compra.txid = cobranca.txid;
        resposta = {
            success: true,
            pix_copia_cola: qrCode.qrcode,
            imagem_qrcode: qrCode.imagemQrcode,
            valor: planoSelecionado.valor
        };
    } catch (e) {
        console.error("Erro PIX:", e);
        // Em DEV, simulamos sucesso para testar voucher sem pagar
        // throw new HttpsError('internal', 'Erro ao gerar PIX');
    }

    // Salva no banco de 'vendas_assinaturas'
    await db.collection("vendas_assinaturas").add(compra);

    return resposta;
});


// --- ATUALIZADO: Criar Agendamento (Aceita Voucher) ---
exports.criarAgendamento = onCall(async (request) => {
    const { servico, data_hora, cpf_user, pet_id, metodo_pagamento, valor } = request.data;

    // --- LÓGICA DE VOUCHER ---
    if (metodo_pagamento === 'voucher') {
        const userRef = db.collection('users').doc(cpf_user);
        const userDoc = await userRef.get();
        const userData = userDoc.data();

        // Verifica saldo
        const campoVoucher = servico === 'Banho' ? 'vouchers_banho' : 'vouchers_tosa';
        const saldo = userData[campoVoucher] || 0;

        if (saldo <= 0) {
            throw new HttpsError('failed-precondition', 'Você não possui vouchers disponíveis para este serviço.');
        }

        // Desconta 1 voucher
        await userRef.update({
            [campoVoucher]: admin.firestore.FieldValue.increment(-1)
        });
    }
    // -------------------------

    const configDoc = await db.collection("config").doc("parametros").get();
    const config = configDoc.data();
    const duracao = servico === 'tosa' ? config.tempo_tosa_min : config.tempo_banho_min;

    const inicio = new Date(data_hora);
    const fim = addMinutes(inicio, duracao);

    const prosSnapshot = await db.collection("profissionais")
        .where("habilidades", "array-contains", servico)
        .orderBy("peso_prioridade", "asc")
        .get();

    let profissionalEscolhido = null;

    for (const doc of prosSnapshot.docs) {
        const conflito = await db.collection("agendamentos")
            .where("profissional_id", "==", doc.id)
            .where("data_inicio", "<", fim)
            .where("data_fim", ">", inicio)
            .get();

        if (conflito.empty) {
            profissionalEscolhido = { id: doc.id, nome: doc.data().nome };
            break;
        }
    }

    if (!profissionalEscolhido) throw new HttpsError('aborted', 'Horário ocupado.');

    const novoAgendamento = {
        userId: cpf_user,
        pet_id,
        profissional_id: profissionalEscolhido.id,
        profissional_nome: profissionalEscolhido.nome,
        servico,
        data_inicio: admin.firestore.Timestamp.fromDate(inicio),
        data_fim: admin.firestore.Timestamp.fromDate(fim),
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        metodo_pagamento,
        valor: metodo_pagamento === 'voucher' ? 0 : valor, // Se voucher, valor é 0 no agendamento
        status: metodo_pagamento === 'pix' ? 'aguardando_pagamento' : 'agendado'
    };

    let resposta = { success: true, mensagem: "Agendado com sucesso!" };

    if (metodo_pagamento === 'pix') {
        try {
            const efipay = new EfiPay(optionsEfi);
            const bodyPix = {
                calendario: { expiracao: 3600 },
                devedor: { cpf: cpf_user.replace(/\D/g, ''), nome: "Cliente AgenPet" },
                valor: { original: valor.toFixed(2) },
                chave: "SUA_CHAVE_PIX_AQUI"
            };
            const cobranca = await efipay.pixCreateImmediateCharge([], bodyPix);
            const qrCode = await efipay.pixGenerateQRCode({ id: cobranca.loc.id });

            novoAgendamento.txid = cobranca.txid;
            resposta = { success: true, pix_copia_cola: qrCode.qrcode, imagem_qrcode: qrCode.imagemQrcode };
        } catch (e) { console.error("Erro PIX:", e); }
    }

    await db.collection("agendamentos").add(novoAgendamento);
    return resposta;
});

// --- Webhook PIX (Atualizado para liberar Vouchers) ---
exports.webhookPix = onRequest(async (req, res) => {
    const { pix } = req.body;
    if (pix) {
        for (const p of pix) {
            // 1. Verifica se é pagamento de Agendamento
            const agendamentoSnap = await db.collection('agendamentos').where('txid', '==', p.txid).get();
            agendamentoSnap.forEach(async doc => await doc.ref.update({ status: 'agendado' }));

            // 2. Verifica se é pagamento de Assinatura
            const assinaturaSnap = await db.collection('vendas_assinaturas').where('txid', '==', p.txid).get();
            assinaturaSnap.forEach(async doc => {
                const venda = doc.data();
                if (venda.status !== 'pago') {
                    await doc.ref.update({ status: 'pago' });

                    // Adiciona Vouchers ao Usuário
                    const qtdVoucher = 4;
                    const campo = venda.plano === 'pct_banho' ? 'vouchers_banho' : 'vouchers_tosa';

                    await db.collection('users').doc(venda.cpf_user).update({
                        [campo]: admin.firestore.FieldValue.increment(qtdVoucher),
                        validade_assinatura: admin.firestore.Timestamp.fromDate(addMinutes(new Date(), 30 * 24 * 60)) // +30 dias
                    });
                }
            });
        }
    }
    res.status(200).send();
});