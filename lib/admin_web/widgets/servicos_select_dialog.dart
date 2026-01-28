import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class ServicosSelectDialog extends StatefulWidget {
  final List<Map<String, dynamic>> initialSelected;

  const ServicosSelectDialog({
    Key? key,
    this.initialSelected = const [],
  }) : super(key: key);

  @override
  _ServicosSelectDialogState createState() => _ServicosSelectDialogState();
}

class _ServicosSelectDialogState extends State<ServicosSelectDialog> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  List<Map<String, dynamic>> _availableServices = [];
  late List<Map<String, dynamic>> _selectedServices;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Deep copy to avoid mutating the original list reference immediately
    _selectedServices = List.from(
        widget.initialSelected.map((e) => Map<String, dynamic>.from(e)));
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      // Tenta buscar com filtro 'ativo'
      final snapshot = await _db
          .collection('servicos_extras')
          .where('ativo', isEqualTo: true)
          .orderBy('nome')
          .get();

      if (mounted) {
        setState(() {
          _availableServices = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'nome': data['nome'],
              'preco': (data['preco'] ?? 0).toDouble(),
              'porte': data['porte'],
              'pelagem': data['pelagem'],
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erro ao carregar serviços com filtro ativo: $e");
      // Fallback sem filtro, caso o índice não exista
      try {
        final snapshot =
            await _db.collection('servicos_extras').orderBy('nome').get();
        if (mounted) {
          setState(() {
            _availableServices = snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'nome': data['nome'],
                'preco': (data['preco'] ?? 0).toDouble(),
                'porte': data['porte'],
                'pelagem': data['pelagem'],
              };
            }).toList();
            _isLoading = false;
          });
        }
      } catch (e2) {
        print("Erro crítico ao carregar serviços: $e2");
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Selecionar Serviços"),
      content: Container(
        width: 500,
        height: 400,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      return _availableServices.where((option) {
                        return option['nome'].toString().toLowerCase().contains(
                                  textEditingValue.text.toLowerCase(),
                                );
                      });
                    },
                    displayStringForOption: (option) => option['nome'],
                    onSelected: (Map<String, dynamic> selection) {
                      setState(() {
                        if (!_selectedServices
                            .any((s) => s['id'] == selection['id'])) {
                          _selectedServices.add(selection);
                        }
                      });
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: "Buscar Serviço...",
                          hintText: "Digite para buscar (ex: Hidratação)",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          child: Container(
                            width: 300,
                            height: 200,
                            color: Colors.white,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option['nome']),
                                  subtitle: Text(
                                      "R\$ ${option['preco'].toStringAsFixed(2)}"),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Serviços Selecionados:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: _selectedServices.isEmpty
                        ? Center(
                            child: Text(
                              "Nenhum serviço extra selecionado",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _selectedServices.length,
                            separatorBuilder: (_, __) => Divider(),
                            itemBuilder: (ctx, index) {
                              final item = _selectedServices[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item['nome']),
                                subtitle: Text(
                                    "R\$ ${item['preco'].toStringAsFixed(2)}"),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _selectedServices.removeAt(index);
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedServices),
          child: Text("Confirmar & Enviar"),
        ),
      ],
    );
  }
}
