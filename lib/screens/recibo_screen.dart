import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReciboScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const ReciboScreen({Key? key, required this.data, required this.docId})
    : super(key: key);

  // Cores da Marca
  final Color _corAcai = const Color(0xFF4A148C);
  final Color _corFundo = const Color(0xFFF5F7FA);

  @override
  Widget build(BuildContext context) {
    // Tratamento de Dados
    final Timestamp? ts = data['data_inicio'];
    final DateTime dataInicio = ts != null ? ts.toDate() : DateTime.now();

    final double valorTotal = (data['valor'] ?? 0).toDouble();
    final double valorPago = (data['valor_final_cobrado'] ?? valorTotal)
        .toDouble();

    final String profissional = data['profissional_nome'] ?? 'Não informado';
    final String servico = _capitalize(data['servico'] ?? 'Serviço');
    final String status = data['status'] ?? 'agendado';
    final String metodoPagamento = _formatarMetodoPagamento(
      data['metodo_pagamento'],
    );

    // Vouchers e Extras
    Map vouchersConsumidos = data['vouchers_consumidos'] ?? {};
    bool usouVoucher = vouchersConsumidos.isNotEmpty;
    List extras = data['extras'] ?? [];

    return Scaffold(
      backgroundColor: _corFundo,
      appBar: AppBar(
        title: Text(
          "Comprovante",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _corAcai),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              // Aqui você pode implementar a função de compartilhar (share_plus)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Função de compartilhar em breve!")),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // TICKET VISUAL
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // CABEÇALHO DO TICKET
                  Container(
                    padding: EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: _corAcai,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          FontAwesomeIcons.paw,
                          color: Colors.white,
                          size: 40,
                        ),
                        SizedBox(height: 15),
                        Text(
                          "R\$ ${valorPago.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          status == 'concluido'
                              ? "Pago com Sucesso"
                              : "Aguardando Pagamento",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        SizedBox(height: 20),
                        Divider(color: Colors.white24),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildHeaderInfo(
                              "Data",
                              DateFormat('dd/MM/yyyy').format(dataInicio),
                            ),
                            _buildHeaderInfo(
                              "Hora",
                              DateFormat('HH:mm').format(dataInicio),
                            ),
                            _buildHeaderInfo("Método", metodoPagamento),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // CORPO DO TICKET
                  Padding(
                    padding: EdgeInsets.all(25),
                    child: Column(
                      children: [
                        _buildItemRow(
                          "Serviço Principal",
                          servico,
                          valorTotal,
                          isBold: true,
                        ),

                        // VOUCHERS
                        if (usouVoucher) ...[
                          SizedBox(height: 10),
                          ...vouchersConsumidos.entries.map((e) {
                            String nome = e.key
                                .toString()
                                .replaceAll('vouchers_', '')
                                .toUpperCase();
                            return _buildDescontoRow("Voucher ($nome)");
                          }).toList(),
                        ],

                        // EXTRAS
                        if (extras.isNotEmpty) ...[
                          SizedBox(height: 15),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Extras / Adicionais",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 5),
                          ...extras
                              .map(
                                (e) => _buildItemRow(
                                  e['nome'],
                                  "qtd: 1",
                                  (e['preco'] ?? 0).toDouble(),
                                ),
                              )
                              .toList(),
                        ],

                        SizedBox(height: 25),
                        // LINHA PONTILHADA (Simulada)
                        Row(
                          children: List.generate(
                            150 ~/ 5,
                            (index) => Expanded(
                              child: Container(
                                color: index % 2 == 0
                                    ? Colors.transparent
                                    : Colors.grey[300],
                                height: 2,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 25),

                        // TOTAIS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total Pago",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "R\$ ${valorPago.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: _corAcai,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // RODAPÉ DO TICKET
                  Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code, size: 20, color: Colors.grey),
                        SizedBox(width: 10),
                        Text(
                          "ID: #${docId.substring(0, 8).toUpperCase()}",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontFamily: 'Monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),

            // INFORMAÇÕES ADICIONAIS
            _buildInfoCard(
              Icons.person,
              "Profissional Responsável",
              profissional,
            ),
            SizedBox(height: 10),
            _buildInfoCard(
              FontAwesomeIcons.locationDot,
              "Local",
              "Unidade Matriz - AgenPet",
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildHeaderInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white60, fontSize: 11)),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(
    String label,
    String sub,
    double value, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    color: Colors.black87,
                  ),
                ),
                if (sub.isNotEmpty && sub != "qtd: 1")
                  Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Text(
            "R\$ ${value.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescontoRow(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer, size: 16, color: Colors.green),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            "-100%",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 20),
          SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return "";
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  String _formatarMetodoPagamento(String? metodo) {
    if (metodo == null) return "Não informado";
    if (metodo == 'pix' || metodo == 'pix_balcao') return "Pix";
    if (metodo == 'cartao_credito') return "Cartão Crédito";
    if (metodo == 'dinheiro') return "Dinheiro";
    if (metodo == 'voucher') return "Assinatura";
    return _capitalize(metodo);
  }
}
