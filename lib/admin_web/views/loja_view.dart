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

  // Vendedor
  TextEditingController _vendedorCodeCtrl = TextEditingController();

  // Busca
  String _filtroBusca = '';
  TextEditingController _searchCtrl = TextEditingController();

  // Paginação
  int _paginaAtual = 0;
  final int _itensPorPagina = 8; // Reduzido para caber a lista embaixo

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Row(
        children: [
          // ESQUERDA: PRODUTOS (CIMA) + LISTA SELECIONADOS (BAIXO)
          Expanded(
            flex: 3,
            child: Container(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // CABEÇALHO BUSCA
                  _buildHeader(),
                  SizedBox(height: 10),

                  // GRID DE PRODUTOS
                  Expanded(
                    flex: 5,
                    child: _buildProductGridWithPagination(),
                  ),

                  Divider(height: 20, thickness: 2),

                  // LISTA DE ITENS SELECIONADOS (Agora aqui embaixo)
                  Container(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      "ITENS NO CARRINHO",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 12, letterSpacing: 1),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: _buildCartList(),
                  ),
                ],
              ),
            ),
          ),

          // DIREITA: PDV / CHECKOUT (CONTROLES)
          Expanded(
            flex: 1, // Area lateral compacta e focada em valores
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
                   // TOTAL DESTAQUE
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _corAcai,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: _corAcai.withOpacity(0.4), blurRadius: 10, offset: Offset(0, 5))]
                    ),
                    child: Column(
                      children: [
                        Text("TOTAL A PAGAR", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        SizedBox(height: 5),
                        Text(
                          "R\$ ${_totalCart.toStringAsFixed(2)}",
                          style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // VENDEDOR
                  TextField(
                    controller: _vendedorCodeCtrl,
                    decoration: InputDecoration(
                      labelText: "Cód. Vendedor",
                      prefixIcon: Icon(Icons.badge, size: 20, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 0),
                    ),
                  ),

                  SizedBox(height: 20),
                  Divider(),
                  SizedBox(height: 10),

                  // RESUMO PAGAMENTO
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
    return Container(
      padding: EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]
      ),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: (val) {
           setState(() {
             _filtroBusca = val;
             _paginaAtual = 0;
           });
        },
        decoration: InputDecoration(
          hintText: "LEITOR DE CÓDIGO DE BARRAS (F1)",
          hintStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(Icons.qr_code_scanner, color: _corAcai),
          suffixIcon: IconButton(icon: Icon(Icons.clear), onPressed: () {
            setState(() {
              _searchCtrl.clear();
              _filtroBusca = '';
            });
          }),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildProductGridWithPagination() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('produtos').orderBy('nome').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator(color: _corAcai));

        var docs = snapshot.data!.docs;

        // FILTRAGEM
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
                Icon(FontAwesomeIcons.boxOpen, size: 30, color: Colors.grey[300]),
                Text("Nada encontrado.", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        // PAGINAÇÃO
        int totalItens = docs.length;
        int totalPaginas = (totalItens / _itensPorPagina).ceil();
        if (_paginaAtual >= totalPaginas) _paginaAtual = 0;

        int start = _paginaAtual * _itensPorPagina;
        int end = start + _itensPorPagina;
        if (end > totalItens) end = totalItens;

        var paginatedDocs = docs.sublist(start, end);

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
        if (maxVendas <= 0) bestSellerId = '';

        return Column(
          children: [
            // GRID
            Expanded(
              child: GridView.builder(
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220, // Um pouco maior já que tem mais espaço na esquerda
                  childAspectRatio: 1.2, // Mais "wide"
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: paginatedDocs.length,
                itemBuilder: (ctx, i) =>
                  _buildProductCard(paginatedDocs[i], paginatedDocs[i].id == bestSellerId),
              ),
            ),

            // PAGINAÇÃO COMPACTA
            if (totalPaginas > 1)
            Container(
              height: 30,
              margin: EdgeInsets.only(top: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, size: 20),
                    padding: EdgeInsets.zero,
                    onPressed: _paginaAtual > 0 ? () => setState(() => _paginaAtual--) : null,
                  ),
                  Text("${_paginaAtual + 1}/$totalPaginas", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.chevron_right, size: 20),
                    padding: EdgeInsets.zero,
                    onPressed: _paginaAtual < totalPaginas - 1 ? () => setState(() => _paginaAtual++) : null,
                  ),
                ],
              ),
            )
          ],
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
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 2, offset: Offset(0, 1)),
              ],
              border: isBestSeller ? Border.all(color: Colors.amber, width: 2) : null,
            ),
            child: Row(
              children: [
                // Icone
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isBestSeller ? Colors.amber.withOpacity(0.1) : _corAcai.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.store,
                      size: 20,
                      color: isBestSeller ? Colors.amber[800] : _corAcai.withOpacity(0.5),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       if (marca.isNotEmpty)
                          Text(marca.toUpperCase(), style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                       Text(nome, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[800]), maxLines: 2, overflow: TextOverflow.ellipsis),
                       SizedBox(height: 2),
                       Text("R\$ ${preco.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _corAcai)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isBestSeller)
            Positioned(
              top: 5,
              right: 5,
              child: Icon(FontAwesomeIcons.trophy, size: 10, color: Colors.amber[800]),
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

    setState(() {
      _pagamentos.add({
        'metodo': _metodoSelecionado,
        'valor': valor
      });
      _valorPagamentoCtrl.clear();
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
        child: Text("O carrinho está vazio.", style: TextStyle(color: Colors.grey[400])),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!)
      ),
      child: Column(
        children: [
          // Header da Tabela
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text("PRODUTO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(flex: 2, child: Text("QTD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(flex: 2, child: Text("UNIT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text("TOTAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey), textAlign: TextAlign.right)),
              ],
            ),
          ),
          Divider(height: 1),
          // Lista
          Expanded(
            child: ListView.separated(
              itemCount: _carrinho.length,
              separatorBuilder: (ctx, i) => Divider(height: 1),
              itemBuilder: (ctx, i) {
                final item = _carrinho[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(item['nome'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            InkWell(onTap: () => _updateQtd(i, -1), child: Icon(Icons.remove_circle_outline, size: 16, color: Colors.grey)),
                            SizedBox(width: 5),
                            Text("${item['qtd']}", style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(width: 5),
                            InkWell(onTap: () => _updateQtd(i, 1), child: Icon(Icons.add_circle_outline, size: 16, color: _corAcai)),
                          ],
                        )
                      ),
                      Expanded(
                        flex: 2,
                        child: Text("R\$ ${item['preco'].toStringAsFixed(2)}", textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.grey[600]))
                      ),
                      Expanded(
                        flex: 2,
                        child: Text("R\$ ${(item['preco'] * item['qtd']).toStringAsFixed(2)}", textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutSection() {
    return Expanded(
      child: Column(
        children: [
          // PAGAMENTO INFO
          _buildRowTotal("Pago", _totalPago, color: Colors.green[700]),
          _buildRowTotal("Restante", _restante, color: Colors.red[700], isBold: true),
          if (_troco > 0)
            _buildRowTotal("Troco", _troco, color: Colors.blue[700], isBold: true),

          SizedBox(height: 10),

          // INPUT PAGAMENTO COMPACTO
          if (_restante > 0 || _pagamentos.isEmpty)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 40,
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _metodoSelecionado,
                      isExpanded: true,
                      style: TextStyle(fontSize: 12, color: Colors.black),
                      items: ['Dinheiro', 'Pix', 'Cartão', 'Outro']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => _metodoSelecionado = v!),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 5),
              Expanded(
                flex: 4,
                child: Container(
                  height: 40,
                  child: TextField(
                    controller: _valorPagamentoCtrl,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "R\$",
                      contentPadding: EdgeInsets.only(top: 0, left: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (_) => _adicionarPagamento(),
                  ),
                ),
              ),
              SizedBox(width: 5),
              SizedBox(
                height: 40,
                width: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                  onPressed: _adicionarPagamento,
                  child: Icon(Icons.add, color: Colors.white, size: 20),
                ),
              )
            ],
          ),

          SizedBox(height: 10),

          // LISTA PAGAMENTOS MINI
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(5)),
              child: ListView.builder(
                padding: EdgeInsets.all(5),
                itemCount: _pagamentos.length,
                itemBuilder: (ctx, i) {
                  final pag = _pagamentos[i];
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${pag['metodo']}", style: TextStyle(fontSize: 11)),
                      Row(
                        children: [
                          Text("R\$ ${pag['valor'].toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          SizedBox(width: 5),
                          InkWell(onTap: () => _removerPagamento(i), child: Icon(Icons.close, size: 12, color: Colors.red))
                        ],
                      )
                    ],
                  );
                },
              ),
            ),
          ),

          SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _restante <= 0 ? _corAcai : Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: (_carrinho.isNotEmpty && _restante <= 0) ? _finalizarVenda : null,
              child: Text(
                "FINALIZAR",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _restante <= 0 ? Colors.white : Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowTotal(String label, double val, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            "R\$ ${val.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _finalizarVenda() async {
    if (_vendedorCodeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Informe o CÓDIGO DO VENDEDOR para finalizar.")));
      return;
    }

    try {
      WriteBatch batch = _db.batch();

      var vendaRef = _db.collection('vendas').doc();
      batch.set(vendaRef, {
        'itens': _carrinho,
        'valor_total': _totalCart,
        'pagamentos': _pagamentos,
        'troco': _troco,
        'vendedor_codigo': _vendedorCodeCtrl.text, // Salva o vendedor
        'data_venda': FieldValue.serverTimestamp(),
        'status': 'concluido',
      });

      for (var item in _carrinho) {
        var prodRef = _db.collection('produtos').doc(item['id']);
        batch.update(prodRef, {
          'qtd_vendida': FieldValue.increment(item['qtd']),
        });
      }

      await batch.commit();

      setState(() {
        _carrinho.clear();
        _pagamentos.clear();
        _metodoSelecionado = 'Dinheiro';
        _valorPagamentoCtrl.clear();
        _searchCtrl.clear();
        _filtroBusca = '';
        // _vendedorCodeCtrl.clear(); // Opcional: Manter o vendedor para a proxima venda? Melhor limpar por segurança.
        _vendedorCodeCtrl.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("VENDA REALIZADA COM SUCESSO!"),
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
}
