import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/config/app_config.dart';

class PdvView extends StatefulWidget {
  final bool isMaster;

  const PdvView({super.key, this.isMaster = false});

  @override
  _PdvViewState createState() => _PdvViewState();
}

class _PdvViewState extends State<PdvView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

  // Carrinho
  final List<Map<String, dynamic>> _carrinho = [];
  final ScrollController _cartScrollCtrl = ScrollController();

  // Pagamentos Multiplos
  final List<Map<String, dynamic>> _pagamentos = [];
  String _metodoSelecionado = 'Dinheiro';
  final TextEditingController _valorPagamentoCtrl = TextEditingController();

  // Vendedor
  final TextEditingController _vendedorCodeCtrl = TextEditingController();

  // Busca e Foco
  String _filtroBusca = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // Paginação
  final int _itensPorPagina = 4;

  @override
  void initState() {
    super.initState();
    // Garante foco inicial no campo de busca
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _cartScrollCtrl.dispose();
    _valorPagamentoCtrl.dispose();
    _vendedorCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Row(
        children: [
          // ESQUERDA: PRODUTOS + LISTA
          Expanded(
            flex: 3,
            child: Container(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // CABEÇALHO BUSCA (SCANNER)
                  _buildHeader(),
                  SizedBox(height: 10),

                  // GRID DE PRODUTOS (AREA MAIOR PARA OS CARDS)
                  Expanded(flex: 4, child: _buildProductGridWithPagination()),

                  Divider(height: 20, thickness: 2),

                  Container(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "ITENS NO CARRINHO",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          "${_carrinho.length} itens",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // LISTA DE CARRINHO
                  Expanded(flex: 3, child: _buildCartList()),
                ],
              ),
            ),
          ),

          // DIREITA: PDV / CHECKOUT (AUMENTADO)
          Expanded(
            flex: 2,
            child: Container(
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.all(25),
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
                  // TOTAL DESTAQUE GIGANTE
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_corAcai, Color(0xFF6A1B9A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _corAcai.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "TOTAL A PAGAR",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "R\$ ${_totalCart.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 50,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30),

                  // VENDEDOR MAIOR
                  TextField(
                    controller: _vendedorCodeCtrl,
                    style: TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: "CÓDIGO DO VENDEDOR",
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.badge,
                        size: 28,
                        color: Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
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
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _corAcai.withValues(alpha: 0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus, // Controle de Foco
        textInputAction: TextInputAction.go, // Botão de ação "Ir"
        onChanged: (val) {
          setState(() => _filtroBusca = val);
        },
        onSubmitted: (val) => _handleScanSubmit(val),
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: "ESCANEIE O CÓDIGO DE BARRAS...",
          hintStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[400],
            fontSize: 16,
          ),
          prefixIcon: Icon(Icons.qr_code_scanner, color: _corAcai, size: 30),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _searchCtrl.clear();
                _filtroBusca = '';
                _searchFocus.requestFocus();
              });
            },
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  // Lógica "Scan & Add"
  Future<void> _handleScanSubmit(String value) async {
    if (value.isEmpty) {
      _searchFocus.requestFocus();
      return;
    }

    try {
      // 1. Tenta buscar por Código de Barras Exato
      var queryBarra = await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('produtos')
          .where('codigo_barras', isEqualTo: value)
          .limit(1)
          .get();

      if (queryBarra.docs.isNotEmpty) {
        var doc = queryBarra.docs.first;
        _addToCart(doc.id, doc.data());
        _clearAndRefocus();
        return;
      }

      // 2. Se não achou, tenta por Nome Exato (caso digite)
      // Nota: Firestore é Case Sensitive por padrão. Para busca robusta por nome, o ideal é o Grid.
      // Mas "Enter" deve ser ação rápida.

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Produto não encontrado pelo código: $value"),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );

      // Mantém o texto para correção, mas seleciona tudo para facilitar redigitar
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      _searchFocus.requestFocus();
    } catch (e) {
      print("Erro ao buscar: $e");
    }
  }

  void _clearAndRefocus() {
    setState(() {
      _searchCtrl.clear();
      _filtroBusca = '';
    });
    _searchFocus.requestFocus();
  }

  Widget _buildProductGridWithPagination() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('produtos')
          .orderBy('nome')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: _corAcai));
        }

        var docs = snapshot.data!.docs;

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
                  size: 40,
                  color: Colors.grey[300],
                ),
                Text(
                  "Nada encontrado.",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        // LIMITA A 4 ITENS INICIAIS COMO SOLICITADO
        var displayDocs = docs.take(_itensPorPagina).toList();

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
            Expanded(
              child: GridView.builder(
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 por linha
                  childAspectRatio: 2.9, // Cards largos
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                ),
                itemCount: displayDocs.length,
                itemBuilder: (ctx, i) => _buildProductCard(
                  displayDocs[i],
                  displayDocs[i].id == bestSellerId,
                ),
              ),
            ),
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
      onTap: () {
        _addToCart(doc.id, data);
        _clearAndRefocus(); // Ao clicar, também limpa a busca para nova ação
      },
      borderRadius: BorderRadius.circular(15),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
              border: isBestSeller
                  ? Border.all(color: Colors.amber, width: 3)
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isBestSeller
                        ? Colors.amber.withOpacity(0.1)
                        : _corAcai.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.store,
                      size: 35,
                      color: isBestSeller
                          ? Colors.amber[800]
                          : _corAcai.withOpacity(0.5),
                    ),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (marca.isNotEmpty)
                        Text(
                          marca.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        nome,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.grey[800],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 5),
                      Text(
                        "R\$ ${preco.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: _corAcai,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.add_circle,
                  size: 35,
                  color: _corAcai.withOpacity(0.8),
                ),
              ],
            ),
          ),
          if (isBestSeller)
            Positioned(
              top: 10,
              right: 10,
              child: Icon(
                FontAwesomeIcons.trophy,
                size: 16,
                color: Colors.amber[800],
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
        // Scroll to bottom when new item added
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_cartScrollCtrl.hasClients) {
            _cartScrollCtrl.animateTo(
              _cartScrollCtrl.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
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

  double get _totalPago =>
      _pagamentos.fold(0, (sum, item) => sum + item['valor']);

  double get _restante {
    double diff = _totalCart - _totalPago;
    return diff > 0 ? diff : 0.0;
  }

  double get _troco {
    return _totalPago > _totalCart ? _totalPago - _totalCart : 0.0;
  }

  void _adicionarPagamento() {
    double valor =
        double.tryParse(_valorPagamentoCtrl.text.replaceAll(',', '.')) ?? 0.0;

    if (valor <= 0) return;

    setState(() {
      _pagamentos.add({'metodo': _metodoSelecionado, 'valor': valor});
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 40,
              color: Colors.grey[300],
            ),
            Text(
              "Aguardando produtos...",
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    "PRODUTO",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "QTD",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "TOTAL",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: ListView.separated(
              controller: _cartScrollCtrl,
              itemCount: _carrinho.length,
              separatorBuilder: (ctx, i) => Divider(height: 1),
              itemBuilder: (ctx, i) {
                final item = _carrinho[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          item['nome'],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () => _updateQtd(i, -1),
                              child: Icon(
                                Icons.remove_circle_outline,
                                size: 20,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              "${item['qtd']}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(width: 8),
                            InkWell(
                              onTap: () => _updateQtd(i, 1),
                              child: Icon(
                                Icons.add_circle_outline,
                                size: 20,
                                color: _corAcai,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "R\$ ${(item['preco'] * item['qtd']).toStringAsFixed(2)}",
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
          // PAGAMENTO INFO MAIOR
          _buildRowTotal(
            "Pago",
            _totalPago,
            color: Colors.green[700],
            fontSize: 16,
          ),
          _buildRowTotal(
            "Restante",
            _restante,
            color: Colors.red[700],
            isBold: true,
            fontSize: 20,
          ),
          if (_troco > 0)
            _buildRowTotal(
              "Troco",
              _troco,
              color: Colors.blue[700],
              isBold: true,
              fontSize: 20,
            ),

          SizedBox(height: 20),

          // INPUT PAGAMENTO
          if (_restante > 0 || _pagamentos.isEmpty)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 50,
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _metodoSelecionado,
                        isExpanded: true,
                        style: TextStyle(fontSize: 16, color: Colors.black),
                        items: ['Dinheiro', 'Pix', 'Cartão', 'Outro']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _metodoSelecionado = v!),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 50,
                    child: TextField(
                      controller: _valorPagamentoCtrl,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(fontSize: 18),
                      decoration: InputDecoration(
                        hintText: "R\$",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onSubmitted: (_) => _adicionarPagamento(),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  width: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _adicionarPagamento,
                    child: Icon(Icons.add, color: Colors.white, size: 30),
                  ),
                ),
              ],
            ),

          SizedBox(height: 15),

          // LISTA PAGAMENTOS MINI
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.builder(
                padding: EdgeInsets.all(10),
                itemCount: _pagamentos.length,
                itemBuilder: (ctx, i) {
                  final pag = _pagamentos[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "• ${pag['metodo']}",
                          style: TextStyle(fontSize: 14),
                        ),
                        Row(
                          children: [
                            Text(
                              "R\$ ${pag['valor'].toStringAsFixed(2)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 10),
                            InkWell(
                              onTap: () => _removerPagamento(i),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _restante <= 0 ? _corAcai : Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 8,
              ),
              onPressed: (_carrinho.isNotEmpty && _restante <= 0)
                  ? _finalizarVenda
                  : null,
              child: Text(
                "FINALIZAR VENDA",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: _restante <= 0 ? Colors.white : Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowTotal(
    String label,
    double val, {
    Color? color,
    bool isBold = false,
    double fontSize = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "R\$ ${val.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _finalizarVenda() async {
    if (_vendedorCodeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Informe o CÓDIGO DO VENDEDOR.")));
      return;
    }

    try {
      WriteBatch batch = _db.batch();

      var vendaRef = _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('vendas')
          .doc();
      batch.set(vendaRef, {
        'itens': _carrinho,
        'valor_total': _totalCart,
        'pagamentos': _pagamentos,
        'troco': _troco,
        'vendedor_codigo': _vendedorCodeCtrl.text,
        'data_venda': FieldValue.serverTimestamp(),
        'status': 'concluido',
      });

      for (var item in _carrinho) {
        var prodRef = _db
            .collection('tenants')
            .doc(AppConfig.tenantId)
            .collection('produtos')
            .doc(item['id']);
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
        _vendedorCodeCtrl.clear();
      });
      _searchFocus.requestFocus();

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
