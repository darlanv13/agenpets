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
    const { nome, cpf, documento, senha, habilidades, perfil, tenantId } = request.data;

    const docFinal = documento || cpf;

    // 2. Validações
    if (!docFinal || !senha || !nome) {
        throw new HttpsError('invalid-argument', 'Nome, Documento (CPF/CNPJ) e Senha são obrigatórios.');
    }
    if (!tenantId) {
        throw new HttpsError('invalid-argument', 'ID da loja (tenantId) é obrigatório.');
    }
    if (senha.length < 6) {
        throw new HttpsError('invalid-argument', 'A senha deve ter no mínimo 6 dígitos.');
    }

    // 3. E-mail Fantasma (Shadow Email)
    const docLimpo = docFinal.replace(/\D/g, '');
    const emailFantasma = `${docLimpo}@agenpets.pro`;
    const tipoDocumento = docLimpo.length > 11 ? 'cnpj' : 'cpf';

    // Lógica do Código de Vendedor (Apenas CPF)
    let codigoVendedor = null;
    const skills = habilidades || [];
    const funcoesElegiveis = ['vendedor', 'tosa', 'banho'];

    // Verifica se tem alguma das funções elegíveis
    const temFuncaoElegivel = skills.some(s => funcoesElegiveis.includes(s.toLowerCase()));

    if (tipoDocumento === 'cpf' && temFuncaoElegivel) {
        codigoVendedor = docLimpo.substring(0, 4);
    }

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
        const dadosProfissional = {
            nome: nome,
            documento: docFinal, // Pode ser CPF ou CNPJ formatado
            cpf: docFinal,       // Mantém campo legado para compatibilidade
            doc_busca: docLimpo, // Números puros
            cpf_busca: docLimpo, // Legado
            tipo_documento: tipoDocumento,
            habilidades: habilidades || [],
            perfil: perfil || 'padrao', // 'master' ou 'padrao'
            ativo: true,
            criado_em: admin.firestore.FieldValue.serverTimestamp(),
            uid_auth: userRecord.uid,
            tenantId: tenantId
        };

        if (codigoVendedor) {
            dadosProfissional.codigo_vendedor = codigoVendedor;
        }

        await db.collection('tenants')
            .doc(tenantId)
            .collection('profissionais')
            .doc(userRecord.uid)
            .set(dadosProfissional);

        return { success: true, message: `Profissional ${nome} criado!` };

    } catch (error) {
        console.error("Erro ao criar conta:", error);
        if (error.code === 'auth/email-already-exists') {
            throw new HttpsError('already-exists', 'Este CPF já possui cadastro.');
        }
        throw new HttpsError('internal', error.message);
    }
});