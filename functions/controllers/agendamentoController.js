const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { db, admin } = require("../config/firebase"); // O admin é essencial para datas!
const { addMinutes, format, parse, isSameDay } = require("date-fns"); // date-fns essencial
const EfiPay = require("sdk-node-apis-efi");
const optionsEfi = require("../config/efipay");

function addDays(date, days) {
    const result = new Date(date);
    result.setDate(result.getDate() + days);
    return result;
}

// --- Função Corrigida: BUSCAR HORÁRIOS ---
exports.buscarHorarios = onCall(async (request) => {
    try {
        const data = request.data;
        const { dataConsulta, servico, tenantId } = data;

        if (!tenantId) {
            throw new HttpsError("invalid-argument", "ID da loja (tenantId) é obrigatório.");
        }

        // CORREÇÃO 1: Criamos a variável servicoNorm que o código usa depois
        const servicoNorm = servico ? servico.toLowerCase() : "";

        // Busca Configuração da Loja
        const configDoc = await db.collection("tenants")
            .doc(tenantId)
            .collection("config")
            .doc("parametros")
            .get();
        const config = configDoc.exists ? configDoc.data() : {};

        // 1. Separa os Profissionais da Loja
        const prosSnapshot = await db.collection("tenants")
            .doc(tenantId)
            .collection("profissionais")
            .where("ativo", "==", true)
            .get();
        const banhistas = [];
        const tosadores = [];

        prosSnapshot.forEach((doc) => {
            const p = { id: doc.id, ...doc.data() };
            // Garante que habilidades existam e sejam minúsculas
            const skills = (p.habilidades || []).map((h) => h.toLowerCase());

            if (skills.includes("tosa")) {
                tosadores.push(p);
            } else if (skills.includes("banho")) { // Else if para evitar duplicidade
                banhistas.push(p);
            }
        });

        const duracaoServico = servicoNorm === "tosa" ? (config.tempo_tosa_min || 90) : (config.tempo_banho_min || 60);

        // 2. Busca agendamentos do dia (DA LOJA)
        const startOfDay = new Date(`${dataConsulta}T00:00:00`);
        const endOfDay = new Date(`${dataConsulta}T23:59:59`);

        const agendamentosSnapshot = await db.collection("tenants")
            .doc(tenantId)
            .collection("agendamentos")
            .where("data_inicio", ">=", startOfDay)
            .where("data_inicio", "<=", endOfDay)
            .where("status", "!=", "cancelado")
            .get();

        const agendamentos = agendamentosSnapshot.docs.map((doc) => ({ ...doc.data(), id: doc.id }));

        // 3. Loop de Horários
        const gradeHorarios = [];

        // CORREÇÃO 2: Parse manual seguro das horas (para evitar erros do date-fns parse string)
        const [hAbre, mAbre] = (config.horario_abertura || "08:00").split(":").map(Number);
        const [hFecha, mFecha] = (config.horario_fechamento || "18:00").split(":").map(Number);

        // Define horaAtual
        let horaAtual = new Date(`${dataConsulta}T00:00:00`);
        horaAtual.setHours(hAbre, mAbre, 0, 0);

        // Define horaLimite (agora sim a variável existe!)
        const horaLimite = new Date(`${dataConsulta}T00:00:00`);
        horaLimite.setHours(hFecha, mFecha, 0, 0);

        // Agora o loop usa a variável certa: horaLimite
        while (addMinutes(horaAtual, duracaoServico) <= horaLimite) {
            const slotInicio = new Date(horaAtual); // Clona data para não bugar referência
            const slotFim = addMinutes(horaAtual, duracaoServico);

            // Verifica ocupação
            const isOcupado = (proId) => {
                return agendamentos.find((ag) => {
                    const agInicio = ag.data_inicio.toDate();
                    const agFim = ag.data_fim.toDate();
                    return ag.profissional_id === proId && (
                        (slotInicio < agFim && slotFim > agInicio)
                    );
                });
            };

            let temVaga = false;

            // --- LÓGICA DE VAGA (Agora usando servicoNorm que existe) ---
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
                            // Verifica se o serviço no agendamento conflituoso é banho
                            const servicoDoConflito = (ag.servico || ag.servicoNorm || "").toLowerCase();
                            return ag && servicoDoConflito === "banho";
                        });
                        if (podeTrocar) temVaga = true;
                    }
                }
            }

            // Formata e adiciona na grade
            const hStr = horaAtual.getHours().toString().padStart(2, "0");
            const mStr = horaAtual.getMinutes().toString().padStart(2, "0");

            gradeHorarios.push({
                hora: `${hStr}:${mStr}`,
                livre: temVaga,
            });

            horaAtual = addMinutes(horaAtual, config.intervalo_agenda || 30);
        }

        return { grade: gradeHorarios };
    } catch (e) {
        console.error("Erro CRÍTICO buscarHorarios:", e);
        // Retorna lista vazia para o app não travar, mas loga o erro no console
        return { grade: [] };
    }
});

