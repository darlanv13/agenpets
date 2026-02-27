import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class ReciboScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const ReciboScreen({
    Key? key,
    required this.data,
    required this.docId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Tratamento de Dados
    final servico = data['servico'] ?? 'Serviço';
    final petNome = data['pet_nome'] ?? 'Pet'; // Se disponível

    // Tratamento de data robusto
    DateTime? dataInicio;
    if (data['data_inicio'] != null) {
      if (data['data_inicio'] is Timestamp) {
        dataInicio = (data['data_inicio'] as Timestamp).toDate();
      } else if (data['data_inicio'] is String) {
        dataInicio = DateTime.tryParse(data['data_inicio']);
      }
    }

    final valor = (data['valor'] ?? 0).toDouble();
    final status = data['status'] ?? 'agendado';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Detalhes do Agendamento"),
        backgroundColor: Color(0xFF4A148C),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Cartão Principal
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Cabeçalho do Ticket
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    width: double.infinity,
                    child: Column(
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          color: Colors.white,
                          size: 40,
                        ),
                        SizedBox(height: 10),
                        Text(
                          status.toUpperCase(),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Conteúdo
                  Padding(
                    padding: EdgeInsets.all(25),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          "Serviço",
                          servico,
                          FontAwesomeIcons.cut,
                        ),
                        Divider(height: 30),
                        if (dataInicio != null) ...[
                          _buildInfoRow(
                            "Data",
                            DateFormat('dd/MM/yyyy').format(dataInicio),
                            FontAwesomeIcons.calendar,
                          ),
                          SizedBox(height: 15),
                          _buildInfoRow(
                            "Horário",
                            DateFormat('HH:mm').format(dataInicio),
                            FontAwesomeIcons.clock,
                          ),
                          Divider(height: 30),
                        ],
                        _buildInfoRow(
                          "Valor",
                          "R\$ ${valor.toStringAsFixed(2)}",
                          FontAwesomeIcons.moneyBillWave,
                          isBold: true,
                          color: Colors.green[700],
                        ),
                      ],
                    ),
                  ),

                  // Rodapé do Ticket (Pontilhado fake)
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),

            if (status == 'concluido' || status == 'pronto')
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Lógica para avaliar serviço poderia vir aqui
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Funcionalidade em breve!")),
                    );
                  },
                  icon: Icon(Icons.star_outline),
                  label: Text("AVALIAR SERVIÇO"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.grey[600], size: 18),
        ),
        SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: color ?? Colors.black87,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
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
      case 'banhando':
      case 'tosando':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'agendado':
        return FontAwesomeIcons.calendarCheck;
      case 'concluido':
        return FontAwesomeIcons.checkDouble;
      case 'cancelado':
        return FontAwesomeIcons.xmark;
      case 'banhando':
        return FontAwesomeIcons.shower;
      case 'tosando':
        return FontAwesomeIcons.scissors;
      default:
        return FontAwesomeIcons.circleInfo;
    }
  }
}
