import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ServicosExtrasTab extends StatefulWidget {
  @override
  _ServicosExtrasTabState createState() => _ServicosExtrasTabState();
}

class _ServicosExtrasTabState extends State<ServicosExtrasTab> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Cores do Tema
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _corFundo,
      padding: EdgeInsets.all(30),
      child: Column(
        children: [
          // Cabeçalho
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Catálogo de Serviços",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _corAcai,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Itens avulsos para adicionar aos pacotes ou vendas",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.add_circle_outline, size: 20),
                label: Text("NOVO SERVIÇO"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  padding: EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () => _abrirEditorServico(context),
              ),
            ],
          ),
          SizedBox(height: 30),

          // Grid de Serviços
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('servicos_extras').snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: _corAcai),
                  );
                }

                final docs = snap.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.playlist_add,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 15),
                        Text(
                          "Nenhum serviço cadastrado.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300, // Largura do Card
                    childAspectRatio: 1.2, // Proporção
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) => _buildServiceCard(docs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- CARD DO SERVIÇO ---
  Widget _buildServiceCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String nome = data['nome'] ?? 'Serviço';
    double preco = (data['preco'] ?? 0).toDouble();

    // Ícone inteligente baseado no nome
    IconData icon = Icons.cleaning_services;
    Color corIcone = Colors.blue;

    if (nome.toLowerCase().contains('taxi')) {
      icon = FontAwesomeIcons.taxi;
      corIcone = Colors.orange;
    } else if (nome.toLowerCase().contains('unha')) {
      icon = FontAwesomeIcons.scissors;
      corIcone = Colors.purple;
    } else if (nome.toLowerCase().contains('hidrat')) {
      icon = FontAwesomeIcons.droplet;
      corIcone = Colors.cyan;
    } else if (nome.toLowerCase().contains('vacina')) {
      icon = FontAwesomeIcons.syringe;
      corIcone = Colors.red;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: corIcone.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: FaIcon(icon, color: corIcone, size: 28),
                ),
                SizedBox(height: 15),
                Text(
                  nome,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 5),
                Text(
                  "R\$ ${preco.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
          // Rodapé Ações
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[100]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(Icons.edit, size: 16, color: Colors.grey),
                    label: Text("Editar", style: TextStyle(color: Colors.grey)),
                    onPressed: () =>
                        _abrirEditorServico(context, docId: doc.id, data: data),
                  ),
                ),
                Container(width: 1, height: 20, color: Colors.grey[200]),
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.red[300],
                    ),
                    label: Text(
                      "Excluir",
                      style: TextStyle(color: Colors.red[300]),
                    ),
                    onPressed: () => _confirmarExclusao(doc),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- EDITOR DE SERVIÇO (MODAL) ---
  void _abrirEditorServico(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? data,
  }) {
    final _nomeCtrl = TextEditingController(text: data?['nome']);
    final _precoCtrl = TextEditingController(text: data?['preco']?.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFFFAFAFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 400, // Largura fixa e compacta
          padding: EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _corAcai.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      docId == null ? Icons.add : Icons.edit,
                      color: _corAcai,
                    ),
                  ),
                  SizedBox(width: 15),
                  Text(
                    docId == null ? "Novo Serviço" : "Editar Serviço",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _corAcai,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 25),

              _inputLabel("Nome do Serviço"),
              TextField(
                controller: _nomeCtrl,
                decoration: InputDecoration(
                  hintText: "Ex: Taxi Dog (km)",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
              SizedBox(height: 20),

              _inputLabel("Preço Unitário (R\$)"),
              TextField(
                controller: _precoCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: "0.00",
                  prefixIcon: Icon(Icons.attach_money, size: 18),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),

              SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      "Cancelar",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _corAcai,
                      padding: EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      if (_nomeCtrl.text.isEmpty || _precoCtrl.text.isEmpty) {
                        return;
                      }

                      double preco =
                          double.tryParse(
                            _precoCtrl.text.replaceAll(',', '.'),
                          ) ??
                          0.0;

                      final payload = {'nome': _nomeCtrl.text, 'preco': preco};

                      if (docId == null) {
                        await _db.collection('servicos_extras').add(payload);
                      } else {
                        await _db
                            .collection('servicos_extras')
                            .doc(docId)
                            .update(payload);
                      }

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Serviço salvo!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    child: Text(
                      "SALVAR",
                      style: TextStyle(
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
      ),
    );
  }

  void _confirmarExclusao(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Excluir Serviço?"),
        content: Text(
          "Tem certeza que deseja remover este item? Ele não aparecerá mais nas opções.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(ctx);
            },
            child: Text(
              "Confirmar",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: Colors.grey[700],
      ),
    ),
  );
}
