import 'package:agenpet/painel_admin_tenants/widgets/tenant_team_manager.dart';
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

  final _efipayClientIdCtrl = TextEditingController();
  final _efipayClientSecretCtrl = TextEditingController();
  final _efipayChavePixCtrl = TextEditingController();
  final _mpAccessTokenCtrl = TextEditingController();
  final _logoAppCtrl = TextEditingController();
  final _logoAdminCtrl = TextEditingController();

  // Módulos (Unified Flags)
  bool _temBanhoTosa = true;
  bool _temHotel = false;
  bool _temCreche = false;
  bool _temLoja = false; // "Loja (App)"
  bool _temPdv = false; // "PDV (Caixa)"
  bool _temVeterinario = false;
  bool _temTaxi = false;

  String _gatewayPagamento = 'efipay';
  bool _efipaySandbox = false;
  bool _isLoading = true, _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarConfiguracoes();
  }

  Future<void> _carregarConfiguracoes() async {
    try {
      final futures = await Future.wait([
        _db
            .collection('tenants')
            .doc(widget.tenantId)
            .collection('config')
            .doc('parametros')
            .get(),
        _db
            .collection('tenants')
            .doc(widget.tenantId)
            .collection('config')
            .doc('segredos')
            .get(),
      ]);

      final docParametros = futures[0];
      final docSegredos = futures[1];

      Map<String, dynamic> data = {};
      if (docParametros.exists) data.addAll(docParametros.data()!);
      if (docSegredos.exists) data.addAll(docSegredos.data()!);

      if (mounted) {
        setState(() {
          _efipayClientIdCtrl.text = data['efipay_client_id'] ?? '';
          _efipayClientSecretCtrl.text = data['efipay_client_secret'] ?? '';
          _efipayChavePixCtrl.text = data['chave_pix'] ?? '';
          _mpAccessTokenCtrl.text = data['mercadopago_access_token'] ?? '';
          _logoAppCtrl.text = data['logo_app_url'] ?? '';
          _logoAdminCtrl.text = data['logo_admin_url'] ?? '';
          _efipaySandbox = data['efipay_sandbox'] ?? false;

          // Carrega módulos (com fallback para legacy se necessário)
          _temBanhoTosa = data['tem_banho_tosa'] ?? (data['tem_banho'] ?? true);
          _temHotel = data['tem_hotel'] ?? false;
          _temCreche = data['tem_creche'] ?? false;
          _temLoja = data['tem_loja'] ?? false;
          _temPdv = data['tem_pdv'] ?? false; // Novo
          _temVeterinario = data['tem_veterinario'] ?? false;
          _temTaxi = data['tem_taxi'] ?? false;

          _gatewayPagamento = data['gateway_pagamento'] ?? 'efipay';
        });
      }
    } catch (e) {
      debugPrint("Erro: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarConfiguracoes() async {
    setState(() => _isSaving = true);
    try {
      await _db
          .collection('tenants')
          .doc(widget.tenantId)
          .collection('config')
          .doc('parametros')
          .set({
            'logo_app_url': _logoAppCtrl.text.trim(),
            'logo_admin_url': _logoAdminCtrl.text.trim(),
            'tem_banho_tosa': _temBanhoTosa,
            'tem_hotel': _temHotel,
            'tem_creche': _temCreche,
            'tem_loja': _temLoja,
            'tem_pdv': _temPdv, // Novo
            'tem_veterinario': _temVeterinario,
            'tem_taxi': _temTaxi,
            // Mantém compatibilidade reversa se necessário, ou removemos fields antigos
            'tem_banho': _temBanhoTosa,
            'tem_tosa': _temBanhoTosa,
          }, SetOptions(merge: true));

      final functions = FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      );
      await functions.httpsCallable('salvarCredenciaisGateway').call({
        'tenantId': widget.tenantId,
        'gateway_pagamento': _gatewayPagamento,
        'efipay_client_id': _efipayClientIdCtrl.text.trim(),
        'efipay_client_secret': _efipayClientSecretCtrl.text.trim(),
        'chave_pix': _efipayChavePixCtrl.text.trim(),
        'mercadopago_access_token': _mpAccessTokenCtrl.text.trim(),
        'efipay_sandbox': _efipaySandbox,
      });

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Salvo com sucesso!"),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          widget.nomeLoja,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: [
            Tab(text: "CONFIGURAÇÕES", icon: Icon(Icons.settings_outlined)),
            Tab(text: "EQUIPE & ACESSO", icon: Icon(Icons.people_outline)),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildConfigTab(),
              TenantTeamManager(tenantId: widget.tenantId),
            ],
          ),
          if (_isSaving)
            Container(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildConfigTab() {
    if (_isLoading) return Center(child: CircularProgressIndicator());

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 800;
        return SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1000),
              child: Column(
                children: [
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildServicesCard()),
                        SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            children: [
                              _buildBrandingCard(),
                              SizedBox(height: 20),
                              _buildPaymentCard(),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildServicesCard(),
                    SizedBox(height: 20),
                    _buildBrandingCard(),
                    SizedBox(height: 20),
                    _buildPaymentCard(),
                  ],
                  SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _salvarConfiguracoes,
                      icon: Icon(Icons.save),
                      label: Text(
                        "SALVAR ALTERAÇÕES",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 50),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.grey[700]),
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
            Divider(height: 30),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildServicesCard() {
    return _buildCard(
      title: "Módulos de Serviço",
      icon: FontAwesomeIcons.layerGroup,
      child: Column(
        children: [
          _buildSwitch(
            "Banho & Tosa",
            "Agendamento e Gestão",
            _temBanhoTosa,
            (v) => setState(() => _temBanhoTosa = v),
          ),
          _buildSwitch(
            "Hotelzinho",
            "Gestão de Hospedagem",
            _temHotel,
            (v) => setState(() => _temHotel = v),
          ),
          _buildSwitch(
            "Creche (DayCare)",
            "Controle diário",
            _temCreche,
            (v) => setState(() => _temCreche = v),
          ),
          _buildSwitch(
            "Loja (App)",
            "Vendas no App do Cliente",
            _temLoja,
            (v) => setState(() => _temLoja = v),
          ),
          _buildSwitch(
            "PDV (Caixa)",
            "Ponto de Venda no Painel Admin",
            _temPdv,
            (v) => setState(() => _temPdv = v),
          ),
          _buildSwitch(
            "Veterinário",
            "Agenda Médica",
            _temVeterinario,
            (v) => setState(() => _temVeterinario = v),
          ),
          _buildSwitch(
            "Táxi Dog",
            "Gestão de Transporte",
            _temTaxi,
            (v) => setState(() => _temTaxi = v),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingCard() {
    return _buildCard(
      title: "Identidade Visual",
      icon: Icons.palette,
      child: Column(
        children: [
          _buildInput(_logoAppCtrl, "URL Logo App", Icons.mobile_friendly),
          SizedBox(height: 15),
          _buildInput(_logoAdminCtrl, "URL Logo Painel", Icons.desktop_windows),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return _buildCard(
      title: "Pagamentos",
      icon: Icons.credit_card,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _gatewayPagamento,
            decoration: InputDecoration(
              labelText: "Gateway",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 15),
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
            onChanged: (v) => setState(() => _gatewayPagamento = v!),
          ),
          SizedBox(height: 20),
          if (_gatewayPagamento == 'efipay') ...[
            _buildSwitch(
              "Ambiente de Teste (Sandbox)",
              "Ative para usar credenciais de homologação",
              _efipaySandbox,
              (v) => setState(() => _efipaySandbox = v),
            ),
            SizedBox(height: 10),
            _buildInput(_efipayClientIdCtrl, "Client ID", Icons.key),
            SizedBox(height: 10),
            _buildInput(
              _efipayClientSecretCtrl,
              "Client Secret",
              Icons.lock,
              obscure: true,
            ),
            SizedBox(height: 10),
            _buildInput(_efipayChavePixCtrl, "Chave PIX", Icons.qr_code),
            SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _testarGateway,
              icon: Icon(Icons.check_circle_outline),
              label: Text("TESTAR CREDENCIAIS"),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 45),
                foregroundColor: Colors.blue[800],
              ),
            ),
            SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _configurarWebhookEfi,
              icon: Icon(Icons.link),
              label: Text("CONFIGURAR WEBHOOK NA EFI"),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 45),
                foregroundColor: Colors.purple[800],
              ),
            ),
          ] else
            _buildInput(
              _mpAccessTokenCtrl,
              "Access Token",
              Icons.vpn_key,
              obscure: true,
            ),
          SizedBox(height: 20),
          Divider(),
          TextButton.icon(
            onPressed: _simularWebhook,
            icon: Icon(Icons.bug_report, size: 18),
            label: Text("SIMULAR WEBHOOK (TESTE)"),
            style: TextButton.styleFrom(foregroundColor: Colors.orange[800]),
          ),
        ],
      ),
    );
  }

  Future<void> _testarGateway() async {
    setState(() => _isSaving = true);
    try {
      final functions = FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      );
      final result = await functions
          .httpsCallable('testarCredenciaisGateway')
          .call({
            'tenantId': widget.tenantId,
            'efipay_client_id': _efipayClientIdCtrl.text.trim(),
            'efipay_client_secret': _efipayClientSecretCtrl.text.trim(),
            'efipay_sandbox': _efipaySandbox,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.data['message'] ?? "Sucesso!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (e is FirebaseFunctionsException) msg = e.message ?? msg;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Falha: $msg"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _configurarWebhookEfi() async {
    final urlCtrl = TextEditingController(
      text: "https://webhookpix-vgbo2eilca-rj.a.run.app",
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Configurar Webhook na EfiPay"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Esta ação registrará a URL abaixo na EfiPay para receber notificações de PIX nesta conta.",
            ),
            SizedBox(height: 15),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: "URL do Webhook",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCELAR"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (urlCtrl.text.isEmpty) return;

              setState(() => _isSaving = true);
              try {
                final functions = FirebaseFunctions.instanceFor(
                  region: 'southamerica-east1',
                );
                final result = await functions
                    .httpsCallable('configurarWebhookEfi')
                    .call({
                      'tenantId': widget.tenantId,
                      'webhookUrl': urlCtrl.text.trim(),
                      'efipay_client_id': _efipayClientIdCtrl.text.trim(),
                      'efipay_client_secret': _efipayClientSecretCtrl.text.trim(),
                      'chave_pix': _efipayChavePixCtrl.text.trim(),
                      'efipay_sandbox': _efipaySandbox,
                    });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.data['message'] ?? "Configurado!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  String msg = e.toString();
                  if (e is FirebaseFunctionsException) msg = e.message ?? msg;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erro: $msg"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            child: Text("REGISTRAR"),
          ),
        ],
      ),
    );
  }

  Future<void> _simularWebhook() async {
    final txidCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Simular Webhook PIX"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Insira o TXID da transação para forçar a aprovação:"),
            SizedBox(height: 10),
            TextField(
              controller: txidCtrl,
              decoration: InputDecoration(
                labelText: "TXID",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCELAR"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (txidCtrl.text.isEmpty) return;

              setState(() => _isSaving = true);
              try {
                final functions = FirebaseFunctions.instanceFor(
                  region: 'southamerica-east1',
                );
                final result = await functions
                    .httpsCallable('simularWebhookPix')
                    .call({'txid': txidCtrl.text.trim()});

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.data['message'] ?? "Processado!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erro: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            child: Text("SIMULAR"),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(
    String title,
    String sub,
    bool val,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: TextStyle(fontSize: 12)),
      value: val,
      activeColor: Theme.of(context).primaryColor,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildInput(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool obscure = false,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}
