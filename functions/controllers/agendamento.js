const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db, admin } = require("../config/firebase");
const { addMinutes, format, parse, isSameDay } = require("date-fns");
const EfiPay = require("sdk-node-apis-efi");
const optionsEfi = require("../config/efipay");

// --- 1. BUSCAR HORÁRIOS ---
exports.buscarHorarios = onCall(async (request) => {
    try {
        const data = request.data;
        const { dataConsulta, servico, tenantId } = data;

        if (!tenantId) throw new HttpsError("invalid-argument", "ID da loja (tenantId) é obrigatório.");

        const servicoNorm = servico ? servico.toLowerCase() : "";

        // Busca Configuração da Loja
        const configDoc = await db.collection("tenants").doc(tenantId).collection("config").doc("parametros").get();
        const config = configDoc.exists ? configDoc.data() : {};

        // Busca Profissionais
        const prosSnapshot = await db.collection("tenants").doc(tenantId).collection("profissionais").where("ativo", "==", true).get();
        const banhistas = [];
        const tosadores = [];

        prosSnapshot.forEach((doc) => {
            const p = { id: doc.id, ...doc.data() };
            const skills = (p.habilidades || []).map((h) => h.toLowerCase());
            if (skills.includes("tosa")) tosadores.push(p);
            else if (skills.includes("banho")) banhistas.push(p);
        });

        const duracaoServico = servicoNorm === "tosa" ? (config.tempo_tosa_min || 90) : (config.tempo_banho_min || 60);

        // Busca Agendamentos
        const startOfDay = new Date(`${dataConsulta}T00:00:00`);
        const endOfDay = new Date(`${dataConsulta}T23:59:59`);

        const agendamentosSnapshot = await db.collection("tenants").doc(tenantId).collection("agendamentos")
            .where("data_inicio", ">=", startOfDay)
            .where("data_inicio", "<=", endOfDay)
            .where("status", "!=", "cancelado")
            .get();

        const agendamentos = agendamentosSnapshot.docs.map((doc) => ({ ...doc.data(), id: doc.id }));

        // Monta Grade
        const gradeHorarios = [];
        const [hAbre, mAbre] = (config.horario_abertura || "08:00").split(":").map(Number);
        const [hFecha, mFecha] = (config.horario_fechamento || "18:00").split(":").map(Number);

        let horaAtual = new Date(`${dataConsulta}T00:00:00`);
        horaAtual.setHours(hAbre, mAbre, 0, 0);

        const horaLimite = new Date(`${dataConsulta}T00:00:00`);
        horaLimite.setHours(hFecha, mFecha, 0, 0);

        while (addMinutes(horaAtual, duracaoServico) <= horaLimite) {
            const slotInicio = new Date(horaAtual);
            const slotFim = addMinutes(horaAtual, duracaoServico);

            const isOcupado = (proId) => {
                return agendamentos.find((ag) => {
                    const agInicio = ag.data_inicio.toDate();
                    const agFim = ag.data_fim.toDate();
                    return ag.profissional_id === proId && ((slotInicio < agFim && slotFim > agInicio));
                });
            };

            let temVaga = false;
            if (servicoNorm === "banho") {
                if (banhistas.some((b) => !isOcupado(b.id))) temVaga = true;
                else if (tosadores.some((t) => !isOcupado(t.id))) temVaga = true;
            } else if (servicoNorm === "tosa") {
                if (tosadores.some((t) => !isOcupado(t.id))) {
                    temVaga = true;
                } else {
                    const banhistasLivres = banhistas.filter((b) => !isOcupado(b.id));
                    if (banhistasLivres.length > 0) {
                        const podeTrocar = tosadores.some((t) => {
                            const ag = isOcupado(t.id);
                            const servicoDoConflito = (ag.servico || ag.servicoNorm || "").toLowerCase();
                            return ag && servicoDoConflito === "banho";
                        });
                        if (podeTrocar) temVaga = true;
                    }
                }
            }

            const hStr = horaAtual.getHours().toString().padStart(2, "0");
            const mStr = horaAtual.getMinutes().toString().padStart(2, "0");

            gradeHorarios.push({ hora: `${hStr}:${mStr}`, livre: temVaga });
            horaAtual = addMinutes(horaAtual, config.intervalo_agenda || 30);
        }

        return { grade: gradeHorarios };
    } catch (e) {
        console.error("Erro buscarHorarios:", e);
        return { grade: [] };
    }
});

