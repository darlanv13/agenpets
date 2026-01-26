import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/admin_web/widgets/professional_editor_dialog.dart';

class EquipeView extends StatefulWidget {
  @override
  _EquipeViewState createState() => _EquipeViewState();
}

class _EquipeViewState extends State<EquipeView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  // --- PALETA DE CORES ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF5F7FA);

  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();

  var maskCpf = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool _isLoading = false;

  // --- FUNÇÕES (CHECKBOXES) ---
  bool fazBanho = true;
  bool fazTosa = false;
  bool fazVendas = false;

  // NOVAS FUNÇÕES SEPARADAS
  bool fazCaixa = false; // Operador de Caixa
  bool fazMaster = false; // Gerente / Admin

  void _cadastrarFuncionario() async {
    if (_nomeController.text.isEmpty ||
        _cpfController.text.isEmpty ||
        _senhaController.text.isEmpty) {
      _showSnack("Preencha Nome, CPF e Senha Inicial.", Colors.orange);
      return;
    }

    if (_senhaController.text.length < 6) {
      _showSnack("A senha deve ter no mínimo 6 caracteres.", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    // 1. Define Habilidades (Tags visuais e filtros)
    List<String> habs = [];
    if (fazBanho) habs.add('banho');
    if (fazTosa) habs.add('tosa');
    if (fazVendas) habs.add('vendedor');
    if (fazCaixa) habs.add('caixa');
    if (fazMaster) habs.add('master');

    if (habs.isEmpty) {
      _showSnack("Selecione ao menos uma função.", Colors.orange);
      setState(() => _isLoading = false);
      return;
    }

    // 2. Define Perfil de Segurança (Isso que define o acesso no Login)
    // Se marcou Master, o perfil é 'master' (Acesso total).
    // Senão, é 'padrao' (Acesso restrito às suas funções).
    String perfilEnvio = fazMaster ? 'master' : 'padrao';

    try {
      await _functions.httpsCallable('criarContaProfissional').call({
        'nome': _nomeController.text.trim(),
        'cpf': _cpfController.text,
        'senha': _senhaController.text.trim(),
        'habilidades': habs,
        'perfil': perfilEnvio,
      });

      // Sucesso
      _nomeController.clear();
      _cpfController.clear();
      _senhaController.clear();
      setState(() {
        fazBanho = true;
        fazTosa = false;
        fazVendas = false;
        fazCaixa = false;
        fazMaster = false;
      });

      _showSnack("Profissional criado com sucesso!", Colors.green);
    } catch (e) {
      String msg = "Erro ao cadastrar.";
      if (e is FirebaseFunctionsException) {
        msg = e.message ?? e.code;
        if (e.code == 'already-exists') msg = "Este CPF já está cadastrado.";
      }
      _showSnack(msg, Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Column(
        children: [
          // HEADER
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
                    color: _corLilas,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.people_alt_rounded,
                    color: _corAcai,
                    size: 28,
                  ),
                ),
                SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Gestão de Equipe",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _corAcai,
                      ),
                    ),
                    Text(
                      "Cadastre e gerencie seus profissionais",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // CONTEÚDO
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- COLUNA FORMULÁRIO ---
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Container(
                        padding: EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Novo Colaborador",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 20),

                            _buildTextField(
                              _nomeController,
                              "Nome Completo",
                              Icons.person,
                            ),
                            SizedBox(height: 15),
                            _buildTextField(
                              _cpfController,
                              "CPF (Login)",
                              Icons.badge,
                              formatter: maskCpf,
                            ),
                            SizedBox(height: 15),

                            TextField(
                              controller: _senhaController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: "Senha Inicial",
                                prefixIcon: Icon(
                                  Icons.lock,
                                  color: _corAcai,
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: _corFundo,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                helperText: "Mínimo 6 caracteres",
                              ),
                            ),

                            SizedBox(height: 25),
                            Text(
                              "Funções Operacionais",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 10),

                            _buildRoleSelector(
                              "Banhista",
                              FontAwesomeIcons.shower,
                              fazBanho,
                              (v) => setState(() => fazBanho = v),
                            ),
                            SizedBox(height: 10),
                            _buildRoleSelector(
                              "Tosador",
                              FontAwesomeIcons.scissors,
                              fazTosa,
                              (v) => setState(() => fazTosa = v),
                            ),
                            SizedBox(height: 10),
                            _buildRoleSelector(
                              "Vendedor",
                              FontAwesomeIcons.basketShopping,
                              fazVendas,
                              (v) => setState(() => fazVendas = v),
                            ),
                            SizedBox(height: 10),
                            // SEPARADO: CAIXA
                            _buildRoleSelector(
                              "Caixa (Operador)",
                              FontAwesomeIcons.cashRegister,
                              fazCaixa,
                              (v) => setState(() => fazCaixa = v),
                            ),

                            SizedBox(height: 20),
                            Divider(),
                            Text(
                              "Permissões Administrativas",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 10),

                            // SEPARADO: MASTER
                            _buildRoleSelector(
                              "Master (Gerente/Admin)",
                              FontAwesomeIcons.userShield,
                              fazMaster,
                              (v) {
                                setState(() {
                                  fazMaster = v;
                                  if (v)
                                    fazCaixa =
                                        true; // Master geralmente também opera caixa se quiser
                                });
                              },
                              isAlert: true,
                            ),

                            SizedBox(height: 30),
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
                                    : Icon(Icons.add_circle),
                                label: Text(
                                  _isLoading ? "CRIANDO..." : "CRIAR CONTA",
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _corAcai,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : _cadastrarFuncionario,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 30),

                  // --- COLUNA LISTA (Visualização) ---
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Equipe Ativa",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 20),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: _db
                                  .collection('profissionais')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return Center(
                                    child: CircularProgressIndicator(),
                                  );
                                final docs = snapshot.data!.docs;
                                if (docs.isEmpty)
                                  return Center(
                                    child: Text("Nenhum profissional ativo."),
                                  );

                                return ListView.separated(
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 30,
                                    color: Colors.grey[100],
                                  ),
                                  itemBuilder: (ctx, index) {
                                    final doc = docs[index];
                                    final data = doc.data() as Map;
                                    final List<dynamic> skills =
                                        data['habilidades'] ?? [];
                                    final String perfil =
                                        data['perfil'] ?? 'padrao';

                                    // Destaque visual para Master
                                    bool isMaster = perfil == 'master';
                                    bool isAtivo = data['ativo'] ?? true;

                                    return Opacity(
                                      opacity: isAtivo ? 1.0 : 0.6,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: isMaster
                                                  ? Colors.amber[100]
                                                  : _corLilas,
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: Center(
                                              child: isMaster
                                                  ? Icon(
                                                      FontAwesomeIcons.crown,
                                                      color: Colors.amber[800],
                                                      size: 22,
                                                    )
                                                  : Text(
                                                      (data['nome'] as String)
                                                              .isNotEmpty
                                                          ? data['nome'][0]
                                                                .toUpperCase()
                                                          : "?",
                                                      style: TextStyle(
                                                        color: _corAcai,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 20,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          SizedBox(width: 15),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      data['nome'],
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                        color: Colors.grey[800],
                                                        decoration: isAtivo
                                                            ? null
                                                            : TextDecoration
                                                                  .lineThrough,
                                                      ),
                                                    ),
                                                    if (!isAtivo)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 8.0,
                                                            ),
                                                        child: Container(
                                                          margin:
                                                              EdgeInsets.only(
                                                                left: 8,
                                                              ),
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            "INATIVO",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                SizedBox(height: 5),
                                                Text(
                                                  "CPF: ${data['cpf']}",
                                                  style: TextStyle(
                                                    color: Colors.grey[500],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 5,
                                                  children: skills
                                                      .map(
                                                        (skill) =>
                                                            _buildSkillBadge(
                                                              skill.toString(),
                                                            ),
                                                      )
                                                      .toList(),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: "Editar Profissional",
                                            icon: Icon(
                                              Icons.edit,
                                              color: Colors.blue[300],
                                            ),
                                            onPressed: () => _editar(doc),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---
  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    MaskTextInputFormatter? formatter,
  }) {
    return TextField(
      controller: ctrl,
      inputFormatters: formatter != null ? [formatter] : [],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _corAcai, size: 20),
        filled: true,
        fillColor: _corFundo,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildRoleSelector(
    String label,
    IconData icon,
    bool isSelected,
    Function(bool) onChanged, {
    bool isAlert = false,
  }) {
    Color activeColor = isAlert ? Colors.red : _corAcai;
    Color bgActive = isAlert
        ? Colors.red.withOpacity(0.1)
        : _corAcai.withOpacity(0.1);

    return InkWell(
      onTap: () => onChanged(!isSelected),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? bgActive : Colors.white,
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? activeColor : Colors.grey),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? activeColor : Colors.grey[700],
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: activeColor, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillBadge(String skill) {
    Color bg;
    Color text;
    String label;
    IconData icon;
    switch (skill) {
      case 'banho':
        bg = Colors.blue[50]!;
        text = Colors.blue[800]!;
        label = "Banhista";
        icon = FontAwesomeIcons.shower;
        break;
      case 'tosa':
        bg = Colors.orange[50]!;
        text = Colors.orange[800]!;
        label = "Tosador";
        icon = FontAwesomeIcons.scissors;
        break;
      case 'vendedor':
        bg = Colors.green[50]!;
        text = Colors.green[800]!;
        label = "Vendas";
        icon = FontAwesomeIcons.basketShopping;
        break;
      case 'caixa':
        bg = Colors.purple[50]!;
        text = Colors.purple[800]!;
        label = "Caixa";
        icon = FontAwesomeIcons.cashRegister;
        break;
      case 'master':
        bg = Colors.red[50]!;
        text = Colors.red[800]!;
        label = "MASTER";
        icon = FontAwesomeIcons.userShield;
        break;
      default:
        bg = Colors.grey[200]!;
        text = Colors.grey[800]!;
        label = skill;
        icon = Icons.circle;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: text),
          SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  void _editar(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => ProfessionalEditorDialog(profissional: doc),
    );
  }
}
