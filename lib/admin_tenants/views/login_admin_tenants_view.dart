import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginAdminTenantsView extends StatefulWidget {
  @override
  _LoginAdminTenantsViewState createState() => _LoginAdminTenantsViewState();
}

class _LoginAdminTenantsViewState extends State<LoginAdminTenantsView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'agenpets');

  bool _isLoading = false;
  bool _isObscure = true;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnack("Preencha todos os campos.", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Authenticate
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Verify Super Admin Access (Optional but recommended)
      // For now, we assume any authenticated user here is valid,
      // OR we can check a 'super_admins' collection.
      final superAdminDoc = await _db.collection('super_admins').doc(userCred.user!.uid).get();

      // If you don't have this collection yet, you can comment this block out
      // or manually add your UID to Firestore 'super_admins' collection.
      /*
      if (!superAdminDoc.exists) {
        await _auth.signOut();
        _showSnack("Acesso negado. Usuário não é Super Admin.", Colors.red);
        setState(() => _isLoading = false);
        return;
      }
      */

      // Success - Navigation is handled by AuthWrapper in main
    } on FirebaseAuthException catch (e) {
      String msg = "Erro desconhecido";
      if (e.code == 'user-not-found') msg = "Usuário não encontrado.";
      if (e.code == 'wrong-password') msg = "Senha incorreta.";
      if (e.code == 'invalid-email') msg = "E-mail inválido.";
      _showSnack(msg, Colors.red);
    } catch (e) {
      _showSnack("Erro ao realizar login: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(maxWidth: 400),
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.shieldHalved,
                    color: Colors.blue[900],
                    size: 40,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "Acesso Super Admin",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                Text(
                  "Gestão de Tenants",
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 30),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "E-mail",
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    labelText: "Senha",
                    prefixIcon: Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "ENTRAR",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
