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

  // Pagamentos Multiplos
  List<Map<String, dynamic>> _pagamentos = [];
  String _metodoSelecionado = 'Dinheiro';
  TextEditingController _valorPagamentoCtrl = TextEditingController();

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
        // BOTÃO REMOVIDO CONFORME SOLICITAÇÃO
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
          docs =
              docs.where((doc) {
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
          itemBuilder:
              (ctx, i) =>
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

    return InkWell(
      onTap: () => _addToCart(doc.id, data),
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
              border:
                  isBestSeller
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
                      color:
                          isBestSeller
                              ? Colors.amber.withOpacity(0.1)
                              : _corAcai.withOpacity(0.05),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                    ),
                    child: Center(
                      // Ícone de Mercado Personalizado
                      child: FaIcon(
                        FontAwesomeIcons.store,
                        size: 40,
                        color:
                            isBestSeller
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
                          Icon(Icons.add_circle, color: _corAcai, size: 24),
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
                    Icon(FontAwesomeIcons.trophy, size: 10, color: Colors.white),
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

  // --- LÓGICA DE MÚLTIPLOS PAGAMENTOS ---

  double get _totalPago => _pagamentos.fold(0, (sum, item) => sum + item['valor']);

  double get _restante {
    double diff = _totalCart - _totalPago;
    return diff > 0 ? diff : 0.0;
  }

  double get _troco {
    return _totalPago > _totalCart ? _totalPago - _totalCart : 0.0;
  }

  void _adicionarPagamento() {
    double valor = double.tryParse(_valorPagamentoCtrl.text.replaceAll(',', '.')) ?? 0.0;

    if (valor <= 0) return;

    // Se não tiver mais restante a pagar e não for para dar troco, evita?
    // Permitir adicionar mesmo que passe o total, para cálculo de troco (ex: Pagar 100 em dinheiro pra conta de 80)

    setState(() {
      _pagamentos.add({
        'metodo': _metodoSelecionado,
        'valor': valor
      });
      _valorPagamentoCtrl.clear();

      // Auto-selecionar 'Dinheiro' se restante for > 0? Não, mantem o ultimo ou reseta.
    });
  }

  void _removerPagamento(int index) {
    setState(() {
      _pagamentos.removeAt(index);
    });
  }

  Widget _buildCartList() {
    if (_carrinho.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket_outlined, size: 50, color: Colors.grey[300]),
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
                    child: Icon(
                      Icons.add_circle,
                      color: _corAcai,
                      size: 20,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 15),
              Text(
                "R\$ ${(item['preco'] * item['qtd']).toStringAsFixed(2)}",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckoutSection() {
    // Se o carrinho estiver vazio, não mostra muita coisa ou desabilita
    if (_carrinho.isEmpty) return SizedBox.shrink();

    return Container(
      height: 350, // Altura fixa para caber a rolagem dos pagamentos se precisar
      child: Column(
        children: [
          // TOTAIS
          _buildRowTotal("Total a Pagar", _totalCart, isBold: true),
          _buildRowTotal("Total Pago", _totalPago, color: Colors.green[700]),
          _buildRowTotal("Restante", _restante, color: Colors.red[700]),
          _buildRowTotal("Troco", _troco, color: Colors.blue[700]),

          Divider(),

          // ÁREA DE ADICIONAR PAGAMENTO
          if (_restante > 0 || _pagamentos.isEmpty)
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _metodoSelecionado,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: ['Dinheiro', 'Pix', 'Cartão', 'Outro']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _metodoSelecionado = v!),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _valorPagamentoCtrl,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: "R\$",
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onSubmitted: (_) => _adicionarPagamento(),
                ),
              ),
              SizedBox(width: 10),
              IconButton(
                onPressed: _adicionarPagamento,
                icon: Icon(Icons.add_circle, color: Colors.green),
                tooltip: "Adicionar",
              )
            ],
          ),

          SizedBox(height: 10),

          // LISTA DE PAGAMENTOS ADICIONADOS
          Expanded(
            child: ListView.builder(
              itemCount: _pagamentos.length,
              itemBuilder: (ctx, i) {
                final pag = _pagamentos[i];
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 2),
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${pag['metodo']}", style: TextStyle(fontSize: 12)),
                      Row(
                        children: [
                          Text("R\$ ${pag['valor'].toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          SizedBox(width: 10),
                          InkWell(
                            onTap: () => _removerPagamento(i),
                            child: Icon(Icons.close, size: 14, color: Colors.red),
                          )
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 10),

          // BOTÃO FINALIZAR
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _restante <= 0 ? Colors.green : Colors.grey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 5,
              ),
              onPressed: (_carrinho.isNotEmpty && _restante <= 0) ? _finalizarVenda : null,
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
      ),
    );
  }

  Widget _buildRowTotal(String label, double val, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            "R\$ ${val.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
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
        'pagamentos': _pagamentos, // Salva a lista de pagamentos
        'troco': _troco,
        'data_venda': FieldValue.serverTimestamp(),
        'status': 'concluido',
      });

      // 2. Atualizar contagem de vendas nos produtos
      for (var item in _carrinho) {
        var prodRef = _db.collection('produtos').doc(item['id']);
        batch.update(prodRef, {
          'qtd_vendida': FieldValue.increment(item['qtd']),
        });
      }

      await batch.commit();

      // Limpar carrinho e pagamentos
      setState(() {
        _carrinho.clear();
        _pagamentos.clear();
        _metodoSelecionado = 'Dinheiro';
        _valorPagamentoCtrl.clear();
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

  // --- EDITOR DE PRODUTO REMOVIDO DA UI MAS MANTIDO NO CÓDIGO SE PRECISAR REATIVAR ---
  void _abrirEditorProduto(BuildContext context) {
    // ... Código mantido mas não acessível via botão
  }
}
