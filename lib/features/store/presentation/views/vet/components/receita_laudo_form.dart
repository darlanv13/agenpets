import 'package:flutter/material.dart';

class ReceitaLaudoForm extends StatefulWidget {
  const ReceitaLaudoForm({Key? key}) : super(key: key);
  @override
  ReceitaLaudoFormState createState() => ReceitaLaudoFormState();
}

class ReceitaLaudoFormState extends State<ReceitaLaudoForm> {
  final diagnosticoCtrl = TextEditingController();
  final receitaCtrl =
      TextEditingController(); // Texto livre simples para o exemplo

  // Cobrança
  bool cobrarConsulta = true;
  final List<Map<String, dynamic>> _procedimentosExtras = [];

  Map<String, dynamic> getData() {
    return {
      'diagnostico': diagnosticoCtrl.text,
      'receita_texto': receitaCtrl.text,
    };
  }

  List<Map<String, dynamic>> getCobranca() {
    List<Map<String, dynamic>> itens = [];
    if (cobrarConsulta)
      itens.add({'nome': 'Consulta Veterinária', 'preco': 150.00});
    itens.addAll(_procedimentosExtras);
    return itens;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lado Esquerdo: Clínico
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: diagnosticoCtrl,
                  decoration: InputDecoration(
                    labelText: "Diagnóstico / Suspeita",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: receitaCtrl,
                  maxLines: 10,
                  decoration: InputDecoration(
                    labelText: "Receituário (Texto Livre)",
                    border: OutlineInputBorder(),
                    hintText: "Uso Oral:\n1. Agemoxi 250mg....",
                  ),
                ),
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1),
        // Lado Direito: Financeiro
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.grey[50],
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Lançamento Financeiro",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SwitchListTile(
                  title: Text("Cobrar Consulta"),
                  subtitle: Text("R\$ 150,00"),
                  value: cobrarConsulta,
                  onChanged: (v) => setState(() => cobrarConsulta = v),
                ),
                Divider(),
                Text("Procedimentos Extras:"),
                // Aqui entraria uma lista dinâmica para adicionar vacinas/exames
                ListTile(
                  leading: Icon(Icons.add),
                  title: Text("Adicionar Item"),
                  onTap: () {
                    setState(() {
                      _procedimentosExtras.add({
                        'nome': 'Aplicação Injetável',
                        'preco': 30.0,
                      });
                    });
                  },
                ),
                ..._procedimentosExtras
                    .map(
                      (e) => ListTile(
                        title: Text(e['nome']),
                        trailing: Text("R\$ ${e['preco']}"),
                        dense: true,
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
