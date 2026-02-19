const { db } = require('../config/firebase');

exports.salvarConsulta = async (req, res) => {
    try {
        const { tenantId, petData, consultaData, itensCobranca } = req.body;

        // 1. Salvar o Prontuário/Consulta
        const consultaRef = await db.collection('tenants').doc(tenantId)
            .collection('consultas').add({
                ...consultaData,
                pet_id: petData.id,
                pet_nome: petData.nome,
                tutor_nome: petData.tutor,
                created_at: new Date(),
                status: 'concluida'
            });

        // 2. Atualizar dados vitais no cadastro do Pet (Histórico de peso)
        if (consultaData.exame_fisico && consultaData.exame_fisico.peso) {
            await db.collection('tenants').doc(tenantId)
                .collection('pets').doc(petData.id).update({
                    peso_atual: consultaData.exame_fisico.peso,
                    ultima_consulta: new Date()
                });
        }

        // 3. Se houver itens para cobrar, criar uma Comanda para o PDV
        if (itensCobranca && itensCobranca.length > 0) {
            // Calcula total
            const total = itensCobranca.reduce((sum, item) => sum + (item.preco || 0), 0);

            await db.collection('tenants').doc(tenantId)
                .collection('comandas').add({
                    cliente_nome: petData.tutor,
                    pet_nome: petData.nome,
                    origem_tipo: 'VETERINARIO',
                    origem_id: consultaRef.id,
                    status: 'aberta', // Aparece na aba "Serviços" do PDV
                    created_at: new Date(),
                    valor_total: total,
                    itens: itensCobranca.map(item => ({
                        nome: item.nome,
                        preco: item.preco,
                        tipo: 'servico_vet',
                        qtd: 1
                    }))
                });
        }

        return res.status(200).json({ success: true, id: consultaRef.id });
    } catch (error) {
        console.error("Erro ao salvar consulta:", error);
        return res.status(500).json({ error: error.message });
    }
};