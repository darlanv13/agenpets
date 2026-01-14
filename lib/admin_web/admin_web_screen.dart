import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// --- IMPORTS DAS VIEWS ---
import 'views/dashboard_view.dart';
import 'views/agenda_view.dart';
import 'views/hotel_view.dart';
import 'views/gestao_precos_view.dart';
import 'views/equipe_view.dart';
import 'views/configuracao_agenda_view.dart';
import 'views/venda_assinatura_view.dart';
import 'views/gestao_banners_view.dart'; // <--- 1. IMPORT NOVO (Verifique se o arquivo está na pasta views)

class AdminWebScreen extends StatefulWidget {
  @override
  _AdminWebScreenState createState() => _AdminWebScreenState();
}

class _AdminWebScreenState extends State<AdminWebScreen> {
  int _selectedIndex = 0;

  // Cores da Identidade Visual
  final Color _corAcaiStart = Color(0xFF4A148C);
  final Color _corAcaiEnd = Color(0xFF7B1FA2);
  final Color _corFundo = Color(0xFFF0F2F5);

  // --- 2. LISTA DE TELAS ATUALIZADA ---
  final List<Widget> _telas = [
    DashboardView(), // 0
    AgendaView(), // 1
    HotelView(), // 2
    VendaAssinaturaView(), // 3
    GestaoPrecosView(), // 4
    GestaoBannersView(), // 5 <--- NOVA TELA AQUI
    EquipeView(), // 6 (Índice deslocado)
    ConfiguracaoAgendaView(), // 7 (Índice deslocado)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Row(
        children: [
          // --- MENU LATERAL (SIDEBAR) ---
          Container(
            width: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_corAcaiStart, _corAcaiEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // --- LOGO ---
                Container(
                  padding: EdgeInsets.only(top: 50, bottom: 40),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.paw,
                          color: Colors.white,
                          size: 35,
                        ),
                      ),
                      SizedBox(height: 15),
                      Text(
                        "AgenPets",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(top: 5),
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "PAINEL GERENCIAL",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- 3. ITENS DO MENU ATUALIZADOS ---
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    children: [
                      _buildSectionTitle("PRINCIPAL"),
                      _buildMenuItem(
                        0,
                        "Dashboard",
                        Icons.space_dashboard_rounded,
                      ),
                      _buildMenuItem(1, "Agenda", Icons.calendar_month_rounded),
                      _buildMenuItem(
                        2,
                        "Hotel & Estadia",
                        FontAwesomeIcons.hotel,
                      ),

                      SizedBox(height: 20),
                      _buildSectionTitle("VENDAS & PRODUTOS"),
                      _buildMenuItem(
                        3,
                        "Venda de Planos",
                        FontAwesomeIcons.cartShopping,
                      ),
                      _buildMenuItem(
                        4,
                        "Tabela de Preços",
                        Icons.price_change_rounded,
                      ),

                      // --- NOVO BOTÃO AQUI ---
                      _buildMenuItem(
                        5,
                        "Banners do App",
                        Icons.view_carousel_rounded,
                      ),

                      SizedBox(height: 20),
                      _buildSectionTitle("ADMINISTRAÇÃO"),
                      _buildMenuItem(
                        6,
                        "Equipe",
                        Icons.people_alt_rounded,
                      ), // Atualizado para 6
                      _buildMenuItem(
                        7,
                        "Configurações",
                        Icons.settings_rounded,
                      ), // Atualizado para 7
                    ],
                  ),
                ),

                // --- RODAPÉ ---
                Container(
                  padding: EdgeInsets.all(20),
                  child: InkWell(
                    onTap: () =>
                        Navigator.pushReplacementNamed(context, '/login'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Sair do Sistema",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- ÁREA DE CONTEÚDO ---
          Expanded(
            child: Container(
              color: _corAcaiEnd,
              child: Container(
                decoration: BoxDecoration(
                  color: _corFundo,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    bottomLeft: Radius.circular(30),
                  ),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    bottomLeft: Radius.circular(30),
                  ),
                  child:
                      _telas[_selectedIndex], // Exibe a tela baseada no índice clicado
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 15, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildMenuItem(int index, String title, IconData icon) {
    bool isSelected = _selectedIndex == index;

    return Container(
      margin: EdgeInsets.only(bottom: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                FaIcon(
                  icon,
                  color: isSelected ? _corAcaiStart : Colors.white70,
                  size: 20,
                ),
                SizedBox(width: 15),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? _corAcaiStart : Colors.white,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                Spacer(),
                if (isSelected)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _corAcaiStart,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
