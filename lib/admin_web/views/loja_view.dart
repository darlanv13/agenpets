import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LojaView extends StatefulWidget {
  final bool isMaster;

  const LojaView({Key? key, this.isMaster = false}) : super(key: key);

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
  double _valorRecebido = 0.0;

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
              hintText: "Buscar produto por nome, código ou marca...",
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
        if (widget.isMaster) ...[
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

        // Filtro local
        if (_filtroBusca.isNotEmpty) {
          docs = docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String nome = (data['nome'] ?? '').toString().toLowerCase();
            String codigo = (data['codigo_barras'] ?? '').toString();
            String marca = (data['marca'] ?? '').toString().toLowerCase();
            String busca = _filtroBusca.toLowerCase();
            return nome.contains(busca) ||
                codigo.contains(busca) ||
                marca.contains(busca);
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

        // Identificar Mais Vendido
        String bestSellerId = '';
        int maxVendas = -1;
        for (var doc in docs) {
          var data = doc.data() as Map<String, dynamic>;
          int vendas = (data['qtd_vendida'] ?? 0);
          if (vendas > maxVendas) {
            maxVendas = vendas;
            bestSellerId = doc.id;
          }
        }
        // Se ninguém vendeu nada, não destaca
        if (maxVendas <= 0) bestSellerId = '';

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            childAspectRatio: 0.75, // Card mais alto para caber marca/codigo
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
          ),
          itemCount: docs.length,
          itemBuilder: (ctx, i) =>
              _buildProductCard(docs[i], docs[i].id == bestSellerId),
        );
      },
    );
  }

  Widget _buildProductCard(DocumentSnapshot doc, bool isBestSeller) {
    final data = doc.data() as Map<String, dynamic>;
    String nome = data['nome'] ?? 'Produto';
    String marca = data['marca'] ?? '';
    double preco = (data['preco'] ?? 0).toDouble();
    int estoque = (data['qtd_estoque'] ?? 0);

    return InkWell(
      onTap: estoque > 0 ? () => _addToCart(doc.id, data) : null,
      borderRadius: BorderRadius.circular(15),
      child: Stack(
        children: [
          Container(
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
              border: isBestSeller
                  ? Border.all(color: Colors.amber, width: 2)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isBestSeller
                          ? Colors.amber.withOpacity(0.1)
                          : _corAcai.withOpacity(0.05),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                    ),
                    child: Center(
                      // Ícone de Mercado Personalizado
                      child: FaIcon(
                        FontAwesomeIcons.store, // Ícone de mercadinho/loja
                        size: 40,
                        color: isBestSeller
                            ? Colors.amber[800]
                            : _corAcai.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (marca.isNotEmpty)
                        Text(
                          marca.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                      SizedBox(height: 5),
                      Text(
                        estoque > 0 ? "Estoque: $estoque" : "Sem Estoque",
                        style: TextStyle(
                          fontSize: 10,
                          color: estoque > 0 ? Colors.grey[600] : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "R\$ ${preco.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: _corAcai,
                            ),
                          ),
                          if (estoque > 0)
                            Icon(Icons.add_circle, color: _corAcai, size: 24)
                          else
                            Icon(Icons.block, color: Colors.grey, size: 24),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isBestSeller)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      FontAwesomeIcons.trophy,
                      size: 10,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4),
                    Text(
                      "Mais Vendido",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  // --- LÓGICA DO CARRINHO ---

  void _addToCart(String id, Map<String, dynamic> data) {
    int estoque = (data['qtd_estoque'] ?? 0);
    int noCarrinho = 0;

    int index = _carrinho.indexWhere((item) => item['id'] == id);
    if (index >= 0) {
      noCarrinho = _carrinho[index]['qtd'];
    }

    if (noCarrinho + 1 > estoque) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Estoque insuficiente! Apenas $estoque itens."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
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

  double get _troco =>
      _valorRecebido > _totalCart ? _valorRecebido - _totalCart : 0.0;

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
        SizedBox(height: 15),

        // Seletor de Pagamento
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
          onChanged: (v) {
            setState(() {
              _metodoPagamento = v!;
              _valorRecebido = 0; // Resetar valor recebido se mudar método
            });
          },
        ),

        // Campo de Valor Recebido (Apenas se Dinheiro)
        if (_metodoPagamento == 'Dinheiro') ...[
          SizedBox(height: 15),
          TextField(
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "Valor Recebido (R\$)",
              prefixIcon: Icon(Icons.money, color: Colors.green),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _valorRecebido =
                    double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
              });
            },
          ),
          if (_valorRecebido > 0) ...[
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Troco:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  "R\$ ${_troco.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _troco >= 0 ? Colors.green : Colors.red,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ],

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
      WriteBatch batch = _db.batch();

      // 1. Salvar venda no Firestore
      var vendaRef = _db.collection('vendas').doc();
      batch.set(vendaRef, {
        'itens': _carrinho,
        'valor_total': _totalCart,
        'valor_recebido': _valorRecebido,
        'troco': _troco,
        'metodo_pagamento': _metodoPagamento,
        'data_venda': FieldValue.serverTimestamp(),
        'status': 'concluido',
      });

      // 2. Atualizar contagem de vendas nos produtos
      for (var item in _carrinho) {
        var prodRef = _db.collection('produtos').doc(item['id']);
        batch.update(prodRef, {
          'qtd_vendida': FieldValue.increment(item['qtd']),
          'qtd_estoque': FieldValue.increment(-item['qtd']),
        });
      }

      await batch.commit();

      if (!mounted) return;

      // Limpar carrinho
      setState(() {
        _carrinho.clear();
        _metodoPagamento = 'Dinheiro';
        _valorRecebido = 0.0;
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
    // Controladores
    final _nomeCtrl = TextEditingController();
    final _marcaCtrl = TextEditingController();
    final _codigoCtrl = TextEditingController();
    final _custoCtrl = TextEditingController();
    final _margemCtrl = TextEditingController();
    final _precoCtrl = TextEditingController(); // Preço Final
    final _estoqueCtrl = TextEditingController(text: '0');

    void _calcularPrecoFinal() {
      double custo =
          double.tryParse(_custoCtrl.text.replaceAll(',', '.')) ?? 0.0;
      double margem =
          double.tryParse(_margemCtrl.text.replaceAll(',', '.')) ?? 0.0;

      if (custo > 0) {
        double lucro = custo * (margem / 100);
        double finalPrice = custo + lucro;
        _precoCtrl.text = finalPrice.toStringAsFixed(2);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Cadastrar Novo Produto"),
        content: Container(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _marcaCtrl,
                        decoration: InputDecoration(
                          labelText: "Marca",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: TextField(
                        controller: _codigoCtrl,
                        decoration: InputDecoration(
                          labelText: "Cód. Barras",
                          prefixIcon: Icon(FontAwesomeIcons.barcode, size: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _custoCtrl,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: "Preço Custo (R\$)",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (_) => _calcularPrecoFinal(),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: TextField(
                        controller: _margemCtrl,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: "Lucro (%)",
                          suffixText: "%",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (_) => _calcularPrecoFinal(),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _estoqueCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Estoque Inicial",
                          prefixIcon: Icon(Icons.inventory_2, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: TextField(
                        controller: _precoCtrl,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: "Preço Final (R\$)",
                          prefixIcon: Icon(Icons.attach_money, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.green[50],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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

              double custo =
                  double.tryParse(_custoCtrl.text.replaceAll(',', '.')) ?? 0.0;
              double margem =
                  double.tryParse(_margemCtrl.text.replaceAll(',', '.')) ?? 0.0;
              double preco =
                  double.tryParse(_precoCtrl.text.replaceAll(',', '.')) ?? 0.0;
              int estoque = int.tryParse(_estoqueCtrl.text) ?? 0;

              await _db.collection('produtos').add({
                'nome': _nomeCtrl.text,
                'marca': _marcaCtrl.text,
                'codigo_barras': _codigoCtrl.text,
                'preco_custo': custo,
                'margem_lucro': margem,
                'preco': preco, // Preço Final de Venda
                'qtd_vendida': 0, // Inicializa contador
                'qtd_estoque': estoque,
                'criado_em': FieldValue.serverTimestamp(),
              });
              if (!context.mounted) return;
              Navigator.pop(ctx);
            },
            child: Text("Salvar Produto"),
          ),
        ],
      ),
    );
  }
}
