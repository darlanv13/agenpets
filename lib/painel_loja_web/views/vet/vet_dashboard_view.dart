import 'package:flutter/material.dart';
import 'package:agenpet/painel_loja_web/views/vet/nova_consulta_screen.dart';

class VetDashboardView extends StatelessWidget {
  const VetDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Área Veterinária",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A148C),
              ),
            ),
            SizedBox(height: 20),
            // Botão de Atendimento Avulso (Emergência)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4A148C),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              ),
              icon: Icon(Icons.add, color: Colors.white),
              label: Text(
                "NOVO ATENDIMENTO AVULSO",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                // Aqui você abriria um dialog para buscar o pet primeiro
                // Para exemplo, vou abrir direto com dados mockados
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NovaConsultaScreen(
                      petData: {
                        'id': '123',
                        'nome': 'Rex',
                        'raca': 'Vira-lata',
                        'tutor_nome': 'João Silva',
                      },
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 30),
            Text(
              "Fila de Espera (Agendados)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Center(child: Text("Integração com Agenda aqui...")),
            ),
          ],
        ),
      ),
    );
  }
}
