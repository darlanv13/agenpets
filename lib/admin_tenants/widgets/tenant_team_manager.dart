import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/admin_web/widgets/professional_editor_dialog.dart';

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

  // Controllers e Forms
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();

  var maskCpf = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );
  bool _isLoading = false;
  String _filtroEquipe = "";

  // Funções / Roles
  Set<String> _rolesSelecionadas = {};

  // Permissões
  final Map<String, String> _availablePages = {
    'dashboard': 'Dashboard',
    'loja_pdv': 'PDV / Vendas',
    'banhos_tosa': 'Agenda Banho/Tosa',
    'hotel': 'Agenda Hotel',
    'creche': 'Agenda Creche',
    'equipe': 'Gestão Equipe',
    'configuracoes': 'Configs',
  };
  Map<String, bool> _selectedAccess = {};

  @override
  void initState() {
    super.initState();
    _availablePages.forEach((k, v) => _selectedAccess[k] = false);
  }

  void _toggleRole(String role) {
    setState(() {
      if (_rolesSelecionadas.contains(role)) {
        _rolesSelecionadas.remove(role);
        // Se remover Master, limpa acessos automáticos
        if (role == 'master')
          _availablePages.keys.forEach((k) => _selectedAccess[k] = false);
      } else {
        _rolesSelecionadas.add(role);
        // Se adicionar Master, seleciona tudo
        if (role == 'master') {
          _availablePages.keys.forEach((k) => _selectedAccess[k] = true);
          _rolesSelecionadas.add('caixa'); // Master geralmente opera caixa
        }
      }
    });
  }

  Future<void> _cadastrar() async {
    if (_nomeController.text.isEmpty ||
        _cpfController.text.isEmpty ||
        _senhaController.text.length < 6) {
      _showSnack(
        "Preencha todos os campos corretamente (senha min 6).",
        Colors.orange,
      );
      return;
    }
    if (_rolesSelecionadas.isEmpty) {
      _showSnack("Selecione ao menos uma função.", Colors.orange);
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
        'perfil': perfil,
        'tenantId': widget.tenantId,
      });

      // Atualiza permissões manuais se não for master (ou reforça se for)
      final q = await _db
          .collection('tenants')
          .doc(widget.tenantId)
          .collection('profissionais')
          .where('documento', isEqualTo: _cpfController.text)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty)
        await q.docs.first.reference.update({'acessos': acessos});

      _clearForm();
      if (mounted) _showSnack("Colaborador adicionado!", Colors.green);
    } catch (e) {
      if (mounted) _showSnack("Erro: ${e.toString()}", Colors.red);
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
      _availablePages.keys.forEach((k) => _selectedAccess[k] = false);
    });
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 900;
        return Padding(
          padding: EdgeInsets.all(isWide ? 30 : 15),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildFormCard()),
                    SizedBox(width: 30),
                    Expanded(flex: 3, child: _buildListCard()),
                  ],
                )
              : Column(
                  children: [
                    _buildFormCard(),
                    SizedBox(height: 30),
                    _buildListCard(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_add, color: Theme.of(context).primaryColor),
                SizedBox(width: 10),
                Text(
                  "Novo Colaborador",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 25),
            TextFormField(
              controller: _nomeController,
              decoration: InputDecoration(
                labelText: "Nome Completo",
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 15),
            TextFormField(
              controller: _cpfController,
              inputFormatters: [maskCpf],
              decoration: InputDecoration(
                labelText: "CPF (Login)",
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 15),
            TextFormField(
              controller: _senhaController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Senha Inicial",
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 25),
            Text(
              "Funções & Permissões",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
                fontSize: 16,
              ),
            ),
            SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildRoleChip("Banhista", "banho", FontAwesomeIcons.shower),
                _buildRoleChip("Tosador", "tosa", FontAwesomeIcons.scissors),
                _buildRoleChip(
                  "Vendedor",
                  "vendedor",
                  FontAwesomeIcons.bagShopping,
                ),
                _buildRoleChip("Caixa", "caixa", FontAwesomeIcons.cashRegister),
                _buildRoleChip(
                  "Gerente/Master",
                  "master",
                  FontAwesomeIcons.userShield,
                  isDestructive: true,
                ),
              ],
            ),

            if (!_rolesSelecionadas.contains('master')) ...[
              SizedBox(height: 20),
              Divider(thickness: 1),
              SizedBox(height: 10),
              Text(
                "Acesso a Páginas",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              ..._availablePages.entries
                  .map(
                    (e) => CheckboxListTile(
                      dense: true,
                      activeColor: Theme.of(context).primaryColor,
                      title: Text(e.value),
                      value: _selectedAccess[e.key],
                      onChanged: (v) =>
                          setState(() => _selectedAccess[e.key] = v!),
                    ),
                  )
                  .toList(),
            ],

            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading ? null : _cadastrar,
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Text(
                        "CADASTRAR EQUIPE",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(25),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.grey[700]),
                SizedBox(width: 10),
                Text(
                  "Equipe Ativa",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                SizedBox(
                  width: 200,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Buscar...",
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onChanged: (v) =>
                        setState(() => _filtroEquipe = v.toLowerCase()),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('tenants')
                  .doc(widget.tenantId)
                  .collection('profissionais')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator()),
                  );

                final docs = snapshot.data!.docs.where((d) {
                  final data = d.data() as Map;
                  return (data['nome'] ?? '').toString().toLowerCase().contains(
                    _filtroEquipe,
                  );
                }).toList();

                if (docs.isEmpty)
                  return Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 40,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Nenhum colaborador encontrado.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );

                return ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map;
                    final skills = List<String>.from(data['habilidades'] ?? []);
                    final bool isMaster =
                        skills.contains('master') || data['perfil'] == 'master';
                    final bool ativo = data['ativo'] ?? true;

                    return Card(
                      elevation: 0,
                      color: ativo ? Colors.white : Colors.grey[100],
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 10,
                        ),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: isMaster
                              ? Colors.amber[100]
                              : Colors.blue[50],
                          child: Icon(
                            isMaster ? FontAwesomeIcons.crown : Icons.person,
                            color: isMaster
                                ? Colors.amber[800]
                                : Colors.blue[800],
                            size: 20,
                          ),
                        ),
                        title: Text(
                          data['nome'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: ativo
                                ? null
                                : TextDecoration.lineThrough,
                            color: ativo ? Colors.black87 : Colors.grey,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              "CPF: ${data['documento']}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: skills
                                  .map(
                                    (s) => _buildSkillBadge(
                                      s,
                                      ativo: ativo,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.edit_outlined, color: Colors.blue),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) =>
                                ProfessionalEditorDialog(profissional: docs[i]),
                          ),
                        ),
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

  Widget _buildRoleChip(
    String label,
    String value,
    IconData icon, {
    bool isDestructive = false,
  }) {
    bool selected = _rolesSelecionadas.contains(value);
    Color color = isDestructive
        ? Colors.amber[800]!
        : Theme.of(context).primaryColor;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: selected ? Colors.white : color),
          SizedBox(width: 8),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => _toggleRole(value),
      backgroundColor: Colors.white,
      selectedColor: color,
      labelStyle: TextStyle(
        color: selected ? Colors.white : color,
        fontWeight: FontWeight.bold,
      ),
      side: BorderSide(color: color.withOpacity(0.3)),
      checkmarkColor: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildSkillBadge(String skill, {bool ativo = true}) {
    // Cores específicas para cada função para facilitar identificação visual
    Color bg = Colors.grey[100]!;
    Color text = Colors.grey[700]!;

    if (ativo) {
      switch (skill) {
        case 'banho':
          bg = Colors.blue[50]!;
          text = Colors.blue[800]!;
          break;
        case 'tosa':
          bg = Colors.purple[50]!;
          text = Colors.purple[800]!;
          break;
        case 'vendedor':
          bg = Colors.green[50]!;
          text = Colors.green[800]!;
          break;
        case 'caixa':
          bg = Colors.orange[50]!;
          text = Colors.orange[800]!;
          break;
        case 'master':
          bg = Colors.amber[50]!;
          text = Colors.amber[900]!;
          break;
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ativo ? bg.withOpacity(0.5) : Colors.grey[300]!,
        ),
      ),
      child: Text(
        skill.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }
}
