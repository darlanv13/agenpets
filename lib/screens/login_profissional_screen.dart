import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class LoginProfissionalScreen extends StatefulWidget {
  @override
  _LoginProfissionalScreenState createState() =>
      _LoginProfissionalScreenState();
}

class _LoginProfissionalScreenState extends State<LoginProfissionalScreen> {
  final _loginController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Instância do Firebase
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // --- CORES DA MARCA ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corAcaiClaro = Color(0xFF7B1FA2);

  bool _isLoading = false;

  var maskCpf = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  Future<void> _fazerLogin() async {
    String login = _loginController.text.trim();

    if (login.isEmpty) {
      _mostrarSnack("Digite seu login ou CPF.", cor: Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    // 1. Lógica específica para "agent"
    if (login.toLowerCase() == 'agent') {
      await _loginAgent();
    }
    // 2. Lógica para CPF
    else {
      // Remove caracteres não numéricos para verificar se é um CPF válido
      String cpfLimpo = login.replaceAll(RegExp(r'[^0-9]'), '');

      if (cpfLimpo.length == 11 && CPFValidator.isValid(cpfLimpo)) {
        // Se parece um CPF, tenta o fluxo profissional antigo
        // Formata o CPF para o padrão 000.000.000-00 se necessário
        String cpfFormatado = maskCpf.maskText(cpfLimpo);
        await _verificarProfissionalCPF(cpfLimpo, cpfFormatado);
      } else {
        _mostrarSnack("Login inválido. Digite 'agent' ou um CPF válido.", cor: Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginAgent() async {
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
        final dadosUser = {
          'nome': 'Agent',
          'perfil': 'master',
          'habilidades': ['master'],
          'ativo': true,
          'uid': userCred.user!.uid,
        };

        _navegarParaAdmin(dadosUser, isMaster: true);
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Erro no login.";
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = "Login 'agent' não autorizado (Verifique Firebase).";
      } else {
        msg = "Erro: ${e.message}";
      }
      _mostrarSnack(msg, cor: Colors.red);
    } catch (e) {
      _mostrarSnack("Erro: $e", cor: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verificarProfissionalCPF(String cpfLimpo, String cpfFormatado) async {
    try {
      // Consulta a coleção 'profissionais'
      final proQuery = await _db
          .collection('profissionais')
          .where('cpf', isEqualTo: cpfFormatado)
          .limit(1)
          .get();

      if (proQuery.docs.isNotEmpty) {
        final docPro = proQuery.docs.first;
        // Se encontrou, pede a senha
        setState(() => _isLoading = false); // Para o loading para mostrar o dialog
        _abrirDialogoSenhaProfissional(cpfLimpo, docPro);
      } else {
        _mostrarSnack("Profissional não encontrado para este CPF.", cor: Colors.red);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _mostrarSnack("Erro de conexão: $e", cor: Colors.orange);
      setState(() => _isLoading = false);
    }
  }

  void _abrirDialogoSenhaProfissional(
    String cpfLimpo,
    DocumentSnapshot docPro,
  ) {
    final _passCtrl = TextEditingController();
    bool _senhaVisivelDialog = false;
    bool _logandoDialog = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.lock, color: _corAcai),
                SizedBox(width: 10),
                Text(
                  "Acesso Profissional",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Olá, ${docPro['nome'].toString().split(' ')[0]}. Digite sua senha.",
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _passCtrl,
                  obscureText: !_senhaVisivelDialog,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: "Senha",
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _senhaVisivelDialog ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setStateDialog(() => _senhaVisivelDialog = !_senhaVisivelDialog),
                    ),
                  ),
                ),
                if (_logandoDialog)
                  Padding(
                    padding: const EdgeInsets.only(top: 15.0),
                    child: LinearProgressIndicator(color: _corAcai),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _logandoDialog ? null : () => Navigator.pop(ctx),
                child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _corAcai),
                onPressed: _logandoDialog
                    ? null
                    : () async {
                        setStateDialog(() => _logandoDialog = true);

                        // Autentica com email cpf@agenpets.pro
                        Map<String, dynamic>? dadosUsuario =
                            await _autenticarProfissionalFirebase(
                              cpfLimpo,
                              _passCtrl.text,
                            );

                        if (dadosUsuario != null) {
                          Navigator.pop(ctx);
                          _rotearProfissional(dadosUsuario);
                        } else {
                          setStateDialog(() => _logandoDialog = false);
                        }
                      },
                child: Text("ENTRAR", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>?> _autenticarProfissionalFirebase(
    String cpfLimpo,
    String senha,
  ) async {
    final emailLogin = "$cpfLimpo@agenpets.pro";

    try {
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: emailLogin,
        password: senha,
      );

      DocumentSnapshot doc = await _db
          .collection('profissionais')
          .doc(userCred.user!.uid)
          .get();

      if (!doc.exists) {
        _mostrarSnack("Erro: Perfil não encontrado no banco.", cor: Colors.red);
        await _auth.signOut();
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;

      if (data['ativo'] == false) {
        _mostrarSnack("Acesso revogado.", cor: Colors.red);
        await _auth.signOut();
        return null;
      }

      return data;
    } on FirebaseAuthException catch (e) {
      String msg = "Erro no login.";
      if (e.code == 'wrong-password' || e.code == 'invalid-credential')
        msg = "Senha incorreta.";
      if (e.code == 'user-not-found') msg = "Usuário não cadastrado.";
      if (e.code == 'too-many-requests') msg = "Muitas tentativas. Aguarde.";
      _mostrarSnack(msg, cor: Colors.red);
      return null;
    } catch (e) {
      _mostrarSnack("Erro: $e", cor: Colors.red);
      return null;
    }
  }

  void _rotearProfissional(Map<String, dynamic> proData) {
    // Mesma lógica de roteamento, mas aqui já estamos no app profissional
    // Então sempre vamos para o Admin Web, mas filtrando o acesso.

    String perfil = (proData['perfil'] ?? 'padrao').toString().toLowerCase();
    List<dynamic> skills = proData['habilidades'] ?? [];
    bool isMaster = perfil == 'master' || skills.contains('master');

    // Se for mobile e tiver skill de tosa/banho, talvez devesse ir para uma tela específica?
    // Mas o pedido diz que "A area do profissional será um App a parte".
    // Vou assumir que o AdminWebScreen é adaptativo ou lida com isso.
    // Mas no LoginScreen original, havia um desvio para '/profissional' no mobile.

    double width = MediaQuery.of(context).size.width;
    bool isMobile = width < 800;

    // Se for mobile e NÃO for master/caixa/vendedor, vai para tela simples
    bool isCaixaOuVendedor = perfil == 'caixa' || perfil == 'vendedor';
    bool vaiParaAdminWeb = !isMobile || isMaster || isCaixaOuVendedor;

    if (!vaiParaAdminWeb) {
         Navigator.pushReplacementNamed(
            context,
            '/profissional',
            arguments: proData,
          );
    } else {
        _navegarParaAdmin(proData, isMaster: isMaster, perfil: perfil);
    }
  }

  void _navegarParaAdmin(Map<String, dynamic> dados, {bool isMaster = false, String perfil = 'master'}) {
    Navigator.pushReplacementNamed(
      context,
      '/admin_web',
      arguments: {
        'tipo_acesso': isMaster ? 'master' : perfil,
        'dados': dados,
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
            // HEADER COM GRADIENTE
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
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.userTie,
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
                      "Digite seu login ou CPF.",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 30),

                    TextField(
                      controller: _loginController,
                      style: TextStyle(fontSize: 18),
                      // Não usamos inputFormatters restritos aqui para permitir "agent"
                      // Mas poderíamos usar um listener para aplicar máscara dinamicamente
                      // Por simplicidade, aceita texto livre e valida no submit.
                      decoration: InputDecoration(
                        labelText: "Login ou CPF",
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
