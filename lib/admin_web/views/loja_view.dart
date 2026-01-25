import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LojaView extends StatefulWidget {
  @override
  _LojaViewState createState() => _LojaViewState();
}

class _LojaViewState extends State<LojaView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

  // Carrinho
  List<Map<String, dynamic>> _carrinho = [];
  String _metodoPagamento = 'Dinheiro';

  // Busca
  String _filtroBusca = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Row(
        children: [
          // ESQUERDA: CATÁLOGO DE PRODUTOS
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHeader(),
                  SizedBox(height: 20),
                  Expanded(child: _buildProductGrid()),
                ],
              ),
            ),
          ),

          // DIREITA: CARRINHO / CAIXA
          Expanded(
            flex: 1,
            child: Container(
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(FontAwesomeIcons.cashRegister, color: _corAcai),
                      SizedBox(width: 10),
                      Text(
                        "Caixa / PDV",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _corAcai,
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 30),
                  Expanded(child: _buildCartList()),
                  Divider(height: 30),
                  _buildCheckoutSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (val) => setState(() => _filtroBusca = val),
            decoration: InputDecoration(
              hintText: "Buscar produto por nome...",
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(width: 15),
        ElevatedButton.icon(
          icon: Icon(Icons.add, size: 20),
          label: Text("NOVO PRODUTO"),
          style: ElevatedButton.styleFrom(
            backgroundColor: _corAcai,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          onPressed: () => _abrirEditorProduto(context),
        ),
      ],
    );
  }

  Widget _buildProductGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('produtos').orderBy('nome').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator(color: _corAcai));

        var docs = snapshot.data!.docs;

        // Filtro local (se o banco for pequeno)
        if (_filtroBusca.isNotEmpty) {
          docs = docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String nome = (data['nome'] ?? '').toString().toLowerCase();
            return nome.contains(_filtroBusca.toLowerCase());
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.boxOpen,
                  size: 50,
                  color: Colors.grey[300],
                ),
                SizedBox(height: 15),
                Text(
                  "Nenhum produto encontrado.",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 0.85,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
          ),
          itemCount: docs.length,
          itemBuilder: (ctx, i) => _buildProductCard(docs[i]),
        );
      },
    );
  }

  Widget _buildProductCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String nome = data['nome'] ?? 'Produto';
    double preco = (data['preco'] ?? 0).toDouble();

    return InkWell(
      onTap: () => _addToCart(doc.id, data),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _corAcai.withOpacity(0.05),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.box,
                    size: 35,
                    color: _corAcai.withOpacity(0.4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "R\$ ${preco.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: _corAcai,
                        ),
                      ),
                      Icon(Icons.add_circle, color: _corAcai, size: 24),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LÓGICA DO CARRINHO ---

  void _addToCart(String id, Map<String, dynamic> data) {
    setState(() {
      int index = _carrinho.indexWhere((item) => item['id'] == id);
      if (index >= 0) {
        _carrinho[index]['qtd']++;
      } else {
        _carrinho.add({
          'id': id,
          'nome': data['nome'],
          'preco': data['preco'],
          'qtd': 1,
        });
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _carrinho.removeAt(index);
    });
  }

  void _updateQtd(int index, int delta) {
    setState(() {
      _carrinho[index]['qtd'] += delta;
      if (_carrinho[index]['qtd'] <= 0) {
        _carrinho.removeAt(index);
      }
    });
  }

  double get _totalCart =>
      _carrinho.fold(0, (sum, item) => sum + (item['preco'] * item['qtd']));

  Widget _buildCartList() {
    if (_carrinho.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 50,
              color: Colors.grey[300],
            ),
            SizedBox(height: 10),
            Text("Carrinho vazio", style: TextStyle(color: Colors.grey)),
            Text(
              "Selecione produtos ao lado",
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _carrinho.length,
      itemBuilder: (ctx, i) {
        final item = _carrinho[i];
        return Container(
          margin: EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['nome'],
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Unit: R\$ ${item['preco'].toStringAsFixed(2)}",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () => _updateQtd(i, -1),
                    child: Icon(
                      Icons.remove_circle_outline,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    "${item['qtd']}",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 10),
                  InkWell(
                    onTap: () => _updateQtd(i, 1),
                    child: Icon(Icons.add_circle, color: _corAcai, size: 20),
                  ),
                ],
              ),
              SizedBox(width: 15),
              Text(
                "R\$ ${(item['preco'] * item['qtd']).toStringAsFixed(2)}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckoutSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Subtotal", style: TextStyle(color: Colors.grey)),
            Text(
              "R\$ ${_totalCart.toStringAsFixed(2)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: _metodoPagamento,
          decoration: InputDecoration(
            labelText: "Forma de Pagamento",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: EdgeInsets.symmetric(horizontal: 15),
          ),
          items: [
            'Dinheiro',
            'Pix',
            'Cartão',
            'Outro',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _metodoPagamento = v!),
        ),
        SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 5,
            ),
            onPressed: _carrinho.isEmpty ? null : _finalizarVenda,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline),
                SizedBox(width: 10),
                Text(
                  "FINALIZAR VENDA",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _finalizarVenda() async {
    try {
      // Salvar venda no Firestore
      await _db.collection('vendas').add({
        'itens': _carrinho,
        'valor_total': _totalCart,
        'metodo_pagamento': _metodoPagamento,
        'data_venda': FieldValue.serverTimestamp(),
        'status': 'concluido',
      });

      // Limpar carrinho
      setState(() {
        _carrinho.clear();
        _metodoPagamento = 'Dinheiro';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Venda registrada com sucesso!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao salvar venda: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- EDITOR DE PRODUTO (MODAL) ---
  void _abrirEditorProduto(BuildContext context) {
    final _nomeCtrl = TextEditingController();
    final _precoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Cadastrar Novo Produto"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nomeCtrl,
              decoration: InputDecoration(
                labelText: "Nome do Produto",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: _precoCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Preço (R\$)",
                prefixIcon: Icon(Icons.attach_money, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _corAcai,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              if (_nomeCtrl.text.isEmpty || _precoCtrl.text.isEmpty) return;

              double preco =
                  double.tryParse(_precoCtrl.text.replaceAll(',', '.')) ?? 0.0;

              await _db.collection('produtos').add({
                'nome': _nomeCtrl.text,
                'preco': preco,
                'criado_em': FieldValue.serverTimestamp(),
              });
              Navigator.pop(ctx);
            },
            child: Text("Salvar Produto"),
          ),
        ],
      ),
    );
  }
}
