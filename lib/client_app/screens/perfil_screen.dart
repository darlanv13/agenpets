import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // Para abrir WhatsApp de suporte (opcional)

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  _PerfilScreenState createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  String? _userCpf;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_userCpf == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null) {
        _userCpf = args['cpf'];
        _carregarDados();
      }
    }
  }

  Future<void> _carregarDados() async {
    try {
      final doc = await _db.collection('users').doc(_userCpf).get();
      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _fazerLogout() {
    // Aqui você limparia dados locais (SharedPreferences) se estivesse usando
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _abrirSuporte() async {
    // Exemplo de link para WhatsApp
    final Uri url = Uri.parse(
      "https://wa.me/5511999999999?text=Preciso+de+ajuda+no+AgenPet",
    );
    if (!await launchUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Não foi possível abrir o WhatsApp")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Meu Perfil"),
        centerTitle: true,
        backgroundColor: Color(0xFF0056D2),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // --- CABEÇALHO ---
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(bottom: 30),
                    decoration: BoxDecoration(
                      color: Color(0xFF0056D2),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              _userData?['nome']?[0].toUpperCase() ?? "U",
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0056D2),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 15),
                        Text(
                          _userData?['nome'] ?? "Usuário",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _userData?['telefone'] ?? "Sem telefone",
                          style: TextStyle(color: Colors.blue[100]),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // --- MENU ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: FontAwesomeIcons.userPen,
                          text: "Meus Dados",
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Em breve: Edição de perfil"),
                              ),
                            );
                          },
                        ),

                        _buildMenuItem(
                          icon: FontAwesomeIcons.paw,
                          text: "Meus Pets",
                          onTap: () {
                            // Navega para a tela de pets passando o CPF
                            Navigator.pushNamed(
                              context,
                              '/meus_pets',
                              arguments: {'cpf': _userCpf},
                            );
                          },
                        ),

                        _buildMenuItem(
                          icon: FontAwesomeIcons.creditCard,
                          text: "Minha Assinatura",
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/historico',
                              arguments: {'cpf': _userCpf},
                            );
                          },
                        ),

                        SizedBox(height: 20),
                        Divider(),
                        SizedBox(height: 10),

                        _buildMenuItem(
                          icon: FontAwesomeIcons.whatsapp,
                          text: "Suporte / Ajuda",
                          onTap: _abrirSuporte,
                          color: Colors.green,
                        ),

                        _buildMenuItem(
                          icon: Icons.exit_to_app,
                          text: "Sair do App",
                          onTap: _fazerLogout,
                          color: Colors.red,
                          isLast: true,
                        ),

                        SizedBox(height: 20),
                        Text(
                          "Versão 1.0.0",
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color color = const Color(0xFF424242),
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: FaIcon(icon, size: 20, color: color),
        ),
        title: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        trailing: isLast
            ? null
            : Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[300]),
      ),
    );
  }
}
