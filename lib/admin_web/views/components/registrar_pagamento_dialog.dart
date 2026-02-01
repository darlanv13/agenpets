import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class RegistrarPagamentoDialog extends StatefulWidget {
  final String reservaId;
  final String nomePet;

  const RegistrarPagamentoDialog({super.key, 
    required this.reservaId,
    required this.nomePet,
  });

  @override
  _RegistrarPagamentoDialogState createState() =>
      _RegistrarPagamentoDialogState();
}

class _RegistrarPagamentoDialogState extends State<RegistrarPagamentoDialog> {
  final _valorCtrl = TextEditingController();
  String _metodo = 'dinheiro';
  bool _isLoading = false;

  void _salvar() async {
    if (_valorCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      double valor = double.parse(_valorCtrl.text.replaceAll(',', '.'));

      await FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      ).httpsCallable('registrarPagamentoHotel').call({
        'reservaId': widget.reservaId,
        'valor': valor,
        'metodo': _metodo,
      });

      Navigator.pop(context, true); // Retorna true para atualizar tela
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Registrar Pagamento Parcial"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Pagamento antecipado para: ${widget.nomePet}"),
          SizedBox(height: 20),
          TextField(
            controller: _valorCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Valor Recebido (R\$)",
              border: OutlineInputBorder(),
              prefixText: "R\$ ",
            ),
          ),
          SizedBox(height: 15),
          DropdownButtonFormField<String>(
            initialValue: _metodo,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: "Forma de Pagamento",
            ),
            items: ['dinheiro', 'pix', 'cartao_debito', 'cartao_credito']
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(m.toUpperCase().replaceAll('_', ' ')),
                  ),
                )
                .toList(),
            onChanged: (v) => _metodo = v!,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _salvar,
          child: Text(_isLoading ? "Salvando..." : "Confirmar Recebimento"),
        ),
      ],
    );
  }
}