// --- ATUALIZADO: Criar Agendamento (Aceita Voucher) ---
exports.criarAgendamento = onCall(async (request) => {
    // 1. Recebe os dados incluindo o tenantId
    const { tenantId, cpf_user, metodo_pagamento, servico, data_hora, pet_id, valor } = request.data;

    // Validações Iniciais
    if (!tenantId) throw new HttpsError("invalid-argument", "ID da loja (tenantId) é obrigatório.");
    if (!data_hora) throw new HttpsError("invalid-argument", "Data e hora são obrigatórios.");

    // Normaliza o nome do serviço para evitar erros (Ex: "Banho" vira "banho")
    const servicoNorm = servico ? servico.toLowerCase() : "";

    // --- LÓGICA DE VOUCHER (ISOLADA POR LOJA) ---
    if (metodo_pagamento === "voucher") {
        const voucherRef = db.collection("users")
            .doc(cpf_user)
            .collection("vouchers")
            .doc(tenantId); // <--- Verifica saldo NA LOJA ATUAL

        const voucherDoc = await voucherRef.get();
        const saldoData = voucherDoc.data();

        // Verifica se tem saldo do serviço específico
        if (!saldoData || !saldoData[servicoNorm] || saldoData[servicoNorm] <= 0) {
            throw new HttpsError("failed-precondition", `Saldo de voucher insuficiente para ${servico} nesta loja.`);
        }

        // Se tiver saldo, desconta DESTA LOJA
        await voucherRef.update({
            [servicoNorm]: admin.firestore.FieldValue.increment(-1),
        });
    }

    // --- BUSCA CONFIGURAÇÃO DA LOJA ---
    // Agora busca em: tenants/{tenantId}/config/parametros
    const configDoc = await db.collection("tenants")
        .doc(tenantId)
        .collection("config")
        .doc("parametros")
        .get();

    // Se a loja não tiver config, usa um fallback (opcional) ou erro
    const config = configDoc.exists ? configDoc.data() : { tempo_tosa_min: 60, tempo_banho_min: 40 };
    const duracao = servicoNorm === "tosa" ? config.tempo_tosa_min : config.tempo_banho_min;

    const inicio = new Date(data_hora);
    const fim = addMinutes(inicio, duracao);

    // --- 1. BUSCA PROFISSIONAIS DA LOJA ---
    const prosSnapshot = await db.collection("tenants")
        .doc(tenantId)
        .collection("profissionais")
        .where("ativo", "==", true)
        .get();

    const banhistas = [];
    const tosadores = [];

    prosSnapshot.forEach((doc) => {
        const p = { id: doc.id, ...doc.data() };
        // Garante que a verificação de array seja segura
        const habilidades = p.habilidades || [];
        if (habilidades.includes("tosa")) tosadores.push(p);
        else banhistas.push(p);
    });

    // --- 2. BUSCA AGENDAMENTOS DA LOJA PARA CONFLITO ---
    const conflitosSnapshot = await db.collection("tenants")
        .doc(tenantId)
        .collection("agendamentos")
        .where("data_inicio", "<", fim)
        .where("data_fim", ">", inicio)
        .where("status", "!=", "cancelado")
        .get();

    const agendamentosNoHorario = conflitosSnapshot.docs.map((d) => ({
        id: d.id,
        ...d.data(),
        ref: d.ref, // Mantemos a referência para poder atualizar se precisar mover (reallocação)
    }));

    // --- ALGORITMO DE ALOCAÇÃO INTELIGENTE (Mantido e Adaptado) ---
    let profissionalEscolhido = null;

    if (servicoNorm === "banho") {
        // Prioridade 1: Banhista Livre
        profissionalEscolhido = banhistas.find((b) => !agendamentosNoHorario.find((ag) => ag.profissional_id === b.id));

        // Prioridade 2: Tosador Livre (se não tiver banhista)
        if (!profissionalEscolhido) {
            profissionalEscolhido = tosadores.find((t) => !agendamentosNoHorario.find((ag) => ag.profissional_id === t.id));
        }
    } else if (servicoNorm === "tosa") {
        // Prioridade 1: Tosador 100% Livre
        profissionalEscolhido = tosadores.find((t) => !agendamentosNoHorario.find((ag) => ag.profissional_id === t.id));

        // Prioridade 2: REALOCAÇÃO (Roubar vaga do banho)
        if (!profissionalEscolhido) {
            // Procura um Tosador que esteja fazendo BANHO
            const agendamentoParaMover = agendamentosNoHorario.find((ag) =>
                ag.servicoNorm === "banho" && tosadores.some((t) => t.id === ag.profissional_id),
            );

            if (agendamentoParaMover) {
                // Achamos um Tosador ocupado com Banho.
                // Agora precisamos de um Banhista Livre para assumir esse B.O.
                const banhistaSalvador = banhistas.find((b) => !agendamentosNoHorario.find((ag) => ag.profissional_id === b.id));

                if (banhistaSalvador) {
                    console.log(`♻️ REALOCANDO (Loja ${tenantId}): Movendo banho do Tosador ${agendamentoParaMover.profissional_nome} para Banhista ${banhistaSalvador.nome}`);

                    // 1. Atualiza o agendamento antigo (Move pro banhista)
                    // Como pegamos a referência lá em cima (.ref), podemos dar update direto
                    await agendamentoParaMover.ref.update({
                        profissional_id: banhistaSalvador.id,
                        profissional_nome: banhistaSalvador.nome,
                    });

                    // 2. Define o Tosador (agora livre) para a nossa Tosa
                    const tosadorLiberado = tosadores.find((t) => t.id === agendamentoParaMover.profissional_id);
                    profissionalEscolhido = tosadorLiberado;
                }
            }
        }
    }

    if (!profissionalEscolhido) {
        throw new HttpsError("aborted", "Infelizmente o horário acabou de ser preenchido.");
    }

    // --- PREPARA O NOVO AGENDAMENTO ---
    const novoAgendamento = {
        tenantId, // Importante salvar o ID da loja no documento
        userId: cpf_user,
        pet_id,
        profissional_id: profissionalEscolhido.id,
        profissional_nome: profissionalEscolhido.nome,
        servicoNorm,
        data_inicio: admin.firestore.Timestamp.fromDate(inicio),
        data_fim: admin.firestore.Timestamp.fromDate(fim),
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        metodo_pagamento,
        valor: metodo_pagamento === "voucher" ? 0 : valor,
        status: metodo_pagamento === "pix" ? "aguardando_pagamento" : "agendado",
    };

    let resposta = { success: true, mensagem: "Agendado com sucesso!" };

    // --- GERAÇÃO DE PIX (EfiPay) ---
    if (metodo_pagamento === "pix") {
        try {
            const efipay = new EfiPay(optionsEfi);
            const bodyPix = {
                calendario: { expiracao: 3600 },
                devedor: { cpf: cpf_user.replace(/\D/g, ""), nome: "Cliente AgenPet" },
                valor: { original: valor.toFixed(2) },
                chave: process.env.EFI_CLIENT_ID_HOMOLOG, // <--- ATENÇÃO: Use a chave da configuração ou fixa
            };
            const cobranca = await efipay.pixCreateImmediateCharge([], bodyPix);
            const qrCode = await efipay.pixGenerateQRCode({ id: cobranca.loc.id });

            novoAgendamento.txid = cobranca.txid;
            resposta = { success: true, pix_copia_cola: qrCode.qrcode, imagem_qrcode: qrCode.imagemQrcode };
        } catch (e) {
            console.error("Erro PIX:", e);
        }
    }

    // --- SALVA O AGENDAMENTO NA LOJA ---
    await db.collection("tenants")
        .doc(tenantId)
        .collection("agendamentos")
        .add(novoAgendamento);

    return resposta;
});


