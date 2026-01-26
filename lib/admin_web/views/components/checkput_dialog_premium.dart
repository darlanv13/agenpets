import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CheckoutDialogPremium extends StatefulWidget {
  final String agendamentoId;
  final Map<String, dynamic> dadosAgendamento;
  final String servicoNome;
  final double valorBase;
  final Map userData;
  final List<Map<String, dynamic>> listaExtras;
  final Color corAcai;
  final VoidCallback onSuccess;

  const CheckoutDialogPremium({
    Key? key,
    required this.agendamentoId,
    required this.dadosAgendamento,
    required this.servicoNome,
    required this.valorBase,
    required this.userData,
    required this.listaExtras,
    required this.corAcai,
    required this.onSuccess,
  }) : super(key: key);

  @override
  _CheckoutDialogPremiumState createState() => _CheckoutDialogPremiumState();
}

class _CheckoutDialogPremiumState extends State<CheckoutDialogPremium> {
  final _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );
  final _db = FirebaseFirestore.instance;

  // --- CONTROLE DE VOUCHERS ---
  Map<String, bool> _vouchersParaUsar = {};
  Map<String, int> _saldosDisponiveis = {};
  bool _jaConsumiuVoucher = false;

  // --- CONTROLE DE ITENS (Serviços Extras + Produtos) ---
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _itensSelecionados = []; // {type, id, nome, preco, qtd}

  // Lista unificada para resultados da busca
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

  // --- CONTROLE DE PAGAMENTO ---
  List<Map<String, dynamic>> _pagamentos = [];
  String _metodoSelecionado = 'Dinheiro';
  final TextEditingController _valorPagamentoCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _verificarConsumoAnterior();
    if (!_jaConsumiuVoucher) {
      _calcularSaldosVouchers();
    }
  }

  // --- LOGICA VOUCHERS ---
  void _verificarConsumoAnterior() {
    if (widget.dadosAgendamento['vouchers_consumidos'] != null &&
        (widget.dadosAgendamento['vouchers_consumidos'] as Map).isNotEmpty) {
      _jaConsumiuVoucher = true;
    }
  }

  void _calcularSaldosVouchers() {
    _saldosDisponiveis = {};
    List<dynamic> listaPacotes = widget.userData['voucher_assinatura'] ?? [];
    for (var pacote in listaPacotes) {
      if (pacote is Map) {
        Timestamp? validade = pacote['validade_pacote'];
        if (validade != null && validade.toDate().isAfter(DateTime.now())) {
          pacote.forEach((key, value) {
            if (key != 'nome_pacote' &&
                key != 'validade_pacote' &&
                key != 'data_compra' &&
                value is int &&
                value > 0) {
              _saldosDisponiveis[key] = (_saldosDisponiveis[key] ?? 0) + value;
            }
          });
        }
      }
    }
    _saldosDisponiveis.forEach((key, value) {
      bool autoSelect = widget.servicoNome.toLowerCase().contains(key.toLowerCase());
      _vouchersParaUsar[key] = autoSelect;
    });
  }

  // --- LOGICA BUSCA UNIFICADA ---
  void _realizarBusca(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    // 1. Busca Local em Serviços Extras
    final localMatches = widget.listaExtras.where((e) {
      return e['nome'].toString().toLowerCase().contains(query.toLowerCase());
    }).map((e) => {
      ...e,
      'type': 'extra',
      'qtd': 1
    }).toList();

    // 2. Busca Firestore em Produtos
    // (Otimização: idealmente usar Algolia ou Elastic, mas para scale pequeno ok)
    // Buscamos tudo que começa com ou contém (client side filtering para contém)
    // Aqui faremos fetch de uma query limitada e filtro local simples
    final querySnap = await _db.collection('produtos')
        .orderBy('nome')
        .startAt([query])
        .endAt([query + '\uf8ff'])
        .limit(10)
        .get();

    // Fallback: se a query direta não retornar nada, tentamos busca contains client-side em um subset maior?
    // Não, vamos manter simples: busca por prefixo (startAt) ou código de barras.

    // Se não achou por nome, tenta codigo barras
    List<DocumentSnapshot> productDocs = querySnap.docs;
    if (productDocs.isEmpty) {
        final codeSnap = await _db.collection('produtos')
            .where('codigo_barras', isEqualTo: query)
            .limit(1)
            .get();
        productDocs = codeSnap.docs;
    }

    final productMatches = productDocs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'nome': data['nome'],
        'preco': (data['preco'] ?? 0).toDouble(),
        'estoque': data['qtd_estoque'] ?? 0,
        'type': 'produto',
        'qtd': 1
      };
    }).toList();

    if (mounted) {
      setState(() {
        _searchResults = [...localMatches, ...productMatches];
        _searching = false;
      });
    }
  }

  void _adicionarItem(Map<String, dynamic> item) {
    setState(() {
      _searchController.clear();
      _searchResults = [];

      // Verifica se já existe na lista
      final index = _itensSelecionados.indexWhere((i) => i['id'] == item['id'] && i['type'] == item['type']);
      if (index >= 0) {
        _itensSelecionados[index]['qtd']++;
      } else {
        _itensSelecionados.add(Map.from(item));
      }
    });
  }

  void _removerItem(int index) {
    setState(() {
      _itensSelecionados.removeAt(index);
    });
  }

  // --- LOGICA FINANCEIRA ---
  double get _valorServicoBase {
    if (_jaConsumiuVoucher) {
      return widget.dadosAgendamento['usou_voucher'] == true ? 0.0 : widget.valorBase;
    }
    // Se está usando voucher para o serviço principal
    bool usaVoucherBase = false;
    _vouchersParaUsar.forEach((k, v) {
      if (v && (k == 'banhos' || k == 'tosa')) usaVoucherBase = true;
    });
    return usaVoucherBase ? 0.0 : widget.valorBase;
  }

  double get _totalGeral {
    double total = _valorServicoBase;
    for (var item in _itensSelecionados) {
      total += (item['preco'] * item['qtd']);
    }
    return total;
  }

  double get _totalPago => _pagamentos.fold(0, (sum, p) => sum + p['valor']);
  double get _restante => (_totalGeral - _totalPago) > 0 ? (_totalGeral - _totalPago) : 0;

  void _adicionarPagamento() {
    double valor = double.tryParse(_valorPagamentoCtrl.text.replaceAll(',', '.')) ?? 0;
    if (valor <= 0) return;
    if (valor > _restante) valor = _restante; // Cap no restante

    setState(() {
      _pagamentos.add({
        'metodo': _metodoSelecionado,
        'valor': valor
      });
      _valorPagamentoCtrl.clear();
    });
  }

  void _removerPagamento(int index) {
    setState(() => _pagamentos.removeAt(index));
  }

  void _finalizarCheckout() async {
    setState(() => _isLoading = true);
    try {
      // Separa Extras e Produtos
      List<String> extrasIds = [];
      List<Map<String, dynamic>> produtosList = [];

      for (var item in _itensSelecionados) {
        if (item['type'] == 'extra') {
          // Extras no backend agendamento são apenas IDs por enquanto?
          // O backend espera 'extrasIds' array de strings. Se tiver qtd > 1, mandamos repetido ou backend não suporta qtd?
          // O backend agendamento 'checkouts_agenpets.js' apenas empurra para array.
          // Vamos adicionar o ID N vezes se qtd > 1
          for (int i=0; i<item['qtd']; i++) extrasIds.add(item['id']);
        } else {
          produtosList.add({
            'id': item['id'],
            'qtd': item['qtd']
          });
        }
      }

      await _functions.httpsCallable('realizarCheckout').call({
        'agendamentoId': widget.agendamentoId,
        'extrasIds': extrasIds,
        'produtos': produtosList,
        'pagamentos': _pagamentos,
        'vouchersParaUsar': _jaConsumiuVoucher ? {} : _vouchersParaUsar,
        'responsavel': 'Admin/Balcão',
      });

      widget.onSuccess();
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 900,
        height: 700,
        child: Column(
          children: [
            // HEADER
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Checkout Agenda", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),

            Expanded(
              child: Row(
                children: [
                  // ESQUERDA: VOUCHERS + BUSCA + LISTA DE ITENS
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. VOUCHERS (Compacto)
                          if (_jaConsumiuVoucher) ...[
                            Container(
                              margin: EdgeInsets.only(bottom: 20),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withOpacity(0.5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                                      SizedBox(width: 5),
                                      Text("Voucher já aplicado neste agendamento", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800])),
                                    ],
                                  ),
                                  if (_detalhesConsumo.isNotEmpty) ...[
                                    SizedBox(height: 5),
                                    ..._detalhesConsumo.entries.map((e) {
                                        final info = e.value as Map;
                                        final responsavel = info['responsavel'] ?? 'N/A';
                                        return Text("Aplicado por: $responsavel", style: TextStyle(fontSize: 12, color: Colors.green[900]));
                                    }).toList(),
                                  ]
                                ],
                              ),
                            ),
                          ] else if (_saldosDisponiveis.isNotEmpty)
                            Container(
                              margin: EdgeInsets.only(bottom: 20),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Vouchers Disponíveis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber[900])),
                                  SizedBox(height: 5),
                                  Wrap(
                                    spacing: 10,
                                    children: _saldosDisponiveis.keys.map((key) {
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Checkbox(
                                            value: _vouchersParaUsar[key] ?? false,
                                            onChanged: (v) => setState(() => _vouchersParaUsar[key] = v!),
                                            activeColor: Colors.amber[800],
                                          ),
                                          Text("${key.toUpperCase()} (${_saldosDisponiveis[key]})", style: TextStyle(fontSize: 13)),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),

                          // 2. BUSCA UNIFICADA
                          Text("Adicionar Itens", style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          TextField(
                            controller: _searchController,
                            onChanged: _realizarBusca,
                            decoration: InputDecoration(
                              hintText: "Buscar serviços ou produtos...",
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            ),
                          ),

                          // RESULTADOS DA BUSCA (Overlay simulado ou lista abaixo)
                          if (_searchResults.isNotEmpty)
                            Container(
                              height: 150,
                              margin: EdgeInsets.only(top: 5),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: ListView.separated(
                                itemCount: _searchResults.length,
                                separatorBuilder: (_,__) => Divider(height:1),
                                itemBuilder: (ctx, i) {
                                  final item = _searchResults[i];
                                  bool isProd = item['type'] == 'produto';
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(isProd ? FontAwesomeIcons.box : FontAwesomeIcons.scissors, size: 16, color: isProd ? Colors.blue : Colors.purple),
                                    title: Text(item['nome']),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("R\$ ${item['preco']}", style: TextStyle(fontWeight: FontWeight.bold)),
                                        SizedBox(width: 10),
                                        Icon(Icons.add_circle, color: Colors.green),
                                      ],
                                    ),
                                    onTap: () => _adicionarItem(item),
                                  );
                                },
                              ),
                            ),

                          SizedBox(height: 20),

                          // 3. LISTA DE ITENS SELECIONADOS
                          Text("Resumo do Consumo", style: TextStyle(fontWeight: FontWeight.bold)),
                          Divider(),
                          Expanded(
                            child: ListView(
                              children: [
                                // Item base (Serviço)
                                ListTile(
                                  dense: true,
                                  title: Text(widget.servicoNome, style: TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text("Serviço Agendado"),
                                  trailing: Text("R\$ ${_valorServicoBase.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                // Itens adicionados
                                ..._itensSelecionados.asMap().entries.map((entry) {
                                  final item = entry.value;
                                  return ListTile(
                                    dense: true,
                                    title: Text(item['nome']),
                                    subtitle: Text("${item['type'].toString().toUpperCase()} • ${item['qtd']}x R\$ ${item['preco']}"),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("R\$ ${(item['preco'] * item['qtd']).toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: Icon(Icons.close, color: Colors.red, size: 16),
                                          onPressed: () => _removerItem(entry.key),
                                        )
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  VerticalDivider(width: 1),

                  // DIREITA: PAGAMENTO
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: Colors.grey[50],
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // TOTALIZADORES
                          _buildTotalRow("Total Geral", _totalGeral, isMain: true),
                          SizedBox(height: 10),
                          _buildTotalRow("Total Pago", _totalPago, color: Colors.green),
                          _buildTotalRow("Restante", _restante, color: _restante > 0 ? Colors.red : Colors.green),

                          Divider(height: 40),

                          // ADICIONAR PAGAMENTO
                          if (_restante > 0 && _pagamentos.length < 3) ...[
                            Text("Adicionar Pagamento", style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    value: _metodoSelecionado,
                                    decoration: InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                      border: OutlineInputBorder(),
                                      filled: true, fillColor: Colors.white
                                    ),
                                    items: ['Dinheiro', 'Pix', 'Cartão'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
                                      hintText: "Valor",
                                      prefixText: "R\$ ",
                                      border: OutlineInputBorder(),
                                      filled: true, fillColor: Colors.white
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: _adicionarPagamento,
                                  child: Icon(Icons.add),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.corAcai,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 16)
                                  ),
                                )
                              ],
                            ),
                          ],

                          SizedBox(height: 20),

                          // LISTA PAGAMENTOS
                          Text("Pagamentos Registrados", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          SizedBox(height: 10),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _pagamentos.length,
                              itemBuilder: (ctx, i) {
                                final p = _pagamentos[i];
                                return Card(
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.check_circle, color: Colors.green),
                                    title: Text(p['metodo']),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("R\$ ${p['valor'].toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold)),
                                        SizedBox(width: 10),
                                        IconButton(icon: Icon(Icons.delete, size: 16), onPressed: () => _removerPagamento(i))
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // BOTAO FINAL
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (_restante <= 0.01) ? Colors.green : Colors.grey[300],
                              ),
                              onPressed: (_restante <= 0.01 && !_isLoading) ? _finalizarCheckout : null,
                              child: _isLoading
                                ? CircularProgressIndicator(color: Colors.white)
                                : Text("FINALIZAR CHECKOUT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double value, {bool isMain = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isMain ? 18 : 14, fontWeight: isMain ? FontWeight.bold : FontWeight.normal)),
        Text("R\$ ${value.toStringAsFixed(2)}", style: TextStyle(fontSize: isMain ? 24 : 16, fontWeight: FontWeight.bold, color: color ?? Colors.black)),
      ],
    );
  }
}
