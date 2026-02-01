import 'package:agenpet/admin_tenants/widgets/tenant_team_manager.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

  // Colors
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

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
      final doc = await _db
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
      backgroundColor: _corFundo,
      appBar: AppBar(
        title: Text(
          "Gerenciar: ${widget.nomeLoja}",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _corAcai,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.amber,
          indicatorWeight: 4,
          tabs: [
            Tab(text: "Configurações da Loja", icon: Icon(Icons.store)),
            Tab(text: "Gestão de Acesso", icon: Icon(Icons.people_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConfigTab(),
          TenantTeamManager(tenantId: widget.tenantId),
        ],
      ),
    );
  }

  Widget _buildConfigTab() {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: _corAcai));

    return SingleChildScrollView(
      padding: EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Serviços Disponíveis", FontAwesomeIcons.layerGroup),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                _buildSwitch("Banho", _temBanho, (v) => setState(() => _temBanho = v), FontAwesomeIcons.shower),
                Divider(height: 1),
                _buildSwitch("Tosa", _temTosa, (v) => setState(() => _temTosa = v), FontAwesomeIcons.scissors),
                Divider(height: 1),
                _buildSwitch("Creche", _temCreche, (v) => setState(() => _temCreche = v), FontAwesomeIcons.dog),
                Divider(height: 1),
                _buildSwitch("Hotel", _temHotel, (v) => setState(() => _temHotel = v), FontAwesomeIcons.hotel),
              ],
            ),
          ),
          SizedBox(height: 30),

          _buildSectionTitle("Identidade Visual", Icons.palette),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildTextField(_logoAppCtrl, "URL Logo App Cliente", Icons.image),
                  if (_logoAppCtrl.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      child: Container(
                        height: 60,
                        alignment: Alignment.centerLeft,
                        child: Image.network(
                          _logoAppCtrl.text,
                          errorBuilder: (_, __, ___) => Text(
                            "URL inválida ou imagem não encontrada",
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: 15),
                  _buildTextField(_logoAdminCtrl, "URL Logo Painel Admin", Icons.admin_panel_settings),
                  if (_logoAdminCtrl.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        height: 60,
                        alignment: Alignment.centerLeft,
                        child: Image.network(
                          _logoAdminCtrl.text,
                          errorBuilder: (_, __, ___) => Text(
                            "URL inválida ou imagem não encontrada",
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 30),

          _buildSectionTitle("Pagamento (Gateway)", Icons.payment),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _gatewayPagamento,
                    decoration: InputDecoration(
                      labelText: "Gateway Principal",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: Icon(Icons.account_balance_wallet, color: _corAcai),
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
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 15),
                    _buildTextField(_efipayClientIdCtrl, "Client ID (Homolog/Prod)", Icons.key),
                    SizedBox(height: 10),
                    _buildTextField(_efipayClientSecretCtrl, "Client Secret (Homolog/Prod)", Icons.lock),
                  ] else ...[
                    Text(
                      "Credenciais Mercado Pago",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 15),
                    _buildTextField(_mpAccessTokenCtrl, "Access Token", Icons.vpn_key),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(Icons.save),
              label: Text(_isLoading ? "SALVANDO..." : "SALVAR CONFIGURAÇÕES"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(15)
                ),
                elevation: 4,
              ),
              onPressed: _isLoading ? null : _salvarConfiguracoes,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(icon, color: _corAcai, size: 22),
          SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(String title, bool val, Function(bool) onChanged, IconData icon) {
    return SwitchListTile(
      title: Row(
        children: [
           FaIcon(icon, color: val ? _corAcai : Colors.grey, size: 18),
           SizedBox(width: 15),
           Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
      value: val,
      activeColor: _corAcai,
      onChanged: onChanged,
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(icon, color: _corAcai),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}
