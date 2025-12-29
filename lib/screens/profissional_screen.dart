import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firebase_service.dart'; // Certifique-se que o service usa o banco 'agenpets'

class ProfissionalScreen extends StatefulWidget {
  @override
  _ProfissionalScreenState createState() => _ProfissionalScreenState();
}

class _ProfissionalScreenState extends State<ProfissionalScreen> {
  // Conexão direta com banco agenpets (conforme configuramos no service)
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Função para abrir WhatsApp
  Future<void> _abrirWhatsApp(
    String telefone,
    String nomePet,
    String nomeDono,
  ) async {
    // Limpa caracteres não numéricos
    final numero = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    final mensagem = Uri.encodeComponent(
      "Olá $nomeDono! 🐶 O banho/tosa do *$nomePet* foi finalizado. Ele já está pronto para ir para casa! 🏠",
    );

    final url = Uri.parse("https://wa.me/55$numero?text=$mensagem");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Não foi possível abrir o WhatsApp")),
      );
    }
  }

  // Função para mudar status
  Future<void> _atualizarStatus(String docId, String novoStatus) async {
    await _db.collection('agendamentos').doc(docId).update({
      'status': novoStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filtra agendamentos de HOJE
    final hoje = DateTime.now();
    final inicioDia = DateTime(hoje.year, hoje.month, hoje.day);
    final fimDia = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: Text("Agenda do Dia ✂️"),
        backgroundColor:
            Colors.green[700], // Cor diferente para diferenciar do app cliente
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('agendamentos')
            .where(
              'data_inicio',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia),
            )
            .where(
              'data_inicio',
              isLessThanOrEqualTo: Timestamp.fromDate(fimDia),
            )
            .orderBy('data_inicio')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Text("Sem agendamentos para hoje. Aproveite o café! ☕"),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              final DateTime horario = (data['data_inicio'] as Timestamp)
                  .toDate();
              final String status = data['status'] ?? 'agendado';

              // Buscamos dados do usuário (precisamos do telefone para o Zap)
              // Nota: Em um app real, seria melhor salvar o telefone dentro do agendamento para economizar leitura

              return Card(
                margin: EdgeInsets.all(10),
                color: status == 'pronto_retirada'
                    ? Colors.green[100]
                    : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(horario),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Chip(
                            label: Text(status.toUpperCase()),
                            backgroundColor: _getCorStatus(status),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Pet: ${data['pet_id']} (Nome Pendente)",
                        style: TextStyle(fontSize: 18),
                      ),
                      Text("Serviço: ${data['servico']}"),
                      Text("Profissional: ${data['profissional_nome']}"),
                      Divider(),

                      // BOTOES DE AÇÃO
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (status == 'agendado' ||
                              status == 'aguardando_pagamento')
                            ElevatedButton.icon(
                              icon: Icon(Icons.play_arrow),
                              label: Text("INICIAR"),
                              onPressed: () =>
                                  _atualizarStatus(docId, 'em_andamento'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                            ),

                          if (status == 'em_andamento')
                            ElevatedButton.icon(
                              icon: FaIcon(FontAwesomeIcons.whatsapp, size: 18),
                              label: Text("AVISAR CLIENTE"),
                              onPressed: () async {
                                // Primeiro muda o status
                                await _atualizarStatus(
                                  docId,
                                  'pronto_retirada',
                                );

                                // Busca telefone do dono (Exemplo simples: pegando do documento User)
                                // Na versão final, traga o telefone junto no agendamentoController.js
                                final userDoc = await _db
                                    .collection('users')
                                    .doc(data['userId'])
                                    .get();
                                final telefone =
                                    userDoc.data()?['telefone'] ?? '';
                                final nomeDono =
                                    userDoc.data()?['nome'] ?? 'Cliente';

                                _abrirWhatsApp(telefone, "Seu Pet", nomeDono);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getCorStatus(String status) {
    switch (status) {
      case 'agendado':
        return Colors.orange[100]!;
      case 'em_andamento':
        return Colors.blue[100]!;
      case 'pronto_retirada':
        return Colors.green[200]!;
      default:
        return Colors.grey[200]!;
    }
  }
}
