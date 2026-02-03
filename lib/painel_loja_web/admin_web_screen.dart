import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/admin_access_manager.dart';

class AdminWebScreen extends StatefulWidget {
  @override
  _AdminWebScreenState createState() => _AdminWebScreenState();
}

class _AdminWebScreenState extends State<AdminWebScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;

  // Menu Dinâmico
  List<AdminModule> _visiblePages = [];

  // Cores da Identidade Visual
  final Color _corAcaiStart = Color(0xFF4A148C);
  final Color _corAcaiEnd = Color(0xFF7B1FA2);
  final Color _corFundo = Color(0xFFF0F2F5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Se não tiver usuário, para o loading (o wrapper de auth deve tratar redirecionamento)
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final modules = await AdminAccessManager().getAccessibleModules(user);
      if (mounted) {
        setState(() {
          _visiblePages = modules;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erro no AdminWebScreen: $e");
      if (mounted) setState(() => _isLoading = false);
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
              Text(
                "Acesso Restrito",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text("Você não tem permissão para acessar nenhuma página."),
              SizedBox(height: 20),
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (route) => false,
                  );
                },
                child: Text("Sair"),
              ),
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

  Widget _buildMenuItem(int index, AdminModule page) {
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
