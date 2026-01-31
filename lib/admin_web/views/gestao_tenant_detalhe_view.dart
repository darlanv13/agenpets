import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:agenpet/admin_web/widgets/tenant_team_manager.dart';

class GestaoTenantDetalheView extends StatefulWidget {
  final String tenantId;
  final String nomeLoja;

  const GestaoTenantDetalheView({
    required this.tenantId,
    required this.nomeLoja,
  });

  @override
  _GestaoTenantDetalheViewState createState() =>
      _GestaoTenantDetalheViewState();
}

class _GestaoTenantDetalheViewState extends State<GestaoTenantDetalheView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Config Controllers
  final _efipayClientIdCtrl = TextEditingController();
  final _efipayClientSecretCtrl = TextEditingController();
  final _mpAccessTokenCtrl = TextEditingController();
  final _logoAppCtrl = TextEditingController();
  final _logoAdminCtrl = TextEditingController();

  // Toggles
  bool _temCreche = false;
  bool _temHotel = false;
  bool _temBanho = false;
  bool _temTosa = false;
  String _gatewayPagamento = 'efipay';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarConfiguracoes();
  }

  Future<void> _carregarConfiguracoes() async {
    try {
      final doc =
          await _db
              .collection('tenants')
              .doc(widget.tenantId)
              .collection('config')
              .doc('parametros')
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _efipayClientIdCtrl.text = data['efipay_client_id'] ?? '';
          _efipayClientSecretCtrl.text = data['efipay_client_secret'] ?? '';
          _mpAccessTokenCtrl.text = data['mercadopago_access_token'] ?? '';
          _logoAppCtrl.text = data['logo_app_url'] ?? '';
          _logoAdminCtrl.text = data['logo_admin_url'] ?? '';

          _temCreche = data['tem_creche'] ?? false;
          _temHotel = data['tem_hotel'] ?? false;
          _temBanho = data['tem_banho'] ?? true;
          _temTosa = data['tem_tosa'] ?? true;
          _gatewayPagamento = data['gateway_pagamento'] ?? 'efipay';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao carregar configs: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarConfiguracoes() async {
    setState(() => _isLoading = true);
    try {
      await _db
          .collection('tenants')
          .doc(widget.tenantId)
          .collection('config')
          .doc('parametros')
          .set({
            'efipay_client_id': _efipayClientIdCtrl.text.trim(),
            'efipay_client_secret': _efipayClientSecretCtrl.text.trim(),
            'mercadopago_access_token': _mpAccessTokenCtrl.text.trim(),
            'logo_app_url': _logoAppCtrl.text.trim(),
            'logo_admin_url': _logoAdminCtrl.text.trim(),
            'tem_creche': _temCreche,
            'tem_hotel': _temHotel,
            'tem_banho': _temBanho,
            'tem_tosa': _temTosa,
            'gateway_pagamento': _gatewayPagamento,
          }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Configurações salvas com sucesso!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Gerenciar: ${widget.nomeLoja}",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[900],
        iconTheme: IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: [Tab(text: "Configurações"), Tab(text: "Equipe de Acesso")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildConfigTab(), TenantTeamManager(tenantId: widget.tenantId)],
      ),
    );
  }

  Widget _buildConfigTab() {
    if (_isLoading) return Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Serviços Disponíveis"),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text("Banho"),
                  value: _temBanho,
                  onChanged: (v) => setState(() => _temBanho = v),
                ),
                SwitchListTile(
                  title: Text("Tosa"),
                  value: _temTosa,
                  onChanged: (v) => setState(() => _temTosa = v),
                ),
                SwitchListTile(
                  title: Text("Creche"),
                  value: _temCreche,
                  onChanged: (v) => setState(() => _temCreche = v),
                ),
                SwitchListTile(
                  title: Text("Hotel"),
                  value: _temHotel,
                  onChanged: (v) => setState(() => _temHotel = v),
                ),
              ],
            ),
          ),
          SizedBox(height: 30),

          _buildSectionTitle("Identidade Visual (URLs)"),
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _logoAppCtrl,
                    decoration: InputDecoration(
                      labelText: "URL Logo App Cliente",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: _logoAdminCtrl,
                    decoration: InputDecoration(
                      labelText: "URL Logo Painel Admin",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 30),

          _buildSectionTitle("Pagamento (Gateway)"),
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _gatewayPagamento,
                    decoration: InputDecoration(
                      labelText: "Gateway Principal",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'efipay',
                        child: Text("EfiPay (Gerencianet)"),
                      ),
                      DropdownMenuItem(
                        value: 'mercadopago',
                        child: Text("Mercado Pago"),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _gatewayPagamento = v);
                    },
                  ),
                  SizedBox(height: 20),
                  if (_gatewayPagamento == 'efipay') ...[
                    Text(
                      "Credenciais EfiPay",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _efipayClientIdCtrl,
                      decoration: InputDecoration(
                        labelText: "Client ID (Homolog/Prod)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _efipayClientSecretCtrl,
                      decoration: InputDecoration(
                        labelText: "Client Secret (Homolog/Prod)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    Text(
                      "Credenciais Mercado Pago",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _mpAccessTokenCtrl,
                      decoration: InputDecoration(
                        labelText: "Access Token",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: Icon(Icons.save),
              label: Text("SALVAR CONFIGURAÇÕES"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[900],
                foregroundColor: Colors.white,
              ),
              onPressed: _salvarConfiguracoes,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue[900],
        ),
      ),
    );
  }
}
