import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

enum CheckoutContext {
  hotel,
  creche,
  agenda,
}

class UnifiedCheckoutDialog extends StatefulWidget {
  final CheckoutContext contextType;
  final String referenceId; // reservaId or agendamentoId
  final Map<String, dynamic> clientData; // User data for vouchers
  final Map<String, dynamic> baseItem; // {nome, preco, detalhes, ...}
  final List<Map<String, dynamic>> availableServices; // "Catalog" of extras (servicos_extras)
  final double totalAlreadyPaid;
  final Map<String, dynamic>? vouchersConsumedHistory; // From agenda history
  final Color themeColor;
  final VoidCallback onSuccess;

  const UnifiedCheckoutDialog({
    Key? key,
    required this.contextType,
    required this.referenceId,
    required this.clientData,
    required this.baseItem,
    required this.availableServices,
    required this.totalAlreadyPaid,
    this.vouchersConsumedHistory,
    this.themeColor = const Color(0xFF4A148C),
    required this.onSuccess,
  }) : super(key: key);

  @override
  _UnifiedCheckoutDialogState createState() => _UnifiedCheckoutDialogState();
}

class _UnifiedCheckoutDialogState extends State<UnifiedCheckoutDialog> {
  final _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // State - Extras
  List<Map<String, dynamic>> _addedExtras = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // State - Payments (Split Payment Logic)
  List<Map<String, dynamic>> _payments = [];
  String _selectedMethod = 'Dinheiro';
  final TextEditingController _amountController = TextEditingController();

