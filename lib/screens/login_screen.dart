import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/firebase_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Conexão com o banco agenpets para verificar profissionais
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final _firebaseService = FirebaseService();
  final _cpfController = TextEditingController();

  // Máscara
  var maskCpf = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool _isLoading = false;

  Future<void> _verificarAcesso() async {
    // 1. Pega o CPF limpo (só números)
    String cpfLimpo = maskCpf.getUnmaskedText();

    // 2. Validação Matemática do CPF
    if (!CPFValidator.isValid(cpfLimpo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 10),
              Text("CPF Inválido. Verifique os números."),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 3. Verifica se é PROFISSIONAL
      // Procura na coleção 'profissionais' se existe algum documento com o campo 'cpf' igual
      final proQuery = await _db
          .collection('profissionais')
          .where('cpf', isEqualTo: cpfLimpo)
          .limit(1)
          .get();

      if (proQuery.docs.isNotEmpty) {
        // É UM PROFISSIONAL! Pergunta como quer entrar.
        _mostrarOpcoesDeAcesso(cpfLimpo);
      } else {
        // NÃO É PROFISSIONAL. Segue fluxo de cliente normal.
        await _loginComoCliente(cpfLimpo);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro de conexão: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fluxo Padrão do Cliente
  Future<void> _loginComoCliente(String cpf) async {
    final user = await _firebaseService.getUser(cpf);

    if (user != null) {
      // Usuário existe -> Home
      Navigator.pushReplacementNamed(context, '/home', arguments: user.toMap());
    } else {
      // Usuário novo -> Cadastro (Onde pediremos o Telefone e Nome)
      Navigator.pushReplacementNamed(
        context,
        '/cadastro',
        arguments: {'cpf': cpf},
      );
    }
  }

  // Modal para escolher perfil (UX Diferenciada)
  void _mostrarOpcoesDeAcesso(String cpf) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(25),
          height: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Identificamos seu perfil! 🌟",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              Text(
                "Como você deseja acessar hoje?",
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 30),

              // Opção 1: Entrar como Profissional
              _buildOpcaoAcesso(
                icon: FontAwesomeIcons.briefcase,
                color: Colors.green,
                titulo: "Acessar como Profissional",
                subtitulo: "Ver minha agenda e atender pets",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profissional');
                },
              ),

              SizedBox(height: 15),

              // Opção 2: Entrar como Cliente
              _buildOpcaoAcesso(
                icon: FontAwesomeIcons.user,
                color: Colors.blue,
                titulo: "Acessar como Cliente",
                subtitulo: "Agendar serviços para meus pets",
                onTap: () {
                  Navigator.pop(context);
                  _loginComoCliente(cpf); // Segue fluxo normal
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOpcaoAcesso({
    required IconData icon,
    required Color color,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: FaIcon(icon, color: color, size: 20),
            ),
            SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  subtitulo,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            Spacer(),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER CURVO (DESIGN) ---
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0056D2), Color(0xFF0078FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(100),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.paw,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "AgenPet",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "Seu pet em boas mãos",
                    style: TextStyle(color: Colors.blue[100]),
                  ),
                ],
              ),
            ),

            SizedBox(height: 40),

            // --- FORMULÁRIO ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bem-vindo(a)!",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    "Digite seu CPF para entrar ou cadastrar.",
                    style: TextStyle(color: Colors.grey[600]),
                  ),

                  SizedBox(height: 30),

                  TextField(
                    controller: _cpfController,
                    inputFormatters: [maskCpf],
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: "CPF",
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.blue, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),

                  SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verificarAcesso,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0056D2),
                        elevation: 8,
                        shadowColor: Colors.blue.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "CONTINUAR",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Icon(Icons.arrow_forward),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: 20),
                  Center(
                    child: Text(
                      "Ao continuar, você concorda com nossos Termos.",
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
