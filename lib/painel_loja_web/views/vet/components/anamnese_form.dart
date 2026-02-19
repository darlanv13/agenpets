import 'package:flutter/material.dart';

class AnamneseForm extends StatefulWidget {
  const AnamneseForm({Key? key}) : super(key: key);
  @override
  AnamneseFormState createState() => AnamneseFormState();
}

class AnamneseFormState extends State<AnamneseForm> {
  final queixaCtrl = TextEditingController();
  final historicoCtrl = TextEditingController();
  final alimentacaoCtrl = TextEditingController();

  Map<String, dynamic> getData() {
    return {
      'queixa': queixaCtrl.text,
      'historico': historicoCtrl.text,
      'alimentacao': alimentacaoCtrl.text,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          _buildInput("Queixa Principal", queixaCtrl, maxLines: 2),
          SizedBox(height: 15),
          _buildInput(
            "Histórico da Moléstia Atual (HMA)",
            historicoCtrl,
            maxLines: 5,
          ),
          SizedBox(height: 15),
          _buildInput("Alimentação e Hábitos", alimentacaoCtrl),
        ],
      ),
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
