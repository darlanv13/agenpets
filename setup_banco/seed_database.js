const admin = require("firebase-admin");

// --- CONFIGURAÇÃO ---
// Se você já tem o serviceAccountKey.json, aponte para ele.
// Caso contrário, certifique-se de estar logado via 'firebase login' e use o applicationDefault
const serviceAccount = require("./functions/serviceAccountKey.json"); // Caminho para sua chave

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function criarDadosFicticios() {
    console.log("🚀 Iniciando criação da agenda fictícia...");

    try {
        // 1. Criar Parâmetros do Sistema (Regras de Negócio)
        // O controller lê 'config/parametros' para saber os horários
        await db.collection("config").doc("parametros").set({
            horario_abertura: "08:00",
            horario_fechamento: "18:00",
            tempo_banho_min: 60, // 1 hora de banho
            tempo_tosa_min: 90   // 1h30 de tosa
        });
        console.log("✅ Configurações de horário criadas!");

        // 2. Criar Profissionais
        // Precisamos de profissionais com habilidades específicas e 'ativo: true'

        // Profissional 1: Ana (Especialista em Banho)
        await db.collection("profissionais").doc("pro_ana").set({
            nome: "Ana Silva",
            ativo: true,
            habilidades: ["banho"], // Só faz banho
            peso_prioridade: 1, // Preferência no algoritmo (mais barato/junior)
            cpf: "123.456.789-00" // Para teste de login
        });
        console.log("✅ Profissional Ana criada (Banho).");

        // Profissional 2: Carlos (Faz Banho e Tosa)
        await db.collection("profissionais").doc("pro_carlos").set({
            nome: "Carlos Souza",
            ativo: true,
            habilidades: ["banho", "tosa"], // Faz os dois
            peso_prioridade: 2,
            cpf: "111.222.333-44" // Para teste de login
        });
        console.log("✅ Profissional Carlos criado (Banho e Tosa).");

        console.log("\n🎉 Sucesso! Agora o App vai encontrar horários disponíveis.");

    } catch (error) {
        console.error("❌ Erro ao criar dados:", error);
    }
}

criarDadosFicticios(); cd
