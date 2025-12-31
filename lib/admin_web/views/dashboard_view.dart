import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DashboardView extends StatelessWidget {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  @override
  Widget build(BuildContext context) {
    // Busca dados de HOJE
    final hoje = DateTime.now();
    final inicioDia = DateTime(hoje.year, hoje.month, hoje.day);
    final fimDia = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Visão Geral",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        Text(
          "Resumo das atividades de hoje",
          style: TextStyle(color: Colors.grey[600]),
        ),
        SizedBox(height: 30),

        // Stream para cards em tempo real
        StreamBuilder<QuerySnapshot>(
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
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return LinearProgressIndicator();

            final docs = snapshot.data!.docs;
            double faturamento = 0;
            int agendados = 0;
            int concluidos = 0;

            for (var doc in docs) {
              final data = doc.data() as Map;
              if (data['status'] == 'concluido') {
                faturamento += (data['valor'] ?? 0);
                concluidos++;
              } else if (data['status'] == 'agendado') {
                agendados++;
              }
            }

            return Row(
              children: [
                _buildKpiCard(
                  "Faturamento do Dia",
                  "R\$ ${faturamento.toStringAsFixed(2)}",
                  Colors.green,
                  FontAwesomeIcons.dollarSign,
                ),
                SizedBox(width: 20),
                _buildKpiCard(
                  "Atendimentos Concluídos",
                  "$concluidos",
                  Colors.blue,
                  FontAwesomeIcons.check,
                ),
                SizedBox(width: 20),
                _buildKpiCard(
                  "Na Fila / Agendados",
                  "$agendados",
                  Colors.orange,
                  FontAwesomeIcons.clock,
                ),
              ],
            );
          },
        ),

        SizedBox(height: 40),

        // Espaço para colocar gráficos futuramente
        Expanded(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Text(
                "Gráficos de Desempenho Mensal virão aqui...",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
          border: Border(left: BorderSide(color: color, width: 5)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: FaIcon(icon, color: color, size: 24),
            ),
            SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.grey[900],
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
