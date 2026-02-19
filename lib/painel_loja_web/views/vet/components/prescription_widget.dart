import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PrescriptionWidget extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onChanged;
  const PrescriptionWidget({super.key, required this.onChanged});

  @override
  State<PrescriptionWidget> createState() => _PrescriptionWidgetState();
}

class _PrescriptionWidgetState extends State<PrescriptionWidget> {
  final List<Map<String, dynamic>> _medications = [];

  void _addMedication() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AddMedicationDialog(),
    );

    if (result != null) {
      setState(() {
        _medications.add(result);
      });
      widget.onChanged(_medications);
    }
  }

  void _removeMedication(int index) {
    setState(() {
      _medications.removeAt(index);
    });
    widget.onChanged(_medications);
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
                  "Receituário & Prescrições",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A148C),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addMedication,
                  icon: const Icon(Icons.add_circle, color: Color(0xFF4A148C)),
                  label: const Text(
                    "ADICIONAR ITEM",
                    style: TextStyle(
                      color: Color(0xFF4A148C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_medications.isEmpty)
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
                    Icon(FontAwesomeIcons.pills, color: Colors.grey, size: 30),
                    SizedBox(height: 10),
                    Text(
                      "Nenhum medicamento prescrito.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _medications.length,
                itemBuilder: (context, index) {
                  final med = _medications[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE1BEE7), // Purple[100]
                        child: Icon(
                          FontAwesomeIcons.pills,
                          color: Color(0xFF4A148C),
                          size: 16,
                        ),
                      ),
                      title: Text(
                        "${med['nome']} ${med['conc']}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Dose: ${med['dose']} • Freq: ${med['freq']} • Dur: ${med['duracao']}\nVia: ${med['via']}",
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeMedication(index),
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

class _AddMedicationDialog extends StatefulWidget {
  @override
  State<_AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<_AddMedicationDialog> {
  final _nomeCtrl = TextEditingController();
  final _concCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _freqCtrl = TextEditingController();
  final _duracaoCtrl = TextEditingController();
  String _via = 'Oral';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Adicionar Medicamento"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _input("Nome do Fármaco (Genérico/Comercial)", _nomeCtrl),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _input("Concentração (mg/ml)", _concCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _input("Dose (mg/kg ou ml)", _doseCtrl)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _input("Frequência (ex: 12/12h)", _freqCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _input("Duração (ex: 5 dias)", _duracaoCtrl)),
              ],
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _via,
              decoration: const InputDecoration(
                labelText: "Via de Administração",
                border: OutlineInputBorder(),
              ),
              items: [
                'Oral',
                'Subcutânea',
                'Intravenosa',
                'Intramuscular',
                'Tópica',
                'Oftálmica',
                'Otológica',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _via = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nomeCtrl.text.isEmpty) return;
            Navigator.pop(context, {
              'nome': _nomeCtrl.text,
              'conc': _concCtrl.text,
              'dose': _doseCtrl.text,
              'freq': _freqCtrl.text,
              'duracao': _duracaoCtrl.text,
              'via': _via,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A148C),
          ),
          child: const Text("Adicionar", style: TextStyle(color: Colors.white)),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 15,
        ),
        isDense: true,
      ),
    );
  }
}
