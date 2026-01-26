import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginProfissionalScreen extends StatefulWidget {
  @override
  _LoginProfissionalScreenState createState() =>
      _LoginProfissionalScreenState();
}

class _LoginProfissionalScreenState extends State<LoginProfissionalScreen> {
  final _loginController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- CORES DA MARCA ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corAcaiClaro = Color(0xFF7B1FA2);

  bool _isLoading = false;

  Future<void> _fazerLogin() async {
    String login = _loginController.text.trim();

    if (login.isEmpty) {
      _mostrarSnack("Digite seu login.", cor: Colors.orange);
      return;
    }

    // Lógica específica para "agent"
    if (login.toLowerCase() == 'agent') {
      setState(() => _isLoading = true);
      try {
        // Tentativa de login com e-mail fantasma e senha padrão
        // E-mail: agent@emailfantasma.com
        // Senha: agent (conforme implícito em "digita apenas seu login")
        // WARNING: Hardcoded password "agent" used to satisfy the "username only" login requirement.
        // In a production environment, use Custom Auth Tokens or a secure backend handshake.
        UserCredential userCred = await _auth.signInWithEmailAndPassword(
          email: "agent@emailfantasma.com",
          password: "agent",
        );

        if (userCred.user != null) {
          // Sucesso - Navega para o Admin Web com perfil Master
          // Montamos o objeto de dados conforme esperado pelo AdminWebScreen
          final dadosUser = {
            'nome': 'Agent',
            'perfil': 'master',
            'habilidades': ['master'],
            'ativo': true,
            'uid': userCred.user!.uid,
          };

          Navigator.pushReplacementNamed(
            context,
            '/admin_web',
            arguments: {
              'tipo_acesso': 'master',
              'dados': dadosUser,
              'isMaster': true,
              'perfil': 'master',
            },
          );
        }
      } on FirebaseAuthException catch (e) {
        String msg = "Erro no login.";
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          msg = "Login não autorizado (Verifique se o usuário 'agent@emailfantasma.com' existe no Firebase).";
        } else {
          msg = "Erro: ${e.message}";
        }
        _mostrarSnack(msg, cor: Colors.red);
      } catch (e) {
        _mostrarSnack("Erro: $e", cor: Colors.red);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      _mostrarSnack("Login não reconhecido.", cor: Colors.red);
    }
  }

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER COM GRADIENTE (Similar ao LoginScreen mas simplificado)
            Container(
              height: 250,
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
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.userTie, // Ícone diferente para pro
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 15),
                  Text(
                    "Área Profissional",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 50),

            // INPUT LOGIN
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Identifique-se",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Digite seu login de acesso.",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 30),

                    TextField(
                      controller: _loginController,
                      style: TextStyle(fontSize: 18),
                      decoration: InputDecoration(
                        labelText: "Login",
                        prefixIcon: Icon(Icons.lock_outline, color: _corAcai),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onSubmitted: (_) => _fazerLogin(),
                    ),

                    SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _fazerLogin,
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
                            : Text(
                                "ENTRAR",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
