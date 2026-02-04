import 'package:agenpet/painel_admin_tenants/views/gestao_tenant_detalhe_view.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

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

  Color get _primary => Theme.of(context).primaryColor;

  Future<void> _criarTenantDialog() async {
    final _nomeCtrl = TextEditingController();
    final _cnpjCtrl = TextEditingController();
    final _slugCtrl = TextEditingController();
    final _cidadeCtrl = TextEditingController();
    final _formKey = GlobalKey<FormState>();
    bool _isLoading = false;

    var maskCnpj = MaskTextInputFormatter(
      mask: '##.###.###/####-##',
      filter: {"#": RegExp(r'[0-9]')},
    );

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(FontAwesomeIcons.store, color: _primary),
                SizedBox(width: 10),
                Text(
                  "Nova Loja Parceira",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nomeCtrl,
                        decoration: _inputDecor("Nome da Loja", Icons.business),
                        validator: (v) => v!.isEmpty ? "Obrigatório" : null,
                      ),
                      SizedBox(height: 15),
                      TextFormField(
                        controller: _cnpjCtrl,
                        inputFormatters: [maskCnpj],
                        decoration: _inputDecor("CNPJ", Icons.badge),
                        validator: (v) {
                          if (v!.isEmpty) return "Obrigatório";
                          if (v.length < 18) return "CNPJ incompleto";
                          return null;
                        },
                        onChanged: (val) {
                          // Define o ID (slug) como apenas números do CNPJ
                          _slugCtrl.text = maskCnpj.getUnmaskedText();
                        },
                      ),
                      SizedBox(height: 15),
                      TextFormField(
                        controller: _slugCtrl,
                        readOnly: true, // ID gerado automaticamente
                        decoration: _inputDecor(
                          "ID Único (Automático)",
                          Icons.fingerprint,
                          helper: "Será o CNPJ (somente números)",
                        ),
                      ),
                      SizedBox(height: 15),
                      TextFormField(
                        controller: _cidadeCtrl,
                        decoration: _inputDecor(
                          "Cidade / UF",
                          Icons.location_city,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _isLoading = true);
                        try {
                          await _functions.httpsCallable('criarTenant').call({
                            'slug': _slugCtrl.text.trim(),
                            'nome': _nomeCtrl.text.trim(),
                            'cidade': _cidadeCtrl.text.trim(),
                          });
                          Navigator.pop(context);
                          _showSnack("Loja criada com sucesso!", Colors.green);
                        } catch (e) {
                          _showSnack("Erro: $e", Colors.red);
                          setState(() => _isLoading = false);
                        }
                      },
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text("CRIAR LOJA"),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _inputDecor(String label, IconData icon, {String? helper}) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          "NOVA LOJA",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        onPressed: _criarTenantDialog,
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primary, Color(0xFF2E0C59)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              FontAwesomeIcons.buildingColumns,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 15),
                          Text(
                            "Gestão de Tenants",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Gerencie parceiros, contratos e acessos em um só lugar.",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Barra de Busca Flutuante
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: Offset(0, -25),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(35.0),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    constraints: BoxConstraints(maxWidth: 800),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Buscar loja...",
                        prefixIcon: Icon(Icons.search, color: _primary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(20),
                      ),
                      onChanged: (v) =>
                          setState(() => _filtro = v.toLowerCase()),
                    ),
                  ),
                ),
              ),
            ),
          ),

          StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('tenants')
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(50),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );

              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final nome = (data['nome'] ?? '').toString().toLowerCase();
                return nome.contains(_filtro);
              }).toList();

              if (docs.isEmpty)
                return SliverToBoxAdapter(child: _buildEmptyState());

              return SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350,
                    mainAxisExtent:
                        170, // Altura fixa controlada para evitar overflow
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _TenantCard(doc: docs[index], primaryColor: _primary),
                    childCount: docs.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        SizedBox(height: 50),
        Icon(
          Icons.store_mall_directory_outlined,
          size: 60,
          color: Colors.grey[300],
        ),
        SizedBox(height: 10),
        Text("Nenhuma loja encontrada", style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _TenantCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final Color primaryColor;

  const _TenantCard({required this.doc, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final bool ativo = data['ativo'] ?? true;
    final nome = data['nome'] ?? "Sem Nome";
    final cidade = data['cidade'] ?? "N/A";

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                GestaoTenantDetalheView(tenantId: doc.id, nomeLoja: nome),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        nome.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          "ID: ${doc.id}",
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Spacer(),
              Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            cidade,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ativo ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ativo ? "ATIVO" : "INATIVO",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: ativo ? Colors.green[700] : Colors.red[700],
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
