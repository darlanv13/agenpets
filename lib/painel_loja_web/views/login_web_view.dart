import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/config/app_config.dart';

class LoginWebView extends StatefulWidget {
  const LoginWebView({super.key});

  @override
  _LoginWebViewState createState() => _LoginWebViewState();
}

class _LoginWebViewState extends State<LoginWebView> {
  // Instâncias do Firebase
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _cpfController = TextEditingController();
  final _passController = TextEditingController();

  // --- CORES DA MARCA ---
  final Color _corAcai = const Color(0xFF4A148C);
  final Color _corAcaiClaro = const Color(0xFF7B1FA2);

  var maskCpf = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool _isLoading = false;
  bool _senhaVisivel = false;

  Future<void> _fazerLogin() async {
    String cpfLimpo = maskCpf.getUnmaskedText();
    String senha = _passController.text;

    if (cpfLimpo.length != 11) {
      _mostrarSnack("CPF inválido.", cor: Colors.red);
      return;
    }

    if (senha.isEmpty) {
      _mostrarSnack("Digite sua senha.", cor: Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    // Login com isolamento de tenant
    final emailLogin = "$cpfLimpo@agenpets.${AppConfig.tenantId}";

    try {
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: emailLogin,
        password: senha,
      );

      DocumentSnapshot doc = await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('profissionais')
          .doc(userCred.user!.uid)
          .get();

      if (!doc.exists) {
        _mostrarSnack(
          "Erro: Perfil profissional não encontrado nesta loja.",
          cor: Colors.red,
        );
        await _auth.signOut();
        setState(() => _isLoading = false);
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      if (data['ativo'] == false) {
        _mostrarSnack("Acesso revogado.", cor: Colors.red);
        await _auth.signOut();
        setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        _rotearParaAdminWeb(data);
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Erro no login.";
      if (e.code == 'wrong-password' || e.code == 'invalid-credential')
        msg = "Senha incorreta.";
      if (e.code == 'user-not-found') msg = "Usuário não cadastrado.";
      if (e.code == 'too-many-requests') msg = "Muitas tentativas. Aguarde.";
      _mostrarSnack(msg, cor: Colors.red);
      setState(() => _isLoading = false);
    } catch (e) {
      _mostrarSnack("Erro: $e", cor: Colors.red);
      setState(() => _isLoading = false);
    }
  }

  void _rotearParaAdminWeb(Map<String, dynamic> proData) {
    String perfil = (proData['perfil'] ?? 'padrao').toString().toLowerCase();
    List<dynamic> skills = proData['habilidades'] ?? [];
    bool isMaster = perfil == 'master' || skills.contains('master');

    Navigator.pushReplacementNamed(
      context,
      '/admin_web',
      arguments: {
        'tipo_acesso': isMaster ? 'master' : perfil,
        'dados': proData,
        'isMaster': isMaster,
        'perfil': perfil,
      },
    );
  }

  void _mostrarSnack(String msg, {Color cor = Colors.black87}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        width: 400, // Largura fixa para desktop
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_corAcai, _corAcaiClaro],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 400, // Largura fixa do card de login
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo / Ícone
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: _corAcai.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.paw,
                        size: 40,
                        color: _corAcai,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Painel da Loja",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _corAcai,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Acesse com seu CPF e senha",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Campos
                    TextField(
                      controller: _cpfController,
                      inputFormatters: [maskCpf],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "CPF",
                        prefixIcon: Icon(Icons.person_outline, color: _corAcai),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passController,
                      obscureText: !_senhaVisivel,
                      decoration: InputDecoration(
                        labelText: "Senha",
                        prefixIcon: Icon(Icons.lock_outline, color: _corAcai),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _senhaVisivel
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () =>
                              setState(() => _senhaVisivel = !_senhaVisivel),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _fazerLogin(),
                    ),
                    const SizedBox(height: 30),

                    // Botão Entrar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _fazerLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _corAcai,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "ENTRAR",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
