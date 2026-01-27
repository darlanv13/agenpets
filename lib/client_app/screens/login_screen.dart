import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/firebase_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Instâncias do Firebase
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );
  final _firebaseService = FirebaseService();
  final _cpfController = TextEditingController();

  // --- CORES DA MARCA ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corAcaiClaro = Color(0xFF7B1FA2);

  var maskCpf = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool _isLoading = false;
  bool _cpfValidoVisualmente = false;

  @override
  void initState() {
    super.initState();
    _cpfController.addListener(() {
      final cpfLimpo = maskCpf.getUnmaskedText();
      final isValido = cpfLimpo.length == 11 && CPFValidator.isValid(cpfLimpo);
      if (isValido != _cpfValidoVisualmente) {
        setState(() => _cpfValidoVisualmente = isValido);
      }
    });
  }

  // --- 1. LOGIN DE CLIENTE ---
  Future<void> _verificarAcesso() async {
    String cpfLimpo = maskCpf.getUnmaskedText();

    if (!CPFValidator.isValid(cpfLimpo)) {
      _mostrarSnack("CPF Inválido. Verifique os números.", cor: Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    await _loginComoCliente(cpfLimpo);
  }

  // --- 4. FLUXO DE CLIENTE (SEM SENHA) ---
  Future<void> _loginComoCliente(String cpfLimpo) async {
    // Aqui usamos o serviço existente para buscar o cliente
    final user = await _firebaseService.getUser(cpfLimpo); //

    if (user != null) {
      // Cliente já existe -> Home
      Navigator.pushReplacementNamed(context, '/home', arguments: user.toMap());
    } else {
      // Cliente novo -> Cadastro (levando o CPF)
      Navigator.pushReplacementNamed(
        context,
        '/cadastro',
        arguments: {'cpf': cpfLimpo},
      );
    }
    setState(() => _isLoading = false);
  }

  // --- WIDGETS AUXILIARES ---

  void _mostrarSnack(String msg, {Color cor = Colors.black87}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            children: [
              // HEADER COM GRADIENTE
              Container(
                height: 320,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_corAcai, _corAcaiClaro],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(80),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _corAcai.withOpacity(0.4),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.paw,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      "AgenPet",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      "Cuidado que seu pet merece",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 50),

              // INPUT CPF
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 450),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Bem-vindo(a)!",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          "Digite seu CPF para acessar.",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        SizedBox(height: 30),

                        TextField(
                          controller: _cpfController,
                          inputFormatters: [maskCpf],
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            fontSize: 18,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w600,
                          ),
                          onSubmitted: (_) => _verificarAcesso(),
                          decoration: InputDecoration(
                            labelText: "CPF",
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: _cpfValidoVisualmente
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            suffixIcon: _cpfValidoVisualmente
                                ? Icon(Icons.check_circle, color: Colors.green)
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
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
                              backgroundColor: _corAcai,
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 25,
                                    height: 25,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "CONTINUAR",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        SizedBox(height: 30),
                        Center(
                          child: Text(
                            "Ao continuar, você concorda com nossos Termos de Uso.",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                          ),
                        ),
                        SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
