import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  _CadastroScreenState createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();

  // O Service já está configurado internamente para usar 'agenpets'
  final _firebaseService = FirebaseService();

  // Máscara para celular (Brasil)
  var maskPhone = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool _isLoading = false;
  String? _cpfRecebido;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    if (args != null) {
      _cpfRecebido = args['cpf'];
    }
  }

  Future<void> _salvarCadastro() async {
    // --- VALIDAÇÃO ---
    String nomeDigitado = _nomeController.text.trim();
    String telefoneDigitado = _telefoneController.text.trim();

    if (nomeDigitado.isEmpty || nomeDigitado.length < 3) {
      _mostrarErro("Por favor, digite seu Nome Completo.");
      return;
    }

    if (telefoneDigitado.isEmpty || telefoneDigitado.length < 14) {
      _mostrarErro("Digite um celular válido com DDD.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final novoUsuario = UserModel(
        cpf: _cpfRecebido!,
        nome: nomeDigitado,
        telefone: telefoneDigitado,
      );

      // O FirebaseService conecta no banco 'agenpets'
      await _firebaseService.createUser(novoUsuario);

      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: novoUsuario.toMap(),
      );
    } catch (e) {
      _mostrarErro("Erro ao cadastrar: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 10),
            Text(mensagem),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Finalizar Cadastro"),
        backgroundColor: Color(0xFF0056D2),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER DECORATIVO ---
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Color(0xFF0056D2),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(50),
                  bottomRight: Radius.circular(50),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.userPen,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),

            // --- FORMULÁRIO ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Falta pouco!",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    "Complete seus dados para agendar serviços.",
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),

                  SizedBox(height: 30),

                  // 1. Campo Nome
                  _buildTextField(
                    controller: _nomeController,
                    label: "Nome Completo",
                    icon: FontAwesomeIcons.user,
                    hint: "Ex: Ana Souza",
                    capitalization: TextCapitalization.words,
                  ),

                  SizedBox(height: 20),

                  // 2. Campo Telefone
                  _buildTextField(
                    controller: _telefoneController,
                    label: "Celular (WhatsApp)",
                    icon: FontAwesomeIcons.whatsapp,
                    hint: "(00) 00000-0000",
                    formatter: maskPhone,
                    inputType: TextInputType.phone,
                  ),

                  SizedBox(height: 20),

                  // 3. Campo CPF (Visualmente Bloqueado)
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: "Seu CPF",
                        hintText:
                            _cpfRecebido, // Mostra o valor como hint para ficar visível
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: Colors.grey,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                      controller: TextEditingController(
                        text: _cpfRecebido,
                      ), // Preenche o valor
                    ),
                  ),

                  SizedBox(height: 40),

                  // Botão Salvar
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _salvarCadastro,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0056D2),
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              "CRIAR CONTA",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget Auxiliar para TextFields Bonitos
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    MaskTextInputFormatter? formatter,
    TextInputType inputType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      inputFormatters: formatter != null ? [formatter] : [],
      keyboardType: inputType,
      textCapitalization: capitalization,
      style: TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: FaIcon(icon, size: 20, color: Color(0xFF0056D2)),
        ),
        filled: true,
        fillColor: Colors.blue[50]!.withOpacity(0.5), // Fundo azul bem clarinho
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Color(0xFF0056D2), width: 1.5),
        ),
      ),
    );
  }
}
