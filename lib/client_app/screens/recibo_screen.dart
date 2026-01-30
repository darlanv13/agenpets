import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReciboScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const ReciboScreen({super.key, required this.data, required this.docId});

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
    final String? profissionalBanho = data['profissional_banho_nome'];
    final String? profissionalTosa = data['profissional_tosa_nome'];
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
            icon: Icon(Icons.print),
            onPressed: () => _generatePdf(context),
            tooltip: "Imprimir / Salvar PDF",
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
                          }),
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
                          ...extras.map(
                            (e) => _buildItemRow(
                              e['nome'],
                              "qtd: 1",
                              (e['preco'] ?? 0).toDouble(),
                            ),
                          ),
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

            // CHECKLIST DO PROFISSIONAL
            if (data['checklist'] != null)
              _buildChecklistSection(data['checklist']),

            SizedBox(height: 30),

            // INFORMAÇÕES ADICIONAIS
            _buildInfoCard(
              Icons.person,
              "Profissional Responsável",
              profissional,
            ),
            if (profissionalBanho != null) ...[
              SizedBox(height: 10),
              _buildInfoCard(
                FontAwesomeIcons.shower,
                "Banhista",
                profissionalBanho,
              ),
            ],
            if (profissionalTosa != null) ...[
              SizedBox(height: 10),
              _buildInfoCard(
                FontAwesomeIcons.scissors,
                "Tosador(a)",
                profissionalTosa,
              ),
            ],
            SizedBox(height: 10),
            _buildInfoCard(
              FontAwesomeIcons.locationDot,
              "Local",
              "Unidade Matriz - AgenPet",
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- CHECKLIST SECTION ---
  Widget _buildChecklistSection(Map<String, dynamic> checklist) {
    bool temPulgas = checklist['tem_pulgas'] ?? false;
    bool temLesoes = checklist['tem_lesoes'] ?? false;
    bool temOtite = checklist['tem_otite'] ?? false;
    bool agressivo = checklist['agressivo'] ?? false;
    String nivelNos = checklist['nivel_nos'] ?? 'nenhum';
    String observacoes = checklist['observacoes'] ?? '';
    List fotos = checklist['fotos_lesoes_paths'] ?? [];

    return Container(
      margin: EdgeInsets.only(top: 30),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(
                  FontAwesomeIcons.clipboardCheck,
                  color: _corAcai,
                  size: 18,
                ),
                SizedBox(width: 10),
                Text(
                  "Checklist de Saúde",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _corAcai,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildCheckChip(
                      "Nós: ${_capitalize(nivelNos)}",
                      isAlert: nivelNos != 'nenhum',
                    ),
                    _buildCheckChip("Pulgas", isAlert: temPulgas),
                    _buildCheckChip("Lesões", isAlert: temLesoes),
                    _buildCheckChip("Otite", isAlert: temOtite),
                    _buildCheckChip("Agressivo", isAlert: agressivo),
                  ],
                ),
                if (observacoes.isNotEmpty) ...[
                  SizedBox(height: 15),
                  Text(
                    "Observações:",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    observacoes,
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
                if (fotos.isNotEmpty) ...[
                  SizedBox(height: 15),
                  Text(
                    "Fotos Registradas:",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: fotos.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: EdgeInsets.only(right: 10),
                          width: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: NetworkImage(fotos[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckChip(String label, {bool isAlert = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isAlert ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAlert ? Colors.red[100]! : Colors.green[100]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAlert ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 14,
            color: isAlert ? Colors.red : Colors.green,
          ),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isAlert ? Colors.red[800] : Colors.green[800],
            ),
          ),
        ],
      ),
    );
  }

  // --- PDF GENERATION ---
  Future<void> _generatePdf(BuildContext context) async {
    final doc = pw.Document();

    // Dados gerais
    final Timestamp? ts = data['data_inicio'];
    final DateTime dataInicio = ts != null ? ts.toDate() : DateTime.now();
    final double valorPago =
        (data['valor_final_cobrado'] ?? (data['valor'] ?? 0)).toDouble();
    final String servico = _capitalize(data['servico'] ?? 'Serviço');
    final String profissional = data['profissional_nome'] ?? 'Não informado';
    final String? profissionalBanho = data['profissional_banho_nome'];
    final String? profissionalTosa = data['profissional_tosa_nome'];
    final Map checklist = data['checklist'] ?? {};

    // Preparar imagens do checklist
    List<pw.Widget> fotosWidgets = [];
    if (checklist['fotos_lesoes_paths'] != null) {
      for (String url in checklist['fotos_lesoes_paths']) {
        try {
          final netImage = await networkImage(url);
          fotosWidgets.add(
            pw.Container(
              margin: const pw.EdgeInsets.only(right: 10),
              width: 100,
              height: 100,
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                image: pw.DecorationImage(
                  image: netImage,
                  fit: pw.BoxFit.cover,
                ),
              ),
            ),
          );
        } catch (e) {
          debugPrint("Erro ao carregar imagem para PDF: $e");
        }
      }
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // CABEÇALHO
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Recibo AgenPet",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "Data: ${DateFormat('dd/MM/yyyy HH:mm').format(dataInicio)}",
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // INFO SERVIÇO
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  children: [
                    _buildPdfRow("Serviço", servico),
                    _buildPdfRow("Profissional", profissional),
                    if (profissionalBanho != null)
                      _buildPdfRow("Banhista", profissionalBanho),
                    if (profissionalTosa != null)
                      _buildPdfRow("Tosador(a)", profissionalTosa),
                    _buildPdfRow(
                      "ID Agendamento",
                      "#${docId.substring(0, 8).toUpperCase()}",
                    ),
                    pw.Divider(),
                    _buildPdfRow(
                      "Valor Total",
                      "R\$ ${valorPago.toStringAsFixed(2)}",
                      isBold: true,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // CHECKLIST
              if (checklist.isNotEmpty) ...[
                pw.Text(
                  "Checklist de Saúde",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildPdfChip(
                            "Nós: ${_capitalize(checklist['nivel_nos'] ?? 'nenhum')}",
                          ),
                          _buildPdfChip(
                            "Pulgas: ${checklist['tem_pulgas'] == true ? 'Sim' : 'Não'}",
                            isAlert: checklist['tem_pulgas'] == true,
                          ),
                          _buildPdfChip(
                            "Lesões: ${checklist['tem_lesoes'] == true ? 'Sim' : 'Não'}",
                            isAlert: checklist['tem_lesoes'] == true,
                          ),
                          _buildPdfChip(
                            "Otite: ${checklist['tem_otite'] == true ? 'Sim' : 'Não'}",
                            isAlert: checklist['tem_otite'] == true,
                          ),
                          _buildPdfChip(
                            "Agressivo: ${checklist['agressivo'] == true ? 'Sim' : 'Não'}",
                            isAlert: checklist['agressivo'] == true,
                          ),
                        ],
                      ),
                      if ((checklist['observacoes'] ?? '').isNotEmpty) ...[
                        pw.SizedBox(height: 10),
                        pw.Text(
                          "Observações:",
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          checklist['observacoes'],
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
              ],

              // FOTOS
              if (fotosWidgets.isNotEmpty) ...[
                pw.Text(
                  "Evidências / Fotos",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Wrap(spacing: 10, runSpacing: 10, children: fotosWidgets),
              ],

              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  "Obrigado pela preferência!",
                  style: pw.TextStyle(
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  pw.Widget _buildPdfRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(
            value,
            style: isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfChip(String label, {bool isAlert = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: isAlert ? PdfColors.red50 : PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(
          color: isAlert ? PdfColors.red200 : PdfColors.green200,
        ),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 10,
          color: isAlert ? PdfColors.red800 : PdfColors.green800,
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
