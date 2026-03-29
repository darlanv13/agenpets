# Relatório de Melhorias e Funcionalidades Faltantes - Projeto AgenPets

Este documento detalha as áreas do projeto que podem ser melhoradas e funcionalidades críticas que estão faltando para um SaaS de gestão de PetShop e Clínica Veterinária robusto. A análise foi baseada na estrutura atual do código (`painel_loja_web`, `functions`, `app_cliente`, `profissional_app`).

## 1. Gestão Financeira (Área Crítica)

Atualmente, o sistema possui um Dashboard de Faturamento (`DashboardView`), mas carece de uma gestão financeira completa. Para um SaaS, isso é essencial.

*   **Fluxo de Caixa Real:** Implementar **Contas a Pagar** (fornecedores, aluguel, luz) e **Contas a Receber** (vendas a prazo, cartões). O Dashboard atual mostra apenas "Vendas", o que não reflete o lucro real.
*   **DRE (Demonstração do Resultado do Exercício):** Relatório contábil gerencial para mostrar Lucro Líquido.
*   **Conciliação Bancária:** Importação de extrato OFX para bater com o caixa.
*   **Plano de Contas:** Categorização de receitas e despesas (ex: "Despesas Operacionais", "Custo da Mercadoria Vendida").
*   **Fechamento de Caixa Cego:** O operador informa quanto tem na gaveta sem saber o total do sistema, para evitar furtos.

## 2. Gestão de Estoque e Compras

O módulo atual (`EstoqueView`) permite ajustes manuais e controle de validade, mas faltam processos profissionais de compra.

*   **Entrada de Nota Fiscal (XML):** Permitir importar o XML da NFe de compra para dar entrada no estoque automaticamente, cadastrando fornecedor e custos sem digitação manual.
*   **Gestão de Fornecedores:** Vincular produtos a fornecedores para facilitar reposição.
*   **Pedido de Compra e Cotação:** Gerar pedidos para enviar aos fornecedores por e-mail/WhatsApp.
*   **Curva ABC:** Relatório para identificar os 20% dos produtos que geram 80% da receita.
*   **Controle de Lote (Rastreabilidade):** Essencial para vacinas e medicamentos. Saber exatamente para qual cliente foi vendido o lote X em caso de recall.

## 3. Gestão Veterinária Avançada (Prontuário e Internação)

O `NovaConsultaScreen` cobre o básico (anamnese, exame físico), mas clínicas completas precisam de mais:

*   **Internação (Hospitalar):** Mapa de leitos, prescrição diária, checagem de fluidoterapia e sinais vitais hora a hora (folha de sala).
*   **Receituário Digital e Atestados:**
    *   Gerador de PDF para receitas e atestados com layout profissional.
    *   Assinatura Digital (ICP-Brasil) ou integração com plataformas como Memed.
*   **Odontograma:** Mapa visual da boca do animal para procedimentos odontológicos.
*   **Gestão de Exames:**
    *   Anexo de PDFs de resultados externos.
    *   Requisição de exames para laboratórios parceiros.
*   **Cirurgia:** Ficha anestésica e descrição cirúrgica.

## 4. CRM e Marketing (Fidelização)

A automação atual de WhatsApp (`notifications_whatsapp.js`) é reativa (confirmação). É preciso ser **proativo**.

*   **Régua de Cobrança e Lembranças:**
    *   Lembrete automático de Vacinas vencendo (Recall).
    *   Lembrete de vermífugo/antipulgas recorrente.
    *   Mensagem de Aniversário do Pet.
*   **Programa de Fidelidade (Cashback/Pontos):** "A cada 10 banhos, ganhe 1".
*   **Pesquisa de Satisfação (NPS):** Enviar link após o atendimento.

## 5. Melhorias Técnicas e Arquitetura

*   **Segurança (Hardcoded Secrets):** O arquivo `functions/controllers/notifications_whatsapp.js` contém tokens do Facebook expostos no código. **Urgente:** Mover para Variáveis de Ambiente ou Google Secret Manager.
*   **Performance e Escalabilidade:**
    *   O `EstoqueView` e `DashboardView` leem coleções inteiras (`snapshots()`). Isso ficará lento e caro com o crescimento dos dados. Implementar **paginação no servidor** (Server-Side Pagination).
    *   Uso de **Algolia** ou **ElasticSearch** para buscas textuais complexas (nomes de produtos, clientes), tirando a carga do Firestore.
*   **Offline First:** O App Profissional e Cliente devem funcionar melhor sem internet, sincronizando dados quando a conexão voltar (usando `sqflite` ou `hive` localmente com sync manager).
*   **Testes Automatizados:** Implementar testes de unidade e integração para garantir que novas features não quebrem o fluxo crítico (agendamento/venda).

## 6. SaaS Admin (Super Admin)

*   **Gestão de Assinaturas do SaaS:** Painel para o dono do software ver quais Tenants (Petshops) estão inadimplentes e bloquear acesso automaticamente.
*   **Onboarding Automatizado:** Wizard para o próprio cliente configurar o sistema (logo, horários, serviços) sem intervenção de suporte.

---
**Recomendação de Prioridade:**
1.  **Segurança (Secrets):** Correção imediata.
2.  **Financeiro (Fluxo de Caixa):** Diferencial competitivo e necessidade básica de gestão.
3.  **Marketing (Lembrete de Vacinas):** Aumenta o faturamento do cliente (Petshop) trazendo o dono do pet de volta.
