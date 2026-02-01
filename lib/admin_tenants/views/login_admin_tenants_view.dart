import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class LoginAdminTenantsView extends StatefulWidget {
  @override
  _LoginAdminTenantsViewState createState() => _LoginAdminTenantsViewState();
}

class _LoginAdminTenantsViewState extends State<LoginAdminTenantsView> {
  // --- Controladores e Serviços ---
  final _cpfController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // --- Máscara CPF ---
  var maskCpf = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  // --- Estados de UI ---
  bool _isLoading = false;
  bool _isObscure = true;
  final _formKey = GlobalKey<FormState>();

  // --- Cores da Marca ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corAcaiLight = Color(0xFF7C43BD);
  final Color _corFundo = Color(0xFFF5F7FA);

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Tratamento "Ghost Email"
      // Remove pontos e traços do CPF digitado
      String cpfRaw = _cpfController.text.replaceAll(RegExp(r'[^0-9]'), '');

      // Cria o email fantasma para autenticação interna
      String emailFantasma = "$cpfRaw@agenpets.pro";

      // 2. Autenticação no Firebase
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: emailFantasma,
        password: _passwordController.text.trim(),
      );

      // 3. Verificação de Segurança (Opcional: Nível Super Admin)
      /* final doc = await _db.collection('super_admins').doc(userCred.user!.uid).get();
      if (!doc.exists) {
        await _auth.signOut();
        throw FirebaseAuthException(code: 'not-admin', message: 'Acesso não autorizado.');
      }
      */

      // Sucesso: O AuthWrapper no main.dart cuidará do redirecionamento
    } on FirebaseAuthException catch (e) {
      String msg = "Ocorreu um erro inesperado.";
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        msg = "CPF ou senha incorretos.";
      } else if (e.code == 'wrong-password') {
        msg = "Senha incorreta.";
      } else if (e.code == 'too-many-requests') {
        msg = "Muitas tentativas. Tente novamente mais tarde.";
      } else if (e.code == 'not-admin') {
        msg = "Este usuário não possui permissão de Super Admin.";
      }
      _showSnack(msg, Colors.redAccent);
    } catch (e) {
      _showSnack("Erro: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Layout Responsivo: Split Screen para Desktop, Card Único para Mobile
    return Scaffold(
      backgroundColor: _corFundo,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return Row(
              children: [
                Expanded(flex: 5, child: _buildBrandingSide()),
                Expanded(flex: 4, child: _buildFormSide()),
              ],
            );
          } else {
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: _buildFormCard(isMobile: true),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  // --- Lado Esquerdo (Branding/Visual) ---
  Widget _buildBrandingSide() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_corAcai, Color(0xFF2E0C59)],
        ),
      ),
      child: Stack(
        children: [
          // Elementos decorativos de fundo
          Positioned(
            top: -100,
            left: -100,
            child: Icon(
              FontAwesomeIcons.paw,
              size: 400,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Icon(
              FontAwesomeIcons.shieldHalved,
              size: 300,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          // Conteúdo Centralizado
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.shieldCat,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 30),
                Text(
                  "AgenPets Admin",
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  "Gestão Centralizada de Tenants & Serviços",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          // Footer
          Positioned(
            bottom: 30,
            left: 30,
            child: Text(
              "© 2026 AgenPets Inc.",
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // --- Lado Direito (Formulário) ---
  Widget _buildFormSide() {
    return Container(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 60),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 450),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Bem-vindo de volta",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Insira suas credenciais de Super Admin para continuar.",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  SizedBox(height: 40),

                  // Input CPF
                  _buildLabel("CPF DE ACESSO"),
                  TextFormField(
                    controller: _cpfController,
                    inputFormatters: [maskCpf],
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 14) {
                        return 'CPF inválido';
                      }
                      return null;
                    },
                    decoration: _inputDecoration(
                      hint: "000.000.000-00",
                      icon: Icons.badge_outlined,
                    ),
                  ),
                  SizedBox(height: 25),

                  // Input Senha
                  _buildLabel("SENHA"),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isObscure,
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Digite sua senha';
                      return null;
                    },
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    decoration: _inputDecoration(
                      hint: "••••••••",
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        icon: Icon(
                          _isObscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey[400],
                        ),
                        onPressed: () =>
                            setState(() => _isObscure = !_isObscure),
                      ),
                    ),
                  ),

                  SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _showSnack(
                          "Contate o suporte técnico para redefinir.",
                          Colors.blueGrey,
                        );
                      },
                      child: Text(
                        "Esqueceu a senha?",
                        style: TextStyle(
                          color: _corAcai,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 30),

                  // Botão de Login
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _corAcai,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        shadowColor: _corAcai.withOpacity(0.4),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              "ACESSAR PAINEL",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
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
    );
  }

  // --- Card Versão Mobile ---
  Widget _buildFormCard({required bool isMobile}) {
    return Container(
      constraints: BoxConstraints(maxWidth: 400),
      padding: EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _corAcai.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: FaIcon(
                  FontAwesomeIcons.shieldCat,
                  size: 40,
                  color: _corAcai,
                ),
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: Text(
                "Super Admin",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _corAcai,
                ),
              ),
            ),
            SizedBox(height: 30),

            _buildLabel("CPF"),
            TextFormField(
              controller: _cpfController,
              inputFormatters: [maskCpf],
              keyboardType: TextInputType.number,
              validator: (val) =>
                  (val?.length ?? 0) < 14 ? 'CPF incompleto' : null,
              decoration: _inputDecoration(
                hint: "000.000.000-00",
                icon: Icons.badge_outlined,
              ),
            ),
            SizedBox(height: 20),

            _buildLabel("SENHA"),
            TextFormField(
              controller: _passwordController,
              obscureText: _isObscure,
              validator: (val) => (val?.isEmpty ?? true) ? 'Obrigatório' : null,
              decoration: _inputDecoration(
                hint: "••••••",
                icon: Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                ),
              ),
            ),
            SizedBox(height: 30),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "ENTRAR",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets Auxiliares ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      prefixIcon: Icon(icon, color: _corAcai.withOpacity(0.7)),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _corAcai, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red[200]!),
      ),
    );
  }
}