// --- FUNÇÃO ATUALIZADA: Realizar Venda de Assinatura (Balcão/Admin) ---
exports.realizarVendaAssinatura = onCall(async (request) => {
    const { userId, pacoteId, metodoPagamento, tenantId } = request.data;

    // 1. Validações
    if (!userId || !pacoteId) throw new HttpsError("invalid-argument", "Dados incompletos");
    if (!tenantId) throw new HttpsError("invalid-argument", "ID da loja (tenantId) é obrigatório.");

    // 2. Busca dados OFICIAIS do Pacote (DA LOJA)
    const pacoteRef = db.collection("tenants")
        .doc(tenantId)
        .collection("pacotes")
        .doc(pacoteId);

    const pacoteSnap = await pacoteRef.get();
    if (!pacoteSnap.exists) throw new HttpsError("not-found", "Pacote não encontrado");
    const pacoteData = pacoteSnap.data();

    // 3. Busca Cliente
    const userRef = db.collection("users").doc(userId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) throw new HttpsError("not-found", "Cliente não encontrado");
    const userData = userSnap.data();

    // 4. Prepara Transação Atômica (Batch)
    const batch = db.batch();
    const dataVenda = admin.firestore.FieldValue.serverTimestamp();

    // Regra de Validade: 30 dias (Alinhei com seu código Flutter, mas você pode mudar para 45 se preferir)
    // Certifique-se de ter a função 'addDays' importada ou use lógica nativa de data
    const validadeDate = addDays(new Date(), 30);

    // A. Registra o Histórico da Venda (Mantém igual para relatórios)
    const vendaRef = db.collection("tenants").doc(tenantId).collection("vendas_assinaturas").doc();
    batch.set(vendaRef, {
        userId: userId,
        tenantId: tenantId, // <--- Importante para filtro
        user_nome: userData.nome || "Cliente",
        pacote_nome: pacoteData.nome,
        pacote_id: pacoteId,
        valor: Number(pacoteData.preco || 0),
        metodo_pagamento: metodoPagamento,
        data_venda: dataVenda,
        status: "pago",
        atendente: "Admin/Balcão",
        origem: "painel_web",
    });

    // --- MUDANÇA PRINCIPAL AQUI ---

    // B. Monta o Objeto do Voucher (Igual ao Flutter)
    const novoItemVoucher = {
        nome_pacote: pacoteData.nome,
        validade_pacote: admin.firestore.Timestamp.fromDate(validadeDate),
        data_compra: dataVenda,
    };

    // Varre o pacote para pegar as quantidades (banho: 4, tosa: 2...)
    // Transforma 'vouchers_banho' em 'banho'
    for (const [key, value] of Object.entries(pacoteData)) {
        if (key.startsWith("vouchers_") && typeof value === "number" && value > 0) {
            const nomeServico = key.replace("vouchers_", ""); // Remove o prefixo
            novoItemVoucher[nomeServico] = value;
        }
    }

    // C. Atualiza o Usuário (Agora usando subcoleção da loja)
    batch.update(userRef, {
        assinante_ativo: true,
        ultima_compra: dataVenda,
    });

    // Atualiza/Cria o documento de vouchers da loja
    const voucherRef = userRef.collection("vouchers").doc(tenantId);

    // Prepara update da subcoleção
    const voucherUpdate = {
        ultima_compra: dataVenda,
        validade: admin.firestore.Timestamp.fromDate(validadeDate),
        // Campos de contagem serão incrementados abaixo
    };

    // Mapeia os itens do pacote para incrementos
    for (const [key, value] of Object.entries(pacoteData)) {
        if (key.startsWith("vouchers_") && typeof value === "number" && value > 0) {
            const nomeServico = key.replace("vouchers_", "");
            voucherUpdate[nomeServico] = admin.firestore.FieldValue.increment(value);
        }
    }

    batch.set(voucherRef, voucherUpdate, { merge: true });

    // 5. Efetiva tudo
    await batch.commit();

    return {
        sucesso: true,
        mensagem: "Venda realizada com sucesso!",
        validade: validadeDate.toISOString(),
    };
});

