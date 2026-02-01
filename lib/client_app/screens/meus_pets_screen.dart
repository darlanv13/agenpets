import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MeusPetsScreen extends StatefulWidget {
  const MeusPetsScreen({super.key});

  @override
  _MeusPetsScreenState createState() => _MeusPetsScreenState();
}

class _MeusPetsScreenState extends State<MeusPetsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Cores do Tema (Mantendo consistência)
  final Color _corAcai = Color(0xFF4A148C);
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
            fontSize: 18,
          ),
        ),
        backgroundColor: _corAcai,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormularioPet(context),
        backgroundColor: _corAcai,
        elevation: 4,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          "Novo Pet",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('users')
            .doc(_userCpf)
            .collection('pets')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _corAcai));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 80),
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

  // --- WIDGETS DE UI ---

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: FaIcon(
              FontAwesomeIcons.paw,
              size: 60,
              color: Colors.grey[300],
            ),
          ),
          SizedBox(height: 20),
          Text(
            "Nenhum pet encontrado",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _corAcai,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Adicione seu melhor amigo para começar!",
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCard(String petId, Map<String, dynamic> data) {
    bool isDog = data['tipo'] == 'cao';
    bool isMale = data['sexo'] == 'Macho'; // Novo campo

    IconData icon = isDog ? FontAwesomeIcons.dog : FontAwesomeIcons.cat;
    // Cores baseadas no tipo (azul para cão, laranja para gato - ou customizável)
    Color themeColor = isDog ? Colors.blue : Colors.orange;

    String raca = data['raca'] ?? 'SRD';
    String nome = data['nome'] ?? 'Sem Nome';

    // Cálculo de idade
    String idadeStr = "";
    if (data['data_nascimento'] != null) {
      DateTime nasc = (data['data_nascimento'] as Timestamp).toDate();
      final now = DateTime.now();
      int anos = now.year - nasc.year;
      if (now.month < nasc.month ||
          (now.month == nasc.month && now.day < nasc.day)) {
        anos--;
      }
      idadeStr = anos == 0 ? "Menos de 1 ano" : "$anos anos";
    }

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () =>
              _abrirFormularioPet(context, petId: petId, dadosAtuais: data),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Avatar do Pet
                Hero(
                  tag: petId,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: FaIcon(icon, color: themeColor, size: 35),
                    ),
                  ),
                ),
                SizedBox(width: 20),

                // Informações
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              nome,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (data['sexo'] != null)
                            Icon(
                              isMale ? Icons.male : Icons.female,
                              size: 18,
                              color: isMale ? Colors.blue : Colors.pink,
                            ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        raca,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (idadeStr.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            idadeStr,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: themeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Ícone de Seta/Editar
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey[300],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- FORMULÁRIO MODERNO (BOTTOM SHEET) ---

  void _abrirFormularioPet(
    BuildContext rootContext, {
    String? petId,
    Map<String, dynamic>? dadosAtuais,
  }) {
    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController(
      text: dadosAtuais?['nome'] ?? '',
    );
    final racaController = TextEditingController(
      text: dadosAtuais?['raca'] ?? '',
    );
    final pesoController = TextEditingController(
      text: dadosAtuais?['peso']?.toString() ?? '',
    );
    final obsController = TextEditingController(
      text: dadosAtuais?['observacoes'] ?? '',
    );
    final nascimentoController = TextEditingController();

    String tipoSelecionado = dadosAtuais?['tipo'] ?? 'cao';
    String sexoSelecionado = dadosAtuais?['sexo'] ?? 'Macho';
    DateTime? dataNascimento;

    if (dadosAtuais?['data_nascimento'] != null) {
      dataNascimento = (dadosAtuais!['data_nascimento'] as Timestamp).toDate();
      nascimentoController.text = DateFormat(
        'dd/MM/yyyy',
      ).format(dataNascimento);
    }

    bool isEditing = petId != null;
    bool isLoading = false;

    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                // Header do Modal
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[100]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        isEditing ? "Editar Pet" : "Adicionar Pet",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _corAcai,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[100],
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Conteúdo Scrollável
                Expanded(
                  child: Form(
                    key: formKey,
                    child: ListView(
                      padding: EdgeInsets.all(24),
                      physics: BouncingScrollPhysics(),
                      children: [
                        // Seção Tipo
                        Text(
                          "O que seu pet é?",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 15),
                        Row(
                          children: [
                            _buildTypeCard(
                              "Cão",
                              FontAwesomeIcons.dog,
                              'cao',
                              tipoSelecionado,
                              setStateModal,
                              (v) => tipoSelecionado = v,
                            ),
                            SizedBox(width: 15),
                            _buildTypeCard(
                              "Gato",
                              FontAwesomeIcons.cat,
                              'gato',
                              tipoSelecionado,
                              setStateModal,
                              (v) => tipoSelecionado = v,
                            ),
                          ],
                        ),

                        SizedBox(height: 30),

                        // Inputs Principais
                        _buildLabel("Nome do Pet *"),
                        TextFormField(
                          controller: nomeController,
                          style: GoogleFonts.poppins(),
                          decoration: _buildInputDecoration(
                            "Ex: Thor",
                            Icons.pets,
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Nome obrigatório' : null,
                        ),
                        SizedBox(height: 20),

                        _buildLabel("Sexo"),
                        Row(
                          children: [
                            _buildGenderOption(
                              "Macho",
                              Icons.male,
                              sexoSelecionado,
                              setStateModal,
                              (v) => sexoSelecionado = v,
                            ),
                            SizedBox(width: 15),
                            _buildGenderOption(
                              "Fêmea",
                              Icons.female,
                              sexoSelecionado,
                              setStateModal,
                              (v) => sexoSelecionado = v,
                            ),
                          ],
                        ),
                        SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel("Raça"),
                                  TextFormField(
                                    controller: racaController,
                                    decoration: _buildInputDecoration(
                                      "Opcional",
                                      Icons.category,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 15),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel("Peso (kg)"),
                                  TextFormField(
                                    controller: pesoController,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: _buildInputDecoration(
                                      "0.0",
                                      Icons.monitor_weight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),

                        _buildLabel("Data de Nascimento"),
                        TextFormField(
                          controller: nascimentoController,
                          readOnly: true,
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: dataNascimento ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: _corAcai,
                                      onPrimary: Colors.white,
                                      onSurface: Colors.black,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              dataNascimento = picked;
                              nascimentoController.text = DateFormat(
                                'dd/MM/yyyy',
                              ).format(picked);
                            }
                          },
                          decoration: _buildInputDecoration(
                            "Selecione a data",
                            Icons.calendar_today,
                          ),
                        ),

                        SizedBox(height: 20),

                        _buildLabel("Observações (Alergias, medos...)"),
                        TextFormField(
                          controller: obsController,
                          maxLines: 3,
                          decoration: _buildInputDecoration(
                            "Digite aqui...",
                            Icons.note,
                          ),
                        ),

                        if (isEditing) ...[
                          SizedBox(height: 20),
                          Center(
                            child: TextButton.icon(
                              onPressed: () {
                                _confirmarExclusao(
                                  rootContext,
                                  petId,
                                  dadosAtuais!['nome'],
                                );
                              },
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              label: Text(
                                "Excluir este pet",
                                style: GoogleFonts.poppins(color: Colors.red),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),

                // Botão de Ação
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (formKey.currentState!.validate()) {
                                setStateModal(() => isLoading = true);

                                Map<String, dynamic> petData = {
                                  'nome': nomeController.text.trim(),
                                  'tipo': tipoSelecionado,
                                  'sexo': sexoSelecionado,
                                  'raca': racaController.text.isEmpty
                                      ? 'SRD'
                                      : racaController.text.trim(),
                                  'peso': double.tryParse(
                                    pesoController.text.replaceAll(',', '.'),
                                  ),
                                  'observacoes': obsController.text.trim(),
                                  'data_nascimento': dataNascimento != null
                                      ? Timestamp.fromDate(dataNascimento!)
                                      : null,
                                  'donoCpf': _userCpf,
                                  'updated_at': FieldValue.serverTimestamp(),
                                };

                                try {
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

                                  Navigator.pop(context); // Fecha modal
                                  ScaffoldMessenger.of(
                                    rootContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isEditing
                                            ? "Pet atualizado!"
                                            : "Pet cadastrado!",
                                      ),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } catch (e) {
                                  setStateModal(() => isLoading = false);
                                  ScaffoldMessenger.of(
                                    rootContext,
                                  ).showSnackBar(
                                    SnackBar(content: Text("Erro: $e")),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _corAcai,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              "SALVAR",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGETS AUXILIARES DO FORM ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          color: Colors.grey[800],
          fontSize: 14,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
      filled: true,
      fillColor: Colors.grey[50],
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
        borderSide: BorderSide(color: _corAcai),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildTypeCard(
    String label,
    IconData icon,
    String value,
    String groupValue,
    StateSetter setState,
    Function(String) onChanged,
  ) {
    bool isSelected = value == groupValue;
    Color color = value == 'cao' ? Colors.blue : Colors.orange;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => onChanged(value)),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Colors.grey[200]!,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              FaIcon(icon, size: 30, color: isSelected ? color : Colors.grey),
              SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderOption(
    String label,
    IconData icon,
    String groupValue,
    StateSetter setState,
    Function(String) onChanged,
  ) {
    bool isSelected = label == groupValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => onChanged(label)),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _corAcai : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _corAcai : Colors.grey[300]!,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarExclusao(
    BuildContext context,
    String petId,
    String nomePet,
  ) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Excluir $nomePet?"),
        content: Text("Essa ação é irreversível."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close modal
              await _db
                  .collection('users')
                  .doc(_userCpf)
                  .collection('pets')
                  .doc(petId)
                  .delete();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Excluir", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
