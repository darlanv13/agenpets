import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class ProntuarioPetScreen extends StatefulWidget {
  final String userId;
  final String petId;
  final String petNome;

  const ProntuarioPetScreen({
    super.key,
    required this.userId,
    required this.petId,
    required this.petNome,
  });

  @override
  State<ProntuarioPetScreen> createState() => _ProntuarioPetScreenState();
}

class _ProntuarioPetScreenState extends State<ProntuarioPetScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = FirebaseFirestore.instance;

  final Color _corAcai = const Color(0xFF4A148C);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Prontuário de ${widget.petNome}",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: _corAcai,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Histórico Clínico"),
            Tab(text: "Carteira de Vacinação"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoricoList(),
          _buildVacinasList(),
        ],
      ),
    );
  }

  Widget _buildHistoricoList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('prontuario')
          .orderBy('data', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("Nenhum registro clínico encontrado.", FontAwesomeIcons.fileMedical);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final DateTime dataConsulta = (data['data'] as Timestamp).toDate();

            final diagnostico = data['diagnostico'] as Map<String, dynamic>? ?? {};
            final queixa = (data['anamnese'] as Map<String, dynamic>? ?? {})['queixa'] ?? 'Consulta de Rotina';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: _corAcai.withOpacity(0.1),
                  child: Icon(FontAwesomeIcons.stethoscope, color: _corAcai, size: 18),
                ),
                title: Text(
                  DateFormat("dd/MM/yyyy 'às' HH:mm").format(dataConsulta),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  diagnostico['definitivo'] ?? queixa,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("Queixa Principal"),
                        Text(queixa),
                        const SizedBox(height: 10),

                        if (diagnostico['definitivo'] != null && diagnostico['definitivo'].isNotEmpty) ...[
                          _buildSectionTitle("Diagnóstico"),
                          Text(diagnostico['definitivo']),
                          const SizedBox(height: 10),
                        ],

                        if (data['receita'] != null && (data['receita'] as List).isNotEmpty) ...[
                          _buildSectionTitle("Prescrição"),
                          ...(data['receita'] as List).map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, size: 6, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text("${r['nome']} ${r['conc']} - ${r['dose']}")),
                              ],
                            ),
                          )).toList(),
                        ]
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVacinasList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('vacinas')
          .orderBy('aplicacao_data', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("Nenhuma vacina registrada.", FontAwesomeIcons.syringe);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            // Handle null aplicacao_data safely
            final aplicacaoData = data['aplicacao_data'] != null
                ? (data['aplicacao_data'] as Timestamp).toDate()
                : DateTime.now();

            DateTime? revacData;
            if (data['revac_data'] != null) {
              if (data['revac_data'] is Timestamp) {
                revacData = (data['revac_data'] as Timestamp).toDate();
              } else if (data['revac_data'] is String) {
                // Fallback for string dates if any
                revacData = DateTime.tryParse(data['revac_data']);
              }
            }

            final bool isVencida = revacData != null && revacData.isBefore(DateTime.now());

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[50],
                  child: Icon(FontAwesomeIcons.syringe, color: Colors.blue[800], size: 16),
                ),
                title: Text(
                  data['nome'] ?? 'Vacina',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Aplicada em: ${DateFormat('dd/MM/yyyy').format(aplicacaoData)}"),
                    if (revacData != null)
                      Text(
                        "Revacinação: ${DateFormat('dd/MM/yyyy').format(revacData)}",
                        style: TextStyle(
                          color: isVencida ? Colors.red : Colors.green[700],
                          fontWeight: FontWeight.bold
                        ),
                      ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.grey[500],
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(msg, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}
