const admin = require("firebase-admin");
// 1. Importar o getFirestore separadamente para poder escolher o banco
const { getFirestore } = require("firebase-admin/firestore");

const serviceAccount = require("./functions/serviceAccountKey.json");

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

// 2. AQUI ESTÁ A CORREÇÃO:
// Em vez de admin.firestore(), usamos:
const db = getFirestore("agenpets");

async function criarDadosFicticios() {
    console.log("🚀 Iniciando criação da agenda fictícia no banco 'agenpets'...");

    try {
        // 1. Criar Parâmetros
        await db.collection("config").doc("parametros").set({
            horario_abertura: "08:00",
            horario_fechamento: "18:00",
            tempo_banho_min: 60,
            tempo_tosa_min: 90
        });
        console.log("✅ Configurações de horário criadas!");

        // 2. Criar Profissionais
        await db.collection("profissionais").doc("pro_ana").set({
            nome: "Ana Silva",
            ativo: true,
            habilidades: ["banho"],
            peso_prioridade: 1,
            cpf: "123.456.789-00"
        });
        console.log("✅ Profissional Ana criada (Banho).");

        await db.collection("profissionais").doc("pro_carlos").set({
            nome: "Carlos Souza",
            ativo: true,
            habilidades: ["banho", "tosa"],
            peso_prioridade: 2,
            cpf: "111.222.333-44"
        });
        console.log("✅ Profissional Carlos criado (Banho e Tosa).");

        console.log("\n🎉 Sucesso! Agora o App vai encontrar horários disponíveis.");

    } catch (error) {
        console.error("❌ Erro ao criar dados:", error);
    }
}

criarDadosFicticios();