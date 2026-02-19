import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:agenpet/config/app_config.dart';

class ServicosSelectDialog extends StatefulWidget {
  final List<Map<String, dynamic>>? initialSelected;

  const ServicosSelectDialog({super.key, this.initialSelected});

  @override
  State<ServicosSelectDialog> createState() => _ServicosSelectDialogState();
}

class _ServicosSelectDialogState extends State<ServicosSelectDialog> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _selectedItems = [];
  String _searchTerm = "";

  @override
  void initState() {
    super.initState();
    if (widget.initialSelected != null) {
      _selectedItems = List.from(widget.initialSelected!);
    }
  }

  void _toggleItem(Map<String, dynamic> item) {
    setState(() {
      final exists = _selectedItems.any((e) => e['id'] == item['id']);
      if (exists) {
        _selectedItems.removeWhere((e) => e['id'] == item['id']);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Selecionar Serviços"),
      content: SizedBox(
        width: 500,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: "Buscar serviço...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchTerm = v.toLowerCase()),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('tenants')
                    .doc(AppConfig.tenantId)
                    .collection('servicos_extras')
                    .where('ativo', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final nome = (data['nome'] as String).toLowerCase();
                    return nome.contains(_searchTerm);
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text("Nenhum serviço encontrado."),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final item = {
                        'id': doc.id,
                        'nome': data['nome'],
                        'preco': (data['preco'] as num).toDouble(),
                      };

                      final isSelected = _selectedItems.any(
                        (e) => e['id'] == item['id'],
                      );

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (_) => _toggleItem(item),
                        title: Text(item['nome']),
                        subtitle: Text("R\$ ${item['preco']}"),
                        secondary: const Icon(Icons.medical_services_outlined),
                      );
                    },
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
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedItems),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A148C),
          ),
          child: Text(
            "Confirmar (${_selectedItems.length})",
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
