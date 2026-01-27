import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart'; // Sugestão: Adicione google_fonts ao pubspec.yaml para fontes melhores

class MeusPetsScreen extends StatefulWidget {
  @override
  _MeusPetsScreenState createState() => _MeusPetsScreenState();
}

class _MeusPetsScreenState extends State<MeusPetsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Cores do Tema
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corLilasEscuro = Color(0xFFCE93D8);
  final Color _corFundo = Color(0xFFF5F7FA);

  String? _userCpf;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null) _userCpf = args['cpf'];
      _init = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userCpf == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: _corAcai)),
      );
    }

    return Scaffold(
      backgroundColor: _corFundo,
      appBar: AppBar(
        title: Text(
          "Meus Pets",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: _corAcai,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormularioPet(context),
        backgroundColor: _corAcai,
        icon: Icon(Icons.add),
        label: Text(
          "Novo Pet",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('users')
            .doc(_userCpf)
            .collection('pets')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _corAcai));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildPetCard(doc.id, data);
            },
          );
        },
      ),
    );
  }

  // --- Widgets de UI ---

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(color: _corLilas, shape: BoxShape.circle),
            child: FaIcon(
              FontAwesomeIcons.paw,
              size: 60,
              color: _corAcai.withOpacity(0.6),
            ),
          ),
          SizedBox(height: 20),
          Text(
            "Nenhum pet por aqui ainda.",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 10),
          Text(
            "Clique no botão abaixo para adicionar\nseu melhor amigo!",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCard(String petId, Map<String, dynamic> data) {
    bool isDog = data['tipo'] == 'cao';
    IconData icon = isDog ? FontAwesomeIcons.dog : FontAwesomeIcons.cat;
    Color iconBgColor = isDog ? Colors.blue[50]! : Colors.orange[50]!;
    Color iconColor = isDog ? Colors.blue[800]! : Colors.orange[800]!;

    String raca = data['raca'] ?? 'SRD';
    String peso = data['peso'] != null ? "${data['peso']} kg" : "";
    String obs = data['observacoes'] ?? "";

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone do Pet
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: FaIcon(icon, color: iconColor, size: 30),
                ),
                SizedBox(width: 16),
                // Informações Principais
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['nome'] ?? 'Pet sem nome',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _corAcai,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "$raca ${peso.isNotEmpty ? '• $peso' : ''}",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (obs.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  obs,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(),
            // Botões de Ação (Editar / Excluir)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      _confirmarExclusao(context, petId, data['nome']),
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red[300],
                    size: 20,
                  ),
                  label: Text(
                    "Excluir",
                    style: GoogleFonts.poppins(color: Colors.red[300]),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _abrirFormularioPet(
                    context,
                    petId: petId,
                    dadosAtuais: data,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _corAcai,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  icon: Icon(Icons.edit, size: 18, color: Colors.white),
                  label: Text(
                    "Editar",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Funções Lógicas e Formulários ---

  Future<void> _confirmarExclusao(
    BuildContext context,
    String petId,
    String? nomePet,
  ) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Excluir Pet?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Tem certeza que deseja remover ${nomePet ?? 'este pet'}? Essa ação não pode ser desfeita.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancelar",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Fecha o diálogo
              await _db
                  .collection('users')
                  .doc(_userCpf)
                  .collection('pets')
                  .doc(petId)
                  .delete();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("$nomePet removido.")));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              "Sim, Excluir",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Formulário Moderno usando ModalBottomSheet
  void _abrirFormularioPet(
    BuildContext rootContext, {
    String? petId,
    Map<String, dynamic>? dadosAtuais,
  }) {
    final _formKey = GlobalKey<FormState>();
    final _nomeController = TextEditingController(
      text: dadosAtuais?['nome'] ?? '',
    );
    final _racaController = TextEditingController(
      text: dadosAtuais?['raca'] ?? '',
    );
    final _pesoController = TextEditingController(
      text: dadosAtuais?['peso']?.toString() ?? '',
    );
    final _obsController = TextEditingController(
      text: dadosAtuais?['observacoes'] ?? '',
    );
    String _tipoSelecionado = dadosAtuais?['tipo'] ?? 'cao';
    bool isEditing = petId != null;
    bool isLoading = false;

    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true, // Permite que o sheet suba com o teclado
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Container(
            height:
                MediaQuery.of(context).size.height * 0.85, // Ocupa 85% da tela
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: EdgeInsets.fromLTRB(
              24,
              30,
              24,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho do Modal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? "Editar Pet" : "Adicionar Novo Pet",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _corAcai,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  Divider(),
                  Expanded(
                    child: ListView(
                      physics: BouncingScrollPhysics(),
                      children: [
                        SizedBox(height: 20),
                        Text(
                          "Tipo de Pet",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            _buildRadioTipo(
                              'cao',
                              "Cão",
                              FontAwesomeIcons.dog,
                              _tipoSelecionado,
                              setStateModal,
                              (valor) => _tipoSelecionado = valor,
                            ),
                            SizedBox(width: 15),
                            _buildRadioTipo(
                              'gato',
                              "Gato",
                              FontAwesomeIcons.cat,
                              _tipoSelecionado,
                              setStateModal,
                              (valor) => _tipoSelecionado = valor,
                            ),
                          ],
                        ),
                        SizedBox(height: 25),

                        _buildTextFieldLabel("Nome do Pet *"),
                        TextFormField(
                          controller: _nomeController,
                          decoration: _inputDecoration("Ex: Rex, Luna..."),
                          validator: (value) =>
                              value!.isEmpty ? 'O nome é obrigatório' : null,
                        ),
                        SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTextFieldLabel("Raça (Opcional)"),
                                  TextFormField(
                                    controller: _racaController,
                                    decoration: _inputDecoration(
                                      "Ex: Poodle, SRD...",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 15),
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTextFieldLabel("Peso (kg)"),
                                  TextFormField(
                                    controller: _pesoController,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: _inputDecoration("Ex: 5.2"),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),

                        _buildTextFieldLabel(
                          "Observações / Alergias (Opcional)",
                        ),
                        TextFormField(
                          controller: _obsController,
                          maxLines: 3,
                          decoration: _inputDecoration(
                            "Ex: Alérgico a frango, tem medo de trovão...",
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  // Botão Salvar
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (_formKey.currentState!.validate()) {
                                setStateModal(() => isLoading = true);

                                Map<String, dynamic> petData = {
                                  'nome': _nomeController.text.trim(),
                                  'tipo': _tipoSelecionado,
                                  'raca': _racaController.text.isEmpty
                                      ? 'SRD'
                                      : _racaController.text.trim(),
                                  'peso': double.tryParse(
                                    _pesoController.text.replaceAll(',', '.'),
                                  ),
                                  'observacoes': _obsController.text.trim(),
                                  'donoCpf': _userCpf,
                                  'updated_at': FieldValue.serverTimestamp(),
                                };

                                if (isEditing) {
                                  await _db
                                      .collection('users')
                                      .doc(_userCpf)
                                      .collection('pets')
                                      .doc(petId)
                                      .update(petData);
                                } else {
                                  petData['created_at'] =
                                      FieldValue.serverTimestamp();
                                  await _db
                                      .collection('users')
                                      .doc(_userCpf)
                                      .collection('pets')
                                      .add(petData);
                                }

                                Navigator.pop(context); // Fecha o modal
                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isEditing
                                          ? "Pet atualizado!"
                                          : "Pet adicionado com sucesso!",
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _corAcai,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                      ),
                      child: isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              isEditing ? "SALVAR ALTERAÇÕES" : "CADASTRAR PET",
                              style: GoogleFonts.poppins(
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
          );
        },
      ),
    );
  }

  // --- Helpers de UI para o Formulário ---

  Widget _buildTextFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: _corAcai,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: _corFundo,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _corAcai, width: 2),
      ),
    );
  }

  Widget _buildRadioTipo(
    String valor,
    String label,
    IconData icon,
    String selecionado,
    StateSetter setStateModal,
    Function(String) onTipoChanged,
  ) {
    bool isSelected = selecionado == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setStateModal(() => onTipoChanged(valor)),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isSelected ? _corAcai : _corFundo,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected ? _corAcai : Colors.transparent,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _corAcai.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              FaIcon(
                icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 24,
              ),
              SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
