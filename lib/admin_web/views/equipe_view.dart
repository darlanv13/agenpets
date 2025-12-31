import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class EquipeView extends StatefulWidget {
  @override
  _EquipeViewState createState() => _EquipeViewState();
}

class _EquipeViewState extends State<EquipeView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Cores
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);

  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  var maskCpf = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );
  bool fazBanho = true;
  bool fazTosa = false;

  void _cadastrarFuncionario() async {
    if (_nomeController.text.isEmpty || _cpfController.text.isEmpty) return;

    List<String> habs = [];
    if (fazBanho) habs.add('banho');
    if (fazTosa) habs.add('tosa');

    await _db.collection('profissionais').add({
      'nome': _nomeController.text,
      'cpf': _cpfController.text,
      'habilidades': habs,
      'ativo': true,
      'peso_prioridade': 5,
    });

    _nomeController.clear();
    _cpfController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Profissional cadastrado!")));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _corLilas,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.people, color: _corAcai, size: 30),
            ),
            SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Gestão de Equipe",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _corAcai,
                  ),
                ),
                Text(
                  "Cadastre e gerencie seus profissionais",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 40),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CARD DE CADASTRO ---
            Expanded(
              flex: 2,
              child: Container(
                padding: EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Novo Cadastro",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _corAcai,
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _nomeController,
                      decoration: InputDecoration(
                        labelText: "Nome Completo",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person, color: _corAcai),
                      ),
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: _cpfController,
                      inputFormatters: [maskCpf],
                      decoration: InputDecoration(
                        labelText: "CPF (Login)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge, color: _corAcai),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Funções:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Checkbox(
                          activeColor: _corAcai,
                          value: fazBanho,
                          onChanged: (v) => setState(() => fazBanho = v!),
                        ),
                        Text("Banhista"),
                        SizedBox(width: 20),
                        Checkbox(
                          activeColor: _corAcai,
                          value: fazTosa,
                          onChanged: (v) => setState(() => fazTosa = v!),
                        ),
                        Text("Tosador"),
                      ],
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _corAcai,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _cadastrarFuncionario,
                        child: Text("CADASTRAR PROFISSIONAL"),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(width: 30),

            // --- LISTA DE FUNCIONÁRIOS ---
            Expanded(
              flex: 3,
              child: Container(
                padding: EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Equipe Ativa",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _corAcai,
                      ),
                    ),
                    SizedBox(height: 15),
                    StreamBuilder<QuerySnapshot>(
                      stream: _db
                          .collection('profissionais')
                          .where('ativo', isEqualTo: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return Center(child: CircularProgressIndicator());
                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: snapshot.data!.docs.length,
                          separatorBuilder: (_, __) => Divider(),
                          itemBuilder: (ctx, index) {
                            final doc = snapshot.data!.docs[index];
                            final data = doc.data() as Map;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _corLilas,
                                child: Text(
                                  data['nome'][0],
                                  style: TextStyle(
                                    color: _corAcai,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                data['nome'],
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                "CPF: ${data['cpf']} • ${data['habilidades'].join(', ')}",
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => doc.reference.update({
                                  'ativo': false,
                                }), // Soft delete
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
