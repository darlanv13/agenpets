import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/admin_web/widgets/product_search_widget.dart';

class CheckoutDialogPremium extends StatefulWidget {
  final String agendamentoId;
  final Map<String, dynamic> dadosAgendamento;
  final String servicoNome;
  final double valorBase; // Valor original do serviço
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

  Map<String, bool> _vouchersParaUsar = {};
  Map<String, int> _saldosDisponiveis = {};

  // Controle dos Extras e Produtos
  List<Map<String, dynamic>> _extrasSelecionados = [];
  List<Map<String, dynamic>> _produtosSelecionados = [];
  List<Map<String, dynamic>> _extrasFiltrados = [];
  TextEditingController _searchController = TextEditingController();

  String? _metodoPagamento;
  bool _isLoading = false;
  bool _jaConsumiuVoucher = false;
  Map _detalhesConsumo = {};

  @override
  void initState() {
    super.initState();
    _verificarConsumoAnterior();
    if (!_jaConsumiuVoucher) {
      _calcularSaldosVouchers();
    }
    _extrasFiltrados = widget.listaExtras;
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

  void _verificarConsumoAnterior() {
    if (widget.dadosAgendamento['vouchers_consumidos'] != null &&
        (widget.dadosAgendamento['vouchers_consumidos'] as Map).isNotEmpty) {
      _jaConsumiuVoucher = true;
      _detalhesConsumo = widget.dadosAgendamento['vouchers_consumidos'];
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
      bool autoSelect = widget.servicoNome.toLowerCase().contains(
        key.toLowerCase(),
      );
      _vouchersParaUsar[key] = autoSelect;
    });
  }

  void _adicionarProduto(Map<String, dynamic> produto) {
    setState(() {
      // Verifica se já existe para incrementar qtd
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

      await _functions.httpsCallable('realizarCheckout').call({
        'agendamentoId': widget.agendamentoId,
        'extrasIds': extrasIds,
        'produtos': produtosList,
        'metodoPagamento': _metodoPagamento,
        'vouchersParaUsar': _jaConsumiuVoucher ? {} : _vouchersParaUsar,
        'responsavel': 'Admin/Balcão',
      });

      Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro no checkout: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lógica Financeira
    double valorFinalServico = widget.valorBase;
    bool descontoAplicado = false;

    if (_jaConsumiuVoucher) {
      if (widget.dadosAgendamento['usou_voucher'] == true) {
        valorFinalServico = 0;
        descontoAplicado = true;
      }
    } else {
      _vouchersParaUsar.forEach((key, usar) {
        if (usar && (key == 'banhos' || key == 'tosa')) {
          valorFinalServico = 0;
          descontoAplicado = true;
        }
      });
    }

    double valorExtrasNovos = _extrasSelecionados.fold(
      0,
      (sum, item) => sum + item['preco'],
    );
    double valorProdutos = _produtosSelecionados.fold(
      0,
      (sum, item) => sum + (item['preco'] * item['qtd'])
    );
    double totalPagar = valorFinalServico + valorExtrasNovos + valorProdutos;
    bool precisaPagar = totalPagar > 0;

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
                      Icon(Icons.point_of_sale, color: widget.corAcai, size: 28),
                      SizedBox(width: 10),
                      Text(
                        "Checkout Agenda",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 22,
                        ),
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

            // BODY SPLIT VIEW
            Expanded(
              child: Row(
                children: [
                  // ESQUERDA: SERVIÇO, VOUCHERS, EXTRAS
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: EdgeInsets.all(25),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. VOUCHERS
                            Text("Vouchers & Assinatura", style: _sectionStyle),
                            SizedBox(height: 10),
                            _buildVouchersSection(),

                            Divider(height: 40),

                            // 2. EXTRAS
                            Text("Adicionar Extras (Serviços)", style: _sectionStyle),
                            SizedBox(height: 10),
                            _buildExtrasSection(),
                          ],
                        ),
                      ),
                    ),
                  ),

                  VerticalDivider(width: 1),

                  // DIREITA: PRODUTOS
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

            // FOOTER: PAGAMENTO E TOTAL
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
                         _buildResumoRow("Serviço Base", "R\$ ${widget.valorBase.toStringAsFixed(2)}"),
                         if(descontoAplicado)
                           _buildResumoRow("Desconto", "- R\$ ${widget.valorBase.toStringAsFixed(2)}", color: Colors.green),
                         if(valorExtrasNovos > 0)
                           _buildResumoRow("Extras", "+ R\$ ${valorExtrasNovos.toStringAsFixed(2)}"),
                         if(valorProdutos > 0)
                            _buildResumoRow("Produtos", "+ R\$ ${valorProdutos.toStringAsFixed(2)}"),
                       ],
                     ),
                   ),
                   Container(width: 1, height: 60, color: Colors.grey[300], margin: EdgeInsets.symmetric(horizontal: 20)),
                   Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                       Text("TOTAL A PAGAR", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                       Text("R\$ ${totalPagar.toStringAsFixed(2)}", style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: widget.corAcai)),
                     ],
                   ),
                   SizedBox(width: 30),
                   if (precisaPagar) ...[
                     _buildPaymentButton("Pix", FontAwesomeIcons.pix, "pix_balcao"),
                     SizedBox(width: 10),
                     _buildPaymentButton("Dinheiro", FontAwesomeIcons.moneyBillWave, "dinheiro"),
                     SizedBox(width: 10),
                     _buildPaymentButton("Cartão", FontAwesomeIcons.creditCard, "cartao"),
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

  Widget _buildVouchersSection() {
    if (_jaConsumiuVoucher) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green),
            SizedBox(width: 5),
            Text("Voucher aplicado", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800])),
          ],
        ),
      );
    } else if (_saldosDisponiveis.isNotEmpty) {
      return Column(
        children: _saldosDisponiveis.keys.map((key) => CheckboxListTile(
          title: Text(key.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Disponível: ${_saldosDisponiveis[key]}"),
          value: _vouchersParaUsar[key] ?? false,
          activeColor: widget.corAcai,
          onChanged: (v) => setState(() => _vouchersParaUsar[key] = v!),
          secondary: Icon(FontAwesomeIcons.ticket, color: Colors.orange),
          contentPadding: EdgeInsets.zero,
          dense: true,
        )).toList(),
      );
    } else {
      return Text("Sem vouchers disponíveis.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    }
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
