import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class VaccineWidget extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onChanged;
  const VaccineWidget({super.key, required this.onChanged});

  @override
  State<VaccineWidget> createState() => _VaccineWidgetState();
}

class _VaccineWidgetState extends State<VaccineWidget> {
  final List<Map<String, dynamic>> _vaccines = [];

  void _addVaccine() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AddVaccineDialog(),
    );

    if (result != null) {
      setState(() {
        _vaccines.add(result);
      });
      widget.onChanged(_vaccines);
    }
  }

  void _removeVaccine(int index) {
    setState(() {
      _vaccines.removeAt(index);
    });
    widget.onChanged(_vaccines);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Controle de Vacinas",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4A148C)),
                ),
                TextButton.icon(
                  onPressed: _addVaccine,
                  icon: const Icon(Icons.add_circle, color: Color(0xFF4A148C)),
                  label: const Text("LANÇAR VACINA", style: TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_vaccines.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Column(
                  children: [
                    Icon(FontAwesomeIcons.syringe, color: Colors.grey, size: 30),
                    SizedBox(height: 10),
                    Text("Nenhuma vacina aplicada nesta consulta.", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _vaccines.length,
                itemBuilder: (context, index) {
                  final vac = _vaccines[index];
                  final revac = vac['revac_data'] != null
                      ? DateFormat('dd/MM/yyyy').format((vac['revac_data'] as DateTime))
                      : 'Não agendada';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFC5CAE9), // Indigo[100]
                        child: Icon(FontAwesomeIcons.syringe, color: Color(0xFF3F51B5), size: 16),
                      ),
                      title: Text(
                        vac['nome'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Lab: ${vac['lab']} • Lote: ${vac['lote']}\nRevacinação: $revac",
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removeVaccine(index),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AddVaccineDialog extends StatefulWidget {
  @override
  State<_AddVaccineDialog> createState() => _AddVaccineDialogState();
}

class _AddVaccineDialogState extends State<_AddVaccineDialog> {
  final _nomeCtrl = TextEditingController();
  final _labCtrl = TextEditingController();
  final _loteCtrl = TextEditingController();
  DateTime? _revacDate;

  final List<String> _commonVaccines = ['V8', 'V10', 'Antirrábica', 'Giárdia', 'Tosse dos Canis (Gripe)', 'Leishmaniose'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Registrar Vacina"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Autocomplete for common vaccines
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<String>.empty();
                }
                return _commonVaccines.where((String option) {
                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                _nomeCtrl.text = selection;
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                // Sync internal controller if user types manually
                textEditingController.addListener(() {
                  _nomeCtrl.text = textEditingController.text;
                });
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: "Nome da Vacina (ex: V10)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(FontAwesomeIcons.syringe, size: 16),
                  ),
                );
              },
            ),
            const SizedBox(height: 15),
            _input("Laboratório / Fabricante", _labCtrl),
            const SizedBox(height: 15),
            _input("Lote / Série", _loteCtrl),
            const SizedBox(height: 15),

            // Date Picker for Revaccination
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 365)), // Default 1 year
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (date != null) setState(() => _revacDate = date);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: "Data de Revacinação",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_month),
                ),
                child: Text(
                  _revacDate != null ? DateFormat('dd/MM/yyyy').format(_revacDate!) : "Selecione a data",
                  style: TextStyle(color: _revacDate != null ? Colors.black : Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: () {
            if (_nomeCtrl.text.isEmpty) return;
            Navigator.pop(context, {
              'nome': _nomeCtrl.text,
              'lab': _labCtrl.text,
              'lote': _loteCtrl.text,
              'revac_data': _revacDate, // Can be null
            });
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C)),
          child: const Text("Registrar", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _input(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        isDense: true,
      ),
    );
  }
}
