import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// REPARE: Classe pública (sem o underline no início)
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

  List<Map<String, dynamic>> _extrasSelecionados = [];
  String? _extraSelecionadoId;
  String _metodoPagamento = 'dinheiro';
  bool _isLoading = false;

  int get _diasEstadia {
    final checkIn = widget.dadosReserva['check_in_real'] != null
        ? (widget.dadosReserva['check_in_real'] as Timestamp).toDate()
        : (widget.dadosReserva['check_in'] as Timestamp).toDate();
    final checkOut = DateTime.now();
    int dias = checkOut.difference(checkIn).inDays;
    return dias < 1 ? 1 : dias; // Mínimo 1 diária
  }

  void _confirmar() async {
    setState(() => _isLoading = true);
    try {
      List<String> extrasIds = _extrasSelecionados
          .map((e) => e['id'] as String)
          .toList();

      final result = await _functions.httpsCallable('realizarCheckoutHotel').call({
        'reservaId': widget.reservaId,
        'extrasIds': extrasIds,
        // Envia o método apenas se houver cobrança pendente no cálculo do backend
        'metodoPagamentoDiferenca': _metodoPagamento,
      });

      final ret = result.data as Map;

      // Feedback visual do valor cobrado
      double cobradoAgora = (ret['valorCobradoAgora'] ?? 0).toDouble();
      String msg = cobradoAgora > 0
          ? "Checkout: Cobrado R\$ ${cobradoAgora.toStringAsFixed(2)}"
          : "Checkout: Tudo já estava pago! ✅";
      print(msg);

      Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      setState(() => _isLoading = false);
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text("Erro"),
          content: Text("$e"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text("OK")),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Calcula Custo Total
    double valorDiarias = _diasEstadia * widget.precoDiaria;
    double valorExtras = _extrasSelecionados.fold(
      0,
      (sum, item) => sum + item['preco'],
    );
    double custoTotalServico = valorDiarias + valorExtras;

    // 2. Recupera o que já foi pago
    double jaPago = (widget.dadosReserva['valor_pago'] ?? 0).toDouble();

    // 3. Calcula o que falta
    double restanteAPagar = custoTotalServico - jaPago;
    if (restanteAPagar < 0) restanteAPagar = 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.corAcai,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(FontAwesomeIcons.fileInvoiceDollar, color: Colors.white),
                  SizedBox(width: 15),
                  Text(
                    "Finalizar Estadia",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resumo Dias
                  _linhaResumo(
                    "Dias de Estadia (${_diasEstadia}d)",
                    valorDiarias,
                  ),

                  // Extras (Lista Visual)
                  if (_extrasSelecionados.isNotEmpty) ...[
                    SizedBox(height: 10),
                    Text(
                      "Extras:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    ..._extrasSelecionados.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "+ ${e['nome']}",
                              style: TextStyle(fontSize: 12),
                            ),
                            InkWell(
                              onTap: () =>
                                  setState(() => _extrasSelecionados.remove(e)),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Área para adicionar mais extras
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _extraSelecionadoId,
                          hint: Text("Adicionar Serviço Extra..."),
                          isDense: true,
                          items: widget.listaExtras
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e['id'].toString(),
                                  child: Text(
                                    "${e['nome']} (+ R\$ ${e['preco']})",
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _extraSelecionadoId = v),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle, color: widget.corAcai),
                        onPressed: () {
                          if (_extraSelecionadoId != null) {
                            final item = widget.listaExtras.firstWhere(
                              (e) => e['id'] == _extraSelecionadoId,
                            );
                            setState(() {
                              _extrasSelecionados.add(item);
                              _extraSelecionadoId = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),

                  Divider(height: 30),

                  // RESUMO FINANCEIRO
                  Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _linhaResumo(
                          "TOTAL DO SERVIÇO",
                          custoTotalServico,
                          isBold: true,
                        ),
                        SizedBox(height: 5),
                        _linhaResumo(
                          "(-) JÁ PAGO",
                          -jaPago,
                          color: Colors.green[700],
                        ),
                        Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "A PAGAR AGORA:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              "R\$ ${restanteAPagar.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: restanteAPagar > 0.01
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // Pagamento (Só exibe se dever algo)
                  if (restanteAPagar > 0.01) ...[
                    DropdownButtonFormField<String>(
                      value: _metodoPagamento,
                      decoration: InputDecoration(
                        labelText: "Forma de Pagamento (Restante)",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'dinheiro',
                          child: Text("Dinheiro"),
                        ),
                        DropdownMenuItem(
                          value: 'pix_balcao',
                          child: Text("Pix"),
                        ),
                        DropdownMenuItem(
                          value: 'cartao_credito',
                          child: Text("Cartão de Crédito"),
                        ),
                      ],
                      onChanged: (v) => setState(() => _metodoPagamento = v!),
                    ),
                  ] else ...[
                    Container(
                      padding: EdgeInsets.all(10),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          "Conta Quitada! ✅",
                          style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: 20),

                  // Botões
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: Text(
                            "CANCELAR",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isLoading ? null : _confirmar,
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  "CONFIRMAR SAÍDA",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linhaResumo(
    String label,
    double val, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
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
            "R\$ ${val.abs().toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
