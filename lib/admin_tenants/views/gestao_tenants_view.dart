import 'package:agenpet/admin_tenants/views/gestao_tenant_detalhe_view.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';

class GestaoTenantsView extends StatefulWidget {
  @override
  _GestaoTenantsViewState createState() => _GestaoTenantsViewState();
}

class _GestaoTenantsViewState extends State<GestaoTenantsView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  // Colors
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

  String _filtro = "";

  Future<void> _criarTenantDialog() async {
    final _nomeCtrl = TextEditingController();
    final _slugCtrl = TextEditingController(); // ID
    final _cidadeCtrl = TextEditingController();
    bool _isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Nova Loja (Tenant)"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nomeCtrl,
                    decoration: InputDecoration(
                      labelText: "Nome da Loja",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                       // Auto-generate slug
                       if (_slugCtrl.text.isEmpty || _slugCtrl.text == val.toLowerCase().replaceAll(' ', '_').substring(0, val.length-1)) {
                          // Simple slug logic for UX
                          final slug = val.toLowerCase()
                              .replaceAll(RegExp(r'[áàâã]'), 'a')
                              .replaceAll(RegExp(r'[éèê]'), 'e')
                              .replaceAll(RegExp(r'[íì]'), 'i')
                              .replaceAll(RegExp(r'[óòôõ]'), 'o')
                              .replaceAll(RegExp(r'[úù]'), 'u')
                              .replaceAll(RegExp(r'[ç]'), 'c')
                              .replaceAll(RegExp(r'[^a-z0-9]'), '_');
                          _slugCtrl.text = slug;
                       }
                    },
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _slugCtrl,
                    decoration: InputDecoration(
                      labelText: "ID (Slug) - Único",
                      helperText: "Ex: pet_shop_centro (sem espaços)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _cidadeCtrl,
                    decoration: InputDecoration(
                      labelText: "Cidade",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancelar"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _corAcai),
                  onPressed: _isLoading ? null : () async {
                    if (_nomeCtrl.text.isEmpty || _slugCtrl.text.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Preencha nome e ID")));
                       return;
                    }

                    setState(() => _isLoading = true);
                    try {
                      // Call Cloud Function to create tenant
                      await _functions.httpsCallable('criarTenant').call({
                        'tenantId': _slugCtrl.text.trim(),
                        'nome': _nomeCtrl.text.trim(),
                        'cidade': _cidadeCtrl.text.trim(),
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Loja criada com sucesso!")));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
                      setState(() => _isLoading = false);
                    }
                  },
                  child: _isLoading
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text("Criar Loja"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _corAcai,
        icon: Icon(Icons.add),
        label: Text("Nova Loja"),
        onPressed: _criarTenantDialog,
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(vertical: 25, horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _corAcai.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.building,
                    color: _corAcai,
                    size: 28,
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Gestão de Tenants",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _corAcai,
                        ),
                      ),
                      Text(
                        "Gerencie as lojas, configurações e acessos",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search & Metrics
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Buscar por nome ou cidade...",
                prefixIcon: Icon(Icons.search, color: _corAcai),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(15),
                   borderSide: BorderSide(color: _corAcai, width: 1),
                ),
              ),
              onChanged: (v) => setState(() => _filtro = v.toLowerCase()),
            ),
          ),

          // Content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('tenants').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: _corAcai));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FontAwesomeIcons.storeSlash, size: 50, color: Colors.grey[300]),
                        SizedBox(height: 20),
                        Text("Nenhuma loja encontrada.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nome = (data['nome'] ?? '').toString().toLowerCase();
                  final cidade = (data['cidade'] ?? '').toString().toLowerCase();
                  return nome.contains(_filtro) || cidade.contains(_filtro);
                }).toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.store, color: _corAcai, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "${docs.length} Loja(s) Encontrada(s)",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _corAcai,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                           maxCrossAxisExtent: 400,
                           childAspectRatio: 2.2,
                           crossAxisSpacing: 20,
                           mainAxisSpacing: 20,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final tenantId = doc.id;
                          final nome = data['nome'] ?? 'Loja sem nome';
                          final cidade = data['cidade'] ?? 'Não informada';
                          final bool ativo = data['ativo'] ?? true;

                          return Card(
                            elevation: 4,
                            shadowColor: Colors.black12,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        GestaoTenantDetalheView(
                                          tenantId: tenantId,
                                          nomeLoja: nome,
                                        ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: _corAcai.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Center(
                                        child: Text(
                                          nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                                          style: TextStyle(
                                            color: _corAcai,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            nome,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.grey[800],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Icon(Icons.location_on, size: 12, color: Colors.grey),
                                              SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  cidade,
                                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 5),
                                           Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: ativo ? Colors.green[50] : Colors.red[50],
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              ativo ? "ATIVO" : "INATIVO",
                                              style: TextStyle(
                                                color: ativo ? Colors.green[800] : Colors.red[800],
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right, color: Colors.grey[300]),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
