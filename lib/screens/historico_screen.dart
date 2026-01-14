import 'package:agenpet/screens/tabs/meus_vouchers_tab.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HistoricoScreen extends StatefulWidget {
  @override
  _HistoricoScreenState createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // --- CORES DA MARCA ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLavanda = Color(0xFFAB47BC);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF8F9FC);

  String? _userCpf;
  bool _init = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

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
    if (_userCpf == null) {
      return Scaffold(
        backgroundColor: _corFundo,
        body: Center(child: CircularProgressIndicator(color: _corAcai)),
      );
    }

    return Scaffold(
      backgroundColor: _corFundo,
      appBar: AppBar(
        title: Text(
          "Minhas Atividades",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: _corAcai,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(70),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              labelColor: _corAcai,
              unselectedLabelColor: Colors.white70,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18),
                      SizedBox(width: 8),
                      Text("AGENDA"),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(FontAwesomeIcons.ticket, size: 16),
                      SizedBox(width: 8),
                      Text("VOUCHERS"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildAbaAgenda(), _buildAbaVouchers()],
      ),
    );
  }

  // --- ABA 1: LISTA DE AGENDAMENTOS ---

  // --- ABA 1: LISTA DE AGENDAMENTOS (COM CORREÇÃO DE ÍNDICE) ---
  Widget _buildAbaAgenda() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('agendamentos')
          .where('userId', isEqualTo: _userCpf)
          .orderBy('data_inicio', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // 1. TRATAMENTO DE ERRO (Para você ver o que falta)
        if (snapshot.hasError) {
          print(
            "ERRO NA AGENDA: ${snapshot.error}",
          ); // <--- Olhe no seu Console (Run)
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 40),
                  SizedBox(height: 10),
                  Text(
                    "Erro ao carregar agenda.\nProvavelmente falta o índice no Firebase.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Verifique o console para o link de criação.",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _corAcai));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            "Você ainda não tem agendamentos.",
            "Que tal marcar um banho pro seu pet?",
            FontAwesomeIcons.calendarXmark,
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          itemCount: docs.length,
          itemBuilder: (ctx, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final timestamp = data['data_inicio'] as Timestamp;
            final dataInicio = timestamp.toDate();
            final status = data['status'] ?? 'agendado';
            final servico = data['servicoNorm'] ?? data['servico'] ?? 'Serviço';

            // Configuração Visual por Status
            Color statusColor;
            Color statusBg;
            String statusLabel;
            IconData statusIcon;

            switch (status) {
              case 'aguardando_pagamento':
                statusColor = Colors.orange[800]!;
                statusBg = Colors.orange[50]!;
                statusLabel = "Pendente";
                statusIcon = Icons.access_time_rounded;
                break;
              case 'concluido':
                statusColor = Colors.green[800]!;
                statusBg = Colors.green[50]!;
                statusLabel = "Concluído";
                statusIcon = Icons.check_circle_outline;
                break;
              case 'cancelado':
                statusColor = Colors.red[800]!;
                statusBg = Colors.red[50]!;
                statusLabel = "Cancelado";
                statusIcon = Icons.cancel_outlined;
                break;
              default: // agendado/reservado
                statusColor = _corAcai;
                statusBg = _corLilas;
                statusLabel = "Confirmado";
                statusIcon = Icons.event_available;
            }

            // Ícone do Serviço
            bool isTosa = servico.toString().toLowerCase().contains('tosa');

            return Container(
              margin: EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Data Box
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _corFundo,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Text(
                                DateFormat('dd').format(dataInicio),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _corAcai,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'MMM',
                                  'pt_BR',
                                ).format(dataInicio).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 15),
                        // Informações
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isTosa
                                        ? FontAwesomeIcons.scissors
                                        : FontAwesomeIcons.shower,
                                    size: 14,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    servico,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Text(
                                DateFormat(
                                  'EEEE, HH:mm',
                                  'pt_BR',
                                ).format(dataInicio),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              if (data['profissional_nome'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    "Com: ${data['profissional_nome']}",
                                    style: TextStyle(
                                      color: _corAcai,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    Divider(height: 1, color: Colors.grey[100]),
                    SizedBox(height: 15),
                    // Rodapé do Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Badge Status
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              SizedBox(width: 5),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Valor
                        if (data['valor'] != null)
                          Text(
                            "R\$ ${data['valor'].toStringAsFixed(2)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          )
                        else
                          Text(
                            "Grátis / Voucher",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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
    );
  }

  // --- ABA 2: CARTEIRA DE VOUCHERS ---
  Widget _buildAbaVouchers() {
    // Chama o novo componente passando o CPF
    return MeusVouchersTab(userCpf: _userCpf!);
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(color: _corLilas, shape: BoxShape.circle),
            child: Icon(icon, size: 50, color: _corAcai.withOpacity(0.5)),
          ),
          SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
