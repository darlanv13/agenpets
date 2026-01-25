import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; //
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/firebase_service.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  // --- 1. CÉREBRO DO LOGIN: IDENTIFICA O TIPO DE USUÁRIO ---
  Future<void> _verificarAcesso() async {
    String cpfLimpo = maskCpf.getUnmaskedText();
    String cpfFormatado = _cpfController.text;

    if (!CPFValidator.isValid(cpfLimpo)) {
      _mostrarSnack("CPF Inválido. Verifique os números.", cor: Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // PASSO A: Verifica se é um Profissional Cadastrado
      // Consultamos a coleção 'profissionais' para saber se pedimos senha ou não.
      final proQuery = await _db
          .collection('profissionais')
          .where('cpf', isEqualTo: cpfFormatado)
          .limit(1)
          .get(); //

      if (proQuery.docs.isNotEmpty) {
        // É PROFISSIONAL: Precisa de senha para gerar o token de segurança
        setState(
          () => _isLoading = false,
        ); // Para o loading para abrir o dialog
        _abrirDialogoSenhaProfissional(cpfLimpo, proQuery.docs.first);
      } else {
        // NÃO É PROFISSIONAL: Segue fluxo de Cliente (Sem senha)
        await _loginComoCliente(cpfLimpo);
      }
    } catch (e) {
      _mostrarSnack("Erro de conexão: $e", cor: Colors.orange);
      setState(() => _isLoading = false);
    }
  }

  // --- 2. FLUXO DE PROFISSIONAL (COM AUTH SEGURO) ---
  void _abrirDialogoSenhaProfissional(
    String cpfLimpo,
    DocumentSnapshot docPro,
  ) {
    final _passCtrl = TextEditingController();
    bool _senhaVisivel = false;
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
                  obscureText: !_senhaVisivel,
                  autofocus: false,
                  decoration: InputDecoration(
                    labelText: "Senha",
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _senhaVisivel ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setStateDialog(() => _senhaVisivel = !_senhaVisivel),
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

                        // 1. Tenta pegar os dados do usuário
                        Map<String, dynamic>? dadosUsuario =
                            await _autenticarProfissionalFirebase(
                              cpfLimpo,
                              _passCtrl.text,
                            );

                        if (dadosUsuario != null) {
                          // 2. SUCESSO: Primeiro fechamos o diálogo!
                          Navigator.pop(ctx);

                          // 3. AGORA navegamos (com o contexto da tela principal livre)
                          _rotearProfissional(dadosUsuario);
                        } else {
                          // ERRO: Apenas para o loading do dialog
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

      return data; // Retorna os dados para quem chamou
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

  // --- 3. ROTEAMENTO (Aqui que decide para onde vai) ---
  void _rotearProfissional(Map<String, dynamic> proData) {
    double width = MediaQuery.of(context).size.width;
    bool isMobile = width < 800;

    // Verifica permissões
    String perfil = proData['perfil'] ?? 'padrao';
    List<dynamic> skills = proData['habilidades'] ?? [];

    // É Master se tiver perfil 'master' OU habilidade 'master' OU 'caixa' (caixa geralmente é admin)
    bool isMaster = perfil == 'master' ||
        skills.contains('master') ||
        perfil == 'caixa';

    if (isMobile) {
      // Mobile: Abre o BottomSheet de escolha
      _mostrarDialogoBifurcacao(proData);
    } else {
      // Desktop: Roteamento direto
      if (isMaster) {
        // Se for Master no PC -> Painel Admin
        // VERIFIQUE SE A ROTA '/admin_web' EXISTE NO SEU MAIN.DART
        Navigator.pushReplacementNamed(
          context,
          '/admin_web',
          arguments: {
            'tipo_acesso': 'master',
            'dados': proData,
            'isMaster': isMaster,
          },
        );
      } else {
        // Se for Banhista no PC -> Área Profissional
        Navigator.pushReplacementNamed(
          context,
          '/profissional',
          arguments: proData,
        );
      }
    }
  }

  void _mostrarDialogoBifurcacao(Map<String, dynamic> proData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (ctx) => Container(
        padding: EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(height: 20),
            Text(
              "Como deseja acessar?",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _corAcai,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Você possui acesso administrativo/profissional.",
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 30),

            // Opção Cliente
            _buildBifurcacaoOption(
              icon: FontAwesomeIcons.user,
              color: Colors.blue,
              title: "Entrar como Cliente",
              subtitle: "Agendar para meus pets",
              onTap: () {
                Navigator.pop(ctx);
                _loginComoCliente(maskCpf.getUnmaskedText());
              },
            ),
            SizedBox(height: 15),

            // Opção Profissional
            _buildBifurcacaoOption(
              icon: FontAwesomeIcons.briefcase,
              color: _corAcai,
              title: "Área Profissional",
              subtitle: "Minha agenda e tarefas",
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(
                  context,
                  '/profissional',
                  arguments: proData,
                );
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
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

  Widget _buildBifurcacaoOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
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
