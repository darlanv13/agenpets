import 'package:agenpet/admin_tenants/widgets/tenant_team_manager.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

  // Controllers
  final _efipayClientIdCtrl = TextEditingController();
  final _efipayClientSecretCtrl = TextEditingController();
  final _mpAccessTokenCtrl = TextEditingController();
  final _logoAppCtrl = TextEditingController();
  final _logoAdminCtrl = TextEditingController();

  // Estados
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
      ).showSnackBar(SnackBar(content: Text("Erro ao carregar: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarConfiguracoes() async {
    setState(() => _isLoading = true);
    try {
      // 1. Salvar Configurações Visuais/Públicas (Escrita direta no Firestore é OK aqui)
      await _db
          .collection('tenants')
          .doc(widget.tenantId)
          .collection('config')
          .doc('parametros')
          .set({
            'logo_app_url': _logoAppCtrl.text.trim(),
            'logo_admin_url': _logoAdminCtrl.text.trim(),
            'tem_creche': _temCreche,
            'tem_hotel': _temHotel,
            'tem_banho': _temBanho,
            'tem_tosa': _temTosa,
            // Não salvamos as chaves aqui!
          }, SetOptions(merge: true));

      // 2. Salvar Credenciais via Cloud Function (Túnel Seguro)
      // Chama a função que criamos no passo anterior
      final functions = FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      );
      await functions.httpsCallable('salvarCredenciaisGateway').call({
        'tenantId': widget.tenantId,
        'gateway_pagamento': _gatewayPagamento,
        'efipay_client_id': _efipayClientIdCtrl.text.trim(),
        'efipay_client_secret': _efipayClientSecretCtrl.text.trim(),
        'mercadopago_access_token': _mpAccessTokenCtrl.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.shield, color: Colors.white),
              SizedBox(width: 10),
              Text("Configurações e Chaves salvas com segurança!"),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao salvar: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.nomeLoja.toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          labelStyle: TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              text: "CONFIGURAÇÕES DA LOJA",
              icon: Icon(Icons.settings_suggest),
            ),
            Tab(text: "EQUIPE & ACESSOS", icon: Icon(Icons.people_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConfigTab(theme),
          TenantTeamManager(tenantId: widget.tenantId),
        ],
      ),
    );
  }

  Widget _buildConfigTab(ThemeData theme) {
    if (_isLoading) return Center(child: CircularProgressIndicator());

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader(
                "Módulos de Serviço",
                FontAwesomeIcons.layerGroup,
              ),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    children: [
                      _buildSwitch(
                        "Banho & Higiene",
                        "Módulo de agendamento de banhos",
                        _temBanho,
                        (v) => setState(() => _temBanho = v),
                        FontAwesomeIcons.shower,
                      ),
                      Divider(),
                      _buildSwitch(
                        "Tosa & Estética",
                        "Módulo de tosa",
                        _temTosa,
                        (v) => setState(() => _temTosa = v),
                        FontAwesomeIcons.scissors,
                      ),
                      Divider(),
                      _buildSwitch(
                        "Creche / Daycare",
                        "Gestão de entrada e saída diária",
                        _temCreche,
                        (v) => setState(() => _temCreche = v),
                        FontAwesomeIcons.dog,
                      ),
                      Divider(),
                      _buildSwitch(
                        "Hotel & Hospedagem",
                        "Gestão de pernoites e baias",
                        _temHotel,
                        (v) => setState(() => _temHotel = v),
                        FontAwesomeIcons.hotel,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 30),
              _buildSectionHeader(
                "Identidade Visual (White Label)",
                Icons.palette,
              ),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildImageInput(
                        _logoAppCtrl,
                        "Logo App Cliente",
                        Icons.phone_iphone,
                      ),
                      SizedBox(height: 20),
                      _buildImageInput(
                        _logoAdminCtrl,
                        "Logo Painel Administrativo",
                        Icons.monitor,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 30),
              _buildSectionHeader("Gateway de Pagamento", Icons.credit_card),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _gatewayPagamento,
                        decoration: InputDecoration(
                          labelText: "Provedor Principal",
                          prefixIcon: Icon(Icons.hub),
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
                        onChanged: (v) =>
                            setState(() => _gatewayPagamento = v!),
                      ),
                      SizedBox(height: 20),
                      if (_gatewayPagamento == 'efipay') ...[
                        TextFormField(
                          controller: _efipayClientIdCtrl,
                          decoration: InputDecoration(
                            labelText: "Client ID",
                            prefixIcon: Icon(Icons.key),
                          ),
                        ),
                        SizedBox(height: 15),
                        TextFormField(
                          controller: _efipayClientSecretCtrl,
                          decoration: InputDecoration(
                            labelText: "Client Secret",
                            prefixIcon: Icon(Icons.lock),
                          ),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _mpAccessTokenCtrl,
                          decoration: InputDecoration(
                            labelText: "Access Token (Production)",
                            prefixIcon: Icon(Icons.vpn_key),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              SizedBox(height: 40),
              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _salvarConfiguracoes,
                  icon: Icon(Icons.save),
                  label: Text("SALVAR ALTERAÇÕES"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 5),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(
    String title,
    String subtitle,
    bool val,
    Function(bool) onChange,
    IconData icon,
  ) {
    return SwitchListTile(
      value: val,
      onChanged: onChange,
      activeColor: Theme.of(context).primaryColor,
      title: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          SizedBox(width: 10),
          Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 28),
        child: Text(subtitle, style: TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildImageInput(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(width: 20),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ctrl.text.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ctrl.text,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.error),
                  ),
                )
              : Icon(Icons.image, color: Colors.grey[300]),
        ),
      ],
    );
  }
}
