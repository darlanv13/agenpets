import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';

class ConfigView extends StatelessWidget {
  final _firebaseService = FirebaseService();
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController(); // Ideal usar mascara aqui

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- COLUNA 1: PREÇOS ---
        Expanded(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tabela de Preços",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Preço Banho (R\$)",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (v) => _firebaseService.updateConfiguracoes({
                      'preco_banho': double.parse(v),
                    }),
                  ),
                  SizedBox(height: 15),
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Preço Tosa (R\$)",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (v) => _firebaseService.updateConfiguracoes({
                      'preco_tosa': double.parse(v),
                    }),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Pressione Enter para salvar.",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(width: 20),

        // --- COLUNA 2: CADASTRAR FUNCIONÁRIO ---
        Expanded(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Cadastrar Novo Profissional",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _nomeController,
                    decoration: InputDecoration(
                      labelText: "Nome Completo",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: _cpfController,
                    decoration: InputDecoration(
                      labelText: "CPF (000.000.000-00)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text("SALVAR NOVO FUNCIONÁRIO"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                    onPressed: () async {
                      if (_nomeController.text.isNotEmpty &&
                          _cpfController.text.isNotEmpty) {
                        await _firebaseService.addProfissional(
                          _nomeController.text,
                          _cpfController.text,
                          ['banho', 'tosa'],
                        );
                        _nomeController.clear();
                        _cpfController.clear();
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text("Cadastrado!")));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
