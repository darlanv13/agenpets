const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { db, admin } = require("../config/firebase"); // O admin é essencial para datas!
const { addMinutes, format, parse, isSameDay } = require("date-fns"); // date-fns essencial
const EfiPay = require("sdk-node-apis-efi");
const optionsEfi = require("../config/efipay");

// --- Buscar Horários (Mantido igual) ---
// --- Função Corrigida: BUSCAR HORÁRIOS ---
exports.buscarHorarios = onCall(async (request) => {
    try {
        const data = request.data;
        const { dataConsulta, servico } = data;

        // CORREÇÃO 1: Criamos a variável servicoNorm que o código usa depois
        const servicoNorm = servico ? servico.toLowerCase() : '';

        const configDoc = await db.collection("config").doc("parametros").get();
        const config = configDoc.exists ? configDoc.data() : {};

        // 1. Separa os Profissionais
        const prosSnapshot = await db.collection("profissionais").where("ativo", "==", true).get();
        const banhistas = [];
        const tosadores = [];

        prosSnapshot.forEach(doc => {
            const p = { id: doc.id, ...doc.data() };
            // Garante que habilidades existam e sejam minúsculas
            const skills = (p.habilidades || []).map(h => h.toLowerCase());

            if (skills.includes('tosa')) {
                tosadores.push(p);
            } else if (skills.includes('banho')) { // Else if para evitar duplicidade
                banhistas.push(p);
            }
        });

        const duracaoServico = servicoNorm === 'tosa' ? (config.tempo_tosa_min || 90) : (config.tempo_banho_min || 60);

        // 2. Busca agendamentos do dia
        const startOfDay = new Date(`${dataConsulta}T00:00:00`);
        const endOfDay = new Date(`${dataConsulta}T23:59:59`);

        const agendamentosSnapshot = await db.collection("agendamentos")
            .where("data_inicio", ">=", startOfDay)
            .where("data_inicio", "<=", endOfDay)
            .where("status", "!=", "cancelado")
            .get();

        const agendamentos = agendamentosSnapshot.docs.map(doc => ({ ...doc.data(), id: doc.id }));

        // 3. Loop de Horários
        let gradeHorarios = [];

        // CORREÇÃO 2: Parse manual seguro das horas (para evitar erros do date-fns parse string)
        const [hAbre, mAbre] = (config.horario_abertura || "08:00").split(':').map(Number);
        const [hFecha, mFecha] = (config.horario_fechamento || "18:00").split(':').map(Number);

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
                return agendamentos.find(ag => {
                    const agInicio = ag.data_inicio.toDate();
                    const agFim = ag.data_fim.toDate();
                    return ag.profissional_id === proId && (
                        (slotInicio < agFim && slotFim > agInicio)
                    );
                });
            };

            let temVaga = false;

            // --- LÓGICA DE VAGA (Agora usando servicoNorm que existe) ---
            if (servicoNorm === 'banho') {
                if (banhistas.some(b => !isOcupado(b.id))) temVaga = true;
                else if (tosadores.some(t => !isOcupado(t.id))) temVaga = true;
            } else if (servicoNorm === 'tosa') {
                if (tosadores.some(t => !isOcupado(t.id))) {
                    temVaga = true;
                } else {
                    const banhistasLivres = banhistas.filter(b => !isOcupado(b.id));
                    if (banhistasLivres.length > 0) {
                        const podeTrocar = tosadores.some(t => {
                            const ag = isOcupado(t.id);
                            // Verifica se o serviço no agendamento conflituoso é banho
                            const servicoDoConflito = (ag.servico || ag.servicoNorm || '').toLowerCase();
                            return ag && servicoDoConflito === 'banho';
                        });
                        if (podeTrocar) temVaga = true;
                    }
                }
            }

            // Formata e adiciona na grade
            const hStr = horaAtual.getHours().toString().padStart(2, '0');
            const mStr = horaAtual.getMinutes().toString().padStart(2, '0');

            gradeHorarios.push({
                hora: `${hStr}:${mStr}`,
                livre: temVaga
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
    const servicoNorm = servico.toLowerCase();
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
    const duracao = servicoNorm === 'tosa' ? config.tempo_tosa_min : config.tempo_banho_min;

    const inicio = new Date(data_hora);
    const fim = addMinutes(inicio, duracao);

    // 1. Busca Profissionais
    const prosSnapshot = await db.collection("profissionais").where("ativo", "==", true).get();
    const banhistas = [];
    const tosadores = [];
    prosSnapshot.forEach(doc => {
        const p = { id: doc.id, ...doc.data() };
        if (p.habilidades.includes('tosa')) tosadores.push(p);
        else banhistas.push(p);
    });

    // 2. Busca Agendamentos Conflitantes no Horário
    const conflitosSnapshot = await db.collection("agendamentos")
        .where("data_inicio", "<", fim)
        .where("data_fim", ">", inicio)
        .where("status", "!=", "cancelado")
        .get();

    const agendamentosNoHorario = conflitosSnapshot.docs.map(d => ({ id: d.id, ...d.data(), ref: d.ref }));

    let profissionalEscolhido = null;

    if (servicoNorm === 'banho') {
        // Prioridade 1: Banhista Livre
        profissionalEscolhido = banhistas.find(b => !agendamentosNoHorario.find(ag => ag.profissional_id === b.id));

        // Prioridade 2: Tosador Livre (se não tiver banhista)
        if (!profissionalEscolhido) {
            profissionalEscolhido = tosadores.find(t => !agendamentosNoHorario.find(ag => ag.profissional_id === t.id));
        }

    } else if (servicoNorm === 'tosa') {
        // Prioridade 1: Tosador 100% Livre
        profissionalEscolhido = tosadores.find(t => !agendamentosNoHorario.find(ag => ag.profissional_id === t.id));

        // Prioridade 2: REALOCAÇÃO (Roubar vaga do banho)
        if (!profissionalEscolhido) {
            // Procura um Tosador que esteja fazendo BANHO
            const agendamentoParaMover = agendamentosNoHorario.find(ag =>
                ag.servicoNorm === 'banho' && tosadores.some(t => t.id === ag.profissional_id)
            );

            if (agendamentoParaMover) {
                // Achamos um Tosador ocupado com Banho. 
                // Agora precisamos de um Banhista Livre para assumir esse B.O.
                const banhistaSalvador = banhistas.find(b => !agendamentosNoHorario.find(ag => ag.profissional_id === b.id));

                if (banhistaSalvador) {
                    console.log(`♻️ REALOCANDO: Movendo banho do Tosador ${agendamentoParaMover.profissional_nome} para Banhista ${banhistaSalvador.nome}`);

                    // 1. Atualiza o agendamento antigo (Move pro banhista)
                    await agendamentoParaMover.ref.update({
                        profissional_id: banhistaSalvador.id,
                        profissional_nome: banhistaSalvador.nome
                    });

                    // 2. Define o Tosador (agora livre) para a nossa Tosa
                    const tosadorLiberado = tosadores.find(t => t.id === agendamentoParaMover.profissional_id);
                    profissionalEscolhido = tosadorLiberado;
                }
            }
        }
    }

    if (!profissionalEscolhido) {
        throw new HttpsError('aborted', 'Infelizmente o horário acabou de ser preenchido.');
    }

    const novoAgendamento = {
        userId: cpf_user,
        pet_id,
        profissional_id: profissionalEscolhido.id, // Aqui já vai o Tosador (que pode ter sido liberado agora)
        profissional_nome: profissionalEscolhido.nome,
        servicoNorm,
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

// --- NOVA FUNÇÃO: Realizar Checkout (Painel Admin) ---
exports.realizarCheckout = onCall(async (request) => {
    // 1. Recebe dados do Painel
    const { agendamentoId, extrasIds, metodoPagamento, vouchersParaUsar } = request.data;

    if (!agendamentoId) throw new HttpsError('invalid-argument', 'ID do agendamento é obrigatório');

    // 2. Busca o Agendamento
    const agendamentoRef = db.collection('agendamentos').doc(agendamentoId);
    const agendamentoSnap = await agendamentoRef.get();

    if (!agendamentoSnap.exists) throw new HttpsError('not-found', 'Agendamento não encontrado');

    const dadosAgendamento = agendamentoSnap.data();
    if (dadosAgendamento.status === 'concluido') {
        throw new HttpsError('failed-precondition', 'Este agendamento já foi finalizado.');
    }

    // 3. Busca o Usuário (Para checar saldo de vouchers)
    const userId = dadosAgendamento.userId;
    const userRef = db.collection('users').doc(userId);
    const userSnap = await userRef.get();
    const userData = userSnap.data() || {};

    // 4. Calcular Valor Base e Verificar Vouchers
    // Se o voucher for usado, o valor do serviço base (Banho/Tosa) vira 0.
    let valorFinal = Number(dadosAgendamento.valor || 0);
    let vouchersConsumidosLog = {}; // Log para salvar no histórico
    let usouVoucherBase = false;

    if (vouchersParaUsar) {
        for (const [chaveVoucher, usar] of Object.entries(vouchersParaUsar)) {
            if (usar === true) {
                // Validação de segurança: O usuário TEM esse voucher?
                const saldoAtual = userData[chaveVoucher] || 0;

                if (saldoAtual > 0) {
                    // Tem saldo! Zera o custo do serviço base e marca para descontar
                    valorFinal = 0;
                    vouchersConsumidosLog[chaveVoucher] = true;
                    usouVoucherBase = true;
                } else {
                    // Não tem saldo (tentativa de fraude ou erro de interface)
                    console.warn(`Admin tentou usar ${chaveVoucher} para ${userId} sem saldo.`);
                    // Aqui optamos por não descontar e cobrar o valor cheio, ou você pode lançar erro:
                    // throw new HttpsError('failed-precondition', `Cliente sem saldo de ${chaveVoucher}`);
                }
            }
        }
    }

    // 5. Calcular Extras (Busca preço no banco para segurança)
    let extrasProcessados = [];
    if (extrasIds && extrasIds.length > 0) {
        for (const extraId of extrasIds) {
            const extraDoc = await db.collection('servicos_extras').doc(extraId).get();
            if (extraDoc.exists) {
                const extraData = extraDoc.data();
                const precoReal = Number(extraData.preco || 0);

                valorFinal += precoReal; // Soma ao total

                extrasProcessados.push({
                    id: extraId,
                    nome: extraData.nome,
                    preco: precoReal
                });
            }
        }
    }

    // 6. Atualização Atômica (Batch)
    const batch = db.batch();

    // A. Atualiza status do Agendamento
    batch.update(agendamentoRef, {
        status: 'concluido',
        status_pagamento: 'pago',
        metodo_pagamento: metodoPagamento,
        pago_em: admin.firestore.FieldValue.serverTimestamp(),
        valor_final_cobrado: valorFinal,
        vouchers_consumidos: vouchersConsumidosLog,
        extras: extrasProcessados,
        usou_voucher: usouVoucherBase
    });

    // B. Desconta os vouchers do usuário (apenas os validados)
    for (const [chave, usou] of Object.entries(vouchersConsumidosLog)) {
        if (usou) {
            batch.update(userRef, {
                [chave]: admin.firestore.FieldValue.increment(-1)
            });
        }
    }

    await batch.commit();

    return {
        sucesso: true,
        mensagem: 'Checkout realizado com sucesso!',
        valorCobrado: valorFinal
    };
});

// --- NOVA FUNÇÃO: Realizar Venda de Assinatura (Balcão/Admin) ---
exports.realizarVendaAssinatura = onCall(async (request) => {
    const { userId, pacoteId, metodoPagamento } = request.data;

    // 1. Validações
    if (!userId || !pacoteId) throw new HttpsError('invalid-argument', 'Dados incompletos');

    // 2. Busca dados OFICIAIS do Pacote (Segurança)
    const pacoteRef = db.collection('pacotes_assinatura').doc(pacoteId);
    const pacoteSnap = await pacoteRef.get();
    if (!pacoteSnap.exists) throw new HttpsError('not-found', 'Pacote não encontrado');
    const pacoteData = pacoteSnap.data();

    // 3. Busca Cliente
    const userRef = db.collection('users').doc(userId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) throw new HttpsError('not-found', 'Cliente não encontrado');
    const userData = userSnap.data();

    // 4. Prepara Transação Atômica (Batch)
    const batch = db.batch();
    const dataVenda = admin.firestore.FieldValue.serverTimestamp();

    // Regra de Validade: 45 dias a partir de hoje
    const validadeDate = addDays(new Date(), 45);

    // A. Registra o Histórico da Venda
    const vendaRef = db.collection('vendas_assinaturas').doc();
    batch.set(vendaRef, {
        userId: userId,
        user_nome: userData.nome || 'Cliente',
        pacote_nome: pacoteData.nome,
        pacote_id: pacoteId,
        valor: Number(pacoteData.preco || 0),
        metodo_pagamento: metodoPagamento,
        data_venda: dataVenda,
        status: 'pago', // Balcão = pagamento imediato
        atendente: 'Admin/Balcão',
        origem: 'painel_web'
    });

    // B. Atualiza o Usuário (Vouchers + Validade)
    let updates = {
        assinante_ativo: true,
        ultima_compra: dataVenda,
        validade_assinatura: admin.firestore.Timestamp.fromDate(validadeDate)
    };

    // Lógica Dinâmica: Varre o pacote e soma TODOS os vouchers encontrados
    // Ex: se o pacote tem 'vouchers_banho': 4 e 'vouchers_tosa': 1
    for (const [key, value] of Object.entries(pacoteData)) {
        if (key.startsWith('vouchers_') && typeof value === 'number' && value > 0) {
            updates[key] = admin.firestore.FieldValue.increment(value);
        }
    }

    batch.update(userRef, updates);

    // 5. Efetiva tudo
    await batch.commit();

    return {
        sucesso: true,
        mensagem: 'Venda realizada com sucesso!',
        validade: validadeDate.toISOString()
    };
});
