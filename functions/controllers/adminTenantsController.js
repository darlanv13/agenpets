const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {db, admin} = require("../config/firebase");

// --- 1. Testar Credenciais do Gateway (Simulação) ---
exports.testarCredenciaisGateway = onCall(async (request) => {
  return {
    success: true,
    message: "Conexão com Gateway verificada com sucesso (Simulação via Admin Tenants).",
  };
});

// --- 2. Criar Novo Tenant ---
exports.criarTenant = onCall(async (request) => {
  const {nome, cidade, slug, emailAdmin} = request.data;

  if (!nome) {
    throw new HttpsError("invalid-argument", "O nome da loja é obrigatório.");
  }

  // Gera ID: slug ou sanitiza o nome
  const tenantId = slug || nome.toLowerCase().replace(/[^a-z0-9]/g, "-");

  // Verifica se já existe
  const docRef = db.collection("tenants").doc(tenantId);
  const docSnap = await docRef.get();
  if (docSnap.exists) {
    throw new HttpsError("already-exists", "Já existe uma loja com este ID (slug).");
  }

  const batch = db.batch();

  // 1. Cria Documento Principal
  batch.set(docRef, {
    nome: nome,
    cidade: cidade || "Não informada",
    ativo: true,
    email_responsavel: emailAdmin || "",
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 2. Cria Configuração Inicial (Parametros)
  const configRef = docRef.collection("config").doc("parametros");
  batch.set(configRef, {
    tem_banho: true,
    tem_tosa: true,
    tem_hotel: false,
    tem_creche: false,
    gateway_pagamento: "efipay", // Default
    logo_app_url: "",
    logo_admin_url: "",
  });

  await batch.commit();

  return {
    success: true,
    tenantId: tenantId,
    message: "Loja criada com sucesso!",
  };
});

// --- 3. Atualizar Dados do Tenant ---
exports.atualizarTenant = onCall(async (request) => {
  const {tenantId, nome, cidade, emailAdmin} = request.data;

  if (!tenantId) {
    throw new HttpsError("invalid-argument", "ID do Tenant obrigatório.");
  }

  const updates = {};
  if (nome) updates.nome = nome;
  if (cidade) updates.cidade = cidade;
  if (emailAdmin) updates.email_responsavel = emailAdmin;
  updates.updated_at = admin.firestore.FieldValue.serverTimestamp();

  await db.collection("tenants").doc(tenantId).update(updates);

  return {success: true, message: "Dados atualizados."};
});

// --- 4. Alternar Status (Ativar/Inativar) ---
exports.alternarStatusTenant = onCall(async (request) => {
  const {tenantId, ativo} = request.data;

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
