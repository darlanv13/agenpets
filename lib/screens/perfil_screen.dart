import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PerfilScreen extends StatefulWidget {
  @override
  _PerfilScreenState createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Controllers apenas para o que é editável
  final _enderecoController = TextEditingController();
  final _nascimentoController = TextEditingController();

  // Variáveis de estado para leitura
  String _nomeUser = "Carregando...";
  String? _cpfUser;
  bool _isLoading = true;

  var maskData = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cpfUser == null) {
      final args = ModalRoute.of(context)!.settings.arguments as Map;
      _cpfUser = args['cpf'];
      _carregarDados();
    }
  }

  Future<void> _carregarDados() async {
    try {
      final doc = await _db.collection('users').doc(_cpfUser).get();
      final data = doc.data() as Map<String, dynamic>;

      setState(() {
        _nomeUser = data['nome'] ?? 'Cliente AgenPet';
        _enderecoController.text = data['endereco'] ?? '';
        _nascimentoController.text = data['nascimento'] ?? '';
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao carregar perfil")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarDados() async {
    setState(() => _isLoading = true);
    try {
      await _db.collection('users').doc(_cpfUser).update({
        'endereco': _enderecoController.text,
        'nascimento': _nascimentoController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Perfil atualizado!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Fundo leve
      appBar: AppBar(
        title: Text("Editar Perfil"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black, // Ícone de voltar preto
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 20),

                  // --- SEÇÃO DE IDENTIDADE (CABEÇALHO) ---
                  Center(
                    child: Column(
                      children: [
                        // Avatar com botão de editar
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.2),
                                  width: 4,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 65,
                                backgroundColor: Colors.blue[50],
                                child: FaIcon(
                                  FontAwesomeIcons.user,
                                  size: 50,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                                child: FaIcon(
                                  FontAwesomeIcons.camera,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),

                        // Nome Grande
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _nomeUser,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),

                        SizedBox(height: 8),

                        // CPF Badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "CPF: $_cpfUser",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 40),

                  // --- SEÇÃO DE FORMULÁRIO (CARD BRANCO) ---
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Informações Pessoais",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        SizedBox(height: 20),

                        // Data de Nascimento
                        _buildTextField(
                          controller: _nascimentoController,
                          label: "Data de Nascimento",
                          icon: FontAwesomeIcons.calendar,
                          mask: maskData,
                          keyboard: TextInputType.datetime,
                        ),

                        SizedBox(height: 20),

                        // Endereço
                        _buildTextField(
                          controller: _enderecoController,
                          label: "Endereço Completo",
                          icon: FontAwesomeIcons.locationDot,
                          keyboard: TextInputType.streetAddress,
                        ),

                        SizedBox(height: 40),

                        // Botão Salvar
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _salvarDados,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Text(
                              "SALVAR ALTERAÇÕES",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20), // Espaço extra para scroll
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputFormatter? mask,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      inputFormatters: mask != null ? [mask] : [],
      keyboardType: keyboard ?? TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12.0),
          child: FaIcon(icon, size: 20, color: Colors.blue[300]),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
      ),
    );
  }
}
