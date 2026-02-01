import 'package:agenpet/admin_tenants/views/gestao_tenants_view.dart';
import 'package:agenpet/admin_web/views/creche_view.dart';
import 'package:agenpet/admin_web/views/gestao_estoque_view.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- IMPORTS DAS VIEWS ---
import 'views/dashboard_view.dart';
import 'views/banho_tosa_view.dart';
import 'views/hotel_view.dart';
import 'views/gestao_precos_view.dart';
import 'views/configuracao_agenda_view.dart';
import 'views/venda_assinatura_view.dart';
import 'views/gestao_banners_view.dart';
import 'views/loja_view.dart';

class AdminWebScreen extends StatefulWidget {
  @override
  _AdminWebScreenState createState() => _AdminWebScreenState();
}

class _AdminWebScreenState extends State<AdminWebScreen> {
  int _selectedIndex = 0;
  bool _isMaster = false;
  String _perfil = 'padrao';

  // Controle de Menu Dinâmico
  late List<Widget> _telas;
  late List<_MenuItem> _menuItems;

  // Cores da Identidade Visual
  final Color _corAcaiStart = Color(0xFF4A148C);
  final Color _corAcaiEnd = Color(0xFF7B1FA2);
  final Color _corFundo = Color(0xFFF0F2F5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recupera argumentos passados pela rota
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null) {
      _isMaster = args['isMaster'] == true;
      _perfil = args['perfil'] ?? 'padrao';
    }

    // LISTA COMPLETA DE TELAS (Índices devem bater com os do menu filtrado)
    // Para simplificar a filtragem, vamos reconstruir a lista baseada no que é visível
    _construirMenuETelas();
  }

  void _construirMenuETelas() {
    // Se não é Master, é restrito (inclui caixa, vendedor, tosador, banhista, etc.)
    bool isRestrito = !_isMaster;

    if (isRestrito) {
      // PERFIL RESTRITO (Caixa, Vendedor, Tosador, Banhista): Acesso limitado
      _telas = [
        LojaView(isMaster: false), // 0
        BanhosTosaView(), // 1
        HotelView(), // 2
        VendaAssinaturaView(), // 3
        CrecheView(), // 4
        GestaoEstoqueView(), // 5
      ];

      _menuItems = [
        _MenuItem("Loja / PDV", FontAwesomeIcons.cashRegister),
        _MenuItem("Banhos & Tosa ", FontAwesomeIcons.scissors),
        _MenuItem("Hotel & Estadia", FontAwesomeIcons.hotel),
        _MenuItem("Venda de Planos", FontAwesomeIcons.cartShopping),
        _MenuItem("Creche", FontAwesomeIcons.dog),
        _MenuItem("Gestão de Estoque", Icons.inventory_rounded),
      ];
    } else {
      // MASTER / ADMIN: Acesso Total
      _telas = [
        DashboardView(), // 0
        LojaView(isMaster: _isMaster), // 1
        BanhosTosaView(), // 2
        HotelView(), // 3
        CrecheView(), // 4
        VendaAssinaturaView(), // 5
        GestaoPrecosView(), // 6
        GestaoBannersView(), // 7
        ConfiguracaoAgendaView(), // 8
        GestaoEstoqueView(), // 9
        GestaoTenantsView(), // 10
      ];

      _menuItems = [
        _MenuItem(
          "Dashboard",
          Icons.space_dashboard_rounded,
          section: "PRINCIPAL",
        ),
        _MenuItem("Loja / PDV", FontAwesomeIcons.cashRegister),
        _MenuItem("Banhos & Tosa", FontAwesomeIcons.scissors),
        _MenuItem("Hotel & Estadia", FontAwesomeIcons.hotel),
        _MenuItem("Creche", FontAwesomeIcons.dog),
        _MenuItem(
          "Venda de Planos",
          FontAwesomeIcons.cartShopping,
          section: "VENDAS & PRODUTOS",
        ),
        _MenuItem("Tabela de Preços", Icons.price_change_rounded),
        _MenuItem("Banners do App", Icons.view_carousel_rounded),
        _MenuItem("Equipe", Icons.people_alt_rounded, section: "ADMINISTRAÇÃO"),
        _MenuItem("Configurações", Icons.settings_rounded),
        _MenuItem("Gestão de Estoque", Icons.inventory_rounded),
        _MenuItem(
          "Gestão Multi-Tenants",
          FontAwesomeIcons.building,
          section: "SUPER ADMIN",
        ),
      ];
    }
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.personDigging, size: 50, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text("Módulo em produção", style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

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

                // --- 3. ITENS DO MENU DINÂMICOS ---
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    itemCount: _menuItems.length,
                    itemBuilder: (ctx, index) {
                      final item = _menuItems[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.section != null) ...[
                            SizedBox(height: 20),
                            _buildSectionTitle(item.section!),
                          ],
                          _buildMenuItem(index, item.title, item.icon),
                        ],
                      );
                    },
                  ),
                ),

                // --- RODAPÉ ---
                Container(
                  padding: EdgeInsets.all(20),
                  child: InkWell(
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/',
                        (route) => false,
                      );
                    },
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

class _MenuItem {
  final String title;
  final IconData icon;
  final String? section;

  _MenuItem(this.title, this.icon, {this.section});
}
