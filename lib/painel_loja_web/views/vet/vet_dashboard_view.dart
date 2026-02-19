import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:agenpet/painel_loja_web/views/vet/nova_consulta_screen.dart';

class VetDashboardView extends StatefulWidget {
  const VetDashboardView({super.key});

  @override
  State<VetDashboardView> createState() => _VetDashboardViewState();
}

class _VetDashboardViewState extends State<VetDashboardView> {
  late Stream<QuerySnapshot> _agendamentosStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    // Performance Optimization: Initialize the stream once in initState.
    // This prevents reconstructing the query and stream on every build/setState,
    // reducing unnecessary Firestore connection overhead.
    _agendamentosStream = FirebaseFirestore.instance
        .collection('tenants')
        .doc(AppConfig.tenantId)
        .collection('agendamentos')
        .where('servico', isEqualTo: 'veterinario')
        .orderBy('data_inicio', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Área Veterinária",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A148C),
              ),
            ),
            const SizedBox(height: 20),
            // Botão de Atendimento Avulso (Emergência)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A148C),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "NOVO ATENDIMENTO AVULSO",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                // Aqui você abriria um dialog para buscar o pet primeiro
                // Para exemplo, vou abrir direto com dados mockados
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NovaConsultaScreen(
                      petData: {
                        'id': '123',
                        'nome': 'Rex',
                        'raca': 'Vira-lata',
                        'tutor_nome': 'João Silva',
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            const Text(
              "Fila de Espera (Agendados)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _agendamentosStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("Erro ao carregar: ${snapshot.error}"));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "Nenhum agendamento veterinário encontrado.",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final petNome = data['pet_nome'] ?? 'Pet sem nome';
                      final tutorNome = data['tutor_nome'] ?? 'Tutor não informado';

                      DateTime? dataInicio;
                      if (data['data_inicio'] != null) {
                         dataInicio = (data['data_inicio'] as Timestamp).toDate();
                      }

                      String dataFormatada = dataInicio != null
                          ? DateFormat('dd/MM/yyyy HH:mm').format(dataInicio)
                          : 'Data indefinida';

                      final status = data['status'] ?? 'pendente';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF4A148C).withOpacity(0.1),
                            child: const Icon(Icons.pets, color: Color(0xFF4A148C)),
                          ),
                          title: Text(
                            petNome,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("$tutorNome • $dataFormatada"),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          onTap: () {
                             // Futuro: Abrir detalhes da consulta
                             Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NovaConsultaScreen(
                                  petData: {
                                    'id': data['pet_id'] ?? 'unknown',
                                    'nome': petNome,
                                    'raca': data['pet_raca'] ?? 'Raça não inf.',
                                    'tutor_nome': tutorNome,
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'agendado':
        return Colors.blue;
      case 'concluido':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      case 'pendente':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