// --- NOVA FUNÇÃO: Salvar Checklist do Pet ---

// CORREÇÃO: Tratamento seguro para 'auth' (evita o erro reading 'uid')
exports.salvarChecklistPet = onCall({
    region: "southamerica-east1",
    maxInstances: 10,
    cors: true,
}, async (request) => {
    const { data, auth } = request;

    // 1. Definição segura do responsável (Funciona com ou sem login)
    // Se 'auth' existir, usa o UID real. Se não, usa um valor padrão.
    const responsavelId = auth ? auth.uid : "usuario_nao_logado";
    const responsavelNome = (auth && auth.token && auth.token.name) ? auth.token.name : "Profissional (Sem Auth)";

    /* SE QUISER BLOQUEAR O ACESSO SEM LOGIN, DESCOMENTE ISTO:
         if (!auth) {
             throw new HttpsError('unauthenticated', 'Usuário não autenticado.');
         }
      */

    const { agendamentoId, checklist, tenantId } = data;

    // 2. Validações básicas
    if (!agendamentoId || !checklist) {
        throw new HttpsError("invalid-argument", "Dados incompletos: ID ou checklist faltando.");
    }

    if (!tenantId) {
        throw new HttpsError("invalid-argument", "ID da loja (tenantId) é obrigatório.");
    }

    // Nota: Usamos 'db' importado no topo do arquivo (não crie admin.firestore() aqui)
    const agendamentoRef = db.collection("tenants")
        .doc(tenantId)
        .collection("agendamentos")
        .doc(agendamentoId);

    try {
        const doc = await agendamentoRef.get();
        if (!doc.exists) {
            throw new HttpsError("not-found", "Agendamento não encontrado.");
        }

        // 3. Prepara o objeto para salvar
        const dadosChecklist = {
            ...checklist,
            "responsavel_id": responsavelId, // <--- Agora usa a variável segura
            "responsavel_nome": responsavelNome, // <--- Agora usa a variável segura
            "data_registro": admin.firestore.FieldValue.serverTimestamp(),
            "versao_app": "2.1",
        };

        // 4. Atualiza o documento
        await agendamentoRef.update({
            "checklist": dadosChecklist,
            "checklist_feito": true,
        });

        return { success: true, message: "Checklist salvo com sucesso." };
    } catch (error) {
        console.error("Erro ao salvar checklist:", error);
        if (error.code) {
            throw error;
        }
        throw new HttpsError("internal", "Erro interno ao salvar checklist.");
    }
});
