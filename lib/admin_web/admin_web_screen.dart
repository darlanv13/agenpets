import 'package:agenpet/admin_tenants/views/gestao_tenants_view.dart';
import 'package:agenpet/admin_web/views/creche_view.dart';
import 'package:agenpet/admin_web/views/gestao_estoque_view.dart';
import 'package:agenpet/admin_web/views/gestao_equipe_view.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _isLoading = true;

  // Dados do Usuário
  bool _isMaster = false;
  String _perfil = 'padrao';
  List<String> _acessos = [];

  // Menu Dinâmico
  List<PageDefinition> _visiblePages = [];

  // Cores da Identidade Visual
  final Color _corAcaiStart = Color(0xFF4A148C);
  final Color _corAcaiEnd = Color(0xFF7B1FA2);
  final Color _corFundo = Color(0xFFF0F2F5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserPermissions();
  }

  Future<void> _loadUserPermissions() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    // Defaults from Login Screen
    if (args != null) {
      _isMaster = args['isMaster'] == true;
      _perfil = args['perfil'] ?? 'padrao';
    }

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
       // Should redirect to login, but let's just stop here
       setState(() => _isLoading = false);
       return;
    }

    try {
      // Fetch permissions from Firestore
      // Path: tenants/{tenantId}/profissionais/{uid}
      final docRef = FirebaseFirestore.instance
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('profissionais')
          .doc(user.uid);

      final snapshot = await docRef.get();

      if (snapshot.exists) {
        final data = snapshot.data()!;
        _perfil = data['perfil'] ?? _perfil;

        // Se for Master no banco, garante a flag
        if (_perfil == 'master') _isMaster = true;

        if (data['acessos'] != null) {
          _acessos = List<String>.from(data['acessos']);
        }
      }

      _buildMenu();

    } catch (e) {
      print("Erro ao carregar permissões: $e");
      // Fallback: build menu based on basic args
      _buildMenu();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _buildMenu() {
    // Definition of ALL available pages
    final allPages = [
      PageDefinition(
        id: 'dashboard',
        title: "Dashboard",
        icon: Icons.space_dashboard_rounded,
        section: "PRINCIPAL",
        widget: DashboardView(),
      ),
      PageDefinition(
        id: 'loja_pdv',
        title: "Loja / PDV",
        icon: FontAwesomeIcons.cashRegister,
        widget: LojaView(isMaster: _isMaster),
      ),
      PageDefinition(
        id: 'banhos_tosa',
        title: "Banhos & Tosa",
        icon: FontAwesomeIcons.scissors,
        widget: BanhosTosaView(),
      ),
      PageDefinition(
        id: 'hotel',
        title: "Hotel & Estadia",
        icon: FontAwesomeIcons.hotel,
        widget: HotelView(),
      ),
      PageDefinition(
        id: 'creche',
        title: "Creche",
        icon: FontAwesomeIcons.dog,
        widget: CrecheView(),
      ),
      PageDefinition(
        id: 'venda_planos',
        title: "Venda de Planos",
        icon: FontAwesomeIcons.cartShopping,
        section: "VENDAS & PRODUTOS",
        widget: VendaAssinaturaView(),
      ),
      PageDefinition(
        id: 'gestao_precos',
        title: "Tabela de Preços",
        icon: Icons.price_change_rounded,
        widget: GestaoPrecosView(),
      ),
      PageDefinition(
        id: 'banners_app',
        title: "Banners do App",
        icon: Icons.view_carousel_rounded,
        widget: GestaoBannersView(),
      ),
      PageDefinition(
        id: 'equipe',
        title: "Equipe",
        icon: Icons.people_alt_rounded,
        section: "ADMINISTRAÇÃO",
        widget: GestaoEquipeView(),
      ),
      PageDefinition(
        id: 'configuracoes',
        title: "Configurações",
        icon: Icons.settings_rounded,
        widget: ConfiguracaoAgendaView(),
      ),
      PageDefinition(
        id: 'gestao_estoque',
        title: "Gestão de Estoque",
        icon: Icons.inventory_rounded,
        widget: GestaoEstoqueView(),
      ),
      PageDefinition(
        id: 'gestao_tenants',
        title: "Gestão Multi-Tenants",
        icon: FontAwesomeIcons.building,
        section: "SUPER ADMIN",
        widget: GestaoTenantsView(),
      ),
    ];

    if (_isMaster) {
      // Master gets EVERYTHING (except maybe tenants if logic dictates, but for now everything)
      _visiblePages = allPages;
    } else {
      // Filter based on 'acessos'
      _visiblePages = allPages.where((page) {
        return _acessos.contains(page.id);
      }).toList();

      // Ensure Dashboard is always there? Or maybe not.
      // If list is empty, maybe show a "No Access" page.
      if (_visiblePages.isEmpty) {
        // Fallback or "Contact Admin"
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _corFundo,
        body: Center(child: CircularProgressIndicator(color: _corAcaiStart)),
      );
    }

    if (_visiblePages.isEmpty) {
       return Scaffold(
        backgroundColor: _corFundo,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 60, color: Colors.grey),
              SizedBox(height: 20),
              Text("Acesso Restrito", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text("Você não tem permissão para acessar nenhuma página."),
              SizedBox(height: 20),
              TextButton(
                onPressed: () async {
                   await FirebaseAuth.instance.signOut();
                   Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                },
                child: Text("Sair"),
              )
            ],
          ),
        ),
      );
    }

    // Safety check for index
    if (_selectedIndex >= _visiblePages.length) {
      _selectedIndex = 0;
    }

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

                // --- ITENS DO MENU DINÂMICOS ---
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    itemCount: _visiblePages.length,
                    itemBuilder: (ctx, index) {
                      final page = _visiblePages[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (page.section != null) ...[
                            SizedBox(height: 20),
                            _buildSectionTitle(page.section!),
                          ],
                          _buildMenuItem(index, page),
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
                  child: _visiblePages[_selectedIndex].widget,
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

  Widget _buildMenuItem(int index, PageDefinition page) {
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
                  page.icon,
                  color: isSelected ? _corAcaiStart : Colors.white70,
                  size: 20,
                ),
                SizedBox(width: 15),
                Text(
                  page.title,
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

class PageDefinition {
  final String id;
  final String title;
  final IconData icon;
  final String? section;
  final Widget widget;

  PageDefinition({
    required this.id,
    required this.title,
    required this.icon,
    this.section,
    required this.widget,
  });
}
