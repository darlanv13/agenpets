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

  // --- CORES DA MARCA ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF8F9FC);

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

  // Função para marcar como concluído com confirmação
  Future<void> _concluirServico(String agendamentoId) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Concluir Serviço?"),
        content: Text("Confirmar que o pet já foi atendido?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _db.collection('agendamentos').doc(agendamentoId).update({
                  'status': 'concluido',
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Serviço concluído com sucesso! 🛁"),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Erro ao atualizar status.")),
                );
              }
            },
            child: Text("Confirmar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dadosPro == null)
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: _corAcai)),
      );

    // Filtros de Data para consulta (Start/End of Day)
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
      backgroundColor: _corFundo,
      body: Column(
        children: [
          // 1. CABEÇALHO PERSONALIZADO
          _buildHeader(),

          // 2. SELETOR DE DATA E RESUMO
          _buildDateSelector(),

          // 3. LISTA DE AGENDAMENTOS
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
                  return Center(
                    child: CircularProgressIndicator(color: _corAcai),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 80),
                  itemCount: docs.length,
                  itemBuilder: (ctx, index) =>
                      _buildAgendamentoCard(docs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(top: 50, left: 25, right: 25, bottom: 25),
      decoration: BoxDecoration(
        color: _corAcai,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: _corAcai.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Olá, ${_dadosPro!['nome'].toString().split(' ')[0]} 👋",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Sua agenda de hoje",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat(
              "dd 'de' MMMM",
              'pt_BR',
            ).format(_dataFiltro).toUpperCase(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          InkWell(
            onTap: () async {
              final data = await showDatePicker(
                context: context,
                initialDate: _dataFiltro,
                firstDate: DateTime.now().subtract(Duration(days: 60)),
                lastDate: DateTime.now().add(Duration(days: 60)),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.light().copyWith(
                      primaryColor: _corAcai,
                      colorScheme: ColorScheme.light(primary: _corAcai),
                    ),
                    child: child!,
                  );
                },
              );
              if (data != null) setState(() => _dataFiltro = data);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: _corAcai),
                  SizedBox(width: 8),
                  Text(
                    "Mudar Data",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _corAcai,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendamentoCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final hora = (data['data_inicio'] as Timestamp).toDate();
    final status = data['status'] ?? 'agendado';

    // Status visual
    bool isConcluido = status == 'concluido';
    bool isPendente = status == 'agendado' || status == 'aguardando_pagamento';

    return Container(
      margin: EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border(
          left: BorderSide(
            color: isConcluido ? Colors.green : _corAcai,
            width: 5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          children: [
            // 1. Coluna de Horário
            Column(
              children: [
                Text(
                  DateFormat('HH:mm').format(hora),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  isConcluido ? "FEITO" : "HORA",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isConcluido ? Colors.green : Colors.grey[400],
                  ),
                ),
              ],
            ),

            Container(
              height: 40,
              width: 1,
              color: Colors.grey[200],
              margin: EdgeInsets.symmetric(horizontal: 15),
            ),

            // 2. Detalhes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['servico'].toString().toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _corAcai,
                    ),
                  ),
                  SizedBox(height: 4),
                  // Busca assíncrona do Pet
                  FutureBuilder<DocumentSnapshot>(
                    future: _db
                        .collection('users')
                        .doc(data['userId'])
                        .collection('pets')
                        .doc(data['pet_id'])
                        .get(),
                    builder: (context, petSnap) {
                      if (!petSnap.hasData)
                        return Text(
                          "...",
                          style: TextStyle(color: Colors.grey),
                        );

                      if (petSnap.data!.exists) {
                        final petData = petSnap.data!.data() as Map;
                        return Row(
                          children: [
                            Icon(
                              petData['tipo'] == 'cao'
                                  ? FontAwesomeIcons.dog
                                  : FontAwesomeIcons.cat,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 6),
                            Text(
                              "${petData['nome']} (${petData['raca'] ?? 'SRD'})",
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        );
                      }
                      return Text(
                        "Pet removido",
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      );
                    },
                  ),
                ],
              ),
            ),

            // 3. Ação
            if (isPendente)
              ElevatedButton(
                onPressed: () => _concluirServico(doc.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green,
                  elevation: 0,
                  side: BorderSide(color: Colors.green),
                  shape: CircleBorder(),
                  padding: EdgeInsets.all(10),
                ),
                child: Icon(Icons.check, size: 24),
              )
            else if (isConcluido)
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: Colors.green, size: 24),
              )
            else // Cancelado
              Icon(Icons.cancel, color: Colors.red[300]),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(color: _corLilas, shape: BoxShape.circle),
            child: Icon(
              FontAwesomeIcons.mugHot,
              size: 40,
              color: _corAcai.withOpacity(0.5),
            ),
          ),
          SizedBox(height: 20),
          Text(
            "Agenda livre por enquanto!",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          Text(
            "Aproveite o descanso.",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
