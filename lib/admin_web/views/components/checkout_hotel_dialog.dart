import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CheckoutHotelDialog extends StatefulWidget {
  final String reservaId;
  final Map<String, dynamic> dadosReserva;
  final double precoDiaria;
  final List<Map<String, dynamic>> listaExtras;
  final Color corAcai;
  final VoidCallback onSuccess;

  const CheckoutHotelDialog({
    Key? key,
    required this.reservaId,
    required this.dadosReserva,
    required this.precoDiaria,
    required this.listaExtras,
    required this.corAcai,
    required this.onSuccess,
  }) : super(key: key);

  @override
  _CheckoutHotelDialogState createState() => _CheckoutHotelDialogState();
}

class _CheckoutHotelDialogState extends State<CheckoutHotelDialog> {
  final _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );
  final _db = FirebaseFirestore.instance;

  // Itens
  List<Map<String, dynamic>> _itensSelecionados = [];
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  // Pagamento
  List<Map<String, dynamic>> _pagamentos = [];
  String _metodoSelecionado = 'Dinheiro';
  final TextEditingController _valorPagamentoCtrl = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  int get _diasEstadia {
    final checkIn = widget.dadosReserva['check_in_real'] != null
        ? (widget.dadosReserva['check_in_real'] as Timestamp).toDate()
        : (widget.dadosReserva['check_in'] as Timestamp).toDate();
    final checkOut = DateTime.now();
    int dias = checkOut.difference(checkIn).inDays;
    return dias < 1 ? 1 : dias;
  }

  // --- BUSCA UNIFICADA ---
  void _realizarBusca(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    // 1. Extras Locais
    final localMatches = widget.listaExtras.where((e) {
      return e['nome'].toString().toLowerCase().contains(query.toLowerCase());
    }).map((e) => {
      ...e,
      'type': 'extra',
      'qtd': 1
    }).toList();

    // 2. Produtos Firestore
    final querySnap = await _db.collection('produtos')
        .orderBy('nome')
        .startAt([query])
        .endAt([query + '\uf8ff'])
        .limit(10)
        .get();

    final productMatches = querySnap.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'nome': data['nome'],
        'preco': (data['preco'] ?? 0).toDouble(),
        'type': 'produto',
        'qtd': 1
      };
    }).toList();

    if (mounted) {
      setState(() {
        _searchResults = [...localMatches, ...productMatches];
      });
    }
  }

  void _adicionarItem(Map<String, dynamic> item) {
    setState(() {
      _searchController.clear();
      _searchResults = [];
      final index = _itensSelecionados.indexWhere((i) => i['id'] == item['id'] && i['type'] == item['type']);
      if (index >= 0) {
        _itensSelecionados[index]['qtd']++;
      } else {
        _itensSelecionados.add(Map.from(item));
      }
    });
  }

  void _removerItem(int index) {
    setState(() => _itensSelecionados.removeAt(index));
  }

  // --- FINANCEIRO ---
  double get _valorDiarias => _diasEstadia * widget.precoDiaria;

  double get _totalGeral {
    double total = _valorDiarias;
    for (var item in _itensSelecionados) {
      total += (item['preco'] * item['qtd']);
    }
    return total;
  }

  double get _jaPago => (widget.dadosReserva['valor_pago'] ?? 0).toDouble();
  double get _totalPagoAgora => _pagamentos.fold(0, (sum, p) => sum + p['valor']);
  double get _restante => (_totalGeral - _jaPago - _totalPagoAgora);

  void _adicionarPagamento() {
    double valor = double.tryParse(_valorPagamentoCtrl.text.replaceAll(',', '.')) ?? 0;
    if (valor <= 0) return;
    if (valor > _restante) valor = _restante;

    setState(() {
      _pagamentos.add({
        'metodo': _metodoSelecionado,
        'valor': valor
      });
      _valorPagamentoCtrl.clear();
    });
  }

  void _removerPagamento(int index) => setState(() => _pagamentos.removeAt(index));

  void _confirmarCheckout() async {
    setState(() => _isLoading = true);
    try {
      List<String> extrasIds = [];
      List<Map<String, dynamic>> produtosList = [];

      for (var item in _itensSelecionados) {
        if (item['type'] == 'extra') {
          for(int i=0; i<item['qtd']; i++) extrasIds.add(item['id']);
        } else {
          produtosList.add({'id': item['id'], 'qtd': item['qtd']});
        }
      }

      await _functions.httpsCallable('realizarCheckoutHotel').call({
        'reservaId': widget.reservaId,
        'extrasIds': extrasIds,
        'produtos': produtosList,
        'pagamentos': _pagamentos,
      });

      widget.onSuccess();
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red),
      );
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
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Checkout Hotel", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),

            Expanded(
              child: Row(
                children: [
                  // ESQUERDA: LISTA ITENS + BUSCA
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // RESUMO DIARIAS
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("$_diasEstadia Diárias x R\$ ${widget.precoDiaria}", style: TextStyle(color: Colors.blue[900])),
                                Text("R\$ ${_valorDiarias.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900])),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),

                          Text("Adicionar Itens", style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 10),
                          TextField(
                            controller: _searchController,
                            onChanged: _realizarBusca,
                            decoration: InputDecoration(
                              hintText: "Serviços extras ou produtos...",
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (_searchResults.isNotEmpty)
                            Container(
                              height: 150,
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!)),
                              child: ListView.separated(
                                itemCount: _searchResults.length,
                                separatorBuilder: (_,__) => Divider(height:1),
                                itemBuilder: (ctx, i) {
                                  final item = _searchResults[i];
                                  return ListTile(
                                    dense: true,
                                    title: Text(item['nome']),
                                    trailing: Text("R\$ ${item['preco']}"),
                                    onTap: () => _adicionarItem(item),
                                  );
                                },
                              ),
                            ),

                          SizedBox(height: 20),
                          Text("Consumo", style: TextStyle(fontWeight: FontWeight.bold)),
                          Divider(),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _itensSelecionados.length,
                              itemBuilder: (ctx, i) {
                                final item = _itensSelecionados[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(item['nome']),
                                  subtitle: Text("${item['qtd']}x R\$ ${item['preco']}"),
                                  trailing: IconButton(icon: Icon(Icons.close, size: 16, color: Colors.red), onPressed: () => _removerItem(i)),
                                );
                              },
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
                          _buildTotalRow("Total Geral", _totalGeral, isMain: true),
                          SizedBox(height: 10),
                          _buildTotalRow("Já Pago (Sinal)", _jaPago, color: Colors.green),
                          _buildTotalRow("Pago Agora", _totalPagoAgora, color: Colors.green),
                          Divider(),
                          _buildTotalRow("A Pagar", _restante > 0 ? _restante : 0, isMain: true, color: _restante > 0.1 ? Colors.red : Colors.green),

                          Divider(height: 30),

                          if (_restante > 0.1) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _metodoSelecionado,
                                    items: ['Dinheiro', 'Pix', 'Cartão'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                    onChanged: (v) => setState(() => _metodoSelecionado = v!),
                                    decoration: InputDecoration(filled: true, fillColor: Colors.white, contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _valorPagamentoCtrl,
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(hintText: "Valor", prefixText: "R\$ ", filled: true, fillColor: Colors.white),
                                  ),
                                ),
                                SizedBox(width: 10),
                                IconButton.filled(onPressed: _adicionarPagamento, icon: Icon(Icons.add)),
                              ],
                            ),
                            SizedBox(height: 20),
                          ],

                          Expanded(
                            child: ListView.builder(
                              itemCount: _pagamentos.length,
                              itemBuilder: (ctx, i) {
                                final p = _pagamentos[i];
                                return Card(
                                  child: ListTile(
                                    dense: true,
                                    title: Text(p['metodo']),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("R\$ ${p['valor'].toStringAsFixed(2)}"),
                                        IconButton(icon: Icon(Icons.delete, size: 16), onPressed: () => _removerPagamento(i))
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: _restante <= 0.1 ? Colors.green : Colors.grey),
                              onPressed: (_restante <= 0.1 && !_isLoading) ? _confirmarCheckout : null,
                              child: _isLoading ? CircularProgressIndicator(color: Colors.white) : Text("FINALIZAR", style: TextStyle(color: Colors.white, fontSize: 18)),
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
        Text("R\$ ${value.toStringAsFixed(2)}", style: TextStyle(fontSize: isMain ? 20 : 14, fontWeight: FontWeight.bold, color: color ?? Colors.black)),
      ],
    );
  }
}
