import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agenpet/config/app_config.dart';

class SelecaoLojaScreen extends StatefulWidget {
  const SelecaoLojaScreen({super.key});

  @override
  State<SelecaoLojaScreen> createState() => _SelecaoLojaScreenState();
}

class _SelecaoLojaScreenState extends State<SelecaoLojaScreen> {
  final _cnpjController = TextEditingController();
  final _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  var maskCnpj = MaskTextInputFormatter(
    mask: '##.###.###/####-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool _isLoading = false;

  Future<void> _verificarLoja() async {
    final cnpjUnmasked = maskCnpj.getUnmaskedText();
    final cnpjVisual =
        _cnpjController.text; // Mantém a máscara para a próxima tela

    if (cnpjUnmasked.length < 14) {
      _showSnack("CNPJ inválido.", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _functions.httpsCallable('verificarLoja').call({
        'cnpj': cnpjUnmasked,
      });

      if (result.data == null) throw Exception("Retorno inválido.");
      final data = result.data as Map;
      final tenantId = data['tenantId'];
      final nomeLoja = data['nome'];

      if (tenantId == null || nomeLoja == null) {
        throw Exception("Dados incompletos da loja.");
      }

      // Salva em Cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tenantId', tenantId);
      await prefs.setString('nomeLoja', nomeLoja);

      // Atualiza Config
      AppConfig.setTenantId(tenantId);

      if (mounted) {
        // Vai para Login Profissional (já configurado)
        Navigator.pushReplacementNamed(
          context,
          '/login_profissional',
          arguments: {'cnpj_empresa': cnpjVisual},
        );
      }
    } catch (e) {
      String msg = "Loja não encontrada.";
      if (e is FirebaseFunctionsException) {
        if (e.code == 'not-found') msg = "Loja não encontrada.";
        if (e.code == 'permission-denied') msg = "Esta loja está inativa.";
      } else {
        // Mostra erro real se não for da Cloud Function (ex: erro de parsing)
        msg = "Erro: $e";
      }
      _showSnack(msg, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(0xFF4A148C);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store_rounded, size: 80, color: primaryColor),
              SizedBox(height: 20),
              Text(
                "Acesso Profissional",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 10),
              Text(
                "Informe o CNPJ da loja onde você trabalha para continuar.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 40),
              TextField(
                controller: _cnpjController,
                inputFormatters: [maskCnpj],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "CNPJ da Empresa",
                  prefixIcon: Icon(Icons.business, color: primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verificarLoja,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "CONTINUAR",
                          style: TextStyle(fontWeight: FontWeight.bold),
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
