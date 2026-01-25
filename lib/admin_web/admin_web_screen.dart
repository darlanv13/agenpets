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
import 'views/gestao_banners_view.dart';

class AdminWebScreen extends StatefulWidget {
  @override
  _AdminWebScreenState createState() => _AdminWebScreenState();
}

class _AdminWebScreenState extends State<AdminWebScreen> {
  int _selectedIndex = 0;

  // Controle de Permissões e Dados do Usuário
  bool _isMaster = false;
  bool _isCaixa = false;
  String _nomeUsuario = "Administrador"; // Nome padrão

  // Cores
  final Color _corAcaiStart = Color(0xFF4A148C);
  final Color _corAcaiEnd = Color(0xFF7B1FA2);
  final Color _corFundo = Color(0xFFF0F2F5);

  // Lista COMPLETA de todas as telas possíveis
  final Map<int, Widget> _mapaTelas = {
    0: DashboardView(),
    1: AgendaView(),
    2: HotelView(),
    3: VendaAssinaturaView(),
    4: GestaoPrecosView(),
    5: GestaoBannersView(),
    6: EquipeView(),
    7: ConfiguracaoAgendaView(),
  };

  List<int> _indicesPermitidos = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configurarPermissoes();
  }

  void _configurarPermissoes() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    // Se não veio argumentos ou é master
    if (args == null || args['tipo_acesso'] == 'master') {
      _isMaster = true;
      _isCaixa = false;
      _nomeUsuario = "Administrador"; // Nome do Master
      _indicesPermitidos = [0, 1, 2, 3, 4, 5, 6, 7];
    } else {
      // É um funcionário com a role 'caixa'
      _isMaster = false;
      _isCaixa = true;

      // Tenta pegar o nome dos dados passados pelo login
      if (args['dados'] != null && args['dados']['nome'] != null) {
        _nomeUsuario = args['dados']['nome'];
      } else {
        _nomeUsuario = "Colaborador";
      }

      // Caixa vê apenas operacional
      _indicesPermitidos = [1, 2, 3];
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    int idTelaReal = _indicesPermitidos.isNotEmpty
        ? _indicesPermitidos[_selectedIndex]
        : 0;

    return Scaffold(
      backgroundColor: _corFundo,
      body: Row(
        children: [
          // SIDEBAR
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
                _buildLogoArea(),

                // ITENS DO MENU (Filtrados)
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    children: [
                      _buildSectionTitle("OPERACIONAL"),
                      if (_indicesPermitidos.contains(0))
                        _buildMenuItem(
                          0,
                          "Dashboard",
                          Icons.space_dashboard_rounded,
                        ),
                      if (_indicesPermitidos.contains(1))
                        _buildMenuItem(
                          1,
                          "Banho & Tosa",
                          Icons.calendar_month_rounded,
                        ),
                      if (_indicesPermitidos.contains(2))
                        _buildMenuItem(
                          2,
                          "Hotel & Estadia",
                          FontAwesomeIcons.hotel,
                        ),
                      if (_indicesPermitidos.contains(3))
                        _buildMenuItem(
                          3,
                          "Venda de Planos",
                          FontAwesomeIcons.cartShopping,
                        ),

                      if (_isMaster) ...[
                        SizedBox(height: 20),
                        _buildSectionTitle("GESTÃO"),
                        _buildMenuItem(
                          4,
                          "Tabela de Preços",
                          Icons.price_change_rounded,
                        ),
                        _buildMenuItem(
                          5,
                          "Banners App",
                          Icons.view_carousel_rounded,
                        ),

                        SizedBox(height: 20),
                        _buildSectionTitle("ADMINISTRAÇÃO"),
                        _buildMenuItem(6, "Equipe", Icons.people_alt_rounded),
                        _buildMenuItem(
                          7,
                          "Configurações",
                          Icons.settings_rounded,
                        ),
                      ],
                    ],
                  ),
                ),
                _buildLogoutButton(),
              ],
            ),
          ),

          // CONTEÚDO
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
                      _mapaTelas[idTelaReal] ??
                      Center(child: Text("Tela não encontrada")),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoArea() {
    // Pega apenas o primeiro nome para não quebrar o layout
    String primeiroNome = _nomeUsuario.split(' ')[0];

    return Container(
      padding: EdgeInsets.only(top: 50, bottom: 30),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: FaIcon(FontAwesomeIcons.paw, color: Colors.white, size: 35),
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
            margin: EdgeInsets.only(top: 5, bottom: 15),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _isMaster ? "MASTER ADMIN" : "PAINEL CAIXA",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
          ),

          // --- NOME DO USUÁRIO LOGADO ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Olá, ",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                primeiroNome,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // ------------------------------
        ],
      ),
    );
  }

  Widget _buildMenuItem(int idTela, String title, IconData icon) {
    int visualIndex = _indicesPermitidos.indexOf(idTela);
    bool isSelected = _selectedIndex == visualIndex;

    return Container(
      margin: EdgeInsets.only(bottom: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = visualIndex),
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

  Widget _buildLogoutButton() {
    return Container(
      padding: EdgeInsets.all(20),
      child: InkWell(
        onTap: () => Navigator.pushReplacementNamed(context, '/login'),
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
              Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
              SizedBox(width: 10),
              Text(
                "Sair",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
