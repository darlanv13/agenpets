const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {db, admin} = require("../config/firebase");
const {getAuth} = require("firebase-admin/auth");

exports.criarContaProfissional = onCall({
  region: "southamerica-east1",
  maxInstances: 10,
  cors: true,
}, async (request) => {
  // 1. Segurança: (Descomente depois de ter o primeiro Master criado)
  /*
    if (!request.auth || request.auth.token.admin !== true) {
        throw new HttpsError('permission-denied', 'Apenas Admin/Master pode criar contas.');
    }
    */

  // Agora aceita 'documento' que pode ser CPF ou CNPJ.
  // Mantemos 'cpf' para compatibilidade se vier, mas preferimos 'documento'.
  const {nome, cpf, documento, senha, habilidades, perfil, tenantId, acessos} = request.data;

  const docFinal = documento || cpf;

  // 2. Validações
  if (!docFinal || !senha || !nome) {
    throw new HttpsError("invalid-argument", "Nome, Documento (CPF/CNPJ) e Senha são obrigatórios.");
  }
  if (!tenantId) {
    throw new HttpsError("invalid-argument", "ID da loja (tenantId) é obrigatório.");
  }
  if (senha.length < 6) {
    throw new HttpsError("invalid-argument", "A senha deve ter no mínimo 6 dígitos.");
  }

  // 3. E-mail Fantasma (Shadow Email)
  const docLimpo = docFinal.replace(/\D/g, "");
  const emailFantasma = `${docLimpo}@agenpets.pro`;
  const tipoDocumento = docLimpo.length > 11 ? "cnpj" : "cpf";

  // Lógica do Código de Vendedor (Apenas CPF)
  let codigoVendedor = null;
  const skills = habilidades || [];
  const funcoesElegiveis = ["vendedor", "tosa", "banho"];

  // Verifica se tem alguma das funções elegíveis
  const temFuncaoElegivel = skills.some((s) => funcoesElegiveis.includes(s.toLowerCase()));

  if (tipoDocumento === "cpf" && temFuncaoElegivel) {
    codigoVendedor = docLimpo.substring(0, 4);
  }

  try {
    let userRecord;
    let isNewUser = false;

    // 4. Tenta buscar usuário existente
    try {
      userRecord = await getAuth().getUserByEmail(emailFantasma);
    } catch (e) {
      if (e.code === "auth/user-not-found") {
        isNewUser = true;
      } else {
        throw e; // Relança outros erros
      }
    }

    if (isNewUser) {
      // --- CENÁRIO: NOVO USUÁRIO ---
      userRecord = await getAuth().createUser({
        email: emailFantasma,
        password: senha,
        displayName: nome,
      });

      // Define Permissões (Claims)
      const claims = {
        profissional: true,
        tenantId: tenantId,
        acessos: acessos || [], // Persiste acessos no token
      };
      if (perfil === "master") {
        claims.admin = true;
        claims.master = true;
      }
      await getAuth().setCustomUserClaims(userRecord.uid, claims);
    } else {
      // --- CENÁRIO: USUÁRIO JÁ EXISTE (Vínculo com nova Tenant) ---

      // Verifica se já está nesta tenant
      const docRef = db.collection("tenants")
          .doc(tenantId)
          .collection("profissionais")
          .doc(userRecord.uid);

      const docSnap = await docRef.get();
      if (docSnap.exists) {
        throw new HttpsError("already-exists", "Este profissional já está cadastrado nesta unidade.");
      }

      // Atualiza claims para incluir novos acessos e garantir tenantId
      // Nota: Em multi-tenant real, acessos nos claims podem ser problemáticos se conflitarem entre tenants.
      // Assumindo que o profissional atua principalmente neste tenant ou que a sobrescrita é intencional.
      const currentClaims = userRecord.customClaims || {};
      const newClaims = {
        ...currentClaims,
        profissional: true,
        tenantId: tenantId, // Atualiza para o tenant atual
        acessos: acessos || [],
      };

      if (perfil === "master") {
        newClaims.admin = true;
        newClaims.master = true;
      }

      await getAuth().setCustomUserClaims(userRecord.uid, newClaims);
    }

    // 6. Salva Perfil no Firestore (SEM A SENHA) na coleção do Tenant
    const dadosProfissional = {
      nome: nome,
      documento: docFinal, // Pode ser CPF ou CNPJ formatado
      cpf: docFinal, // Mantém campo legado para compatibilidade
      doc_busca: docLimpo, // Números puros
      cpf_busca: docLimpo, // Legado
      tipo_documento: tipoDocumento,
      habilidades: habilidades || [],
      acessos: acessos || [],
      perfil: perfil || "padrao", // 'master' ou 'padrao'
      ativo: true,
      criado_em: admin.firestore.FieldValue.serverTimestamp(),
      uid_auth: userRecord.uid,
      tenantId: tenantId,
    };

    if (codigoVendedor) {
      dadosProfissional.codigo_vendedor = codigoVendedor;
    }

    await db.collection("tenants")
        .doc(tenantId)
        .collection("profissionais")
        .doc(userRecord.uid)
        .set(dadosProfissional);

    return {success: true, message: `Profissional ${nome} ${isNewUser ? "criado" : "vinculado"}!`};
  } catch (error) {
    console.error("Erro ao criar conta:", error);
    if (error.code === "auth/email-already-exists") {
      // Fallback caso ocorra condição de corrida
      throw new HttpsError("already-exists", "Este CPF já possui cadastro.");
    }
    if (error.code === "already-exists") {
      throw error; // Re-throw do erro manual
    }
    throw new HttpsError("internal", error.message);
  }
});
