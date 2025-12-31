import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HistoricoScreen extends StatefulWidget {
  @override
  _HistoricoScreenState createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  String? _userCpf;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null) _userCpf = args['cpf'];
      _init = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userCpf == null)
      return Scaffold(body: Center(child: CircularProgressIndicator()));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text("Minhas Atividades"),
          backgroundColor: Color(0xFF0056D2),
          centerTitle: true,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "AGENDA", icon: Icon(Icons.calendar_month)),
              Tab(
                text: "MEUS VOUCHERS",
                icon: FaIcon(FontAwesomeIcons.ticket, size: 18),
              ),
            ],
          ),
        ),
        body: TabBarView(children: [_buildAbaAgenda(), _buildAbaVouchers()]),
      ),
    );
  }

  // --- ABA 1: LISTA DE AGENDAMENTOS ---
  Widget _buildAbaAgenda() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('agendamentos')
          .where('userId', isEqualTo: _userCpf)
          .orderBy('data_inicio', descending: true) // Mais recentes primeiro
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            "Nenhum agendamento encontrado.",
            Icons.calendar_today,
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (ctx, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final timestamp = data['data_inicio'] as Timestamp;
            final dataInicio = timestamp.toDate();
            final status = data['status'] ?? 'agendado';

            // Definição de Cores por Status
            Color statusColor = Colors.blue;
            String statusLabel = "Confirmado";

            if (status == 'aguardando_pagamento') {
              statusColor = Colors.orange;
              statusLabel = "Pendente";
            } else if (status == 'concluido') {
              statusColor = Colors.green;
              statusLabel = "Concluído";
            } else if (status == 'cancelado') {
              statusColor = Colors.red;
              statusLabel = "Cancelado";
            }

            return Card(
              margin: EdgeInsets.only(bottom: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Data e Hora (Destaque)
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    DateFormat('dd').format(dataInicio),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'MMM',
                                    ).format(dataInicio).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['servico'] ?? 'Serviço',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'EEEE, HH:mm',
                                    'pt_BR',
                                  ).format(dataInicio),
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Badge de Status
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, size: 16, color: Colors.grey),
                            SizedBox(width: 5),
                            Text(
                              data['profissional_nome'] ?? 'Profissional',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        if (data['valor'] != null)
                          Text(
                            "R\$ ${data['valor'].toStringAsFixed(2)}",
                            style: TextStyle(fontWeight: FontWeight.bold),
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
    );
  }

  // --- ABA 2: CARTEIRA DE VOUCHERS ---
  Widget _buildAbaVouchers() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(_userCpf).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator());

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null)
          return _buildEmptyState("Erro ao carregar dados.", Icons.error);

        final vouchersBanho = userData['vouchers_banho'] ?? 0;
        final vouchersTosa = userData['vouchers_tosa'] ?? 0;
        final validadeTimestamp = userData['validade_assinatura'] as Timestamp?;

        bool temAssinaturaAtiva =
            validadeTimestamp != null &&
            validadeTimestamp.toDate().isAfter(DateTime.now());

        return SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // CARD STATUS ASSINATURA
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: temAssinaturaAtiva
                        ? [Color(0xFF0056D2), Colors.blueAccent]
                        : [Colors.grey, Colors.grey[400]!],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    FaIcon(
                      temAssinaturaAtiva
                          ? FontAwesomeIcons.crown
                          : FontAwesomeIcons.lock,
                      color: Colors.white,
                      size: 40,
                    ),
                    SizedBox(height: 10),
                    Text(
                      temAssinaturaAtiva
                          ? "ASSINATURA ATIVA"
                          : "SEM ASSINATURA",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (temAssinaturaAtiva)
                      Padding(
                        padding: const EdgeInsets.only(top: 5.0),
                        child: Text(
                          "Válido até ${DateFormat('dd/MM/yyyy').format(validadeTimestamp!.toDate())}",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    if (!temAssinaturaAtiva)
                      Padding(
                        padding: const EdgeInsets.only(top: 15.0),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/assinatura',
                            arguments: {'cpf': _userCpf},
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                          child: Text("QUERO ASSINAR"),
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(height: 30),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Seus Vouchers",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 15),

              _buildVoucherCard(
                "Banho",
                vouchersBanho,
                FontAwesomeIcons.shower,
                Colors.blue,
              ),
              SizedBox(height: 15),
              _buildVoucherCard(
                "Banho & Tosa",
                vouchersTosa,
                FontAwesomeIcons.scissors,
                Colors.purple,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVoucherCard(String titulo, int qtd, IconData icon, Color cor) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: FaIcon(icon, color: cor, size: 24),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Disponíveis para uso",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            "$qtd",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: qtd > 0 ? cor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey[300]),
          SizedBox(height: 20),
          Text(msg, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
