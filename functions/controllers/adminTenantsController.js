const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db, admin } = require("../config/firebase");
const pixService = require("../services/pixService");
const fs = require('fs');


// --- 2. Criar Novo Tenant ---
exports.criarTenant = onCall(async (request) => {
  const { nome, cidade, slug, emailAdmin } = request.data;

  // Validação básica
  if (!nome) {
    throw new HttpsError("invalid-argument", "O nome da loja é obrigatório.");
  }

  // Gera ID: usa o slug fornecido ou sanitiza o nome
  const tenantId = slug || nome.toLowerCase().replace(/[^a-z0-9]/g, "-");

  // Verifica duplicidade
  const docRef = db.collection("tenants").doc(tenantId);
  const docSnap = await docRef.get();
  if (docSnap.exists) {
    throw new HttpsError("already-exists", "Já existe uma loja com este ID (slug).");
  }

  const batch = db.batch();

  // A. Cria Documento Principal
  batch.set(docRef, {
    nome: nome,
    cidade: cidade || "Não informada",
    ativo: true,
    email_responsavel: emailAdmin || "",
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  // B. Cria Configuração Pública Inicial (Parametros)
  // Nota: Não salvamos segredos aqui, apenas flags e configs públicas
  const configRef = docRef.collection("config").doc("parametros");
  batch.set(configRef, {
    tem_banho: true,
    tem_tosa: true,
    tem_hotel: false,
    tem_creche: false,
    gateway_pagamento: "mercadopago", // Default
    logo_app_url: "",
    logo_admin_url: "",
  });

  // C. (Opcional) Cria o documento de segredos vazio para garantir a estrutura
  const segredosRef = docRef.collection("config").doc("segredos");
  batch.set(segredosRef, {
    criado_em: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();

  return {
    success: true,
    tenantId: tenantId,
    message: "Loja criada com sucesso!",
  };
});

// --- 3. Atualizar Dados Básicos do Tenant ---
exports.atualizarTenant = onCall(async (request) => {
  const { tenantId, nome, cidade, emailAdmin } = request.data;

  if (!tenantId) {
    throw new HttpsError("invalid-argument", "ID do Tenant obrigatório.");
  }

  const updates = {};
  if (nome) updates.nome = nome;
  if (cidade) updates.cidade = cidade;
  if (emailAdmin) updates.email_responsavel = emailAdmin;
  updates.updated_at = admin.firestore.FieldValue.serverTimestamp();

  await db.collection("tenants").doc(tenantId).update(updates);

  return { success: true, message: "Dados atualizados." };
});

// --- 4. Alternar Status (Ativar/Inativar) ---
exports.alternarStatusTenant = onCall(async (request) => {
  const { tenantId, ativo } = request.data;

  if (!tenantId) {
    throw new HttpsError("invalid-argument", "ID do Tenant obrigatório.");
  }

  await db.collection("tenants").doc(tenantId).update({
    ativo: ativo,
    status_updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    message: ativo ? "Loja ativada com sucesso." : "Loja inativada com sucesso.",
  };
});

// --- 5. [NOVO] Salvar Credenciais de Pagamento (Segurança) ---
// Separa o que é público (parametros) do que é privado (segredos)
exports.salvarCredenciaisGateway = onCall(async (request) => {
  // Verifica autenticação (Recomendado)
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Usuário não autenticado.");
  }

  const {
    tenantId,
    gateway_pagamento,

    mercadopago_access_token,

  } = request.data;

  if (!tenantId) {
    throw new HttpsError("invalid-argument", "ID do Tenant obrigatório.");
  }

  const batch = db.batch();

  // A. Atualiza configs públicas (saber qual gateway está ativo)
  if (gateway_pagamento) {
    const publicConfigRef = db.collection("tenants").doc(tenantId).collection("config").doc("parametros");
    batch.set(publicConfigRef, {
      gateway_pagamento: gateway_pagamento,
    }, { merge: true });
  }

  // B. Atualiza credenciais no cofre seguro (config/segredos)
  // Regras do Firestore devem bloquear leitura pública deste documento
  const dadosSeguros = {
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
    atualizado_por: request.auth.uid, // Audit trail: quem alterou
  };

  // Só salva se o dado foi enviado (evita sobrescrever com null)
  if (efipay_client_id !== undefined) dadosSeguros.efipay_client_id = efipay_client_id;
  if (efipay_client_secret !== undefined) dadosSeguros.efipay_client_secret = efipay_client_secret;
  if (chave_pix !== undefined) dadosSeguros.chave_pix = chave_pix;
  if (mercadopago_access_token !== undefined) dadosSeguros.mercadopago_access_token = mercadopago_access_token;
  if (efipay_sandbox !== undefined) dadosSeguros.efipay_sandbox = efipay_sandbox;
  // Se o gateway mudou, salvamos também nos segredos para redundância/backend saber a preferência segura
  if (gateway_pagamento !== undefined) dadosSeguros.gateway_selecionado = gateway_pagamento;

  const secureConfigRef = db.collection("tenants").doc(tenantId).collection("config").doc("segredos");
  batch.set(secureConfigRef, dadosSeguros, { merge: true });

  await batch.commit();

  return {
    success: true,
    message: "Credenciais e configurações de pagamento salvas com segurança.",
  };
});

// --- 6. [NOVO] Verificar Existência da Loja (Para Login Profissional) ---
exports.verificarLoja = onCall(async (request) => {
  const { cnpj } = request.data; // Espera apenas números

  if (!cnpj) {
    throw new HttpsError("invalid-argument", "CNPJ é obrigatório.");
  }

  // Como definimos que o ID é o CNPJ (numérico), buscamos direto
  const docRef = db.collection("tenants").doc(cnpj);
  const docSnap = await docRef.get();

  if (!docSnap.exists) {
    throw new HttpsError("not-found", "Loja não encontrada. Verifique o CNPJ.");
  }

  const data = docSnap.data();
  if (data.ativo === false) {
    throw new HttpsError("permission-denied", "Esta loja está inativa.");
  }

  return {
    success: true,
    tenantId: docSnap.id,
    nome: data.nome,
  };
});