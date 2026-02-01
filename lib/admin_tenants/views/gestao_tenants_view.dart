import 'package:agenpet/admin_tenants/views/gestao_tenant_detalhe_view.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class GestaoTenantsView extends StatefulWidget {
  @override
  _GestaoTenantsViewState createState() => _GestaoTenantsViewState();
}

class _GestaoTenantsViewState extends State<GestaoTenantsView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  String _filtro = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
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
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.building,
                    color: Colors.blue[800],
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
                          color: Colors.blue[900],
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
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
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
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("Nenhuma loja encontrada."));
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nome = (data['nome'] ?? '').toString().toLowerCase();
                  final cidade = (data['cidade'] ?? '')
                      .toString()
                      .toLowerCase();
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
                          Icon(Icons.store, color: Colors.blue[900], size: 20),
                          SizedBox(width: 8),
                          Text(
                            "${docs.length} Loja(s) Encontrada(s)",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 30),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final tenantId = doc.id;
                          final nome = data['nome'] ?? 'Loja sem nome';
                          final cidade = data['cidade'] ?? 'Não informada';

                          return Card(
                            margin: EdgeInsets.only(bottom: 15),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(20),
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                child: Text(
                                  nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                nome,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 5),
                                  Text("ID: $tenantId"),
                                  Text("Cidade: $cidade"),
                                ],
                              ),
                              trailing: Icon(Icons.arrow_forward_ios, size: 16),
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
