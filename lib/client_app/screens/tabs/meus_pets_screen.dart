import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class MeusVouchersTab extends StatefulWidget {
  final String userCpf;

  const MeusVouchersTab({super.key, required this.userCpf});

  @override
  _MeusVouchersTabState createState() => _MeusVouchersTabState();
}

class _MeusVouchersTabState extends State<MeusVouchersTab> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Cores
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);

  @override
  Widget build(BuildContext context) {
    // Agora busca na subcoleção do Tenant atual
    return StreamBuilder<DocumentSnapshot>(
      stream: _db
          .collection('users')
          .doc(widget.userCpf)
          .collection('vouchers')
          .doc(AppConfig.tenantId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: _corAcai));
        }

        if (!snapshot.data!.exists) {
          return _buildSemAssinatura(context);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        // Verifica Validade
        Timestamp? validadeTs = data['validade'];
        if (validadeTs == null ||
            validadeTs.toDate().isBefore(DateTime.now())) {
          return _buildSemAssinatura(context);
        }

        // Como agora é um único documento por loja, tratamos como uma assinatura única ativa
        return SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Sua Assinatura Ativa",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 15),
              _buildAssinaturaCard(data),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssinaturaCard(Map<String, dynamic> dados) {
    // Extrai dados fixos (Adaptado para estrutura nova)
    // O nome do pacote pode não estar salvo se for apenas contadores,
    // mas idealmente salvamos no momento da compra. Se não tiver, chamamos de "Assinatura Local"
    String nomePacote = dados['nome_pacote'] ?? 'Assinatura Ativa';

    // Validade agora é 'validade', não 'validade_pacote'
    DateTime validade = (dados['validade'] as Timestamp).toDate();

    // Identifica chaves de serviços (ignora metadados)
    List<Widget> listaServicos = [];

    dados.forEach((key, value) {
      // Ignora campos que não são serviços (contadores)
      if (key != 'nome_pacote' &&
          key != 'validade' &&
          key != 'ultima_compra' &&
          value is int) {
        listaServicos.add(_buildSaldoRowDinamyc(key, value));
        listaServicos.add(Divider(height: 20));
      }
    });

    // Remove o último divider se existir
    if (listaServicos.isNotEmpty) listaServicos.removeLast();

    return Card(
      elevation: 8,
      shadowColor: _corAcai.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true, // Já vem aberto para facilitar
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          tilePadding: EdgeInsets.zero,

          // --- CABEÇALHO DO CARD ---
          title: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_corAcai, Color(0xFF7B1FA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(FontAwesomeIcons.crown, color: Colors.amber, size: 24),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "ATIVO",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                Text(
                  nomePacote,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Válido até ${DateFormat('dd/MM/yyyy').format(validade)}",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),

          // --- LISTA DE SERVIÇOS (DINÂMICA) ---
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "SALDO DE SERVIÇOS",
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 15),

                  // Aqui entram os serviços encontrados (Banhos, Tosas, Hidratação, etc)
                  ...listaServicos,

                  SizedBox(height: 25),

                  // Último Uso (Busca Assíncrona Global)
                  _buildUltimoUso(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaldoRowDinamyc(String keyServico, int qtd) {
    // Formata o nome (ex: "vouchers_banho" ou "banhos" -> "Banhos")
    String label = keyServico.replaceAll('_', ' ');
    label = label[0].toUpperCase() + label.substring(1); // Capitaliza

    // Escolhe ícone baseado no nome (lógica simples)
    IconData icon = FontAwesomeIcons.ticket;
    Color cor = Colors.grey;

    if (keyServico.contains('banho')) {
      icon = FontAwesomeIcons.shower;
      cor = Colors.blue;
    } else if (keyServico.contains('tosa')) {
      icon = FontAwesomeIcons.scissors;
      cor = Colors.orange;
    } else if (keyServico.contains('hidratacao')) {
      icon = FontAwesomeIcons.droplet;
      cor = Colors.cyan;
    }

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: FaIcon(icon, color: cor, size: 18),
        ),
        SizedBox(width: 15),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          "$qtd un",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: qtd > 0 ? Colors.black87 : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildUltimoUso() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _corLilas,
        borderRadius: BorderRadius.circular(15),
      ),
      child: FutureBuilder<QuerySnapshot>(
        future: _db
            .collection('tenants')
            .doc(AppConfig.tenantId)
            .collection('agendamentos')
            .where('userId', isEqualTo: widget.userCpf)
            .orderBy('data_inicio', descending: true)
            .limit(1)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Row(
              children: [
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text("Buscando histórico..."),
              ],
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Row(
              children: [
                Icon(Icons.history, color: _corAcai),
                SizedBox(width: 10),
                Text("Nenhum uso recente."),
              ],
            );
          }

          var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          DateTime dataUso = (data['data_inicio'] as Timestamp).toDate();
          String servico = data['servico'] ?? 'Serviço';

          return Row(
            children: [
              Icon(Icons.history_edu, color: _corAcai),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Último agendamento:",
                      style: TextStyle(fontSize: 12, color: _corAcai),
                    ),
                    Text(
                      "${DateFormat('dd/MM/yy').format(dataUso)} - $servico",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _corAcai,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSemAssinatura(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FontAwesomeIcons.ticket, size: 60, color: Colors.grey[300]),
            SizedBox(height: 20),
            Text(
              "Sem assinatura ativa",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Assine um de nossos planos para ganhar descontos e vouchers exclusivos.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(
                context,
                '/assinatura',
                arguments: {'cpf': widget.userCpf},
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _corAcai,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "VER PLANOS",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Text("Erro ao carregar perfil."));
  }
}
