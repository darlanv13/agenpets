import 'package:agenpet/config/app_config.dart';
import 'package:agenpet/painel_loja_web/services/caixa_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum CheckoutContext { hotel, creche, agenda }

class UnifiedCheckoutDialog extends StatefulWidget {
  final CheckoutContext contextType;
  final String referenceId; // reservaId or agendamentoId
  final String? userId; // Client User ID for voucher lookup
  final Map<String, dynamic> clientData; // User data for display info
  final Map<String, dynamic> baseItem; // {nome, preco, detalhes, ...}
  final List<Map<String, dynamic>> availableServices; // "Catalog" of extras
  final double totalAlreadyPaid;
  final Map<String, dynamic>? vouchersConsumedHistory; // From agenda history
  final Color themeColor;
  final VoidCallback onSuccess;

  const UnifiedCheckoutDialog({
    super.key,
    required this.contextType,
    required this.referenceId,
    this.userId,
    required this.clientData,
    required this.baseItem,
    required this.availableServices,
    required this.totalAlreadyPaid,
    this.vouchersConsumedHistory,
    this.themeColor = const Color(0xFF4A148C),
    required this.onSuccess,
  });

  @override
  _UnifiedCheckoutDialogState createState() => _UnifiedCheckoutDialogState();
}

class _UnifiedCheckoutDialogState extends State<UnifiedCheckoutDialog> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // State - Extras
  final List<Map<String, dynamic>> _addedExtras = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // State - Vouchers
  Map<String, bool> _vouchersToUse = {};
  Map<String, int> _availableVouchers = {};
  bool _voucherConsumedPreviously = false;
  bool _loadingVouchers = true;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initExtrasFromBaseItem();
    _loadVouchers();
    _performSearch(''); // Init with available services
  }

  void _initExtrasFromBaseItem() {
    if (widget.baseItem.containsKey('servicos_extras')) {
      final extras = widget.baseItem['servicos_extras'];
      if (extras is List) {
        for (var item in extras) {
          if (item is Map) {
            try {
              _addedExtras.add(Map<String, dynamic>.from(item));
            } catch (e) {
              print("Erro ao carregar extra inicial: $e");
            }
          }
        }
      }
    }
  }

  String? _getCategoryForBaseItem() {
    String baseName = (widget.baseItem['nome'] ?? '').toString();
    try {
      final service = widget.availableServices.firstWhere(
        (s) =>
            (s['nome'] ?? '').toString().toLowerCase() ==
            baseName.toLowerCase(),
        orElse: () => {},
      );
      return service['categoria'];
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadVouchers() async {
    _availableVouchers = {};
    _vouchersToUse = {};

    if (widget.vouchersConsumedHistory != null &&
        widget.vouchersConsumedHistory!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _voucherConsumedPreviously = true;
          _loadingVouchers = false;
        });
      }
      return;
    }

    if (widget.userId == null) {
      if (mounted) setState(() => _loadingVouchers = false);
      return;
    }

    try {
      final voucherDoc = await _db
          .collection('users')
          .doc(widget.userId)
          .collection('vouchers')
          .doc(AppConfig.tenantId)
          .get();

      if (voucherDoc.exists) {
        final data = voucherDoc.data()!;
        Timestamp? validade = data['validade'];
        if (validade != null && validade.toDate().isAfter(DateTime.now())) {
          data.forEach((key, value) {
            if (key != 'nome_pacote' &&
                key != 'validade' &&
                key != 'ultima_compra' &&
                value is int &&
                value > 0) {
              _availableVouchers[key] = (_availableVouchers[key] ?? 0) + value;
            }
          });
        }
      }

      String baseName = (widget.baseItem['nome'] ?? '')
          .toString()
          .toLowerCase();
      String? category = _getCategoryForBaseItem();

      _availableVouchers.forEach((key, value) {
        bool match = false;
        String keyLower = key.toLowerCase();

        if (baseName.contains(keyLower)) match = true;
        if (category != null) {
          if (category == 'Banho' && keyLower.contains('banho')) match = true;
          if (category == 'Tosa' && keyLower.contains('tosa')) match = true;
        }

        if (match) {
          _vouchersToUse[key] = true;
        }
      });
    } catch (e) {
      print("Erro ao carregar vouchers: $e");
    } finally {
      if (mounted) setState(() => _loadingVouchers = false);
    }
  }

  // --- CALCULATIONS ---

  double get _totalBase => (widget.baseItem['preco'] ?? 0).toDouble();

  double get _totalExtras =>
      _addedExtras.fold(0, (sum, item) => sum + (item['preco'] as double));

  double get _discountVoucher {
    if (_voucherConsumedPreviously) return _totalBase;

    double discount = 0;
    _vouchersToUse.forEach((key, active) {
      if (active) {
        String baseName = (widget.baseItem['nome'] ?? '')
            .toString()
            .toLowerCase();
        String? category = _getCategoryForBaseItem();
        bool match = false;
        String keyLower = key.toLowerCase();

        if (baseName.contains(keyLower)) match = true;
        if (category != null) {
          if (category == 'Banho' && keyLower.contains('banho')) match = true;
          if (category == 'Tosa' && keyLower.contains('tosa')) match = true;
        }

        if (match) discount = _totalBase;
      }
    });
    return discount;
  }

  double get _totalDue => (_totalBase + _totalExtras) - _discountVoucher;

  double get _remainingToPay {
    double val = _totalDue - widget.totalAlreadyPaid;
    return val > 0 ? val : 0.0;
  }

  // --- SEARCH LOGIC ---

  void _performSearch(String query) async {
    setState(() => _isSearching = true);

    List<Map<String, dynamic>> localResults = [];
    if (query.isEmpty) {
      localResults = List.from(widget.availableServices);
    } else {
      localResults = widget.availableServices
          .where((item) {
            final nome = (item['nome'] ?? '').toString().toLowerCase();
            return nome.contains(query.toLowerCase());
          })
          .map((e) => {...e, 'type': 'service'})
          .toList();
    }

    List<Map<String, dynamic>> remoteResults = [];
    if (query.isNotEmpty) {
      try {
        String searchQuery = query;
        if (query.isNotEmpty && query[0] == query[0].toLowerCase()) {
          searchQuery = query[0].toUpperCase() + query.substring(1);
        }

        final snapshot = await _db
            .collection('tenants')
            .doc(AppConfig.tenantId)
            .collection('produtos')
            .orderBy('nome')
            .startAt([searchQuery])
            .endAt(['$searchQuery\uf8ff'])
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

  // --- NEW SUBMIT LOGIC (SEND TO PDV) ---

  void _submitCheckout() async {
    setState(() => _isLoading = true);

    try {
      // 1. Verify if Caja is Open
      final isOpen = await CaixaService.isCaixaAberto(AppConfig.tenantId);
      if (!isOpen) {
        setState(() => _isLoading = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 10),
                  Text("Caixa Fechado"),
                ],
              ),
              content: Text(
                "O caixa do PDV precisa estar aberto para receber este serviço.\nPor favor, abra o caixa na tela de PDV/Loja.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("OK, Entendi"),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 2. Construct Items List
      // Base Item + Extras
      List<Map<String, dynamic>> itensComanda = [];

      // Add Base Item
      if (_totalBase > 0 || _discountVoucher > 0) {
        // If voucher covers it, we still add it but maybe price is affected?
        // Comanda logic: Items list usually sums to total.
        // If we have a voucher discount, we can add it as a negative item or just adjust base price.
        // Let's add the base item with full price, and a discount item if applicable.
        itensComanda.add({
          'nome': widget.baseItem['nome'],
          'preco': _totalBase,
          'tipo': 'servico_base',
        });
      }

      // Add Extras
      for (var extra in _addedExtras) {
        itensComanda.add({
          'nome': extra['nome'],
          'preco': (extra['preco'] as num).toDouble(),
          'tipo': 'extra',
          'id_origem': extra['id'],
        });
      }

      // Add Voucher Discount as Item (Negative Price)
      if (_discountVoucher > 0) {
        itensComanda.add({
          'nome': 'Desconto Voucher / Pacote',
          'preco': -_discountVoucher,
          'tipo': 'desconto',
        });
      }

      // Already Paid deduction?
      // Usually "Already Paid" means we only charge the difference.
      // If we send to PDV, we should probably only send the *difference* to be paid?
      // Or send everything and let PDV handle "Total vs Paid"?
      // For simplicity in PDV, let's send the *amount due* as the billable items.
      // But if we add "Base Item $50" and "Already Paid $20", the PDV cart will show $50.
      // We should insert a "Pagamento Anterior" item.
      if (widget.totalAlreadyPaid > 0) {
        itensComanda.add({
          'nome': 'Pagamento Adiantado / Parcial',
          'preco': -widget.totalAlreadyPaid,
          'tipo': 'deducao',
        });
      }

      // 3. Create Comanda
      String origemCollection = '';
      if (widget.contextType == CheckoutContext.agenda) origemCollection = 'agendamentos';
      if (widget.contextType == CheckoutContext.hotel) origemCollection = 'reservas_hotel';
      if (widget.contextType == CheckoutContext.creche) origemCollection = 'reservas_creche';

      final comandaData = {
        'tenantId': AppConfig.tenantId,
        'cliente_nome': widget.clientData['nome'] ?? 'Cliente Não Identificado',
        'cliente_id': widget.userId,
        'valor_total': _remainingToPay, // This matches sum of items
        'itens': itensComanda,
        'origem_tipo': widget.contextType.toString().split('.').last,
        'origem_collection': origemCollection,
        'origem_id': widget.referenceId,
        'status': 'aberta',
        'created_at': FieldValue.serverTimestamp(),
        'vouchers_usados': _vouchersToUse,
      };

      await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('comandas')
          .add(comandaData);

      // 4. Update Original Document
      final docRef = _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection(origemCollection)
          .doc(widget.referenceId);

      await docRef.update({
        'enviado_pdv': true,
        'status_pagamento': 'no_caixa', // Optional flag
        'servicos_extras': _addedExtras, // Save selected extras
        'valor_final_calculado': _remainingToPay + widget.totalAlreadyPaid, // Total value
      });

      // 5. Success
      if (mounted) {
        Navigator.pop(context); // Close Dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("Enviado para o Caixa com Sucesso!"),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        widget.onSuccess();
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao enviar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildFinancialRow(
    String label,
    double val, {
    Color? color,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
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
      content: SizedBox(
        width: 900,
        height: 600, // Reduced height as payment section is gone
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

            // RIGHT: SUMMARY & ACTIONS
            Expanded(
              flex: 5,
              child: Container(
                color: Colors.grey[50],
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Resumo & Envio",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                          tooltip: "Fechar",
                        ),
                      ],
                    ),
                    SizedBox(height: 15),

                    // VOUCHERS SECTION
                    if (_loadingVouchers)
                      Container(
                        height: 100,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_voucherConsumedPreviously)
                      Container(
                        padding: EdgeInsets.all(10),
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.history,
                              size: 20,
                              color: Colors.green[700],
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Voucher já consumido nesta reserva.",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_availableVouchers.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            FontAwesomeIcons.ticket,
                            size: 14,
                            color: Colors.amber[800],
                          ),
                          SizedBox(width: 8),
                          Text(
                            "SEUS VOUCHERS",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey[700],
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 100, // Scrollable Area fixed height
                        margin: EdgeInsets.only(bottom: 12),
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
                              String key = _availableVouchers.keys.elementAt(
                                index,
                              );
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
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.amber[50]
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.amber[100]
                                                : Colors.grey[100],
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isSelected
                                                ? Icons.check
                                                : FontAwesomeIcons.ticket,
                                            size: 16,
                                            color: isSelected
                                                ? Colors.amber[800]
                                                : Colors.grey,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                key.toUpperCase(),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                "Disponíveis: $qtd",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              "USAR",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
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

                    Spacer(),

                    // FINANCIAL SUMMARY
                    _buildFinancialRow("Valor Base", _totalBase),
                    if (_discountVoucher > 0)
                      _buildFinancialRow(
                        "Desconto Voucher",
                        -_discountVoucher,
                        color: Colors.green,
                      ),
                    _buildFinancialRow("Extras", _totalExtras),
                    Divider(),
                    _buildFinancialRow(
                      "TOTAL GERAL",
                      _totalBase + _totalExtras,
                      isBold: true,
                    ),
                    _buildFinancialRow(
                      "(-) Já Pago",
                      -widget.totalAlreadyPaid,
                      color: Colors.blue,
                    ),

                    SizedBox(height: 10),

                    Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: _remainingToPay <= 0.01
                            ? Colors.green[50]
                            : Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                           color: _remainingToPay <= 0.01 ? Colors.green[200]! : Colors.blue[200]!
                        )
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "A RECEBER NO CAIXA",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                                fontSize: 12
                            ),
                          ),
                          Text(
                            "R\$ ${_remainingToPay.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: _remainingToPay <= 0.01
                                  ? Colors.green[800]
                                  : Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    Text(
                      "Ao enviar, o cliente aparecerá na lista de 'Serviços' no PDV para pagamento.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic
                      ),
                    ),

                    SizedBox(height: 10),

                    // SEND BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        icon: _isLoading ? SizedBox() : Icon(Icons.point_of_sale),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 5
                        ),
                        onPressed: (_isLoading)
                            ? null
                            : _submitCheckout,
                        label: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                "ENVIAR PARA O CAIXA",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 16
                                ),
                              ),
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
          widget.contextType == CheckoutContext.hotel
              ? FontAwesomeIcons.hotel
              : widget.contextType == CheckoutContext.creche
              ? FontAwesomeIcons.school
              : FontAwesomeIcons.calendarCheck,
          color: widget.themeColor,
          size: 24,
        ),
        SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Checkout ${widget.contextType == CheckoutContext.hotel
                  ? 'Hotel'
                  : widget.contextType == CheckoutContext.creche
                  ? 'Creche'
                  : 'Agenda'}",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              "Revise os valores e envie ao caixa",
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
        hintText: "Adicionar serviços ou produtos...",
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
      return Center(
        child: Text(
          "Nenhum item encontrado.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final isProduct = item['type'] == 'product';
        String? subtitle;

        if (isProduct) {
          subtitle = item['brand'] ?? '';
        } else {
          // Service logic
          List<String> parts = [];
          if (item['porte'] != null && item['porte'].toString().isNotEmpty) {
            parts.add("Porte: ${item['porte']}");
          }
          if (item['pelagem'] != null &&
              item['pelagem'].toString().isNotEmpty) {
            parts.add("Pelagem: ${item['pelagem']}");
          }
          if (parts.isNotEmpty) {
            subtitle = parts.join(" | ");
          }
        }

        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          leading: CircleAvatar(
            backgroundColor: isProduct ? Colors.orange[50] : Colors.blue[50],
            radius: 15,
            child: Icon(
              isProduct ? FontAwesomeIcons.box : FontAwesomeIcons.conciergeBell,
              size: 14,
              color: isProduct ? Colors.orange : Colors.blue,
            ),
          ),
          title: Text(
            item['nome'],
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          subtitle: subtitle != null
              ? Text(subtitle, style: TextStyle(fontSize: 10))
              : null,
          trailing: Text(
            "+ R\$ ${(item['preco'] as double).toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: widget.themeColor,
            ),
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
        Text(
          "Itens Adicionados:",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(item['nome'], style: TextStyle(fontSize: 12)),
                    ),
                    Text(
                      "R\$ ${(item['preco'] as double).toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
