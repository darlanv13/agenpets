import 'package:agenpet/admin_web/views/configuracao_agenda_view.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// Importe as novas telas
import 'views/dashboard_view.dart';
import 'views/agenda_view.dart';
import 'views/hotel_view.dart';
import 'views/gestao_precos_view.dart'; // <--- Nova
import 'views/equipe_view.dart'; // <--- Nova

class AdminWebScreen extends StatefulWidget {
  @override
  _AdminWebScreenState createState() => _AdminWebScreenState();
}

class _AdminWebScreenState extends State<AdminWebScreen> {
  int _selectedIndex = 0;

  // Lista de Telas Atualizada
  final List<Widget> _telas = [
    DashboardView(),
    AgendaView(),
    HotelView(),
    GestaoPrecosView(), // Índice 3
    EquipeView(), // Índice 4
    ConfiguracaoAgendaView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: Row(
        children: [
          // MENU LATERAL
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: Color(0xFF0056D2), // Azul Principal
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Column(
              children: [
                Container(
                  height: 120,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.paw,
                        color: Colors.white,
                        size: 30,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "AgenPet Admin",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.white24, height: 1),
                SizedBox(height: 20),

                // ITENS DO MENU
                _buildMenuItem(0, "Dashboard", FontAwesomeIcons.chartPie),
                _buildMenuItem(
                  1,
                  "Agenda & Caixa",
                  FontAwesomeIcons.calendarDay,
                ),
                _buildMenuItem(2, "Hotelzinho", FontAwesomeIcons.hotel),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "GESTÃO",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                _buildMenuItem(
                  3,
                  "Tabela de Preços",
                  FontAwesomeIcons.moneyBillWave,
                ),
                _buildMenuItem(4, "Equipe & RH", FontAwesomeIcons.users),

                _buildMenuItem(5, "Config. Agenda", FontAwesomeIcons.clock),

                Spacer(),
                ListTile(
                  leading: Icon(Icons.exit_to_app, color: Colors.white70),
                  title: Text(
                    "Sair do Sistema",
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),

          // CONTEÚDO
          Expanded(
            child: Container(
              padding: EdgeInsets.all(40),
              child: _telas[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, String title, IconData icon) {
    bool isSelected = _selectedIndex == index;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: FaIcon(
          icon,
          color: isSelected ? Color(0xFF0056D2) : Colors.white70,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Color(0xFF0056D2) : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => setState(() => _selectedIndex = index),
      ),
    );
  }
}
