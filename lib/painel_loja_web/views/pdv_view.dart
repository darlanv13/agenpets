import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:agenpet/services/app_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class PdvView extends StatefulWidget {
  final bool isMaster;

  const PdvView({super.key, this.isMaster = false});

  @override
  _PdvViewState createState() => _PdvViewState();
}

class _PdvViewState extends State<PdvView> {
  final _db = AppDatabase.instance;

  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

  // --- CONTROLE DE CAIXA ---
  String? _caixaAbertoId; // Armazena o ID do caixa se estiver aberto
  bool _verificandoCaixa = true; // Para mostrar um loading inicial
  final TextEditingController _fundoTrocoCtrl = TextEditingController();
  final TextEditingController _operadorAberturaCtrl = TextEditingController();

  // Carrinho
  List<Map<String, dynamic>> _carrinho = [];
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
  Timer? _debounce;

  // Paginação
  final int _itensPorPagina = 4;

  // --- COMANDAS / SERVIÇOS ---
  int _tabIndex = 0; // 0 = Produtos, 1 = Serviços
  Map<String, dynamic>? _currentComanda;
  String? _currentComandaId;

  @override
  void initState() {
    super.initState();
    // Foco inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
      _verificarStatusCaixa();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _cartScrollCtrl.dispose();
    _valorPagamentoCtrl.dispose();
    _vendedorCodeCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _filtroBusca = val);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.f2): () => _searchFocus.requestFocus(),
        SingleActivator(LogicalKeyboardKey.escape): () {
          _searchCtrl.clear();
          _onSearchChanged('');
          _searchFocus.unfocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
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
                      // HEADER COMPACTO
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // CAIXA STATUS
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _caixaAbertoId != null
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _caixaAbertoId != null ? Colors.green : Colors.red,
                                width: 0.5
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 8, color: _caixaAbertoId != null ? Colors.green : Colors.red),
                                SizedBox(width: 6),
                                Text(
                                  _caixaAbertoId != null ? "CAIXA ABERTO" : "CAIXA FECHADO",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black54),
                                ),
                                if (_caixaAbertoId != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: InkWell(
                                      onTap: _iniciarFechamentoCaixa,
                                      child: Icon(Icons.lock_clock, size: 14, color: Colors.red),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // TABS
                          Row(
                            children: [
                              _buildTabButton("Produtos", 0),
                              SizedBox(width: 10),
                              StreamBuilder<QuerySnapshot>(
                                stream: _db.collection('tenants').doc(AppConfig.tenantId).collection('comandas').where('status', isEqualTo: 'aberta').snapshots(),
                                builder: (context, snapshot) {
                                  int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                                  return _buildTabButton("Serviços", 1, badgeCount: count);
                                },
                              ),
                            ],
                          )
                        ],
                      ),

                      SizedBox(height: 10),

                      // CONTEUDO DA ESQUERDA (GRID ou LISTA)
                      Expanded(
                        flex: 4,
                        child: _tabIndex == 0
                          ? Column(
                              children: [
                                _buildHeader(), // Search Bar
                                SizedBox(height: 10),
                                Expanded(child: _buildProductGridWithPagination()),
                              ],
                            )
                          : _buildComandasList(),
                      ),

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
                      // HEADER: SE É COMANDA
                      if (_currentComanda != null)
                        Container(
                          margin: EdgeInsets.only(bottom: 15),
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue[200]!)
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.receipt_long, color: Colors.blue[800]),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "PAGANDO SERVIÇO DE:",
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                                    ),
                                    Text(
                                      _currentComanda!['cliente_nome'] ?? 'Cliente',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    )
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.red),
                                onPressed: _limparComandaAtual,
                                tooltip: "Cancelar Comanda",
                              )
                            ],
                          ),
                        ),

                      // TOTAL COMPACTO
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_corAcai, Color(0xFF6A1B9A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "TOTAL",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "R\$ ${_totalCart.toStringAsFixed(2)}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 15),

                      // VENDEDOR COMPACTO
                      SizedBox(
                        height: 45,
                        child: TextField(
                          controller: _vendedorCodeCtrl,
                          style: TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: "Código Vendedor",
                            prefixIcon: Icon(Icons.badge, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ),

                      SizedBox(height: 10),
                      Divider(),
                      SizedBox(height: 5),

                      // RESUMO PAGAMENTO
                      _buildCheckoutSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index, {int badgeCount = 0}) {
    bool isActive = _tabIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _tabIndex = index;
          // Se voltar para produtos, mantemos o estado por enquanto
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
                color: isActive ? _corAcai : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: isActive ? _corAcai : Colors.grey[300]!)),
            child: Text(
              label,
              style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                padding: EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badgeCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- COMANDAS LIST ---
  Widget _buildComandasList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('comandas')
          .where('status', isEqualTo: 'aberta')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 40, color: Colors.red),
                SizedBox(height: 10),
                Text(
                  "Erro ao carregar serviços.\nVerifique se o índice 'status' + 'created_at' existe.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
                SizedBox(height: 5),
                SelectableText(
                  snapshot.error.toString(),
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                )
              ],
            ),
          );
        }

        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_turned_in_outlined, size: 50, color: Colors.grey[300]),
                Text("Nenhum serviço aguardando pagamento.", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final created = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
            final valor = (data['valor_total'] ?? 0).toDouble();
            final nome = data['cliente_nome'] ?? 'Cliente';
            final origem = data['origem_tipo'] ?? 'serviço';

            return Card(
              margin: EdgeInsets.only(bottom: 10),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[50],
                  child: Icon(Icons.receipt, color: Colors.blue),
                ),
                title: Text(nome, style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("$origem • ${DateFormat('HH:mm').format(created)}"),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("R\$ ${valor.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _corAcai)),
                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey)
                  ],
                ),
                onTap: () => _selecionarComanda(doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  void _selecionarComanda(String id, Map<String, dynamic> data) {
    setState(() {
      _carrinho.clear(); // Limpa carrinho atual
      _pagamentos.clear(); // Limpa pagamentos
      _currentComanda = data;
      _currentComandaId = id;

      // Popula carrinho com itens da comanda
      if (data['itens'] != null) {
        for (var item in data['itens']) {
          _carrinho.add({
            'id': item['id_origem'] ?? 'srv_${DateTime.now().millisecondsSinceEpoch}',
            'nome': item['nome'],
            'preco': (item['preco'] as num).toDouble(),
            'qtd': 1, // Serviços geralmente são 1
            'tipo': item['tipo'] ?? 'servico' // Mantem tipo para rastreio
          });
        }
      }
    });

    // Opcional: Auto-preencher vendedor se tiver na comanda?
    // Mas geralmente quem fecha o caixa é o operador atual.
  }

  void _limparComandaAtual() {
    setState(() {
      _currentComanda = null;
      _currentComandaId = null;
      _carrinho.clear();
      _pagamentos.clear();
    });
  }

  // --- RESTO DO CÓDIGO (Header, Caixa, Grid, Cart, Checkout) ---
  // Mantive a estrutura original mas ajustada para usar as variaveis novas

  Widget _buildHeader() {
    return Container(
      height: 45,
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        textInputAction: TextInputAction.go,
        onChanged: _onSearchChanged, // USANDO DEBOUNCE
        onSubmitted: (val) => _handleScanSubmit(val),
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: "Buscar produto ou código (F2)",
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(Icons.search, color: _corAcai, size: 20),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear, size: 16),
            onPressed: () {
              setState(() {
                _searchCtrl.clear();
                _filtroBusca = '';
                _searchFocus.requestFocus();
              });
            },
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(bottom: 12),
        ),
      ),
    );
  }

  Future<void> _verificarStatusCaixa() async {
    setState(() => _verificandoCaixa = true);

    try {
      var query = await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('caixas_diarios')
          .where('status', isEqualTo: 'ABERTO')
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        setState(() {
          _caixaAbertoId = query.docs.first.id;
          _verificandoCaixa = false;
          var dados = query.docs.first.data();
          if (dados['usuario_nome'] != null) {
            _vendedorCodeCtrl.text = dados['usuario_nome'];
          }
        });
      } else {
        setState(() => _verificandoCaixa = false);
        if (mounted) _abrirDialogoCaixa();
      }
    } catch (e) {
      print("Erro ao verificar caixa: $e");
      setState(() => _verificandoCaixa = false);
    }
  }

  void _abrirDialogoCaixa() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: [
                Icon(Icons.point_of_sale, color: _corAcai),
                SizedBox(width: 10),
                Text("Abertura de Caixa"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "O caixa está fechado. Informe os dados para iniciar as vendas.",
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _operadorAberturaCtrl,
                  decoration: InputDecoration(
                    labelText: "Nome/Código do Operador",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                SizedBox(height: 15),
                TextField(
                  controller: _fundoTrocoCtrl,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Fundo de Troco (R\$)",
                    hintText: "Valor inicial na gaveta",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  "Sair do PDV",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                ),
                onPressed: () {
                  if (_operadorAberturaCtrl.text.isEmpty) return;
                  _confirmarAberturaCaixa(ctx);
                },
                child: Text(
                  "ABRIR CAIXA",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- LÓGICA DE FECHAMENTO DE CAIXA ---

  void _iniciarFechamentoCaixa() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(child: CircularProgressIndicator()),
    );

    try {
      var vendasSnapshot = await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('vendas')
          .where('caixa_id', isEqualTo: _caixaAbertoId)
          .get();

      double totalDinheiro = 0.0;
      double totalPix = 0.0;
      double totalCartao = 0.0;
      double totalOutros = 0.0;
      double totalTrocoDado = 0.0;

      for (var doc in vendasSnapshot.docs) {
        var dados = doc.data();
        List pagamentos = dados['pagamentos'] ?? [];
        double troco = (dados['troco'] ?? 0).toDouble();

        totalTrocoDado += troco;

        for (var pag in pagamentos) {
          String metodo = pag['metodo'] ?? 'Outro';
          double valor = (pag['valor'] ?? 0).toDouble();

          if (metodo == 'Dinheiro')
            totalDinheiro += valor;
          else if (metodo == 'Pix')
            totalPix += valor;
          else if (metodo == 'Cartão')
            totalCartao += valor;
          else
            totalOutros += valor;
        }
      }

      double dinheiroLiquidoVendas = totalDinheiro - totalTrocoDado;

      var caixaDoc = await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('caixas_diarios')
          .doc(_caixaAbertoId)
          .get();

      double valorInicial = (caixaDoc.data()?['valor_inicial'] ?? 0).toDouble();

      Navigator.pop(context);

      if (mounted) {
        _mostrarDialogoConferencia(
          valorInicial: valorInicial,
          dinheiroVendas: dinheiroLiquidoVendas,
          pix: totalPix,
          cartao: totalCartao,
          outros: totalOutros,
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao calcular fechamento: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarDialogoConferencia({
    required double valorInicial,
    required double dinheiroVendas,
    required double pix,
    required double cartao,
    required double outros,
  }) {
    final _dinheiroGavetaCtrl = TextEditingController();
    double totalEsperadoEmDinheiro = valorInicial + dinheiroVendas;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Fechamento de Caixa"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResumoLinha("Fundo Inicial (+)", valorInicial),
                _buildResumoLinha("Vendas Dinheiro (+)", dinheiroVendas),
                Divider(),
                _buildResumoLinha(
                  "ESPERADO NA GAVETA (=)",
                  totalEsperadoEmDinheiro,
                  isBold: true,
                ),
                SizedBox(height: 20),
                Text(
                  "Outros Recebimentos (Info):",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  "Pix: R\$ ${pix.toStringAsFixed(2)} | Cartão: R\$ ${cartao.toStringAsFixed(2)}",
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _dinheiroGavetaCtrl,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Valor Contado na Gaveta (R\$)",
                    hintText: "Quanto dinheiro tem fisicamente?",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                double valorInformado =
                    double.tryParse(
                      _dinheiroGavetaCtrl.text.replaceAll(',', '.'),
                    ) ??
                    0.0;
                _confirmarFechamentoFinal(
                  valorInformado: valorInformado,
                  esperado: totalEsperadoEmDinheiro,
                  resumo: {
                    'dinheiro_vendas': dinheiroVendas,
                    'pix': pix,
                    'cartao': cartao,
                    'outros': outros,
                  },
                );
                Navigator.pop(ctx);
              },
              child: Text(
                "ENCERRAR CAIXA",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResumoLinha(String label, double val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "R\$ ${val.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarFechamentoFinal({
    required double valorInformado,
    required double esperado,
    required Map<String, double> resumo,
  }) async {
    double diferenca = valorInformado - esperado;
    try {
      await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('caixas_diarios')
          .doc(_caixaAbertoId)
          .update({
            'data_fechamento': FieldValue.serverTimestamp(),
            'status': 'FECHADO',
            'valor_fechamento_informado': valorInformado,
            'valor_fechamento_esperado': esperado,
            'diferenca_quebra': diferenca,
            'resumo_vendas': resumo,
          });

      setState(() {
        _caixaAbertoId = null;
        _vendedorCodeCtrl.clear();
      });

      String msg = diferenca == 0
          ? "Caixa fechado com Sucesso! Valores batem."
          : "Caixa fechado com Diferença de R\$ ${diferenca.toStringAsFixed(2)}";

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text("Resultado"),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _verificarStatusCaixa();
              },
              child: Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
    }
  }

  Future<void> _confirmarAberturaCaixa(BuildContext dialogContext) async {
    double valorInicial =
        double.tryParse(_fundoTrocoCtrl.text.replaceAll(',', '.')) ?? 0.0;
    String operador = _operadorAberturaCtrl.text;

    try {
      DocumentReference ref = await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('caixas_diarios')
          .add({
            'data_abertura': FieldValue.serverTimestamp(),
            'usuario_nome': operador,
            'valor_inicial': valorInicial,
            'valor_fechamento': 0.0,
            'status': 'ABERTO',
            'saldo_atual': valorInicial,
          });

      setState(() {
        _caixaAbertoId = ref.id;
        _vendedorCodeCtrl.text = operador;
      });

      Navigator.pop(dialogContext);
      _searchFocus.requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Caixa aberto com sucesso! Boas vendas.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao abrir caixa: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleScanSubmit(String value) async {
    if (value.isEmpty) {
      _searchFocus.requestFocus();
      return;
    }
    try {
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Produto não encontrado pelo código: $value"),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
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

        var displayDocs = docs.take(_itensPorPagina).toList();

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
                  crossAxisCount: 2,
                  childAspectRatio: 2.9,
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
    String? imagemUrl = data['imagem'] ?? data['foto'];

    return InkWell(
      onTap: () {
        _addToCart(doc.id, data);
        _clearAndRefocus();
      },
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2)],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _corAcai.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    image: imagemUrl != null && imagemUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(imagemUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (imagemUrl == null || imagemUrl.isEmpty)
                      ? Center(
                          child: FaIcon(
                            FontAwesomeIcons.box,
                            size: 18,
                            color: _corAcai.withOpacity(0.6),
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        nome,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (marca.isNotEmpty)
                        Text(marca.toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                Text(
                  "R\$ ${preco.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _corAcai,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
            Opacity(
              opacity: 0.5,
              child: Icon(
                FontAwesomeIcons.cartPlus,
                size: 50,
                color: Colors.grey[300],
              ),
            ),
            SizedBox(height: 15),
            Text(
              "Seu carrinho está vazio",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.bold
              ),
            ),
            SizedBox(height: 5),
            Text(
              "Escaneie um produto ou selecione um serviço",
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
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
    if (_caixaAbertoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "ERRO CRÍTICO: Caixa não está aberto! Recarregue a tela.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      _verificarStatusCaixa();
      return;
    }

    if (_vendedorCodeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Informe o CÓDIGO DO VENDEDOR.")));
      return;
    }

    try {
      await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('vendas')
          .add({
            'itens': _carrinho,
            'valor_total': _totalCart,
            'pagamentos': _pagamentos,
            'troco': _troco,
            'vendedor_codigo': _vendedorCodeCtrl.text,
            'data_venda': FieldValue.serverTimestamp(),
            'status': 'concluido',
            'canal': 'PDV_MOBILE',
            'caixa_id': _caixaAbertoId,
            'comanda_id': _currentComandaId // Se vier de comanda
          });

      // Se for pagamento de comanda, atualiza status
      if (_currentComanda != null && _currentComandaId != null) {
        // 1. Marca Comanda como Paga
        await _db
            .collection('tenants')
            .doc(AppConfig.tenantId)
            .collection('comandas')
            .doc(_currentComandaId)
            .update({'status': 'pago'});

        // 2. Marca Origem como Concluido (e Pago)
        String? origemCol = _currentComanda!['origem_collection'];
        String? origemId = _currentComanda!['origem_id'];

        if (origemCol != null && origemId != null && origemCol.isNotEmpty) {
           await _db
            .collection('tenants')
            .doc(AppConfig.tenantId)
            .collection(origemCol)
            .doc(origemId)
            .update({
              'status': 'concluido',
              'status_pagamento': 'pago',
              'valor_final_cobrado': _totalCart,
              'data_pagamento': FieldValue.serverTimestamp(),
            });
        }
      }

      // Limpeza da tela
      setState(() {
        _carrinho.clear();
        _pagamentos.clear();
        _metodoSelecionado = 'Dinheiro';
        _valorPagamentoCtrl.clear();
        _searchCtrl.clear();
        _filtroBusca = '';
        _vendedorCodeCtrl.clear();
        _currentComanda = null;
        _currentComandaId = null;
      });
      _searchFocus.requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "VENDA REGISTRADA!",
          ),
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
