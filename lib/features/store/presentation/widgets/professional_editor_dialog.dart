import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ProfessionalEditorDialog extends StatefulWidget {
  final DocumentSnapshot profissional;

  const ProfessionalEditorDialog({super.key, required this.profissional});

  @override
  _ProfessionalEditorDialogState createState() =>
      _ProfessionalEditorDialogState();
}

class _ProfessionalEditorDialogState extends State<ProfessionalEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeCtrl;
  late TextEditingController _cpfCtrl;

  // Skills
  bool fazBanho = false;
  bool fazTosa = false;
  bool fazVendas = false;
  bool fazCaixa = false;
  bool fazMaster = false;

  bool ativo = true;
  bool _isLoading = false;

  // Colors (copied from EquipeView for consistency)
  final Color _corAcai = Color(0xFF4A148C);

  // --- PERMISSÕES DE ACESSO (PÁGINAS) ---
  final Map<String, String> _availablePages = {
    'dashboard': 'Dashboard',
    'loja_pdv': 'Loja / PDV',
    'banhos_tosa': 'Banhos & Tosa',
    'hotel': 'Hotel & Estadia',
    'creche': 'Creche',
    'venda_planos': 'Venda de Planos',
    'gestao_precos': 'Tabela de Preços',
    'banners_app': 'Banners do App',
    'equipe': 'Gestão de Equipe',
    'configuracoes': 'Configurações',
    'gestao_estoque': 'Gestão de Estoque',
  };

  final Map<String, bool> _selectedAccess = {};

  @override
  void initState() {
    super.initState();
    final data = widget.profissional.data() as Map<String, dynamic>;
    _nomeCtrl = TextEditingController(text: data['nome'] ?? '');
    _cpfCtrl = TextEditingController(text: data['cpf'] ?? '');
    ativo = data['ativo'] ?? true;

    final List<dynamic> skills = data['habilidades'] ?? [];
    fazBanho = skills.contains('banho');
    fazTosa = skills.contains('tosa');
    fazVendas = skills.contains('vendedor');
    fazCaixa = skills.contains('caixa');
    fazMaster = skills.contains('master');

    // Init Access
    final List<dynamic> currentAccess = data['acessos'] ?? [];
    _availablePages.forEach((key, value) {
      _selectedAccess[key] = currentAccess.contains(key);
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      List<String> habs = [];
      if (fazBanho) habs.add('banho');
      if (fazTosa) habs.add('tosa');
      if (fazVendas) habs.add('vendedor');
      if (fazCaixa) habs.add('caixa');
      if (fazMaster) habs.add('master');

      String perfil = fazMaster ? 'master' : 'padrao';

      // Prepare Access List
      List<String> acessos = [];
      if (fazMaster) {
        // Optionally save all keys, or just empty if logic relies only on master profile.
        // Saving keys allows easier downgrade later.
        acessos = _availablePages.keys.toList();
      } else {
        _selectedAccess.forEach((key, value) {
          if (value) acessos.add(key);
        });
      }

      await widget.profissional.reference.update({
        'nome': _nomeCtrl.text.trim(),
        'habilidades': habs,
        'perfil': perfil,
        'ativo': ativo,
        'acessos': acessos,
        // CPF não atualiza pois é chave/login
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profissional atualizado com sucesso!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao salvar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _excluir() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Excluir Profissional?"),
        content: Text(
          "Esta ação é irreversível. O profissional será removido permanentemente do sistema.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Excluir", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await widget.profissional.reference.delete();
        if (mounted) {
          Navigator.pop(context); // Close Editor Dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Profissional excluído."),
              backgroundColor: Colors.grey,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erro ao excluir: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Editar Profissional"),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            tooltip: "Excluir Profissional",
            onPressed: _isLoading ? null : _excluir,
          ),
        ],
      ),
      content: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // STATUS SWITCH
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ativo ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ativo ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      ativo ? "Usuário Ativo" : "Usuário Inativo",
                      style: TextStyle(
                        color: ativo ? Colors.green[800] : Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      ativo
                          ? "O profissional tem acesso ao sistema."
                          : "O acesso está bloqueado.",
                    ),
                    value: ativo,
                    activeThumbColor: Colors.green,
                    onChanged: (v) => setState(() => ativo = v),
                  ),
                ),
                SizedBox(height: 20),

                TextFormField(
                  controller: _nomeCtrl,
                  decoration: InputDecoration(
                    labelText: "Nome Completo",
                    prefixIcon: Icon(Icons.person, color: _corAcai),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo obrigatório' : null,
                ),
                SizedBox(height: 15),
                TextFormField(
                  controller: _cpfCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "CPF (Login)",
                    prefixIcon: Icon(Icons.badge, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),

                SizedBox(height: 25),
                Text(
                  "Funções e Permissões",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 10),

                _buildCheckbox(
                  "Banhista",
                  FontAwesomeIcons.shower,
                  fazBanho,
                  (v) => setState(() => fazBanho = v!),
                ),
                _buildCheckbox(
                  "Tosador",
                  FontAwesomeIcons.scissors,
                  fazTosa,
                  (v) => setState(() => fazTosa = v!),
                ),
                _buildCheckbox(
                  "Vendedor",
                  FontAwesomeIcons.basketShopping,
                  fazVendas,
                  (v) => setState(() => fazVendas = v!),
                ),
                _buildCheckbox(
                  "Caixa",
                  FontAwesomeIcons.cashRegister,
                  fazCaixa,
                  (v) => setState(() => fazCaixa = v!),
                ),
                Divider(),
                _buildCheckbox(
                  "Master (Gerente/Admin)",
                  FontAwesomeIcons.userShield,
                  fazMaster,
                  (v) => setState(() {
                    fazMaster = v!;
                    if (v) {
                      fazCaixa = true;
                      _availablePages.forEach(
                        (key, val) => _selectedAccess[key] = true,
                      );
                    }
                  }),
                  isAlert: true,
                ),

                // --- SEÇÃO DE ACESSOS ---
                if (!fazMaster) ...[
                  SizedBox(height: 20),
                  Divider(),
                  Text(
                    "Acesso às Páginas (Permissões)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 10),
                  ..._availablePages.entries.map((entry) {
                    return CheckboxListTile(
                      title: Text(entry.value),
                      value: _selectedAccess[entry.key] ?? false,
                      activeColor: _corAcai,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() {
                          _selectedAccess[entry.key] = val ?? false;
                        });
                      },
                    );
                  }).toList(),
                ],
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
            backgroundColor: _corAcai,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _isLoading ? null : _salvar,
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text("Salvar Alterações"),
        ),
      ],
    );
  }

  Widget _buildCheckbox(
    String label,
    IconData icon,
    bool value,
    Function(bool?) onChanged, {
    bool isAlert = false,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Row(
        children: [
          Icon(icon, size: 16, color: isAlert ? Colors.red : Colors.grey[700]),
          SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: isAlert ? Colors.red : Colors.grey[800],
              fontWeight: isAlert ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      activeColor: isAlert ? Colors.red : _corAcai,
    );
  }
}
