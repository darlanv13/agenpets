import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class EquipeView extends StatefulWidget {
  @override
  _EquipeViewState createState() => _EquipeViewState();
}

class _EquipeViewState extends State<EquipeView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // --- PALETA DE CORES ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF5F7FA);

  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();

  var maskCpf = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  // Estados dos Checkboxes
  bool fazBanho = true;
  bool fazTosa = false;
  bool fazVendas = false; // <--- NOVA FUNÇÃO

  void _cadastrarFuncionario() async {
    if (_nomeController.text.isEmpty || _cpfController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Preencha nome e CPF"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    List<String> habs = [];
    if (fazBanho) habs.add('banho');
    if (fazTosa) habs.add('tosa');
    if (fazVendas) habs.add('vendedor'); // <--- SALVA NO BANCO

    if (habs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Selecione ao menos uma função"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _db.collection('profissionais').add({
      'nome': _nomeController.text,
      'cpf': _cpfController.text,
      'habilidades': habs,
      'ativo': true,
      'peso_prioridade': 5,
      'criado_em': FieldValue.serverTimestamp(),
    });

    _nomeController.clear();
    _cpfController.clear();
    // Reseta opções para padrão
    setState(() {
      fazBanho = true;
      fazTosa = false;
      fazVendas = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Profissional cadastrado com sucesso! 🚀"),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Column(
        children: [
          // --- HEADER ---
          Container(
            padding: EdgeInsets.symmetric(vertical: 25, horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _corLilas,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.people_alt_rounded,
                    color: _corAcai,
                    size: 28,
                  ),
                ),
                SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Gestão de Equipe",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _corAcai,
                      ),
                    ),
                    Text(
                      "Cadastre e gerencie seus profissionais",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- CONTEÚDO ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- COLUNA DA ESQUERDA: FORMULÁRIO (Fixa ou Flex) ---
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Container(
                        padding: EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Novo Colaborador",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 20),

                            _buildTextField(
                              _nomeController,
                              "Nome Completo",
                              Icons.person,
                            ),
                            SizedBox(height: 15),
                            _buildTextField(
                              _cpfController,
                              "CPF (Login)",
                              Icons.badge,
                              formatter: maskCpf,
                            ),

                            SizedBox(height: 25),
                            Text(
                              "Funções e Habilidades",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 10),

                            // SELETORES DE FUNÇÃO
                            _buildRoleSelector(
                              "Banhista",
                              FontAwesomeIcons.shower,
                              fazBanho,
                              (v) => setState(() => fazBanho = v),
                            ),
                            SizedBox(height: 10),
                            _buildRoleSelector(
                              "Tosador",
                              FontAwesomeIcons.scissors,
                              fazTosa,
                              (v) => setState(() => fazTosa = v),
                            ),
                            SizedBox(height: 10),
                            _buildRoleSelector(
                              "Vendedor",
                              FontAwesomeIcons.cashRegister,
                              fazVendas,
                              (v) => setState(() => fazVendas = v),
                            ), // <--- NOVO

                            SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.add_circle),
                                label: Text("CADASTRAR MEMBRO"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _corAcai,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 5,
                                ),
                                onPressed: _cadastrarFuncionario,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 30),

                  // --- COLUNA DA DIREITA: LISTA ---
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Equipe Ativa",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Icon(Icons.filter_list, color: Colors.grey[400]),
                            ],
                          ),
                          SizedBox(height: 20),

                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: _db
                                  .collection('profissionais')
                                  .where('ativo', isEqualTo: true)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return Center(
                                    child: CircularProgressIndicator(),
                                  );
                                final docs = snapshot.data!.docs;

                                if (docs.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.group_off,
                                          size: 50,
                                          color: Colors.grey[300],
                                        ),
                                        Text(
                                          "Nenhum profissional ativo.",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 30,
                                    color: Colors.grey[100],
                                  ),
                                  itemBuilder: (ctx, index) {
                                    final doc = docs[index];
                                    final data = doc.data() as Map;
                                    final List<dynamic> skills =
                                        data['habilidades'] ?? [];

                                    return Row(
                                      children: [
                                        // Avatar com Iniciais
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: _corLilas,
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              (data['nome'] as String)
                                                      .isNotEmpty
                                                  ? data['nome'][0]
                                                        .toUpperCase()
                                                  : "?",
                                              style: TextStyle(
                                                color: _corAcai,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 15),

                                        // Infos
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                data['nome'],
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.grey[800],
                                                ),
                                              ),
                                              SizedBox(height: 5),
                                              Text(
                                                "CPF: ${data['cpf']}",
                                                style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 12,
                                                ),
                                              ),
                                              SizedBox(height: 8),

                                              // Badges de Habilidades
                                              Wrap(
                                                spacing: 5,
                                                children: skills
                                                    .map(
                                                      (skill) =>
                                                          _buildSkillBadge(
                                                            skill.toString(),
                                                          ),
                                                    )
                                                    .toList(),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Ações
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: Colors.red[300],
                                          ),
                                          tooltip: "Desativar",
                                          onPressed: () =>
                                              _confirmarExclusao(doc),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    MaskTextInputFormatter? formatter,
  }) {
    return TextField(
      controller: ctrl,
      inputFormatters: formatter != null ? [formatter] : [],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _corAcai, size: 20),
        filled: true,
        fillColor: _corFundo,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildRoleSelector(
    String label,
    IconData icon,
    bool isSelected,
    Function(bool) onChanged,
  ) {
    return InkWell(
      onTap: () => onChanged(!isSelected),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _corAcai.withOpacity(0.1) : Colors.white,
          border: Border.all(color: isSelected ? _corAcai : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? _corAcai : Colors.grey),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? _corAcai : Colors.grey[700],
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: _corAcai, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillBadge(String skill) {
    Color bg;
    Color text;
    String label;
    IconData icon;

    switch (skill) {
      case 'banho':
        bg = Colors.blue[50]!;
        text = Colors.blue[800]!;
        label = "Banhista";
        icon = FontAwesomeIcons.shower;
        break;
      case 'tosa':
        bg = Colors.orange[50]!;
        text = Colors.orange[800]!;
        label = "Tosador";
        icon = FontAwesomeIcons.scissors;
        break;
      case 'vendedor': // <--- COR PARA VENDEDOR
        bg = Colors.green[50]!;
        text = Colors.green[800]!;
        label = "Vendas";
        icon = FontAwesomeIcons.cashRegister;
        break;
      default:
        bg = Colors.grey[200]!;
        text = Colors.grey[800]!;
        label = skill;
        icon = Icons.circle;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: text),
          SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarExclusao(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Desativar Profissional?"),
        content: Text("Ele não aparecerá mais na lista de agendamentos."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              doc.reference.update({'ativo': false});
              Navigator.pop(ctx);
            },
            child: Text("Desativar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
