import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class ProductEditorDialog extends StatefulWidget {
  final DocumentSnapshot? produto; // Se null, é criação. Se não, é edição.

  const ProductEditorDialog({super.key, this.produto});

  @override
  _ProductEditorDialogState createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<ProductEditorDialog> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _custoCtrl = TextEditingController();
  final _margemCtrl = TextEditingController();
  final _precoCtrl = TextEditingController();
  final _estoqueCtrl = TextEditingController(text: '0');
  final _validadeCtrl = TextEditingController();

  DateTime? _dataValidade;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.produto != null) {
      final data = widget.produto!.data() as Map<String, dynamic>;
      _nomeCtrl.text = data['nome'] ?? '';
      _marcaCtrl.text = data['marca'] ?? '';
      _codigoCtrl.text = data['codigo_barras'] ?? '';
      _custoCtrl.text = (data['preco_custo'] ?? 0.0).toString();
      _margemCtrl.text = (data['margem_lucro'] ?? 0.0).toString();
      _precoCtrl.text = (data['preco'] ?? 0.0).toString();
      _estoqueCtrl.text = (data['qtd_estoque'] ?? 0).toString();

      if (data['data_validade'] != null) {
        _dataValidade = (data['data_validade'] as Timestamp).toDate();
        _validadeCtrl.text = DateFormat('dd/MM/yyyy').format(_dataValidade!);
      }
    }
  }

  void _calcularPrecoFinal() {
    double custo = double.tryParse(_custoCtrl.text.replaceAll(',', '.')) ?? 0.0;
    double margem =
        double.tryParse(_margemCtrl.text.replaceAll(',', '.')) ?? 0.0;

    if (custo > 0) {
      double lucro = custo * (margem / 100);
      double finalPrice = custo + lucro;
      _precoCtrl.text = finalPrice.toStringAsFixed(2);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      double custo =
          double.tryParse(_custoCtrl.text.replaceAll(',', '.')) ?? 0.0;
      double margem =
          double.tryParse(_margemCtrl.text.replaceAll(',', '.')) ?? 0.0;
      double preco =
          double.tryParse(_precoCtrl.text.replaceAll(',', '.')) ?? 0.0;
      int estoque = int.tryParse(_estoqueCtrl.text) ?? 0;

      final data = {
        'nome': _nomeCtrl.text,
        'marca': _marcaCtrl.text,
        'codigo_barras': _codigoCtrl.text,
        'preco_custo': custo,
        'margem_lucro': margem,
        'preco': preco,
        'qtd_estoque': estoque,
        'data_validade': _dataValidade != null
            ? Timestamp.fromDate(_dataValidade!)
            : null,
        'atualizado_em': FieldValue.serverTimestamp(),
      };

      if (widget.produto == null) {
        // Criar
        data['qtd_vendida'] = 0;
        data['criado_em'] = FieldValue.serverTimestamp();
        await _db.collection('produtos').add(data);
      } else {
        // Editar
        await _db.collection('produtos').doc(widget.produto!.id).update(data);
      }

      if (mounted) {
        Navigator.pop(context, true); // Retorna true para indicar sucesso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.produto == null
                  ? "Produto criado com sucesso!"
                  : "Produto atualizado com sucesso!",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao salvar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text(
        widget.produto == null ? "Cadastrar Novo Produto" : "Editar Produto",
      ),
      content: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nomeCtrl,
                  decoration: InputDecoration(
                    labelText: "Nome do Produto",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo obrigatório' : null,
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _marcaCtrl,
                        decoration: InputDecoration(
                          labelText: "Marca",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: TextFormField(
                        controller: _codigoCtrl,
                        decoration: InputDecoration(
                          labelText: "Cód. Barras",
                          prefixIcon: Icon(FontAwesomeIcons.barcode, size: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _custoCtrl,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: "Preço Custo (R\$)",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (_) => _calcularPrecoFinal(),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: TextFormField(
                        controller: _margemCtrl,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: "Lucro (%)",
                          suffixText: "%",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (_) => _calcularPrecoFinal(),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _estoqueCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Estoque",
                          prefixIcon: Icon(Icons.inventory_2, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: TextFormField(
                        controller: _precoCtrl,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: "Preço Final (R\$)",
                          prefixIcon: Icon(Icons.attach_money, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.green[50],
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Campo obrigatório' : null,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                TextFormField(
                  controller: _validadeCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "Data de Validade (Opcional)",
                    prefixIcon: Icon(Icons.calendar_today, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: _dataValidade != null
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _dataValidade = null;
                                _validadeCtrl.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _dataValidade ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(Duration(days: 365)),
                      lastDate: DateTime.now().add(Duration(days: 365 * 5)),
                    );
                    if (picked != null) {
                      setState(() {
                        _dataValidade = picked;
                        _validadeCtrl.text = DateFormat(
                          'dd/MM/yyyy',
                        ).format(picked);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF4A148C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _isLoading ? null : _salvar,
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text("Salvar"),
        ),
      ],
    );
  }
}
