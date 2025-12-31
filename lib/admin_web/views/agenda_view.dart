import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AgendaView extends StatefulWidget {
  @override
  _AgendaViewState createState() => _AgendaViewState();
}

class _AgendaViewState extends State<AgendaView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );
  DateTime _dataFiltro = DateTime.now();

  void _abrirWhatsApp(String telefone) async {
    String num = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!num.startsWith('55')) num = "55$num";
    launchUrl(Uri.parse("https://wa.me/$num"));
  }

  void _finalizarServico(String docId, Map data) {
    String metodo = 'dinheiro';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Receber Pagamento"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Valor: R\$ ${data['valor']}",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: metodo,
              decoration: InputDecoration(
                labelText: "Forma de Pagamento",
                border: OutlineInputBorder(),
              ),
              items: ['dinheiro', 'pix_balcao', 'cartao']
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => metodo = v!,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await _db.collection('agendamentos').doc(docId).update({
                'status': 'concluido',
                'metodo_pagamento': metodo,
                'pago_em': FieldValue.serverTimestamp(),
              });
              Navigator.pop(ctx);
            },
            child: Text("CONFIRMAR RECEBIMENTO"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inicio = DateTime(
      _dataFiltro.year,
      _dataFiltro.month,
      _dataFiltro.day,
    );
    final fim = DateTime(
      _dataFiltro.year,
      _dataFiltro.month,
      _dataFiltro.day,
      23,
      59,
      59,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header com Filtro de Data
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Controle de Agenda",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.calendar_today),
              label: Text(DateFormat('dd/MM/yyyy').format(_dataFiltro)),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dataFiltro,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (d != null) setState(() => _dataFiltro = d);
              },
            ),
          ],
        ),
        SizedBox(height: 20),

        // Tabela
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            padding: EdgeInsets.all(20),
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('agendamentos')
                  .where(
                    'data_inicio',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(inicio),
                  )
                  .where(
                    'data_inicio',
                    isLessThanOrEqualTo: Timestamp.fromDate(fim),
                  )
                  .orderBy('data_inicio')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                if (docs.isEmpty)
                  return Center(child: Text("Sem agendamentos para este dia."));

                return SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        Colors.grey[100],
                      ),
                      columns: [
                        DataColumn(
                          label: Text(
                            "HORÁRIO",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "CLIENTE",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "SERVIÇO",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "PROFISSIONAL",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "VALOR",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "STATUS",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "AÇÕES",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final hora = (data['data_inicio'] as Timestamp)
                            .toDate();

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                DateFormat('HH:mm').format(hora),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            // Buscamos o telefone/nome do cliente sob demanda ou passamos a salvar no agendamento para performance
                            DataCell(
                              FutureBuilder<DocumentSnapshot>(
                                future: _db
                                    .collection('users')
                                    .doc(data['userId'])
                                    .get(),
                                builder: (c, s) => Text(
                                  s.hasData && s.data!.exists
                                      ? (s.data!.data() as Map)['nome']
                                      : "Carregando...",
                                ),
                              ),
                            ),
                            DataCell(Text(data['servico'])),
                            DataCell(Text(data['profissional_nome'])),
                            DataCell(Text("R\$ ${data['valor']}")),
                            DataCell(_buildStatusBadge(data['status'])),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: FaIcon(
                                      FontAwesomeIcons.whatsapp,
                                      size: 18,
                                      color: Colors.green,
                                    ),
                                    onPressed: () async {
                                      final user = await _db
                                          .collection('users')
                                          .doc(data['userId'])
                                          .get();
                                      if (user.exists)
                                        _abrirWhatsApp(
                                          (user.data() as Map)['telefone'],
                                        );
                                    },
                                  ),
                                  if (data['status'] != 'concluido')
                                    ElevatedButton(
                                      child: Text("Finalizar"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[900],
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () =>
                                          _finalizarServico(doc.id, data),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color cor = Colors.grey;
    if (status == 'concluido') cor = Colors.green;
    if (status == 'agendado') cor = Colors.blue;
    if (status == 'cancelado') cor = Colors.red;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}
