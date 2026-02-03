import 'package:agenpet/services/app_database.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  _DashboardViewState createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final _db = AppDatabase.instance;

  // Cores do Tema
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF5F7FA);

  String _filtroSelecionado = 'Hoje'; // Opções: Hoje, Semana, Mes

  // --- LÓGICA DE DATAS ---
  DateTimeRange _getPeriodo() {
    final agora = DateTime.now();
    DateTime inicio, fim;

    if (_filtroSelecionado == 'Hoje') {
      inicio = DateTime(agora.year, agora.month, agora.day);
      fim = DateTime(agora.year, agora.month, agora.day, 23, 59, 59);
    } else if (_filtroSelecionado == 'Semana') {
      // Começa na segunda-feira da semana atual
      inicio = agora.subtract(Duration(days: agora.weekday - 1));
      inicio = DateTime(inicio.year, inicio.month, inicio.day);
      fim = DateTime(agora.year, agora.month, agora.day, 23, 59, 59);
    } else {
      // Mês
      inicio = DateTime(agora.year, agora.month, 1);
      fim = DateTime(agora.year, agora.month + 1, 0, 23, 59, 59);
    }
    return DateTimeRange(start: inicio, end: fim);
  }

  @override
  Widget build(BuildContext context) {
    final periodo = _getPeriodo();

    return Scaffold(
      backgroundColor: _corFundo,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER COM FILTRO
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Dashboard Gerencial",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _corAcai,
                      ),
                    ),
                    Text(
                      "Visão geral do seu negócio",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                // Botões de Filtro
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      _buildFilterButton("Hoje"),
                      Container(width: 1, height: 20, color: Colors.grey[300]),
                      _buildFilterButton("Semana"),
                      Container(width: 1, height: 20, color: Colors.grey[300]),
                      _buildFilterButton("Mês"),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 30),

            // STREAM PRINCIPAL (Busca Agendamentos do Período)
            StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('tenants')
                  .doc(AppConfig.tenantId)
                  .collection('agendamentos')
                  .where(
                    'data_inicio',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(periodo.start),
                  )
                  .where(
                    'data_inicio',
                    isLessThanOrEqualTo: Timestamp.fromDate(periodo.end),
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                // --- PROCESSAMENTO DE DADOS ---
                double faturamentoTotal = 0;
                int qtdAtendimentos = 0;
                int qtdAgendados = 0;

                int countBanho = 0;
                int countTosa = 0;

                Map<String, double> pagamentos = {
                  'dinheiro': 0,
                  'pix': 0,
                  'cartao': 0,
                  'voucher': 0,
                };

                Map<String, int> funcionariosCount = {};
                Map<String, double> funcionariosRevenue = {};

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'];
                  // Valor final cobrado (prioridade) ou valor estimado
                  final valor =
                      (data['valor_final_cobrado'] ?? data['valor'] ?? 0)
                          .toDouble();
                  final servico = (data['servicoNorm'] ?? data['servico'] ?? '')
                      .toString()
                      .toLowerCase();
                  final metodo = data['metodo_pagamento'] ?? 'outros';
                  final profissional =
                      data['profissional_nome'] ?? 'Não atribuído';

                  if (status == 'concluido' || status == 'pago') {
                    faturamentoTotal += valor;
                    qtdAtendimentos++;

                    // Contagem Serviços
                    if (servico.contains('banho')) {
                      countBanho++;
                    } else if (servico.contains('tosa'))
                      countTosa++;

                    // Contagem Pagamento
                    String keyPag = metodo.toString().contains('pix')
                        ? 'pix'
                        : metodo.toString().contains('cartao')
                        ? 'cartao'
                        : metodo.toString().contains('voucher')
                        ? 'voucher'
                        : 'dinheiro';
                    pagamentos[keyPag] = (pagamentos[keyPag] ?? 0) + valor;

                    // Ranking Funcionário
                    if (profissional != 'Não atribuído') {
                      funcionariosCount[profissional] =
                          (funcionariosCount[profissional] ?? 0) + 1;
                      funcionariosRevenue[profissional] =
                          (funcionariosRevenue[profissional] ?? 0) + valor;
                    }
                  } else if (status == 'agendado' || status == 'reservado') {
                    qtdAgendados++;
                  }
                }

                // Calcular Ticket Médio
                double ticketMedio = qtdAtendimentos > 0
                    ? faturamentoTotal / qtdAtendimentos
                    : 0;

                // Achar Melhor Funcionário (Por Faturamento)
                String topFuncionario = "--";
                double topFuncionarioValor = 0;
                funcionariosRevenue.forEach((nome, valor) {
                  if (valor > topFuncionarioValor) {
                    topFuncionarioValor = valor;
                    topFuncionario = nome;
                  }
                });

                return Column(
                  children: [
                    // LINHA 1: KPIS PRINCIPAIS
                    Row(
                      children: [
                        _buildKpiCard(
                          "Faturamento ($_filtroSelecionado)",
                          "R\$ ${faturamentoTotal.toStringAsFixed(2)}",
                          Colors.green,
                          FontAwesomeIcons.dollarSign,
                        ),
                        SizedBox(width: 20),
                        _buildKpiCard(
                          "Atendimentos",
                          "$qtdAtendimentos",
                          _corAcai,
                          FontAwesomeIcons.checkCircle,
                        ),
                        SizedBox(width: 20),
                        _buildKpiCard(
                          "Ticket Médio",
                          "R\$ ${ticketMedio.toStringAsFixed(2)}",
                          Colors.orange,
                          FontAwesomeIcons.chartLine,
                        ),
                        SizedBox(width: 20),
                        _buildKpiCard(
                          "Na Fila / Agendados",
                          "$qtdAgendados",
                          Colors.blue,
                          FontAwesomeIcons.clock,
                        ),
                      ],
                    ),

                    SizedBox(height: 30),

                    // LINHA 2: DETALHAMENTO
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ESQUERDA: GRÁFICOS
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              // Serviços (Banho vs Tosa)
                              _buildServicosChart(countBanho, countTosa),
                              SizedBox(height: 20),
                              // Métodos de Pagamento
                              _buildPagamentosChart(
                                pagamentos,
                                faturamentoTotal,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(width: 20),

                        // DIREITA: DESTAQUE & HOTEL
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              // Card Funcionário Destaque
                              _buildFuncionarioDestaque(
                                topFuncionario,
                                topFuncionarioValor,
                                funcionariosCount[topFuncionario] ?? 0,
                              ),
                              SizedBox(height: 20),
                              // Mini Resumo Hotel (Outra coleção)
                              _buildResumoHotel(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildFilterButton(String label) {
    bool isSelected = _filtroSelecionado == label;
    return InkWell(
      onTap: () => setState(() => _filtroSelecionado = label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _corAcai : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
          border: Border(left: BorderSide(color: color, width: 5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(icon, color: color.withOpacity(0.5), size: 20),
              ],
            ),
            SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicosChart(int banhos, int tosas) {
    int total = banhos + tosas;
    double pctBanho = total > 0 ? banhos / total : 0;

    return Container(
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Serviços Realizados",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _corAcai,
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              _buildLegendDot(Colors.blue, "Banhos ($banhos)"),
              SizedBox(width: 15),
              _buildLegendDot(Colors.orange, "Tosas ($tosas)"),
            ],
          ),
          SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 30,
              width: double.infinity,
              color: Colors.grey[100],
              child: Row(
                children: [
                  Flexible(
                    flex: (pctBanho * 100).toInt(),
                    child: Container(color: Colors.blue),
                  ),
                  Flexible(
                    flex: ((1 - pctBanho) * 100).toInt(),
                    child: Container(color: Colors.orange),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagamentosChart(Map<String, double> map, double total) {
    return Container(
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Receita por Método",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _corAcai,
            ),
          ),
          SizedBox(height: 20),
          _buildPaymentRow("Dinheiro", map['dinheiro']!, total, Colors.green),
          _buildPaymentRow("Pix", map['pix']!, total, Color(0xFF32BCAD)),
          _buildPaymentRow("Cartão", map['cartao']!, total, Colors.blue),
          _buildPaymentRow(
            "Voucher (Pré-pago)",
            map['voucher']!,
            total,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, double val, double total, Color color) {
    if (val == 0) return SizedBox();
    double pct = total > 0 ? val / total : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, size: 10, color: color),
                  SizedBox(width: 5),
                  Text(label),
                ],
              ),
              Text(
                "R\$ ${val.toStringAsFixed(2)} (${(pct * 100).toStringAsFixed(1)}%)",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 5),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withOpacity(0.1),
            color: color,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildFuncionarioDestaque(String nome, double receita, int qtd) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_corAcai, Color(0xFF6A1B9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _corAcai.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(FontAwesomeIcons.crown, color: Colors.amber, size: 40),
          SizedBox(height: 15),
          Text(
            "Funcionário Destaque",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          SizedBox(height: 5),
          Text(
            nome,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 15),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Gerou R\$ ${receita.toStringAsFixed(2)} em $qtd serviços",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoHotel() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('reservas_hotel')
          .where('status', isEqualTo: 'hospedado')
          .snapshots(),
      builder: (context, snapshot) {
        int ocupados = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Hotelzinho",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _corAcai,
                    ),
                  ),
                  Icon(FontAwesomeIcons.hotel, color: _corAcai),
                ],
              ),
              SizedBox(height: 15),
              Text(
                "$ocupados hóspedes",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Text("ativos agora", style: TextStyle(color: Colors.grey)),
              SizedBox(height: 10),
              LinearProgressIndicator(
                value: ocupados / 60,
                backgroundColor: Colors.grey[200],
                color: _corAcai,
              ), // Assume 60 vagas
              SizedBox(height: 5),
              Text(
                "Ocupação: ${(ocupados / 60 * 100).toStringAsFixed(0)}%",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendDot(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 5),
        Text(text, style: TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
