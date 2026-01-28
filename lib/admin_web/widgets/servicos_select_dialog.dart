import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);

  List<Map<String, dynamic>> _availableServices = [];
  late List<Map<String, dynamic>> _selectedServices;
  bool _isLoading = true;

  // Controller para limpar o campo
  TextEditingController? _autocompleteController;

  @override
  void initState() {
    super.initState();
    // Deep copy
    _selectedServices = List.from(
        widget.initialSelected.map((e) => Map<String, dynamic>.from(e)));
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
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
      // Fallback
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
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 550,
        height: 600,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // HEADER
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: _corAcai,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(FontAwesomeIcons.listCheck,
                          color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Serviços Adicionais",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Selecione o que será realizado",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // BODY
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _corAcai))
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // BUSCA
                          Autocomplete<Map<String, dynamic>>(
                            optionsBuilder: (TextEditingValue textValue) {
                              if (textValue.text.isEmpty)
                                return const Iterable<
                                    Map<String, dynamic>>.empty();
                              return _availableServices.where((opt) {
                                return opt['nome']
                                    .toString()
                                    .toLowerCase()
                                    .contains(textValue.text.toLowerCase());
                              });
                            },
                            displayStringForOption: (opt) => opt['nome'],
                            onSelected: (selection) {
                              setState(() {
                                if (!_selectedServices
                                    .any((s) => s['id'] == selection['id'])) {
                                  _selectedServices.add(selection);
                                }
                              });
                              // Limpa o campo após seleção
                              if (_autocompleteController != null) {
                                _autocompleteController!.clear();
                              }
                            },
                            fieldViewBuilder: (ctx, controller, focus, submit) {
                              // Guarda a referência para limpar depois
                              if (_autocompleteController != controller) {
                                _autocompleteController = controller;
                              }

                              return TextField(
                                controller: controller,
                                focusNode: focus,
                                onSubmitted: (_) {
                                  // Limpa após enter se necessário
                                },
                                decoration: InputDecoration(
                                  labelText: "Adicionar Serviço",
                                  hintText: "Digite para buscar...",
                                  prefixIcon:
                                      Icon(Icons.search, color: _corAcai),
                                  suffixIcon: IconButton(
                                    icon: Icon(Icons.clear, size: 16),
                                    onPressed: () => controller.clear(),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: _corAcai, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                              );
                            },
                            optionsViewBuilder: (ctx, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 300,
                                    height: 250,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero,
                                      itemCount: options.length,
                                      separatorBuilder: (_, __) =>
                                          Divider(height: 1),
                                      itemBuilder: (ctx, idx) {
                                        final opt = options.elementAt(idx);
                                        return ListTile(
                                          title: Text(
                                            opt['nome'],
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                            "R\$ ${opt['preco'].toStringAsFixed(2)}",
                                            style: TextStyle(
                                                color: Colors.green[700]),
                                          ),
                                          onTap: () {
                                            onSelected(opt);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          SizedBox(height: 25),

                          // LISTA
                          Row(
                            children: [
                              Text(
                                "ITENS SELECIONADOS",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  letterSpacing: 1,
                                ),
                              ),
                              SizedBox(width: 10),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _corLilas,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "${_selectedServices.length}",
                                  style: TextStyle(
                                    color: _corAcai,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),

                          Expanded(
                            child: _selectedServices.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(FontAwesomeIcons.basketShopping,
                                            size: 40, color: Colors.grey[300]),
                                        SizedBox(height: 10),
                                        Text(
                                          "Nenhum serviço selecionado",
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                          color: Colors.grey[200]!),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListView.separated(
                                      padding: EdgeInsets.all(5),
                                      itemCount: _selectedServices.length,
                                      separatorBuilder: (_, __) =>
                                          Divider(height: 1),
                                      itemBuilder: (ctx, index) {
                                        final item = _selectedServices[index];

                                        // Subtitle Construction
                                        List<String> details = [];
                                        details.add("R\$ ${item['preco'].toStringAsFixed(2)}");

                                        if (item['porte'] != null && item['porte'].toString().isNotEmpty) {
                                          details.add("Porte: ${item['porte']}");
                                        }
                                        if (item['pelagem'] != null && item['pelagem'].toString().isNotEmpty) {
                                          details.add("Pelagem: ${item['pelagem']}");
                                        }

                                        return ListTile(
                                          dense: true,
                                          leading: CircleAvatar(
                                            radius: 18,
                                            backgroundColor: _corLilas,
                                            child: Icon(Icons.check,
                                                size: 16, color: _corAcai),
                                          ),
                                          title: Text(
                                            item['nome'],
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600),
                                          ),
                                          subtitle: Text(
                                            details.join(' | '),
                                            style: TextStyle(
                                                color: Colors.green[700], fontSize: 12),
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(Icons.delete_outline,
                                                color: Colors.red[300]),
                                            onPressed: () {
                                              setState(() {
                                                _selectedServices
                                                    .removeAt(index);
                                              });
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),

            // FOOTER
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    child: Text("Cancelar"),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: Icon(Icons.check, size: 18),
                    label: Text("CONFIRMAR"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _corAcai,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding:
                          EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () =>
                        Navigator.pop(context, _selectedServices),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
