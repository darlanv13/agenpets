import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'recibo_screen.dart'; // Certifique-se de que este arquivo existe

class MinhasAgendas extends StatefulWidget {
  final String userCpf;

  const MinhasAgendas({Key? key, required this.userCpf}) : super(key: key);

  @override
  _MinhasAgendasState createState() => _MinhasAgendasState();
}

class _MinhasAgendasState extends State<MinhasAgendas> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      appBar: AppBar(
        title: Text(
          "Meus Agendamentos",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('agendamentos')
            .where('userId', isEqualTo: widget.userCpf)
            .orderBy('data_inicio', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _corAcai));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs = snapshot.data!.docs;

          // Filtra ativos e histórico
          final ativos = docs.where((doc) {
            String s = doc['status'] ?? '';
            return ['agendado', 'banhando', 'tosando', 'pronto'].contains(s);
          }).toList();

          final listaGeral = docs.where((doc) {
            String s = doc['status'] ?? '';
            return ['concluido', 'cancelado'].contains(s);
          }).toList();

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              if (ativos.isNotEmpty) ...[
                _buildSectionTitle(
                  "ACONTECENDO AGORA",
                  Icons.circle,
                  Colors.redAccent,
                ),
                ...ativos
                    .map((doc) => _buildCardModerno(doc, isAtivo: true))
                    .toList(),
                SizedBox(height: 25),
              ],

              _buildSectionTitle("HISTÓRICO", Icons.history, Colors.grey),
              if (listaGeral.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    "Nenhum histórico recente.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),

              ...listaGeral
                  .map((doc) => _buildCardModerno(doc, isAtivo: false))
                  .toList(),
              SizedBox(height: 40), // Espaço extra no final
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 5, top: 10),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // --- O NOVO DESIGN DO CARD ---
  Widget _buildCardModerno(DocumentSnapshot doc, {required bool isAtivo}) {
    final data = doc.data() as Map<String, dynamic>;

    // Tratamento de Dados
    Timestamp? ts = data['data_inicio'];
    final DateTime dataInicio = ts != null ? ts.toDate() : DateTime.now();
    final String status = data['status'] ?? 'agendado';
    final String servico = _capitalize(
      data['servicoNorm'] ?? data['servico'] ?? 'Serviço',
    );

    // Configuração Visual baseada no Status
    Color corTema = Colors.grey;
    String textoStatus = "Agendado";
    String textoBotao = "Detalhes";
    IconData iconeBotao = Icons.chevron_right;
    Color bgButton = Colors.white;
    Color textButtonColor = Colors.grey[700]!;

    if (status == 'banhando') {
      corTema = Colors.blue;
      textoStatus = "No Banho";
      textoBotao = "Acompanhar";
      iconeBotao = FontAwesomeIcons.eye;
      bgButton = Colors.blue[50]!;
      textButtonColor = Colors.blue[800]!;
    } else if (status == 'tosando') {
      corTema = Colors.orange;
      textoStatus = "Na Tosa";
      textoBotao = "Acompanhar";
      iconeBotao = FontAwesomeIcons.eye;
      bgButton = Colors.orange[50]!;
      textButtonColor = Colors.orange[800]!;
    } else if (status == 'pronto') {
      corTema = Colors.purple;
      textoStatus = "Pronto p/ Sair";
      textoBotao = "Buscar Pet";
      iconeBotao = FontAwesomeIcons.dog;
      bgButton = Colors.purple[50]!;
      textButtonColor = Colors.purple[800]!;
    } else if (status == 'concluido') {
      corTema = Colors.green;
      textoStatus = "Finalizado";
      textoBotao = "Ver Recibo";
      iconeBotao = Icons.receipt_long;
      bgButton = Colors.grey[100]!;
      textButtonColor = Colors.grey[800]!;
    } else if (status == 'cancelado') {
      corTema = Colors.red;
      textoStatus = "Cancelado";
      textoBotao = "Ver info";
      bgButton = Colors.red[50]!;
      textButtonColor = Colors.red;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _abrirRecibo(context, data, doc.id),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. FAIXA LATERAL COLORIDA (Identidade Visual do Status)
                Container(width: 6, color: corTema),

                // 2. CONTEÚDO DO CARD
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TOPO: DATA E HORA (Discreto)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  "${DateFormat('dd/MM').format(dataInicio)} • ${DateFormat('HH:mm').format(dataInicio)}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            // Badge de Status Pequeno
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: corTema.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                textoStatus.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: corTema,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12),

                        // MEIO: SERVIÇO E PET (Destaque)
                        Row(
                          children: [
                            // Avatar do Pet (Placeholder)
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _corFundo,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                FontAwesomeIcons.paw,
                                color: Colors.grey[400],
                                size: 18,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    servico,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "Agendamento #${doc.id.substring(0, 4).toUpperCase()}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 15),

                        // RODAPÉ: BOTÃO DE AÇÃO
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            decoration: BoxDecoration(
                              color: bgButton,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    _abrirRecibo(context, data, doc.id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        textoBotao,
                                        style: TextStyle(
                                          color: textButtonColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Icon(
                                        iconeBotao,
                                        size: 12,
                                        color: textButtonColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _abrirRecibo(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReciboScreen(data: data, docId: docId),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              FontAwesomeIcons.calendarPlus,
              size: 40,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 20),
          Text(
            "Você ainda não tem agendamentos.",
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _corAcai,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            onPressed: () =>
                Navigator.pop(context), // Volta ou leva pra agendar
            child: Text("Agendar Agora", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return "";
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}
