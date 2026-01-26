import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/admin_web/widgets/product_search_widget.dart';

class CheckoutCrecheDialog extends StatefulWidget {
  final String reservaId;
  final Map<String, dynamic> dadosReserva;
  final double precoDiaria;
  final List<Map<String, dynamic>> listaExtras;
  final Color corAcai;
  final VoidCallback onSuccess;

  const CheckoutCrecheDialog({
    Key? key,
    required this.reservaId,
    required this.dadosReserva,
    required this.precoDiaria,
    required this.listaExtras,
    required this.corAcai,
    required this.onSuccess,
  }) : super(key: key);

  @override
  _CheckoutCrecheDialogState createState() => _CheckoutCrecheDialogState();
}

class _CheckoutCrecheDialogState extends State<CheckoutCrecheDialog> {
  final _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  List<Map<String, dynamic>> _extrasSelecionados = [];
  List<Map<String, dynamic>> _produtosSelecionados = [];
  List<Map<String, dynamic>> _extrasFiltrados = [];
  final TextEditingController _searchController = TextEditingController();

  String? _metodoPagamento;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _extrasFiltrados = widget.listaExtras;
  }

  int get _diasEstadia {
    final checkIn = widget.dadosReserva['check_in_real'] != null
        ? (widget.dadosReserva['check_in_real'] as Timestamp).toDate()
        : (widget.dadosReserva['check_in'] as Timestamp).toDate();
    final checkOut = DateTime.now();
    int dias = checkOut.difference(checkIn).inDays;
    return dias < 1 ? 1 : dias;
  }

  void _filtrarExtras(String query) {
    if (query.isEmpty) {
      setState(() => _extrasFiltrados = widget.listaExtras);
    } else {
      setState(() {
        _extrasFiltrados = widget.listaExtras.where((item) {
          final nome = item['nome'].toString().toLowerCase();
          return nome.contains(query.toLowerCase());
        }).toList();
      });
    }
  }

  void _adicionarProduto(Map<String, dynamic> produto) {
    setState(() {
      int index = _produtosSelecionados.indexWhere((p) => p['id'] == produto['id']);
      if (index != -1) {
        _produtosSelecionados[index]['qtd']++;
      } else {
        _produtosSelecionados.add({
          'id': produto['id'],
          'nome': produto['nome'],
          'preco': produto['preco'],
          'qtd': 1
        });
      }
    });
  }

  void _removerProduto(int index) {
    setState(() {
      _produtosSelecionados.removeAt(index);
    });
  }

  void _confirmarCheckout() async {
    setState(() => _isLoading = true);
    try {
      List<String> extrasIds = _extrasSelecionados
          .map((e) => e['id'] as String)
          .toList();

      List<Map<String, dynamic>> produtosList = _produtosSelecionados.map((p) => {
        'id': p['id'],
        'qtd': p['qtd']
      }).toList();

      final result = await _functions
          .httpsCallable('realizarCheckoutCreche')
          .call({
            'reservaId': widget.reservaId,
            'extrasIds': extrasIds,
            'produtos': produtosList,
            'metodoPagamentoDiferenca': _metodoPagamento,
          });

      final ret = result.data as Map;
      double cobradoAgora = (ret['valorCobradoAgora'] ?? 0).toDouble();
      print("Checkout Creche: Cobrado R\$ $cobradoAgora");

      Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double valorDiarias = _diasEstadia * widget.precoDiaria;
    double valorExtras = _extrasSelecionados.fold(
      0,
      (sum, item) => sum + item['preco'],
    );
    double valorProdutos = _produtosSelecionados.fold(
      0,
      (sum, item) => sum + (item['preco'] * item['qtd'])
    );
    double custoTotalServico = valorDiarias + valorExtras + valorProdutos;
    double jaPago = (widget.dadosReserva['valor_pago'] ?? 0).toDouble();
    double restanteAPagar = custoTotalServico - jaPago;
    if (restanteAPagar < 0) restanteAPagar = 0;

    bool precisaPagar = restanteAPagar > 0.01;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 1000,
        height: 700,
        child: Column(
          children: [
            // HEADER
            Container(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(FontAwesomeIcons.school, color: widget.corAcai, size: 28),
                      SizedBox(width: 10),
                      Text(
                        "Checkout Creche",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 22),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),

            // BODY
            Expanded(
              child: Row(
                children: [
                  // LEFT: Estadia, Extras
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: EdgeInsets.all(25),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Resumo da Estadia", style: _sectionStyle),
                            SizedBox(height: 10),
                            _buildResumoEstadia(valorDiarias),

                            Divider(height: 40),

                            Text("Adicionar Extras (Serviços)", style: _sectionStyle),
                            SizedBox(height: 10),
                            _buildExtrasSection(),
                          ],
                        ),
                      ),
                    ),
                  ),

                  VerticalDivider(width: 1),

                  // RIGHT: Produtos
                  Expanded(
                    flex: 2,
                    child: Container(
                      color: Colors.grey[50],
                      padding: EdgeInsets.all(25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Adicionar Produtos", style: _sectionStyle),
                          SizedBox(height: 10),
                          SizedBox(
                            height: 300,
                            child: ProductSearchWidget(
                              onProductSelected: _adicionarProduto,
                              corDestaque: widget.corAcai,
                            ),
                          ),
                          Divider(),
                          Expanded(
                            child: _produtosSelecionados.isEmpty
                            ? Center(child: Text("Nenhum produto adicionado", style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: _produtosSelecionados.length,
                                itemBuilder: (context, index) {
                                  final p = _produtosSelecionados[index];
                                  return ListTile(
                                    dense: true,
                                    title: Text(p['nome'], style: TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text("Qtd: ${p['qtd']} x R\$ ${p['preco']}"),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("R\$ ${(p['preco'] * p['qtd']).toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold)),
                                        SizedBox(width: 5),
                                        IconButton(
                                          icon: Icon(Icons.delete, color: Colors.red, size: 18),
                                          onPressed: () => _removerProduto(index),
                                        )
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // FOOTER
            Container(
              height: 100,
              padding: EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))
                ]
              ),
              child: Row(
                children: [
                   Expanded(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         _buildResumoRow("Total Diárias", "R\$ ${valorDiarias.toStringAsFixed(2)}"),
                         if(valorExtras > 0)
                           _buildResumoRow("Extras", "+ R\$ ${valorExtras.toStringAsFixed(2)}"),
                         if(valorProdutos > 0)
                            _buildResumoRow("Produtos", "+ R\$ ${valorProdutos.toStringAsFixed(2)}"),
                         _buildResumoRow("Já Pago", "- R\$ ${jaPago.toStringAsFixed(2)}", color: Colors.green),
                       ],
                     ),
                   ),
                   Container(width: 1, height: 60, color: Colors.grey[300], margin: EdgeInsets.symmetric(horizontal: 20)),
                   Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                       Text("A PAGAR", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                       Text("R\$ ${restanteAPagar.toStringAsFixed(2)}", style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: precisaPagar ? Colors.red : Colors.green)),
                     ],
                   ),
                   SizedBox(width: 30),
                   if (precisaPagar) ...[
                     _buildPaymentButton("Pix", FontAwesomeIcons.pix, "pix_balcao"),
                     SizedBox(width: 10),
                     _buildPaymentButton("Dinheiro", FontAwesomeIcons.moneyBillWave, "dinheiro"),
                     SizedBox(width: 10),
                     _buildPaymentButton("Cartão", FontAwesomeIcons.creditCard, "cartao_credito"),
                     SizedBox(width: 20),
                   ],
                   ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (precisaPagar && _metodoPagamento == null) ? Colors.grey[300] : Colors.green,
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isLoading || (precisaPagar && _metodoPagamento == null) ? null : _confirmarCheckout,
                      child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text("FINALIZAR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                   )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  TextStyle get _sectionStyle => TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 16);

  Widget _buildResumoEstadia(double valorDiarias) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _colunaResumo("Dias", "$_diasEstadia"),
          _colunaResumo(
            "Valor Diária",
            "R\$ ${widget.precoDiaria.toStringAsFixed(2)}",
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.blue.withOpacity(0.3),
          ),
          Text(
            "Subtotal: R\$ ${valorDiarias.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _colunaResumo(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.blue[800])),
        Text(
          val,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildExtrasSection() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: _filtrarExtras,
          decoration: InputDecoration(
            hintText: "Buscar serviço extra...",
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: Icon(Icons.clear), onPressed: () {_searchController.clear(); _filtrarExtras('');}) : null,
            contentPadding: EdgeInsets.symmetric(horizontal: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true, fillColor: Colors.white,
          ),
        ),
        SizedBox(height: 10),
        Container(
          height: 150,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(8)),
          child: ListView.separated(
            itemCount: _extrasFiltrados.length,
            separatorBuilder: (_, __) => Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _extrasFiltrados[index];
              return ListTile(
                dense: true,
                title: Text(item['nome']),
                trailing: Text("+ R\$ ${item['preco']}", style: TextStyle(color: widget.corAcai, fontWeight: FontWeight.bold)),
                onTap: () {
                  setState(() {
                    _extrasSelecionados.add(item);
                    _searchController.clear();
                    _filtrarExtras('');
                  });
                },
              );
            },
          ),
        ),
        if (_extrasSelecionados.isNotEmpty) ...[
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _extrasSelecionados.asMap().entries.map((entry) => Chip(
              label: Text("${entry.value['nome']} (R\$ ${entry.value['preco']})"),
              backgroundColor: widget.corAcai.withOpacity(0.1),
              deleteIcon: Icon(Icons.close, size: 14),
              onDeleted: () => setState(() => _extrasSelecionados.removeAt(entry.key)),
            )).toList(),
          )
        ]
      ],
    );
  }

  Widget _buildPaymentButton(String label, IconData icon, String value) {
    bool isSelected = _metodoPagamento == value;
    return InkWell(
      onTap: () => setState(() => _metodoPagamento = value),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? widget.corAcai : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? widget.corAcai : Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.grey[600]),
            SizedBox(height: 5),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: isSelected ? Colors.white : Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label + ": ", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color ?? Colors.black87)),
        ],
      ),
    );
  }
}