  // State - Vouchers
  Map<String, bool> _vouchersToUse = {};
  Map<String, int> _availableVouchers = {};
  bool _voucherConsumedPreviously = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initVouchers();
    _performSearch(''); // Init with available services
  }

  void _initVouchers() {
    _availableVouchers = {};
    _vouchersToUse = {};

    // Check previous consumption (for Agenda mostly)
    if (widget.vouchersConsumedHistory != null && widget.vouchersConsumedHistory!.isNotEmpty) {
       _voucherConsumedPreviously = true;
       // If consumed, we don't init available vouchers for the base item
       return;
    }

    List<dynamic> packs = widget.clientData['voucher_assinatura'] ?? [];
    for (var pack in packs) {
      if (pack is Map) {
        Timestamp? validade = pack['validade_pacote'];
        if (validade != null && validade.toDate().isAfter(DateTime.now())) {
          pack.forEach((key, value) {
            if (key != 'nome_pacote' &&
                key != 'validade_pacote' &&
                key != 'data_compra' &&
                value is int &&
                value > 0) {
              _availableVouchers[key] = (_availableVouchers[key] ?? 0) + value;
            }
          });
        }
      }
    }

    // Auto-select if base item matches
    String baseName = (widget.baseItem['nome'] ?? '').toString().toLowerCase();
    _availableVouchers.forEach((key, value) {
      if (baseName.contains(key.toLowerCase())) {
        _vouchersToUse[key] = true;
      }
    });
  }

  // --- CALCULATIONS ---

  double get _totalBase => (widget.baseItem['preco'] ?? 0).toDouble();

  double get _totalExtras => _addedExtras.fold(0, (sum, item) => sum + (item['preco'] as double));

  double get _discountVoucher {
    // If voucher was consumed previously, full discount on base
    if (_voucherConsumedPreviously) {
      return _totalBase;
    }

    double discount = 0;

    // Agenda Logic: if 'banhos' or 'tosa' voucher is used, base service is free.
    _vouchersToUse.forEach((key, active) {
      if (active) {
         // Simple heuristic: if key matches base item, discount base price.
         String baseName = (widget.baseItem['nome'] ?? '').toString().toLowerCase();
         if (baseName.contains(key.toLowerCase())) {
           discount = _totalBase;
         }
      }
    });
    return discount;
  }

  double get _totalDue => (_totalBase + _totalExtras) - _discountVoucher;

  double get _remainingToPay {
    double paidInSession = _payments.fold(0, (sum, p) => sum + (p['valor'] as double));
    double val = _totalDue - widget.totalAlreadyPaid - paidInSession;
    return val > 0 ? val : 0.0; // Ensure no negative
  }

  // --- PAYMENT LOGIC ---

  void _addPayment() {
    double amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0) return;

    // Optional: Prevent overpayment?
    // LojaView calculates 'Troco', so overpayment is allowed there.
    // Here we stick to exact or partial.

    setState(() {
      _payments.add({
        'metodo': _selectedMethod,
        'valor': amount,
      });
      _amountController.clear();
    });
  }

  void _removePayment(int index) {
    setState(() {
      _payments.removeAt(index);
    });
  }

  // --- SEARCH LOGIC ---

  void _performSearch(String query) async {
    setState(() => _isSearching = true);

    // 1. Local Search (Services)
    List<Map<String, dynamic>> localResults = [];
    if (query.isEmpty) {
      localResults = List.from(widget.availableServices);
    } else {
      localResults = widget.availableServices.where((item) {
        final nome = (item['nome'] ?? '').toString().toLowerCase();
        return nome.contains(query.toLowerCase());
      }).map((e) => {...e, 'type': 'service'}).toList();
    }

    // 2. Remote Search (Products) - Only if query is not empty
    List<Map<String, dynamic>> remoteResults = [];
    if (query.isNotEmpty) {
      try {
        // Fallback for case sensitivity: Try to capitalize first letter if user typed lowercase
        String searchQuery = query;
        if (query.isNotEmpty && query[0] == query[0].toLowerCase()) {
           searchQuery = query[0].toUpperCase() + query.substring(1);
        }

        final snapshot = await _db.collection('produtos')
            .orderBy('nome')
            .startAt([searchQuery])
            .endAt([searchQuery + '\uf8ff'])
            .limit(20)
            .get();

        remoteResults = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'nome': data['nome'],
            'preco': (data['preco'] ?? 0).toDouble(),
            'type': 'product',
            'brand': data['marca'] ?? '',
          };
        }).toList();
      } catch (e) {
        print("Error searching products: $e");
      }
    }

    if (mounted) {
      setState(() {
        _searchResults = [...localResults, ...remoteResults];
        _isSearching = false;
      });
    }
  }

  void _addExtra(Map<String, dynamic> item) {
    setState(() {
      _addedExtras.add(item);
      _searchController.clear();
      _performSearch('');
    });
  }

  void _removeExtra(int index) {
    setState(() {
      _addedExtras.removeAt(index);
    });
  }

  void _submitCheckout() async {
    setState(() => _isLoading = true);

    try {
      // 1. Prepare Data
      List<String> extrasIds = _addedExtras.map((e) => e['id'] as String).toList();

      String paymentString;
      if (_payments.isEmpty) {
        // If remaining is 0 without payments, it implies Voucher or Pre-Paid
        if (_discountVoucher >= _totalBase && _totalExtras == 0) {
          paymentString = "voucher";
        } else {
          paymentString = "isento/ja_pago";
        }
      } else if (_payments.length == 1) {
        paymentString = _payments.first['metodo'];
      } else {
        // Composite string for backend
        paymentString = "Misto: " + _payments.map((p) => "${p['metodo']} R\$${(p['valor'] as double).toStringAsFixed(2)}").join(', ');
      }

      // 2. Call Cloud Function
      if (widget.contextType == CheckoutContext.hotel) {
        await _functions.httpsCallable('realizarCheckoutHotel').call({
          'reservaId': widget.referenceId,
          'extrasIds': extrasIds,
          'metodoPagamentoDiferenca': paymentString,
        });
      } else if (widget.contextType == CheckoutContext.creche) {
        await _functions.httpsCallable('realizarCheckoutCreche').call({
          'reservaId': widget.referenceId,
          'extrasIds': extrasIds,
          'metodoPagamentoDiferenca': paymentString,
        });
      } else if (widget.contextType == CheckoutContext.agenda) {
        // Filter used vouchers for Agenda
        Map<String, bool> usedVouchers = {};
        _vouchersToUse.forEach((key, val) {
          if (val) usedVouchers[key] = true;
        });

        await _functions.httpsCallable('realizarCheckout').call({
          'agendamentoId': widget.referenceId,
          'extrasIds': extrasIds,
          'metodoPagamento': paymentString,
          'vouchersParaUsar': usedVouchers,
          'responsavel': 'UnifiedCheckout',
        });
      }

      // 3. Success
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao finalizar: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildFinancialRow(String label, double val, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            "R\$ ${val.abs().toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black87,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      contentPadding: EdgeInsets.all(0),
      content: Container(
        width: 900,
        height: 650,
        child: Row(
          children: [
            // LEFT: SEARCH & SUMMARY
            Expanded(
              flex: 5,
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderLeft(),
                    SizedBox(height: 20),
                    _buildSearchBar(),
                    SizedBox(height: 10),
                    Expanded(child: _buildSearchResults()),
                    Divider(height: 30),
                    _buildAddedExtrasList(),
                  ],
                ),
              ),
            ),

            // RIGHT: PAYMENT & VOUCHERS
            Expanded(
              flex: 4,
              child: Container(
                color: Colors.grey[50],
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Pagamento & Vouchers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 15),

                    // VOUCHERS SECTION
                    if (_voucherConsumedPreviously)
                      Container(
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green[200]!)),
                        child: Row(children: [Icon(Icons.history, size: 20, color: Colors.green[700]), SizedBox(width: 10), Expanded(child: Text("Voucher já consumido nesta reserva.", style: TextStyle(fontSize: 13, color: Colors.green[800], fontWeight: FontWeight.bold)))]),
                      )
                    else if (_availableVouchers.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(FontAwesomeIcons.ticket, size: 14, color: Colors.amber[800]),
                          SizedBox(width: 8),
                          Text("SEUS VOUCHERS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[700], letterSpacing: 1)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 140, // Scrollable Area fixed height
                        margin: EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: ListView.separated(
                            padding: EdgeInsets.all(5),
                            itemCount: _availableVouchers.length,
                            separatorBuilder: (_, __) => Divider(height: 1),
                            itemBuilder: (ctx, index) {
                              String key = _availableVouchers.keys.elementAt(index);
                              int qtd = _availableVouchers[key]!;
                              bool isSelected = _vouchersToUse[key] ?? false;

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                     setState(() {
                                        _vouchersToUse[key] = !isSelected;
                                     });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.amber[50] : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isSelected ? Colors.amber[100] : Colors.grey[100],
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isSelected ? Icons.check : FontAwesomeIcons.ticket,
                                            size: 16,
                                            color: isSelected ? Colors.amber[800] : Colors.grey,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(key.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                                              Text("Disponíveis: $qtd", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                                            child: Text("USAR", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],

                    // FINANCIAL SUMMARY
                    _buildFinancialRow("Valor Base", _totalBase),
                    if (_discountVoucher > 0)
                      _buildFinancialRow("Desconto Voucher", -_discountVoucher, color: Colors.green),
                    _buildFinancialRow("Extras", _totalExtras),
                    Divider(),
                    _buildFinancialRow("TOTAL GERAL", _totalBase + _totalExtras, isBold: true),
                    _buildFinancialRow("(-) Já Pago", -widget.totalAlreadyPaid, color: Colors.blue),
                    _buildFinancialRow("(-) Pago Agora", -_payments.fold(0.0, (s, p) => s + (p['valor'] as double)), color: Colors.blue),
                    SizedBox(height: 10),

                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _remainingToPay <= 0.01 ? Colors.green[100] : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("RESTANTE", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            "R\$ ${_remainingToPay.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _remainingToPay <= 0.01 ? Colors.green[800] : Colors.red[800],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // ADD PAYMENT SECTION
                    if (_remainingToPay > 0.01) ...[
                      Text("Adicionar Pagamento:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[700])),
                      SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _selectedMethod,
                              items: ['Dinheiro', 'Pix', 'Cartão', 'Outro'].map((m) => DropdownMenuItem(value: m, child: Text(m, style: TextStyle(fontSize: 13)))).toList(),
                              onChanged: (v) => setState(() => _selectedMethod = v!),
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: "Valor",
                                prefixText: "R\$ ",
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onSubmitted: (_) => _addPayment(),
                            ),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.add_circle, color: Colors.green, size: 30),
                            onPressed: _addPayment,
                          ),
                        ],
                      ),
                    ],

                    SizedBox(height: 10),

                    // LIST OF ADDED PAYMENTS
                    Expanded(
                      child: ListView.separated(
                        itemCount: _payments.length,
                        separatorBuilder: (_, __) => Divider(height: 1),
                        itemBuilder: (context, index) {
                          final p = _payments[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(p['metodo'], style: TextStyle(fontSize: 13)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("R\$ ${(p['valor'] as double).toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(width: 10),
                                InkWell(onTap: () => _removePayment(index), child: Icon(Icons.close, size: 14, color: Colors.red)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // CONFIRM BUTTON
                    SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _remainingToPay <= 0.01 ? Colors.green : Colors.grey,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: (_remainingToPay <= 0.01 && !_isLoading) ? _submitCheckout : null,
                        child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text("FINALIZAR CHECKOUT", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderLeft() {
    return Row(
      children: [
        Icon(
          widget.contextType == CheckoutContext.hotel ? FontAwesomeIcons.hotel :
          widget.contextType == CheckoutContext.creche ? FontAwesomeIcons.school :
          FontAwesomeIcons.calendarCheck,
          color: widget.themeColor,
          size: 24,
        ),
        SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Checkout ${widget.contextType == CheckoutContext.hotel ? 'Hotel' : widget.contextType == CheckoutContext.creche ? 'Creche' : 'Agenda'}",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              "Adicione itens ou finalize",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (val) => _performSearch(val),
      decoration: InputDecoration(
        hintText: "Buscar serviços ou produtos...",
        prefixIcon: Icon(Icons.search, color: Colors.grey),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, size: 16),
                onPressed: () {
                  _searchController.clear();
                  _performSearch('');
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_searchResults.isEmpty) {
      return Center(child: Text("Nenhum item encontrado.", style: TextStyle(color: Colors.grey)));
    }

    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final isProduct = item['type'] == 'product';

        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          leading: CircleAvatar(
            backgroundColor: isProduct ? Colors.orange[50] : Colors.blue[50],
            child: Icon(
              isProduct ? FontAwesomeIcons.box : FontAwesomeIcons.conciergeBell,
              size: 14,
              color: isProduct ? Colors.orange : Colors.blue,
            ),
            radius: 15,
          ),
          title: Text(item['nome'], style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          subtitle: isProduct ? Text(item['brand'] ?? '', style: TextStyle(fontSize: 10)) : null,
          trailing: Text(
            "+ R\$ ${(item['preco'] as double).toStringAsFixed(2)}",
            style: TextStyle(fontWeight: FontWeight.bold, color: widget.themeColor),
          ),
          onTap: () => _addExtra(item),
        );
      },
    );
  }

  Widget _buildAddedExtrasList() {
    if (_addedExtras.isEmpty) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Itens Adicionados:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[700])),
        SizedBox(height: 5),
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ListView.separated(
            padding: EdgeInsets.all(5),
            itemCount: _addedExtras.length,
            separatorBuilder: (_, __) => SizedBox(height: 5),
            itemBuilder: (context, index) {
              final item = _addedExtras[index];
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)],
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(item['nome'], style: TextStyle(fontSize: 12))),
                    Text("R\$ ${(item['preco'] as double).toStringAsFixed(2)}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(width: 10),
                    InkWell(
                      onTap: () => _removeExtra(index),
                      child: Icon(Icons.close, size: 14, color: Colors.red),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
