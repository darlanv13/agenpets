import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:agenpet/painel_loja_web/views/vet/nova_consulta_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/painel_loja_web/widgets/product_editor_dialog.dart'; // Placeholder for customer dialog
import 'package:agenpet/painel_loja_web/widgets/servicos_select_dialog.dart'; // Placeholder

// NEW: Dialog for Client/Pet Search
import 'dialogs/busca_tutor_pet_dialog.dart';

class VetDashboardView extends StatefulWidget {
  const VetDashboardView({super.key});

  @override
  State<VetDashboardView> createState() => _VetDashboardViewState();
}

class _VetDashboardViewState extends State<VetDashboardView> {
  final _db = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _agendamentosStream;

  String? _selectedAgendamentoId;
  String _termoBusca = "";
  final TextEditingController _searchController = TextEditingController();

  // Cores
  final Color _corAcai = const Color(0xFF4A148C);
  final Color _corFundo = const Color(0xFFF5F7FA);
  final Color _corSucesso = const Color(0xFF00C853);
  final Color _corAtencao = const Color(0xFFFF6D00);
  final Color _corProcesso = const Color(0xFF2962FF);

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    _agendamentosStream = _db
        .collection('tenants')
        .doc(AppConfig.tenantId)
        .collection('agendamentos')
        .where('servico', isEqualTo: 'veterinario')
        .where('data_inicio', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('data_inicio', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('data_inicio')
        .snapshots();
  }

  void _iniciarNovoAtendimento() async {
    // 1. Abre Dialog de Busca de Tutor e Pet
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const BuscaTutorPetDialog(),
    );

    if (result != null) {
      // 2. Se selecionado, inicia consulta com dados reais
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NovaConsultaScreen(petData: result),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Column(
        children: [
          // HEADER
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(FontAwesomeIcons.userDoctor, color: _corAcai, size: 20),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Agenda Veterinária",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          DateFormat("EEEE, d MMM", 'pt_BR').format(DateTime.now()).toUpperCase(),
                          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _iniciarNovoAtendimento,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("NOVO ATENDIMENTO"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _corAcai,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          // BODY (SPLIT VIEW)
          Expanded(
            child: Row(
              children: [
                // LISTA (ESQUERDA)
                Expanded(
                  flex: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(right: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _termoBusca = v.toLowerCase()),
                            decoration: InputDecoration(
                              hintText: "Buscar paciente...",
                              prefixIcon: const Icon(Icons.search, color: Colors.grey),
                              filled: true,
                              fillColor: _corFundo,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                            ),
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _agendamentosStream,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) return const Center(child: Text("Erro ao carregar"));
                              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                              final docs = snapshot.data!.docs;
                              if (docs.isEmpty) {
                                return const Center(
                                  child: Text("Nenhum agendamento hoje.", style: TextStyle(color: Colors.grey)),
                                );
                              }

                              // Auto-select first if none selected
                              if (_selectedAgendamentoId == null && docs.isNotEmpty) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) setState(() => _selectedAgendamentoId = docs.first.id);
                                });
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                itemCount: docs.length,
                                itemBuilder: (context, index) => _buildListItem(docs[index]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // DETALHES (DIREITA)
                Expanded(
                  flex: 70,
                  child: _selectedAgendamentoId == null
                      ? _buildEmptyDetails()
                      : StreamBuilder<DocumentSnapshot>(
                          key: ValueKey(_selectedAgendamentoId), // Force rebuild on change
                          stream: _db
                              .collection('tenants')
                              .doc(AppConfig.tenantId)
                              .collection('agendamentos')
                              .doc(_selectedAgendamentoId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            if (!snapshot.data!.exists) return _buildEmptyDetails();
                            return _buildDetailsPanel(snapshot.data!);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isSelected = _selectedAgendamentoId == doc.id;
    final petNome = data['pet_nome'] ?? 'Pet';
    final tutorNome = data['tutor_nome'] ?? 'Tutor';

    // Filter
    if (_termoBusca.isNotEmpty) {
      if (!petNome.toLowerCase().contains(_termoBusca) && !tutorNome.toLowerCase().contains(_termoBusca)) {
        return const SizedBox.shrink();
      }
    }

    final status = data['status'] ?? 'agendado';
    Color statusColor = Colors.grey;
    if (status == 'em_atendimento') statusColor = _corProcesso;
    if (status == 'concluido') statusColor = _corSucesso;
    if (status == 'cancelado') statusColor = Colors.red;

    final hora = (data['data_inicio'] as Timestamp).toDate();

    return GestureDetector(
      onTap: () => setState(() => _selectedAgendamentoId = doc.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? _corAcai.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _corAcai : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Text(
                  DateFormat('HH:mm').format(hora),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(petNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(tutorNome, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            if (status == 'concluido')
              const Icon(Icons.check_circle, size: 16, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDetails() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.userDoctor, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text("Selecione um paciente para iniciar", style: TextStyle(color: Colors.grey[400], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final petData = {
      'id': data['pet_id'],
      'nome': data['pet_nome'],
      'raca': data['pet_raca'],
      'tutor_nome': data['tutor_nome'],
      'tutor_id': data['userId'], // Ensure we pass userId as tutor_id
      'agendamento_id': doc.id,
    };

    return Container(
      padding: const EdgeInsets.all(30),
      color: _corFundo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: _corAcai.withOpacity(0.1),
                  child: Icon(FontAwesomeIcons.dog, size: 35, color: _corAcai),
                ),
                const SizedBox(width: 25),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        petData['nome'] ?? 'Pet',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "${petData['raca'] ?? 'Raça não inf.'} • Tutor: ${petData['tutor_nome']}",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          _buildTag("Peso: -- kg", Colors.blue[50]!, Colors.blue[800]!),
                          const SizedBox(width: 10),
                          _buildTag("Idade: -- anos", Colors.orange[50]!, Colors.orange[800]!),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                         Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NovaConsultaScreen(petData: petData),
                          ),
                        );
                      },
                      icon: const Icon(FontAwesomeIcons.stethoscope, size: 18),
                      label: const Text("INICIAR CONSULTA"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _corAcai,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Ver histórico
                      },
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text("VER HISTÓRICO"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Placeholder for Timeline / Recent Activity
          const Text("Atividades Recentes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: const Center(
                child: Text(
                  "Histórico de consultas será exibido aqui.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
