import 'package:agenpet/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CadastroRapidoDialog extends StatefulWidget {
  final String? cpfInicial;

  const CadastroRapidoDialog({super.key, this.cpfInicial});

  @override
  _CadastroRapidoDialogState createState() => _CadastroRapidoDialogState();
}

class _CadastroRapidoDialogState extends State<CadastroRapidoDialog> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Cores
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFFAFAFA);

  // Controladores
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _telController = TextEditingController();

  // Pet Inicial
  final _petNomeController = TextEditingController();
  final _petRacaController = TextEditingController();
  String _tipoPet = 'cao';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.cpfInicial != null) {
      _cpfController.text = widget.cpfInicial!;
    }
  }

  Future<void> _salvarCadastro() async {
    // Validação de campos vazios
    if (_nomeController.text.isEmpty ||
        _cpfController.text.isEmpty ||
        _petNomeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Preencha Nome, CPF e Nome do Pet.")),
      );
      return;
    }

    String cpfLimpo = _cpfController.text.replaceAll(RegExp(r'[^0-9]'), '');
    // --- VALIDAÇÃO DE CPF AQUI ---
    if (!Validators.isCpfValido(cpfLimpo)) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text("CPF Inválido"),
          content: Text("O CPF informado não é válido."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text("Corrigir"),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Salva Usuário
      await _db.collection('users').doc(cpfLimpo).set({
        'cpf': cpfLimpo,
        'nome': _nomeController.text.trim(),
        'telefone': _telController.text.trim(),
        'criado_em': FieldValue.serverTimestamp(),
        'origem': 'cadastro_rapido_admin',
        'assinante_ativo': false,
      }, SetOptions(merge: true));

      // 2. Salva Pet Inicial
      DocumentReference petRef = await _db
          .collection('users')
          .doc(cpfLimpo)
          .collection('pets')
          .add({
            'nome': _petNomeController.text.trim(),
            'raca': _petRacaController.text.isEmpty
                ? 'SRD'
                : _petRacaController.text.trim(),
            'tipo': _tipoPet,
            'donoCpf': cpfLimpo,
            'criado_em': FieldValue.serverTimestamp(),
          });

      // 3. Retorna os dados para quem chamou (para já selecionar automático)
      Navigator.pop(context, {
        'sucesso': true,
        'cpf': cpfLimpo,
        'nome_cliente': _nomeController.text.trim(),
        'pet_novo': {
          'id': petRef.id,
          'nome': _petNomeController.text.trim(),
          'tipo': _tipoPet,
          'raca': _petRacaController.text.trim(),
        },
      });
    } catch (e) {
      setState(() => _isLoading = false);
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text("Erro ao Salvar"),
          content: Text("Detalhes: $e"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text("OK")),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _corAcai,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_add, color: Colors.white),
                  SizedBox(width: 15),
                  Text(
                    "Cadastro Rápido",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("1. Dados do Tutor"),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _cpfController,
                            "CPF",
                            Icons.badge,
                            isNumber: true,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            _telController,
                            "WhatsApp",
                            Icons.phone,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    _buildTextField(
                      _nomeController,
                      "Nome Completo",
                      Icons.person,
                    ),

                    Divider(height: 30),

                    _buildSectionTitle("2. Dados do Pet Inicial"),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            _petNomeController,
                            "Nome do Pet",
                            FontAwesomeIcons.paw,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            _petRacaController,
                            "Raça",
                            Icons.pets,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    Row(
                      children: [
                        Text(
                          "Tipo de Animal:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(width: 15),
                        _buildRadioTipo('cao', "Cão", FontAwesomeIcons.dog),
                        SizedBox(width: 15),
                        _buildRadioTipo('gato', "Gato", FontAwesomeIcons.cat),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer Buttons
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancelar",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isLoading ? null : _salvarCadastro,
                    icon: _isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(Icons.check, color: Colors.white),
                    label: Text(
                      "SALVAR E USAR",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(color: _corAcai, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildRadioTipo(String valor, String label, IconData icon) {
    bool isSelected = _tipoPet == valor;
    return GestureDetector(
      onTap: () => setState(() => _tipoPet = valor),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _corAcai.withOpacity(0.1) : Colors.white,
          border: Border.all(color: isSelected ? _corAcai : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? _corAcai : Colors.grey),
            SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _corAcai : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
