import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'recibo_screen.dart'; // Certifique-se de que este arquivo existe

class MinhasAgendas extends StatefulWidget {
  final String userCpf;

  const MinhasAgendas({super.key, required this.userCpf});

  @override
  State<MinhasAgendas> createState() => _MinhasAgendasState();
}

class _MinhasAgendasState extends State<MinhasAgendas> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

  Map<String, Map<String, dynamic>> _petsCache = {};

  @override
  void initState() {
    super.initState();
    _carregarPets();
  }

  Future<void> _carregarPets() async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(widget.userCpf)
          .collection('pets')
          .get();

      final Map<String, Map<String, dynamic>> pets = {};
      for (var doc in snapshot.docs) {
        pets[doc.id] = doc.data();
      }

      if (mounted) {
        setState(() {
          _petsCache = pets;
        });
      }
    } catch (e) {
      // Erro silencioso ou log
    }
  }

  Map<String, List<DocumentSnapshot>> _groupAppointmentsByDate(
    List<DocumentSnapshot> docs,
  ) {
    final Map<String, List<DocumentSnapshot>> grouped = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final Timestamp? ts = data['data_inicio'];
      if (ts == null) continue;

      final date = ts.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(Duration(days: 1));
      final itemDate = DateTime(date.year, date.month, date.day);

      String key;
      if (itemDate == today) {
        key = "Hoje";
      } else if (itemDate == tomorrow) {
        key = "Amanhã";
      } else {
        key = DateFormat('dd/MM - EEEE', 'pt_BR').format(date);
        key = key[0].toUpperCase() + key.substring(1);
      }

      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(doc);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('tenants')
            .doc(AppConfig.tenantId)
            .collection('agendamentos')
            .where('userId', isEqualTo: widget.userCpf)
            .orderBy('data_inicio', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // --- ESTADO DE CARREGAMENTO ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _corAcai));
          }

          // --- ESTADO DE VAZIO ---
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverFillRemaining(child: _buildEmptyState()),
              ],
            );
          }

          // --- PREPARAÇÃO DOS DADOS ---
          final docs = snapshot.data!.docs;
          final groupedDocs = _groupAppointmentsByDate(docs);

          return CustomScrollView(
            physics: BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final sectionKey = groupedDocs.keys.elementAt(index);
                    final sectionDocs = groupedDocs[sectionKey]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(sectionKey),
                        ...sectionDocs.map((doc) => _buildCardModerno(doc)),
                        SizedBox(height: 10),
                      ],
                    );
                  }, childCount: groupedDocs.keys.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: _corFundo,
      expandedHeight: 80.0,
      floating: true,
      pinned: false,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: 20, bottom: 10),
        title: Text(
          "Minhas Agendas",
          style: TextStyle(
            color: _corAcai,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      centerTitle: false,
      automaticallyImplyLeading:
          true, // Garante que o botão de voltar apareça se necessário
      iconTheme: IconThemeData(color: _corAcai),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 10, left: 5),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: _corAcai.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // --- O NOVO DESIGN DO CARD ---
  Widget _buildCardModerno(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Tratamento de Dados
    Timestamp? ts = data['data_inicio'];
    final DateTime dataInicio = ts != null ? ts.toDate() : DateTime.now();
    final String status = data['status'] ?? 'agendado';
    final String servico = _capitalize(
      data['servicoNorm'] ?? data['servico'] ?? 'Serviço',
    );

    // Recupera dados do Pet do Cache
    final String? petId = data['pet_id'];
    final Map<String, dynamic>? petData = (petId != null)
        ? _petsCache[petId]
        : null;
    final String petName = petData?['nome'] ?? 'Seu Pet';
    final String petType = petData?['tipo'] ?? 'dog'; // default to dog icon

    // Configuração Visual baseada no Status
    Color corTema = Colors.grey;
    String textoStatus = "Agendado";
    IconData statusIcon = FontAwesomeIcons.calendarCheck;

    if (status == 'banhando') {
      corTema = Colors.blue;
      textoStatus = "No Banho";
      statusIcon = FontAwesomeIcons.shower;
    } else if (status == 'tosando') {
      corTema = Colors.orange;
      textoStatus = "Na Tosa";
      statusIcon = FontAwesomeIcons.scissors;
    } else if (status == 'pronto') {
      corTema = Colors.purple;
      textoStatus = "Pronto";
      statusIcon = FontAwesomeIcons.dog;
    } else if (status == 'concluido') {
      corTema = Colors.green;
      textoStatus = "Finalizado";
      statusIcon = FontAwesomeIcons.checkDouble;
    } else if (status == 'cancelado') {
      corTema = Colors.red;
      textoStatus = "Cancelado";
      statusIcon = FontAwesomeIcons.xmark;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _abrirRecibo(context, data, doc.id),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 1. Coluna Hora (Estilo Timeline)
                Column(
                  children: [
                    Text(
                      DateFormat('HH:mm').format(dataInicio),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: corTema.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, size: 8, color: corTema),
                          SizedBox(width: 4),
                          Text(
                            textoStatus.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: corTema,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(width: 16),

                // Divisória Vertical
                Container(width: 1, height: 40, color: Colors.grey[200]),

                SizedBox(width: 16),

                // 2. Info Principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            petType == 'gato'
                                ? FontAwesomeIcons.cat
                                : FontAwesomeIcons.dog,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          SizedBox(width: 6),
                          Text(
                            petName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        servico,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // 3. Ícone de Ação
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _corFundo,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Colors.grey[400],
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
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(35),
              decoration: BoxDecoration(
                color: _corAcai.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                FontAwesomeIcons.calendarXmark,
                size: 50,
                color: _corAcai.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: 24),
            Text(
              "Nenhum agendamento",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Seu pet está merecendo um cuidado especial. Que tal agendar algo agora?",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Agendar Novo Horário",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return "";
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}
