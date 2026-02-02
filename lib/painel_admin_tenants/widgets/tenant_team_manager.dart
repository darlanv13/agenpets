import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TenantTeamManager extends StatefulWidget {
  final String tenantId;
  const TenantTeamManager({super.key, required this.tenantId});
  @override
  _TenantTeamManagerState createState() => _TenantTeamManagerState();
}

class _TenantTeamManagerState extends State<TenantTeamManager> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );
  final _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();

  var maskCpf = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );
  bool _isLoading = false;
  String _filtroEquipe = "";
  Set<String> _rolesSelecionadas = {};

  // Permissões
  final Map<String, String> _allPossiblePages = {
    'dashboard': 'Dashboard',
    'loja_pdv': 'PDV / Vendas',
    'banhos_tosa': 'Agenda Banho/Tosa',
    'hotel': 'Agenda Hotel',
    'creche': 'Agenda Creche',
    'venda_planos': 'Venda de Planos',
    'gestao_precos': 'Tabela de Preços',
    'banners_app': 'Banners do App',
    'gestao_estoque': 'Gestão de Estoque',
    'equipe': 'Gestão Equipe',
    'configuracoes': 'Configs',
  };

  Map<String, String> _filteredAvailablePages = {};
  Map<String, bool> _selectedAccess = {};

  @override
  void initState() {
    super.initState();
    _loadTenantConfig();
  }

  Future<void> _loadTenantConfig() async {
    try {
      final doc = await _db
          .collection('tenants')
          .doc(widget.tenantId)
          .collection('config')
          .doc('parametros')
          .get();

      Map<String, dynamic> config = {};
      if (doc.exists) config = doc.data()!;

      bool temPdv = config['tem_pdv'] ?? false;
      bool temBanhoTosa = config['tem_banho_tosa'] ?? true;
      bool temHotel = config['tem_hotel'] ?? false;
      bool temCreche = config['tem_creche'] ?? false;

      Map<String, String> filtered = {};
      _allPossiblePages.forEach((key, value) {
        if (key == 'loja_pdv' && !temPdv) return;
        if (key == 'banhos_tosa' && !temBanhoTosa) return;
        if (key == 'hotel' && !temHotel) return;
        if (key == 'creche' && !temCreche) return;
        filtered[key] = value;
      });

      if (mounted) {
        setState(() {
          _filteredAvailablePages = filtered;
          // Inicializa dashboard como true
          filtered.keys.forEach((k) {
            if (!_selectedAccess.containsKey(k)) {
              _selectedAccess[k] = (k == 'dashboard');
            }
          });
          // Garante dashboard ativo
          _selectedAccess['dashboard'] = true;
        });
      }
    } catch (e) {
      print("Erro ao carregar config do tenant: $e");
      // Fallback
      if (mounted) {
        setState(() {
          _filteredAvailablePages = _allPossiblePages;
          _allPossiblePages.keys
              .forEach((k) => _selectedAccess[k] = (k == 'dashboard'));
        });
      }
    }
  }

  void _toggleRole(String role) {
    setState(() {
      if (_rolesSelecionadas.contains(role)) {
        _rolesSelecionadas.remove(role);
        if (role == 'master')
          _filteredAvailablePages.keys
              .forEach((k) => _selectedAccess[k] = false);
      } else {
        _rolesSelecionadas.add(role);
        if (role == 'master') {
          _filteredAvailablePages.keys
              .forEach((k) => _selectedAccess[k] = true);
          _rolesSelecionadas.add('caixa');
        }
      }
    });
  }

  Future<void> _cadastrar() async {
    if (_nomeController.text.isEmpty ||
        _cpfController.text.length < 14 ||
        _senhaController.text.length < 6) {
      _showSnack("Preencha os campos corretamente.", Colors.orange);
      return;
    }
    if (_rolesSelecionadas.isEmpty) {
      _showSnack("Selecione uma função.", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      List<String> acessos = _selectedAccess.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
      String perfil = _rolesSelecionadas.contains('master')
          ? 'master'
          : 'padrao';

      await _functions.httpsCallable('criarContaProfissional').call({
        'nome': _nomeController.text.trim(),
        'documento': _cpfController.text,
        'cpf': _cpfController.text,
        'senha': _senhaController.text.trim(),
        'habilidades': _rolesSelecionadas.toList(),
        'acessos': acessos,
        'perfil': perfil,
        'tenantId': widget.tenantId,
      });

      _clearForm();
      if (mounted) _showSnack("Adicionado!", Colors.green);
    } catch (e) {
      if (mounted) _showSnack("Erro: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _nomeController.clear();
    _cpfController.clear();
    _senhaController.clear();
    setState(() {
      _rolesSelecionadas.clear();
      _filteredAvailablePages.keys
          .forEach((k) => _selectedAccess[k] = (k == 'dashboard'));
    });
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
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 900;

        // Form Widget isolado
        Widget formWidget = _buildFormCard();
        // List Widget isolado
        Widget listWidget = _buildListCard();

        if (isWide) {
          return Padding(
            padding: EdgeInsets.all(30),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(child: formWidget),
                ), // Scroll para prevenir overflow vertical em telas médias
                SizedBox(width: 30),
                Expanded(flex: 3, child: listWidget),
              ],
            ),
          );
        } else {
          // Mobile: Coluna com Scroll Geral
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [formWidget, SizedBox(height: 30), listWidget],
            ),
          );
        }
      },
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Novo Colaborador",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            _buildInput(_nomeController, "Nome Completo", Icons.person),
            SizedBox(height: 15),
            _buildInput(
              _cpfController,
              "CPF (Login)",
              Icons.badge,
              formatter: maskCpf,
            ),
            SizedBox(height: 15),
            _buildInput(
              _senhaController,
              "Senha Inicial",
              Icons.lock,
              obscure: true,
            ),
            SizedBox(height: 25),
            Text(
              "Função",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip("Banhista", "banho"),
                _buildChip("Tosador", "tosa"),
                _buildChip("Vendedor", "vendedor"),
                _buildChip("Caixa", "caixa"),
                _buildChip("Gerente", "master", color: Colors.amber[800]),
              ],
            ),
            if (!_rolesSelecionadas.contains('master')) ...[
              Divider(height: 30),
              Text(
                "Permissões Extras",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              ..._filteredAvailablePages.entries
                  .map(
                    (e) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Theme.of(context).primaryColor,
                      title: Text(e.value, style: TextStyle(fontSize: 13)),
                      value: _selectedAccess[e.key] ?? false,
                      onChanged: (v) =>
                          setState(() => _selectedAccess[e.key] = v!),
                    ),
                  )
                  .toList(),
            ],
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _cadastrar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "CADASTRAR",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  "Equipe",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Container(
                  width: 150,
                  height: 40,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Buscar...",
                      prefixIcon: Icon(Icons.search, size: 18),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onChanged: (v) =>
                        setState(() => _filtroEquipe = v.toLowerCase()),
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('tenants')
                  .doc(widget.tenantId)
                  .collection('profissionais')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs
                    .where(
                      (d) => (d['nome'] as String).toLowerCase().contains(
                        _filtroEquipe,
                      ),
                    )
                    .toList();

                if (docs.isEmpty)
                  return Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      "Nenhum colaborador.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );

                return ListView.separated(
                  shrinkWrap: true,
                  physics:
                      NeverScrollableScrollPhysics(), // Scroll controlado pelo pai
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map;
                    final skills = List<String>.from(data['habilidades'] ?? []);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        child: Text(
                          data['nome'][0],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      title: Text(
                        data['nome'],
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "CPF: ${data['documento']} • ${skills.join(', ').toUpperCase()}",
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red[300],
                        ),
                        onPressed: () {
                          /* Implementar Delete */
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool obscure = false,
    MaskTextInputFormatter? formatter,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      inputFormatters: formatter != null ? [formatter] : [],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
    );
  }

  Widget _buildChip(String label, String val, {Color? color}) {
    bool selected = _rolesSelecionadas.contains(val);
    Color c = color ?? Theme.of(context).primaryColor;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _toggleRole(val),
      selectedColor: c.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? c : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: selected ? c : Colors.grey[300]!),
      backgroundColor: Colors.white,
    );
  }
}
