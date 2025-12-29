const functions = require("firebase-functions");
const { db, admin } = require("../config/firebase");
const optionsEfi = require("../config/efipay");
const EfiPay = require("sdk-node-apis-efi");
const { addMinutes, format, parse } = require("date-fns");

// --- Função Auxiliar: Busca Horários Disponíveis ---
exports.buscarHorarios = functions.region('southamerica-east1').https.onCall(async (data, context) => {
    const { dataConsulta, servico } = data; // 'YYYY-MM-DD', 'banho' ou 'tosa'

    const configDoc = await db.collection("config").doc("parametros").get();
    const config = configDoc.data();
    const duracaoServico = servico === 'tosa' ? config.tempo_tosa_min : config.tempo_banho_min;

    // Busca profissionais habilitados
    const prosSnapshot = await db.collection("profissionais")
        .where("habilidades", "array-contains", servico)
        .where("ativo", "==", true)
        .get();

    const profissionais = [];
    prosSnapshot.forEach(doc => profissionais.push({ id: doc.id, ...doc.data() }));

    // Busca agendamentos do dia
    const startOfDay = new Date(`${dataConsulta}T00:00:00`);
    const endOfDay = new Date(`${dataConsulta}T23:59:59`);

    const agendamentosSnapshot = await db.collection("agendamentos")
        .where("data_inicio", ">=", startOfDay)
        .where("data_inicio", "<=", endOfDay)
        .where("status", "!=", "cancelado")
        .get();

    const agendamentos = [];
    agendamentosSnapshot.forEach(doc => agendamentos.push(doc.data()));

    // Gera slots
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
                    (slotFim > agInicio && slotFim <= agFim)
                );
            });
            if (!ocupado) { slotLivre = true; break; }
        }
        if (slotLivre) horariosDisponiveis.push(format(horaAtual, "HH:mm"));
        horaAtual = addMinutes(horaAtual, duracaoServico === 40 ? 40 : 60);
    }

    return { horarios: horariosDisponiveis };
});

// --- Função Principal: Criar Agendamento + Pagamento ---
exports.criar = functions.region('southamerica-east1').https.onCall(async (data, context) => {
    const { servico, data_hora, cpf_user, pet_id, metodo_pagamento, valor } = data;

    const configDoc = await db.collection("config").doc("parametros").get();
    const config = configDoc.data();
    const duracao = servico === 'tosa' ? config.tempo_tosa_min : config.tempo_banho_min;

    const inicio = new Date(data_hora);
    const fim = addMinutes(inicio, duracao);

    // 1. Lógica de Prioridade (Peso)
    const prosSnapshot = await db.collection("profissionais")
        .where("habilidades", "array-contains", servico)
        .orderBy("peso_prioridade", "asc") // Tenta o mais "barato" (Banhista) primeiro
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

    if (!profissionalEscolhido) {
        throw new functions.https.HttpsError('aborted', 'Horário indisponível.');
    }

    // 2. Prepara Agendamento
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
        status: metodo_pagamento === 'pix' ? 'aguardando_pagamento' : 'agendado'
    };

    // 3. Integração PIX EfiPay
    let resposta = { mensagem: "Agendado com sucesso (Pagamento Balcão)" };

    if (metodo_pagamento === 'pix') {
        const efipay = new EfiPay(optionsEfi);
        const bodyPix = {
            calendario: { expiracao: 3600 },
            devedor: { cpf: cpf_user, nome: "Cliente App" },
            valor: { original: valor.toFixed(2) },
            chave: "SUA_CHAVE_PIX"
        };

        try {
            const cobranca = await efipay.pixCreateImmediateCharge([], bodyPix);
            const qrCode = await efipay.pixGenerateQRCode({ id: cobranca.loc.id });

            novoAgendamento.txid = cobranca.txid;
            resposta = {
                pix_copia_cola: qrCode.qrcode,
                imagem_qrcode: qrCode.imagemQrcode,
                txid: cobranca.txid
            };
        } catch (e) {
            console.error(e);
            throw new functions.https.HttpsError('internal', 'Erro no PIX');
        }
    }

    await db.collection("agendamentos").add(novoAgendamento);
    return resposta;
});

// --- Webhook para confirmar pagamento ---
exports.webhookPix = functions.region('southamerica-east1').https.onRequest(async (req, res) => {
    const { pix } = req.body;
    if (pix) {
        for (const p of pix) {
            const snapshot = await db.collection('agendamentos').where('txid', '==', p.txid).get();
            snapshot.forEach(async doc => {
                await doc.ref.update({ status: 'agendado' });
            });
        }
    }
    res.status(200).send();
});