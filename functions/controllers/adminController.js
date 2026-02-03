const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db, admin } = require("../config/firebase");
const { getAuth } = require("firebase-admin/auth");

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
    const { nome, cpf, documento, senha, habilidades, perfil, tenantId, acessos } = request.data;

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
    // Agora o e-mail é específico por tenant para evitar conflitos
    const emailFantasma = `${docLimpo}@agenpets.${tenantId}`;
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
        } else {
            // Se não for novo usuário, significa que já existe NAQUELE TENANT
            // pois o email é único por tenant. Então lançamos erro.
            throw new HttpsError("already-exists", "Este profissional já possui cadastro nesta unidade.");
        }

        // Define Permissões (Claims) - Sempre define do zero pois é usuário novo/isolado
        const claims = {
            profissional: true,
            tenantId: tenantId,
            acessos: acessos || [],
        };
        if (perfil === "master") {
            claims.admin = true;
            claims.master = true;
        }
        await getAuth().setCustomUserClaims(userRecord.uid, claims);

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

        return { success: true, message: `Profissional ${nome} ${isNewUser ? "criado" : "vinculado"}!` };
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

// --- NOVO: Atualizar Conta Profissional ---
exports.atualizarContaProfissional = onCall({
    region: "southamerica-east1",
    maxInstances: 10,
    cors: true,
}, async (request) => {
    const { uid, nome, habilidades, acessos, perfil, tenantId } = request.data;

    if (!uid || !tenantId) {
        throw new HttpsError("invalid-argument", "UID e TenantId são obrigatórios.");
    }

    try {
        // 1. Atualizar no Auth (Display Name e Claims)
        await admin.auth().updateUser(uid, { displayName: nome });

        const claims = {
            profissional: true,
            tenantId: tenantId,
            acessos: acessos || [],
        };
        if (perfil === "master") {
            claims.admin = true;
            claims.master = true;
        }
        await admin.auth().setCustomUserClaims(uid, claims);

        // 2. Atualizar no Firestore
        const updateData = {
            nome: nome,
            habilidades: habilidades || [],
            acessos: acessos || [],
            perfil: perfil || "padrao",
            atualizado_em: admin.firestore.FieldValue.serverTimestamp(),
        };

        // Remove campos undefined/null para não apagar dados véios sem querer
        Object.keys(updateData).forEach((key) => updateData[key] === undefined && delete updateData[key]);

        await db.collection("tenants")
            .doc(tenantId)
            .collection("profissionais")
            .doc(uid)
            .update(updateData);

        return { success: true, message: "Profissional atualizado com sucesso!" };
    } catch (error) {
        console.error("Erro ao atualizar conta:", error);
        throw new HttpsError("internal", error.message);
    }
});

// --- NOVO: Deletar Conta Profissional ---
exports.deletarContaProfissional = onCall({
    region: "southamerica-east1",
    maxInstances: 10,
    cors: true,
}, async (request) => {
    const { uid, tenantId } = request.data;

    if (!uid || !tenantId) {
        throw new HttpsError("invalid-argument", "UID e TenantId são obrigatórios.");
    }

    try {
        // 1. Deletar do Auth
        await admin.auth().deleteUser(uid);

        // 2. Deletar do Firestore
        await db.collection("tenants")
            .doc(tenantId)
            .collection("profissionais")
            .doc(uid)
            .delete();

        return { success: true, message: "Profissional excluído com sucesso!" };
    } catch (error) {
        console.error("Erro ao deletar conta:", error);
        // Se o usuário não existe no Auth (já deletado manualmente), prossegue para limpar o Firestore
        if (error.code === "auth/user-not-found") {
            await db.collection("tenants")
                .doc(tenantId)
                .collection("profissionais")
                .doc(uid)
                .delete();
            return { success: true, message: "Registro limpo (usuário Auth não existia)." };
        }
        throw new HttpsError("internal", error.message);
    }
});