// --- 2. CRIAR AGENDAMENTO ---
exports.criarAgendamento = onCall(async (request) => {
    const { tenantId, cpf_user, metodo_pagamento, servico, data_hora, pet_id, valor } = request.data;

    if (!tenantId) throw new HttpsError("invalid-argument", "TenantId obrigatório.");
    if (!data_hora) throw new HttpsError("invalid-argument", "Data obrigatória.");

    const servicoNorm = servico ? servico.toLowerCase() : "";

    // Lógica de Voucher
    if (metodo_pagamento === "voucher") {
        const voucherRef = db.collection("users").doc(cpf_user).collection("vouchers").doc(tenantId);
        const voucherDoc = await voucherRef.get();
        const saldoData = voucherDoc.data();

        if (!saldoData || !saldoData[servicoNorm] || saldoData[servicoNorm] <= 0) {
            throw new HttpsError("failed-precondition", `Saldo de voucher insuficiente.`);
        }

        await voucherRef.update({ [servicoNorm]: admin.firestore.FieldValue.increment(-1) });
    }

    // Configuração e Profissionais
    const configDoc = await db.collection("tenants").doc(tenantId).collection("config").doc("parametros").get();
    const config = configDoc.exists ? configDoc.data() : { tempo_tosa_min: 60, tempo_banho_min: 40 };
    const duracao = servicoNorm === "tosa" ? config.tempo_tosa_min : config.tempo_banho_min;

    const inicio = new Date(data_hora);
    const fim = addMinutes(inicio, duracao);

    const prosSnapshot = await db.collection("tenants").doc(tenantId).collection("profissionais").where("ativo", "==", true).get();
    const banhistas = [];
    const tosadores = [];
    prosSnapshot.forEach((doc) => {
        const p = { id: doc.id, ...doc.data() };
        if ((p.habilidades || []).includes("tosa")) tosadores.push(p);
        else banhistas.push(p);
    });

    // Conflitos
    const conflitosSnapshot = await db.collection("tenants").doc(tenantId).collection("agendamentos")
        .where("data_inicio", "<", fim)
        .where("data_fim", ">", inicio)
        .where("status", "!=", "cancelado")
        .get();

    const agendamentosNoHorario = conflitosSnapshot.docs.map((d) => ({ id: d.id, ...d.data(), ref: d.ref }));

    // Alocação (Resumida para caber)
    let profissionalEscolhido = null;
    if (servicoNorm === "banho") {
        profissionalEscolhido = banhistas.find((b) => !agendamentosNoHorario.find((ag) => ag.profissional_id === b.id));
        if (!profissionalEscolhido) profissionalEscolhido = tosadores.find((t) => !agendamentosNoHorario.find((ag) => ag.profissional_id === t.id));
    } else if (servicoNorm === "tosa") {
        profissionalEscolhido = tosadores.find((t) => !agendamentosNoHorario.find((ag) => ag.profissional_id === t.id));
        if (!profissionalEscolhido) {
            // Tenta realocação
            const agMovel = agendamentosNoHorario.find((ag) => ag.servicoNorm === "banho" && tosadores.some((t) => t.id === ag.profissional_id));
            if (agMovel) {
                const banhistaLivre = banhistas.find((b) => !agendamentosNoHorario.find((ag) => ag.profissional_id === b.id));
                if (banhistaLivre) {
                    await agMovel.ref.update({ profissional_id: banhistaLivre.id, profissional_nome: banhistaLivre.nome });
                    profissionalEscolhido = tosadores.find((t) => t.id === agMovel.profissional_id);
                }
            }
        }
    }

    if (!profissionalEscolhido) throw new HttpsError("aborted", "Horário indisponível.");

    const novoAgendamento = {
        tenantId, userId: cpf_user, pet_id, profissional_id: profissionalEscolhido.id, profissional_nome: profissionalEscolhido.nome,
        servicoNorm, data_inicio: admin.firestore.Timestamp.fromDate(inicio), data_fim: admin.firestore.Timestamp.fromDate(fim),
        created_at: admin.firestore.FieldValue.serverTimestamp(), metodo_pagamento, valor: metodo_pagamento === "voucher" ? 0 : valor,
        status: metodo_pagamento === "pix" ? "aguardando_pagamento" : "agendado",
    };

    let resposta = { success: true };

    if (metodo_pagamento === "pix") {
        try {
            const efipay = new EfiPay(optionsEfi);
            const cobranca = await efipay.pixCreateImmediateCharge([], {
                calendario: { expiracao: 3600 }, devedor: { cpf: cpf_user.replace(/\D/g, ""), nome: "Cliente" },
                valor: { original: valor.toFixed(2) }, chave: process.env.EFI_CLIENT_ID_HOMOLOG
            });
            const qrCode = await efipay.pixGenerateQRCode({ id: cobranca.loc.id });
            novoAgendamento.txid = cobranca.txid;
            resposta = { success: true, pix_copia_cola: qrCode.qrcode, imagem_qrcode: qrCode.imagemQrcode };
        } catch (e) { console.error("Erro PIX:", e); }
    }

    await db.collection("tenants").doc(tenantId).collection("agendamentos").add(novoAgendamento);
    return resposta;
});

// --- 3. SALVAR CHECKLIST ---
exports.salvarChecklistPet = onCall({ region: "southamerica-east1" }, async (request) => {
    const { data, auth } = request;
    const responsavelId = auth ? auth.uid : "nao_logado";
    const responsavelNome = (auth && auth.token && auth.token.name) ? auth.token.name : "Profissional";
    const { agendamentoId, checklist, tenantId } = data;

    if (!agendamentoId || !checklist || !tenantId) throw new HttpsError("invalid-argument", "Dados incompletos.");

    const agendamentoRef = db.collection("tenants").doc(tenantId).collection("agendamentos").doc(agendamentoId);

    await agendamentoRef.update({
        "checklist": { ...checklist, responsavel_id: responsavelId, responsavel_nome: responsavelNome, data_registro: admin.firestore.FieldValue.serverTimestamp() },
        "checklist_feito": true
    });
    return { success: true };
});