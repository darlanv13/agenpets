import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart';
import 'package:agenpet/config/app_config.dart';

class FastClientRegistrationDialog extends StatefulWidget {
  final String? initialCpf;
  const FastClientRegistrationDialog({super.key, this.initialCpf});

  @override
  State<FastClientRegistrationDialog> createState() => _FastClientRegistrationDialogState();
}

class _FastClientRegistrationDialogState extends State<FastClientRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _celularCtrl = TextEditingController();

  final _maskCpf = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final _maskCel = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCpf != null) {
      _cpfCtrl.text = widget.initialCpf!;
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final db = FirebaseFirestore.instance;

    try {
      final cpfUnmasked = _maskCpf.getUnmaskedText();
      final celularUnmasked = _maskCel.getUnmaskedText();
      final nome = _nomeCtrl.text.trim();
      final cpfFormatado = _maskCpf.getMaskedText();

      // Use CPF as Document ID for quick lookups
      final docRef = db.collection('users').doc(cpfUnmasked);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Este CPF já possui cadastro."), backgroundColor: Colors.orange),
          );
          // Return existing data so user can proceed
          Navigator.pop(context, docSnapshot.data());
        }
        return;
      }

      // Create new user document
      final userData = {
        'uid': cpfUnmasked,
        'cpf': cpfFormatado, // Save formatted for display consistency
        'nome': nome,
        'celular': celularUnmasked,
        'email': '$cpfUnmasked@agenpets.temp', // Placeholder email
        'created_at': FieldValue.serverTimestamp(),
        'origem': 'cadastro_rapido_vet',
        'tenantId': AppConfig.tenantId, // Link to current tenant
      };

      await docRef.set(userData);

      if (mounted) {
        Navigator.pop(context, userData);
      }
    } catch (e) {
      debugPrint("Error saving user: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao cadastrar: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Cadastro Rápido de Tutor"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(
                  labelText: "Nome Completo",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person)
                ),
                validator: (v) => v == null || v.isEmpty ? "Nome é obrigatório" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _cpfCtrl,
                inputFormatters: [_maskCpf],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "CPF",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge)
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return "CPF é obrigatório";
                  if (!CPFValidator.isValid(v)) return "CPF Inválido";
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _celularCtrl,
                inputFormatters: [_maskCel],
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Celular / WhatsApp",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone)
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Celular é obrigatório";
                  if (v.length < 15) return "Número incompleto";
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _salvar,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A148C),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("CADASTRAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
