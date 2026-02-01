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
  String _filtro = "";

  // Cores locais (herdarão do tema, mas para referências rápidas)
  Color get _primary => Theme.of(context).primaryColor;

  Future<void> _criarTenantDialog() async {
    final _nomeCtrl = TextEditingController();
    final _slugCtrl = TextEditingController();
    final _cidadeCtrl = TextEditingController();
    final _formKey = GlobalKey<FormState>();
    bool _isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(FontAwesomeIcons.store, color: _primary),
                SizedBox(width: 10),
                Text("Nova Loja Parceira"),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: SizedBox(
              width: 400,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nomeCtrl,
                      decoration: InputDecoration(
                        labelText: "Nome da Loja",
                        prefixIcon: Icon(Icons.business),
                      ),
                      validator: (v) => v!.isEmpty ? "Obrigatório" : null,
                      onChanged: (val) {
                        // Slug automático aprimorado
                        if (_slugCtrl.text.isEmpty ||
                            !_slugCtrl.text.contains('_man')) {
                          final slug = val
                              .toLowerCase()
                              .replaceAll(RegExp(r'[áàâãä]'), 'a')
                              .replaceAll(RegExp(r'[éèêë]'), 'e')
                              .replaceAll(RegExp(r'[íìîï]'), 'i')
                              .replaceAll(RegExp(r'[óòôõö]'), 'o')
                              .replaceAll(RegExp(r'[úùûü]'), 'u')
                              .replaceAll(RegExp(r'[ç]'), 'c')
                              .replaceAll(RegExp(r'[^a-z0-9]'), '_')
                              .replaceAll(
                                RegExp(r'_+'),
                                '_',
                              ); // remove duplicados
                          _slugCtrl.text = slug;
                        }
                      },
                    ),
                    SizedBox(height: 15),
                    TextFormField(
                      controller: _slugCtrl,
                      decoration: InputDecoration(
                        labelText: "ID Único (Slug)",
                        prefixIcon: Icon(Icons.fingerprint),
                        helperText: "Usado na URL e IDs internos",
                      ),
                      validator: (v) => v!.isEmpty ? "Obrigatório" : null,
                    ),
                    SizedBox(height: 15),
                    TextFormField(
                      controller: _cidadeCtrl,
                      decoration: InputDecoration(
                        labelText: "Cidade / UF",
                        prefixIcon: Icon(Icons.location_city),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: EdgeInsets.all(20),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _isLoading = true);
                        try {
                          await _functions.httpsCallable('criarTenant').call({
                            'tenantId': _slugCtrl.text.trim(),
                            'nome': _nomeCtrl.text.trim(),
                            'cidade': _cidadeCtrl.text.trim(),
                          });
                          Navigator.pop(context);
                          _showSnack("Loja criada com sucesso!", Colors.green);
                        } catch (e) {
                          _showSnack("Erro ao criar: $e", Colors.red);
                          setState(() => _isLoading = false);
                        }
                      },
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Text("Confirmar Criação"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          "NOVA LOJA",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: _criarTenantDialog,
        elevation: 4,
      ),
      body: Column(
        children: [
          // Header Moderno
          Container(
            padding: EdgeInsets.fromLTRB(40, 60, 40, 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primary, Color(0xFF2E0C59)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
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
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.buildingColumns,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Gestão de Tenants",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "Gerencie parceiros, contratos e acessos",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Área de Busca
          Transform.translate(
            offset: Offset(0, -25),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                constraints: BoxConstraints(maxWidth: 800),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Buscar por nome, ID ou cidade...",
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 20,
                    ),
                  ),
                  onChanged: (v) => setState(() => _filtro = v.toLowerCase()),
                ),
              ),
            ),
          ),

          // Lista de Tenants
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('tenants').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nome = (data['nome'] ?? '').toString().toLowerCase();
                  final id = doc.id.toLowerCase();
                  return nome.contains(_filtro) || id.contains(_filtro);
                }).toList();

                if (docs.isEmpty) return _buildEmptyState();

                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(40, 0, 40, 80),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 160, // Altura fixa do card
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) =>
                      _buildTenantCard(docs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 10),
          Text(
            "Nenhuma loja encontrada",
            style: TextStyle(fontSize: 18, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bool ativo = data['ativo'] ?? true;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GestaoTenantDetalheView(
              tenantId: doc.id,
              nomeLoja: data['nome'] ?? 'Loja',
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    (data['nome'] ?? "?").substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['nome'] ?? "Sem Nome",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      "ID: ${doc.id}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            data['cidade'] ?? "Local não informado",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ativo ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: ativo
                            ? Colors.green.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      ativo ? "ATIVO" : "INATIVO",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: ativo ? Colors.green[800] : Colors.red[800],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
