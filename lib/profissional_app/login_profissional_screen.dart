import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cpf_cnpj_validator/cnpj_validator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agenpet/profissional_app/views/selecao_loja_screen.dart';

class LoginProfissionalScreen extends StatefulWidget {
  const LoginProfissionalScreen({super.key});

  @override
  _LoginProfissionalScreenState createState() =>
      _LoginProfissionalScreenState();
}

class _LoginProfissionalScreenState extends State<LoginProfissionalScreen> {
  // Instâncias do Firebase
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _cpfController = TextEditingController();
  final _passController = TextEditingController();

  // --- CORES DA MARCA ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corAcaiClaro = Color(0xFF7B1FA2);

  var maskCpf = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  var maskCnpj = MaskTextInputFormatter(
    mask: '##.###.###/####-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool _isLoading = false;
  bool _senhaVisivel = false;
  bool _verificandoAuth = true;
  String? _nomeLoja;
  bool _cnpjLocked = false;
  bool _initializedArgs = false;

  @override
  void initState() {
    super.initState();
    _verificarConfiguracaoLoja();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args.containsKey('cnpj_empresa')) {
        final cnpj = args['cnpj_empresa'];
        if (cnpj != null && cnpj is String && cnpj.isNotEmpty) {
          _cpfController.text = cnpj;
          _cnpjLocked = true;
        }
      }
      _initializedArgs = true;
    }
  }

  // --- VERIFICAÇÃO INICIAL ---
  Future<void> _verificarConfiguracaoLoja() async {
    final prefs = await SharedPreferences.getInstance();
    final tenantId = prefs.getString('tenantId');
    final nomeLoja = prefs.getString('nomeLoja');

    if (tenantId == null) {
      // Se não tem loja configurada, redireciona para seleção
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (ctx) => SelecaoLojaScreen()),
        );
      }
      return;
    }

    // Configura o AppConfig com o tenant salvo
    AppConfig.setTenantId(tenantId);
    if (mounted) {
      setState(() {
        _nomeLoja = nomeLoja;
      });
    }

    // Só depois de configurar o tenantId, verificamos login automático
    _verificarSessaoExistente();
  }

  // --- AUTO-LOGIN ---
  Future<void> _verificarSessaoExistente() async {
    final user = _auth.currentUser;

    if (user != null) {
      // Já existe um usuário logado. Verifica se é válido no banco.
      try {
        final doc = await _db
            .collection('tenants')
            .doc(AppConfig.tenantId)
            .collection('profissionais')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['ativo'] == true) {
            // Sucesso: Redireciona
            if (mounted) {
              _rotearProfissional(data);
              return;
            }
          }
        }
      } catch (e) {
        print("Erro ao verificar sessão: $e");
      }
    }

    if (mounted) {
      setState(() => _verificandoAuth = false);
    }
  }

  Future<void> _trocarLoja() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Limpa tudo ou remove 'tenantId'
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (ctx) => SelecaoLojaScreen()),
      );
    }
  }

  Future<void> _fazerLogin() async {
    // Tenta pegar de CNPJ primeiro, se vazio tenta CPF (mas a UI vai forçar CNPJ visualmente se desejado)
    String docLimpo = _cpfController.text.replaceAll(RegExp(r'[^0-9]'), '');
    String senha = _passController.text;

    bool isCnpj = docLimpo.length > 11;

    // Validação estrita: O usuário pediu "Acesso só permitido com CNPJ" no App.
    if (!isCnpj) {
      _mostrarSnack("Acesso permitido apenas para PJ (CNPJ).", cor: Colors.red);
      return;
    } else {
      if (!CNPJValidator.isValid(docLimpo)) {
        _mostrarSnack("CNPJ Inválido.", cor: Colors.red);
        return;
      }
    }

    if (senha.isEmpty) {
      _mostrarSnack("Digite a senha.", cor: Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    // Uso de tenantId para login isolado
    final emailLogin = "$docLimpo@agenpets.${AppConfig.tenantId}";

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
          "Perfil profissional não encontrado nesta loja.",
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

      // Login Bem Sucedido
      if (mounted) {
        _rotearProfissional(data);
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Erro no login.";
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = "Senha ou Documento incorretos.";
      }
      if (e.code == 'user-not-found') msg = "Profissional não cadastrado.";
      if (e.code == 'too-many-requests') msg = "Muitas tentativas. Aguarde.";
      _mostrarSnack(msg, cor: Colors.red);
      setState(() => _isLoading = false);
    } catch (e) {
      _mostrarSnack("Erro: $e", cor: Colors.red);
      setState(() => _isLoading = false);
    }
  }

  // --- ROTEAMENTO ---
  void _rotearProfissional(Map<String, dynamic> proData) {
    double width = MediaQuery.of(context).size.width;
    bool isMobile = width < 800;

    // Verifica permissões (Normalizando para minúsculas para evitar erros de case)
    String perfil = (proData['perfil'] ?? 'padrao').toString().toLowerCase();
    List<dynamic> skills = proData['habilidades'] ?? [];

    // É Master se tiver perfil 'master' OU habilidade 'master'
    bool isMaster = perfil == 'master' || skills.contains('master');
    // Caixa/Vendedor também acessam painel web, mas com restrições (isMaster=false)
    bool isCaixaOuVendedor = perfil == 'caixa' || perfil == 'vendedor';

    if (isMobile && !isMaster && !isCaixaOuVendedor) {
      // Mobile workers (Groomers/Bathers) go to checklist/work screen
      Navigator.pushReplacementNamed(
        context,
        '/profissional',
        arguments: proData,
      );
    } else {
      // Admin/Desktop users go to Admin Panel
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
    if (_verificandoAuth) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _corAcai)),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            children: [
              // HEADER
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
                    bottomRight: Radius.circular(60),
                    bottomLeft: Radius.circular(20),
                  ),
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
                        FontAwesomeIcons.idCard, // Icone de Crachá/Pro
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      "Área do Profissional",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (_nomeLoja != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _nomeLoja!,
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(height: 40),

              // FORMULÁRIO
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    TextField(
                      controller: _cpfController,
                      // Permite digitar CNPJ
                      inputFormatters: [maskCnpj],
                      keyboardType: TextInputType.number,
                      readOnly: _cnpjLocked,
                      decoration: InputDecoration(
                        labelText: "CNPJ de Acesso",
                        prefixIcon: Icon(Icons.domain, color: _corAcai),
                        filled: _cnpjLocked,
                        fillColor: _cnpjLocked ? Colors.grey[200] : null,
                        suffixIcon: _cnpjLocked
                            ? Icon(Icons.lock, color: Colors.grey)
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        helperText: "Acesso exclusivo para PJ",
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _passController,
                      obscureText: !_senhaVisivel,
                      decoration: InputDecoration(
                        labelText: "Senha",
                        prefixIcon: Icon(Icons.lock, color: _corAcai),
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
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _fazerLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _corAcai,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                "ACESSAR",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: _trocarLoja,
                      icon: Icon(Icons.swap_horiz, color: Colors.grey),
                      label: Text(
                        "Trocar de Loja",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
