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

    const { nome, cpf, senha, habilidades, perfil, tenantId } = request.data;

    // 2. Validações
    if (!cpf || !senha || !nome) {
        throw new HttpsError('invalid-argument', 'Nome, CPF e Senha são obrigatórios.');
    }
    if (!tenantId) {
        throw new HttpsError('invalid-argument', 'ID da loja (tenantId) é obrigatório.');
    }
    if (senha.length < 6) {
        throw new HttpsError('invalid-argument', 'A senha deve ter no mínimo 6 dígitos.');
    }

    // 3. E-mail Fantasma (Shadow Email)
    const cpfLimpo = cpf.replace(/\D/g, '');
    const emailFantasma = `${cpfLimpo}@agenpets.pro`;

    try {
        // 4. Cria Login no Firebase Auth
        const userRecord = await getAuth().createUser({
            email: emailFantasma,
            password: senha,
            displayName: nome,
        });

        // 5. Define Permissões (Claims)
        const claims = {
            profissional: true,
            tenantId: tenantId // <--- Vincula ao Tenant
        };
        if (perfil === 'master') {
            claims.admin = true;
            claims.master = true;
        }
        await getAuth().setCustomUserClaims(userRecord.uid, claims);

        // 6. Salva Perfil no Firestore (SEM A SENHA) na coleção do Tenant
        await db.collection('tenants')
            .doc(tenantId)
            .collection('profissionais')
            .doc(userRecord.uid)
            .set({
                nome: nome,
                cpf: cpf,         // Visual (com pontos)
                cpf_busca: cpfLimpo,
                habilidades: habilidades || [],
                perfil: perfil || 'padrao', // 'master' ou 'padrao'
                ativo: true,
                criado_em: admin.firestore.FieldValue.serverTimestamp(),
                uid_auth: userRecord.uid,
                tenantId: tenantId
            });

        return { success: true, message: `Profissional ${nome} criado!` };

    } catch (error) {
        console.error("Erro ao criar conta:", error);
        if (error.code === 'auth/email-already-exists') {
            throw new HttpsError('already-exists', 'Este CPF já possui cadastro.');
        }
        throw new HttpsError('internal', error.message);
    }
});