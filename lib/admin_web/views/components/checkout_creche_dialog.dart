import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

  void _confirmarCheckout() async {
    setState(() => _isLoading = true);
    try {
      List<String> extrasIds = _extrasSelecionados
          .map((e) => e['id'] as String)
          .toList();

      final result = await _functions
          .httpsCallable('realizarCheckoutCreche')
          .call({
            'reservaId': widget.reservaId,
            'extrasIds': extrasIds,
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
    double custoTotalServico = valorDiarias + valorExtras;
    double jaPago = (widget.dadosReserva['valor_pago'] ?? 0).toDouble();
    double restanteAPagar = custoTotalServico - jaPago;
    if (restanteAPagar < 0) restanteAPagar = 0;

    bool precisaPagar = restanteAPagar > 0.01;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      contentPadding: EdgeInsets.zero, // Remove padding padrão para compactar
      // HEADER COMPACTO
      titlePadding: EdgeInsets.fromLTRB(20, 15, 20, 10),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(FontAwesomeIcons.school, color: widget.corAcai, size: 20),
              SizedBox(width: 8),
              Text(
                "Checkout Creche",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          if (precisaPagar)
            Row(
              children: [
                _buildPaymentOption("Pix", FontAwesomeIcons.pix, "pix_balcao"),
                SizedBox(width: 5),
                _buildPaymentOption(
                  "Dinheiro",
                  FontAwesomeIcons.moneyBillWave,
                  "dinheiro",
                ),
                SizedBox(width: 5),
                _buildPaymentOption(
                  "Cartão",
                  FontAwesomeIcons.creditCard,
                  "cartao_credito",
                ),
              ],
            ),
        ],
      ),

      content: Container(
        width: 500,
        height: 520, // Altura fixa reduzida
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(height: 1),
            SizedBox(height: 10),

            // 1. RESUMO DA ESTADIA (Compacto)
            Text(
              "Resumo da Estadia",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 5),
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _colunaResumo("Dias", "$_diasEstadia"),
                  _colunaResumo(
                    "Diária",
                    "R\$ ${widget.precoDiaria.toStringAsFixed(2)}",
                  ),
                  Container(
                    height: 20,
                    width: 1,
                    color: Colors.blue.withOpacity(0.3),
                  ),
                  Text(
                    "Total Diárias: R\$ ${valorDiarias.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 15),

            // 2. EXTRAS (Compacto)
            Text(
              "Consumo Extra",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 5),

            // Busca
            SizedBox(
              height: 35,
              child: TextField(
                controller: _searchController,
                onChanged: _filtrarExtras,
                style: TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Buscar item...",
                  prefixIcon: Icon(Icons.search, size: 16, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _searchController.clear();
                            _filtrarExtras('');
                          },
                        )
                      : null,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ),
            SizedBox(height: 5),

            // Lista Resultados (Pequena)
            Container(
              height: 90, // Altura bem reduzida
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _extrasFiltrados.isEmpty
                  ? Center(
                      child: Text(
                        "Sem itens",
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _extrasFiltrados.length,
                      separatorBuilder: (_, __) => Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _extrasFiltrados[index];
                        return ListTile(
                          visualDensity:
                              VisualDensity.compact, // Compacta a linha
                          dense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                          title: Text(
                            item['nome'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Text(
                            "+ R\$ ${item['preco']}",
                            style: TextStyle(
                              color: widget.corAcai,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

            // Chips Selecionados (Horizontal Scroll se tiver muitos)
            if (_extrasSelecionados.isNotEmpty)
              Container(
                height: 30,
                margin: EdgeInsets.only(top: 5),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _extrasSelecionados.length,
                  separatorBuilder: (_, __) => SizedBox(width: 5),
                  itemBuilder: (context, index) {
                    final e = _extrasSelecionados[index];
                    return Chip(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      label: Text(
                        "${e['nome']} (R\$${e['preco']})",
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                      backgroundColor: widget.corAcai,
                      deleteIcon: Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.white,
                      ),
                      onDeleted: () =>
                          setState(() => _extrasSelecionados.removeAt(index)),
                    );
                  },
                ),
              ),

            Spacer(), // Empurra o resumo financeiro para o fundo

            Divider(height: 10),

            // 3. RESUMO FINANCEIRO FINAL
            _linhaFinanceira("Total Serviços", custoTotalServico, isBold: true),
            _linhaFinanceira("(-) Já Pago", -jaPago, color: Colors.green[700]),

            SizedBox(height: 5),

            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "A PAGAR",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "R\$ ${restanteAPagar.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: precisaPagar ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            // Aviso de Seleção
            if (precisaPagar && _metodoPagamento == null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "Selecione o pagamento ↗",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )
            else if (!precisaPagar)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    "✅ Conta Quitada.",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),

      actionsPadding: EdgeInsets.fromLTRB(20, 0, 20, 15),
      actions: [
        SizedBox(
          height: 35,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ),
        SizedBox(
          height: 35,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: (precisaPagar && _metodoPagamento == null)
                  ? Colors.grey[300]
                  : Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _isLoading || (precisaPagar && _metodoPagamento == null)
                ? null
                : _confirmarCheckout,
            child: _isLoading
                ? SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    "CONFIRMAR CHECKOUT",
                    style: TextStyle(
                      fontSize: 13,
                      color: (precisaPagar && _metodoPagamento == null)
                          ? Colors.grey[600]
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // --- WIDGETS AUXILIARES COMPACTOS ---

  Widget _colunaResumo(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.blue[800])),
        Text(
          val,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _linhaFinanceira(
    String label,
    double val, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "R\$ ${val.abs().toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String label, IconData icon, String value) {
    bool isSelected = _metodoPagamento == value;
    return InkWell(
      onTap: () => setState(() => _metodoPagamento = value),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? widget.corAcai : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? widget.corAcai : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
