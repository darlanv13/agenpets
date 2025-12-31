import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ProfissionalScreen extends StatefulWidget {
  @override
  _ProfissionalScreenState createState() => _ProfissionalScreenState();
}

class _ProfissionalScreenState extends State<ProfissionalScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  Map<String, dynamic>? _dadosPro;
  DateTime _dataFiltro = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dadosPro == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _dadosPro = args;
    }
  }

  // Função para marcar como concluído
  Future<void> _concluirServico(String agendamentoId) async {
    try {
      await _db.collection('agendamentos').doc(agendamentoId).update({
        'status': 'concluido',
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Serviço concluído! 🛁")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao atualizar.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dadosPro == null)
      return Scaffold(body: Center(child: CircularProgressIndicator()));

    // Filtros de Data
    final inicioDia = DateTime(
      _dataFiltro.year,
      _dataFiltro.month,
      _dataFiltro.day,
    );
    final fimDia = DateTime(
      _dataFiltro.year,
      _dataFiltro.month,
      _dataFiltro.day,
      23,
      59,
      59,
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Área do Profissional", style: TextStyle(fontSize: 14)),
            Text(
              "Olá, ${_dadosPro!['nome']}",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () async {
              final data = await showDatePicker(
                context: context,
                initialDate: _dataFiltro,
                firstDate: DateTime.now().subtract(Duration(days: 30)),
                lastDate: DateTime.now().add(Duration(days: 30)),
              );
              if (data != null) setState(() => _dataFiltro = data);
            },
          ),
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Cabeçalho de Data
          Container(
            padding: EdgeInsets.all(15),
            color: Colors.green[600],
            width: double.infinity,
            child: Text(
              "Agenda de ${DateFormat('dd/MM/yyyy (EEEE)', 'pt_BR').format(_dataFiltro)}",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Lista de Agendamentos
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('agendamentos')
                  .where('profissional_id', isEqualTo: _dadosPro!['id'])
                  .where(
                    'data_inicio',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia),
                  )
                  .where(
                    'data_inicio',
                    isLessThanOrEqualTo: Timestamp.fromDate(fimDia),
                  )
                  .orderBy('data_inicio', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 50, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          "Agenda livre para hoje!",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(15),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (ctx, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final hora = (data['data_inicio'] as Timestamp).toDate();
                    final status = data['status'] ?? 'agendado';

                    // Se não for 'agendado' (ex: concluido, cancelado), mostra diferente
                    bool isAtivo =
                        status == 'agendado' ||
                        status == 'aguardando_pagamento';

                    return Card(
                      color: isAtivo ? Colors.white : Colors.grey[200],
                      margin: EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(15),
                        leading: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text(
                            DateFormat('HH:mm').format(hora),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                        ),
                        title: Text(
                          data['servico'].toString().toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 5),
                            // Busca nome do Pet (poderia vir salvo no agendamento para otimizar, mas vamos buscar rapidinho ou mostrar o ID)
                            // Para simplificar, vou mostrar "Pet do cliente" se não tivermos o nome salvo no agendamento
                            FutureBuilder<DocumentSnapshot>(
                              future: _db
                                  .collection('users')
                                  .doc(data['userId'])
                                  .collection('pets')
                                  .doc(data['pet_id'])
                                  .get(),
                              builder: (context, petSnap) {
                                if (petSnap.hasData && petSnap.data!.exists) {
                                  final petData = petSnap.data!.data() as Map;
                                  return Row(
                                    children: [
                                      FaIcon(
                                        petData['tipo'] == 'cao'
                                            ? FontAwesomeIcons.dog
                                            : FontAwesomeIcons.cat,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        "${petData['nome']} (${petData['raca']})",
                                      ),
                                    ],
                                  );
                                }
                                return Text("Carregando pet...");
                              },
                            ),
                            SizedBox(height: 5),
                            Text(
                              "Status: $status",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        trailing: isAtivo
                            ? ElevatedButton(
                                onPressed: () => _concluirServico(doc.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: CircleBorder(),
                                  padding: EdgeInsets.all(10),
                                ),
                                child: Icon(Icons.check, color: Colors.white),
                              )
                            : Icon(Icons.check_circle, color: Colors.grey),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
