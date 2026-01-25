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
  TextEditingController _searchCtrl = TextEditingController();

  // Paginação
  int _paginaAtual = 0;
  final int _itensPorPagina = 12; // Ajuste conforme necessário

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Row(
        children: [
          // ESQUERDA: CATÁLOGO DE PRODUTOS
          Expanded(
            flex: 5, // Area menor que antes (era 2:1, agora 5:4)
            child: Container(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHeader(),
                  SizedBox(height: 10),
                  Expanded(child: _buildProductGridWithPagination()),
                ],
              ),
            ),
          ),

          // DIREITA: CARRINHO / CAIXA (PDV ROBUSTO)
          Expanded(
            flex: 4,
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
                  // CABEÇALHO PDV
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _corAcai.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)
                            ),
                            child: Icon(FontAwesomeIcons.cashRegister, color: _corAcai, size: 20)
                          ),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "PDV / CAIXA",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _corAcai,
                                  letterSpacing: 1.0
                                ),
                              ),
                              Text("Operação de Venda", style: TextStyle(fontSize: 12, color: Colors.grey))
                            ],
                          ),
                        ],
                      ),
                      if (_carrinho.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.delete_sweep, color: Colors.red[300]),
                          tooltip: "Limpar Carrinho",
                          onPressed: () {
                            setState(() {
                              _carrinho.clear();
                              _pagamentos.clear();
                            });
                          },
                        )
                    ],
                  ),
                  Divider(height: 30),

                  // LISTA DE ITENS
                  Expanded(child: _buildCartList()),

                  Divider(height: 30),

                  // CHECKOUT
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
        autofocus: true, // FOCO NO LEITOR DE CÓDIGO
        textInputAction: TextInputAction.search,
        onChanged: (val) {
           setState(() {
             _filtroBusca = val;
             _paginaAtual = 0; // Resetar paginação ao buscar
           });
        },
        onSubmitted: (val) {
          // Lógica para adicionar direto se encontrar match exato (comum em leitores)
          // Implementaremos isso dentro do StreamBuilder se possível ou aqui se tivéssemos a lista.
          // Como dependemos do stream, o ideal é o usuário ver e clicar, ou implementarmos uma busca assíncrona aqui.
          // Para simplificar: foca de volta.
          _searchCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _searchCtrl.text.length);
        },
        decoration: InputDecoration(
          hintText: "LEITOR DE CÓDIGO DE BARRAS / BUSCA (F1)",
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

            // Match exato de código para adicionar direto? (Opcional, mas robusto)
            /*
            if (codigo == _filtroBusca) {
               // Poderia adicionar auto
            }
            */

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
                Icon(FontAwesomeIcons.boxOpen, size: 50, color: Colors.grey[300]),
                SizedBox(height: 15),
                Text("Nenhum produto encontrado.", style: TextStyle(color: Colors.grey)),
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

        // Identificar Mais Vendido (Global ou Local? Global é melhor)
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
            // GRID (Sem Scroll na área de produtos, usa paginação)
            Expanded(
              child: GridView.builder(
                physics: NeverScrollableScrollPhysics(), // Evita rolagem interna
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160, // Cards menores
                  childAspectRatio: 0.8, // Mais quadrado/compacto
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: paginatedDocs.length,
                itemBuilder: (ctx, i) =>
                  _buildProductCard(paginatedDocs[i], paginatedDocs[i].id == bestSellerId),
              ),
            ),

            SizedBox(height: 10),

            // CONTROLES DE PAGINAÇÃO
            if (totalPaginas > 1)
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left),
                    onPressed: _paginaAtual > 0 ? () => setState(() => _paginaAtual--) : null,
                  ),
                  Text("Página ${_paginaAtual + 1} de $totalPaginas", style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.chevron_right),
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
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 2, offset: Offset(0, 1)),
              ],
              border: isBestSeller ? Border.all(color: Colors.amber, width: 2) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isBestSeller ? Colors.amber.withOpacity(0.1) : _corAcai.withOpacity(0.05),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Center(
                      child: FaIcon(
                        FontAwesomeIcons.store,
                        size: 25, // Icone menor
                        color: isBestSeller ? Colors.amber[800] : _corAcai.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (marca.isNotEmpty)
                              Text(marca.toUpperCase(), style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            Text(nome, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[800]), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                        Text("R\$ ${preco.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _corAcai)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isBestSeller)
            Positioned(
              top: 5,
              right: 5,
              child: Icon(FontAwesomeIcons.trophy, size: 12, color: Colors.amber[800]),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart, size: 60, color: Colors.grey[200]),
            SizedBox(height: 10),
            Text("CAIXA LIVRE", style: TextStyle(color: Colors.grey[400], fontSize: 18, fontWeight: FontWeight.bold)),
            Text("Passe os produtos", style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _carrinho.length,
      itemBuilder: (ctx, i) {
        final item = _carrinho[i];
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['nome'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text("Unit: R\$ ${item['preco'].toStringAsFixed(2)}", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(5)
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => _updateQtd(i, -1),
                      child: Padding(padding: EdgeInsets.all(5), child: Icon(Icons.remove, size: 16)),
                    ),
                    Text("${item['qtd']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    InkWell(
                      onTap: () => _updateQtd(i, 1),
                      child: Padding(padding: EdgeInsets.all(5), child: Icon(Icons.add, size: 16)),
                    ),
                  ],
                ),
              ),
              Container(
                width: 80,
                alignment: Alignment.centerRight,
                child: Text(
                  "R\$ ${(item['preco'] * item['qtd']).toStringAsFixed(2)}",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
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
      // Altura dinâmica ou flexível
      child: Column(
        children: [
          // TOTAIS GRANDES
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!)
            ),
            child: Column(
              children: [
                _buildRowTotal("Subtotal", _totalCart, fontSize: 16),
                Divider(),
                _buildRowTotal("Pago", _totalPago, color: Colors.green[700], fontSize: 16),
                _buildRowTotal("Restante", _restante, color: Colors.red[700], fontSize: 20, isBold: true),
                if (_troco > 0)
                  _buildRowTotal("Troco", _troco, color: Colors.blue[700], fontSize: 18, isBold: true),
              ],
            ),
          ),

          SizedBox(height: 15),

          // PAGAMENTOS
          if (_restante > 0 || _pagamentos.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Adicionar Pagamento", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 45,
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _metodoSelecionado,
                          isExpanded: true,
                          items: ['Dinheiro', 'Pix', 'Cartão', 'Outro']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (v) => setState(() => _metodoSelecionado = v!),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 45,
                      child: TextField(
                        controller: _valorPagamentoCtrl,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: "R\$ 0,00",
                          contentPadding: EdgeInsets.only(top: 5, left: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onSubmitted: (_) => _adicionarPagamento(),
                      ),
                    ),
                  ),
                  SizedBox(width: 5),
                  Container(
                    height: 45,
                    width: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                      onPressed: _adicionarPagamento,
                      child: Icon(Icons.add, color: Colors.white),
                    ),
                  )
                ],
              ),
            ],
          ),

          // LISTA DE PAGAMENTOS
          if (_pagamentos.isNotEmpty) ...[
             SizedBox(height: 10),
             Container(
               height: 60,
               child: ListView.builder(
                 itemCount: _pagamentos.length,
                 itemBuilder: (ctx, i) {
                   final pag = _pagamentos[i];
                   return Padding(
                     padding: const EdgeInsets.only(bottom: 2),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text("• ${pag['metodo']}", style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                         Row(
                           children: [
                             Text("R\$ ${pag['valor'].toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                             SizedBox(width: 5),
                             InkWell(onTap: () => _removerPagamento(i), child: Icon(Icons.close, size: 12, color: Colors.red))
                           ],
                         )
                       ],
                     ),
                   );
                 },
               ),
             )
          ],

          SizedBox(height: 15),

          // BOTÃO FINALIZAR
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _restante <= 0 ? _corAcai : Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: _restante <= 0 ? 5 : 0,
              ),
              onPressed: (_carrinho.isNotEmpty && _restante <= 0) ? _finalizarVenda : null,
              child: Text(
                "FINALIZAR (ENTER)",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _restante <= 0 ? Colors.white : Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowTotal(String label, double val, {Color? color, bool isBold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
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
    try {
      WriteBatch batch = _db.batch();

      // 1. Salvar venda no Firestore
      var vendaRef = _db.collection('vendas').doc();
      batch.set(vendaRef, {
        'itens': _carrinho,
        'valor_total': _totalCart,
        'pagamentos': _pagamentos,
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
        _searchCtrl.clear();
        _filtroBusca = '';
      });

      // Focar busca novamente para próxima venda
      // Idealmente usar FocusNode, mas o autofocus do header deve pegar se for reconstruido ou se usarmos requestFocus.

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("VENDA REALIZADA COM SUCESSO!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
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
