import 'package:agenpet/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PacotesView extends StatefulWidget {
  const PacotesView({super.key});

  @override
  _PacotesViewState createState() => _PacotesViewState();
}

class _PacotesViewState extends State<PacotesView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 30),
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Pacotes e Assinaturas",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _corAcai,
              ),
            ),
            Text(
              "Gerencie os planos exibidos no aplicativo",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        ElevatedButton.icon(
          icon: Icon(Icons.add, size: 18),
          label: Text("NOVO PACOTE"),
          style: ElevatedButton.styleFrom(
            backgroundColor: _corAcai,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => _abrirEditorPacote(context),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('pacotes')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: _corAcai));
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.boxOpen,
                  size: 50,
                  color: Colors.grey[300],
                ),
                SizedBox(height: 15),
                Text(
                  "Nenhum pacote criado.",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 350,
            childAspectRatio: 0.8,
            crossAxisSpacing: 25,
            mainAxisSpacing: 25,
          ),
          itemCount: docs.length,
          itemBuilder: (ctx, i) => _buildPacoteCard(docs[i]),
        );
      },
    );
  }

  Widget _buildPacoteCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    bool isAtivo = data['ativo'] ?? true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Status
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: isAtivo
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey[100],
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAtivo ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isAtivo ? "ATIVO" : "INATIVO",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  "R\$ ${data['preco']}",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _corAcai,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['nome'],
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 5),
                  Text(
                    data['porte'] ?? 'Todos',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  Divider(height: 30),
                  Expanded(child: ListView(children: _buildResumoItens(data))),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _corAcai,
                      side: BorderSide(color: _corAcai),
                    ),
                    onPressed: () =>
                        _abrirEditorPacote(context, docId: doc.id, data: data),
                    child: Text("Editar"),
                  ),
                ),
                SizedBox(width: 10),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                  onPressed: () => _confirmarExclusao(doc),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildResumoItens(Map<String, dynamic> data) {
    List<Widget> widgets = [];
    if ((data['vouchers_banho'] ?? 0) > 0) {
      widgets.add(
        _itemRow(
          "Banho",
          data['vouchers_banho'],
          FontAwesomeIcons.shower,
          Colors.blue,
        ),
      );
    }
    if ((data['vouchers_tosa'] ?? 0) > 0) {
      widgets.add(
        _itemRow(
          "Tosa",
          data['vouchers_tosa'],
          FontAwesomeIcons.scissors,
          Colors.orange,
        ),
      );
    }
    if (data['itens_extra'] != null) {
      for (var item in data['itens_extra']) {
        widgets.add(
          _itemRow(
            item['servico'],
            item['qtd'],
            FontAwesomeIcons.plus,
            Colors.purple,
          ),
        );
      }
    }
    return widgets;
  }

  Widget _itemRow(String label, int qtd, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 10),
          Text("$qtd x $label", style: TextStyle(color: Colors.grey[800])),
        ],
      ),
    );
  }

  // --- EDITOR DE PACOTES (Full Redesign) ---
  void _abrirEditorPacote(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? data,
  }) {
    // Controllers e State
    final nomeCtrl = TextEditingController(text: data?['nome']);
    final precoCtrl = TextEditingController(text: data?['preco']?.toString());
    final descCtrl = TextEditingController(text: data?['descricao']);
    String porteSelecionado = data?['porte'] ?? 'Pequeno Porte';
    bool ativo = data?['ativo'] ?? true;

    // Lista de itens
    List<Map<String, dynamic>> itens = [];
    if (data != null) {
      if ((data['vouchers_banho'] ?? 0) > 0) {
        itens.add({'servico': 'Banho', 'qtd': data['vouchers_banho']});
      }
      if ((data['vouchers_tosa'] ?? 0) > 0) {
        itens.add({'servico': 'Tosa', 'qtd': data['vouchers_tosa']});
      }
      if (data['itens_extra'] != null) {
        for (var item in data['itens_extra']) {
          itens.add({'servico': item['servico'], 'qtd': item['qtd']});
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          void addItem(String nome) {
            int idx = itens.indexWhere((e) => e['servico'] == nome);
            if (idx >= 0) {
              setState(() => itens[idx]['qtd']++);
            } else {
              setState(() => itens.add({'servico': nome, 'qtd': 1}));
            }
          }

          void removeItem(int idx) {
            setState(() {
              if (itens[idx]['qtd'] > 1) {
                itens[idx]['qtd']--;
              } else {
                itens.removeAt(idx);
              }
            });
          }

          return Dialog(
            backgroundColor: Color(0xFFFAFAFA),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SizedBox(
              width: 900,
              height: 600,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          docId == null ? "Criar Pacote" : "Editar Pacote",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _corAcai,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        // Coluna Esquerda: Informações
                        Expanded(
                          flex: 4,
                          child: Container(
                            color: Colors.white,
                            padding: EdgeInsets.all(30),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Detalhes do Plano",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 20),
                                TextField(
                                  controller: nomeCtrl,
                                  decoration: InputDecoration(
                                    labelText: "Nome do Pacote",
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                ),
                                SizedBox(height: 15),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: precoCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: "Preço (R\$)",
                                          filled: true,
                                          fillColor: Colors.grey[50],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 15),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: porteSelecionado,
                                        decoration: InputDecoration(
                                          labelText: "Porte",
                                          filled: true,
                                          fillColor: Colors.grey[50],
                                        ),
                                        items:
                                            [
                                                  'Pequeno Porte',
                                                  'Médio Porte',
                                                  'Grande Porte',
                                                ]
                                                .map(
                                                  (e) => DropdownMenuItem(
                                                    value: e,
                                                    child: Text(e),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (v) => setState(
                                          () => porteSelecionado = v!,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 15),
                                TextField(
                                  controller: descCtrl,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: "Descrição App",
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                ),
                                Spacer(),
                                SwitchListTile(
                                  title: Text("Ativo no App?"),
                                  value: ativo,
                                  onChanged: (v) => setState(() => ativo = v),
                                ),
                              ],
                            ),
                          ),
                        ),
                        VerticalDivider(width: 1),
                        // Coluna Direita: Builder
                        Expanded(
                          flex: 5,
                          child: Container(
                            color: Color(0xFFF5F7FA),
                            padding: EdgeInsets.all(30),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Composição",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 15),
                                Wrap(
                                  spacing: 10,
                                  children: [
                                    ActionChip(
                                      label: Text("Add Banho"),
                                      avatar: Icon(
                                        FontAwesomeIcons.shower,
                                        size: 14,
                                      ),
                                      onPressed: () => addItem("Banho"),
                                    ),
                                    ActionChip(
                                      label: Text("Add Tosa"),
                                      avatar: Icon(
                                        FontAwesomeIcons.scissors,
                                        size: 14,
                                      ),
                                      onPressed: () => addItem("Tosa"),
                                    ),
                                    // Future Builder para outros serviços
                                    StreamBuilder<QuerySnapshot>(
                                      stream: _db
                                          .collection('tenants')
                                          .doc(AppConfig.tenantId)
                                          .collection('servicos_extras')
                                          .snapshots(),
                                      builder: (context, snap) {
                                        if (!snap.hasData) return SizedBox();
                                        return PopupMenuButton<String>(
                                          child: Chip(label: Text("Outros +")),
                                          onSelected: (v) => addItem(v),
                                          itemBuilder: (ctx) =>
                                              snap.data!.docs.map((d) {
                                                String nome = d['nome'];
                                                return PopupMenuItem(
                                                  value: nome,
                                                  child: Text(nome),
                                                );
                                              }).toList(),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                SizedBox(height: 20),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ListView.separated(
                                      itemCount: itens.length,
                                      separatorBuilder: (_, __) =>
                                          Divider(height: 1),
                                      itemBuilder: (ctx, i) {
                                        final item = itens[i];
                                        return ListTile(
                                          title: Text(
                                            item['servico'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.remove_circle,
                                                  color: Colors.grey,
                                                ),
                                                onPressed: () => removeItem(i),
                                              ),
                                              Text(
                                                "${item['qtd']}",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.add_circle,
                                                  color: _corAcai,
                                                ),
                                                onPressed: () =>
                                                    addItem(item['servico']),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text("Cancelar"),
                        ),
                        SizedBox(width: 15),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _corAcai,
                            padding: EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 15,
                            ),
                          ),
                          onPressed: () => _salvarPacote(
                            context,
                            docId,
                            nomeCtrl.text,
                            precoCtrl.text,
                            porteSelecionado,
                            descCtrl.text,
                            ativo,
                            itens,
                          ),
                          child: Text(
                            "SALVAR PACOTE",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _salvarPacote(
    BuildContext context,
    String? docId,
    String nome,
    String precoStr,
    String porte,
    String desc,
    bool ativo,
    List<Map<String, dynamic>> itens,
  ) async {
    if (nome.isEmpty || precoStr.isEmpty || itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Preencha todos os campos obrigatórios.")),
      );
      return;
    }

    double preco = double.tryParse(precoStr.replaceAll(',', '.')) ?? 0.0;
    int totalBanho = 0;
    int totalTosa = 0;
    List<Map<String, dynamic>> extrasVisual = [];
    Map<String, int> vouchersDinamicos = {};

    for (var item in itens) {
      String servico = item['servico'];
      int qtd = item['qtd'];
      if (servico == 'Banho') {
        totalBanho += qtd;
      } else if (servico == 'Tosa')
        totalTosa += qtd;
      else {
        extrasVisual.add(item);
        // Gera chave segura para vouchers dinâmicos
        String key =
            "vouchers_${servico.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}";
        vouchersDinamicos[key] = (vouchersDinamicos[key] ?? 0) + qtd;
      }
    }

    Map<String, dynamic> data = {
      'nome': nome,
      'preco': preco,
      'porte': porte,
      'descricao': desc,
      'ativo': ativo,
      'visivel_app': ativo,
      'vouchers_banho': totalBanho,
      'vouchers_tosa': totalTosa,
      'itens_extra': extrasVisual,
      ...vouchersDinamicos,
    };

    if (docId == null) {
      await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('pacotes')
          .add(data);
    } else {
      await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('pacotes')
          .doc(docId)
          .update(data);
    }

    if (!context.mounted) return;
    Navigator.pop(context);
  }

  void _confirmarExclusao(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Excluir Pacote?"),
        content: Text("Isso removerá o pacote do aplicativo."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              await doc.reference.delete();
              if (!context.mounted) return;
              Navigator.pop(ctx);
            },
            child: Text("Excluir", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
