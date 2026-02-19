import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ExameFisicoForm extends StatefulWidget {
  const ExameFisicoForm({Key? key}) : super(key: key);
  @override
  ExameFisicoFormState createState() => ExameFisicoFormState();
}

class ExameFisicoFormState extends State<ExameFisicoForm> {
  final pesoCtrl = TextEditingController();
  final tempCtrl = TextEditingController();
  final fcCtrl = TextEditingController();
  final frCtrl = TextEditingController();
  final tpcCtrl = TextEditingController();
  String mucosa = 'Normocorada';

  Map<String, dynamic> getData() {
    return {
      'peso': double.tryParse(pesoCtrl.text) ?? 0.0,
      'temperatura': double.tryParse(tempCtrl.text) ?? 0.0,
      'fc': int.tryParse(fcCtrl.text) ?? 0,
      'mucosa': mucosa,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Sinais Vitais",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildNumInput(
                  "Peso (kg)",
                  pesoCtrl,
                  FontAwesomeIcons.weightScale,
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: _buildNumInput(
                  "Temp (ºC)",
                  tempCtrl,
                  FontAwesomeIcons.temperatureThreeQuarters,
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: _buildNumInput(
                  "FC (bpm)",
                  fcCtrl,
                  FontAwesomeIcons.heartPulse,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text("Avaliação Mucosas", style: TextStyle(fontSize: 16)),
          DropdownButtonFormField<String>(
            value: mucosa,
            items: [
              'Normocorada',
              'Pálida',
              'Cianótica',
              'Ictérica',
              'Congesta',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => mucosa = v!),
            decoration: InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  Widget _buildNumInput(
    String label,
    TextEditingController ctrl,
    IconData icon,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(),
      ),
    );
  }
}
