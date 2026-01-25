import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PacotesAssinaturaTab extends StatefulWidget {
  @override
  _PacotesAssinaturaTabState createState() => _PacotesAssinaturaTabState();
}

class _PacotesAssinaturaTabState extends State<PacotesAssinaturaTab> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Cores do Tema
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _corFundo,
      padding: EdgeInsets.all(30),
      child: Column(
        children: [
          // Cabeçalho da Tab
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Catálogo de Assinaturas",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _corAcai,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Crie e gerencie os planos visíveis no App",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.add, size: 20),
                label: Text("NOVO PACOTE"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  padding: EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () => _abrirEditorPacote(context),
              ),
            ],
          ),
          SizedBox(height: 30),

          // Grid de Pacotes
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('pacotes_assinatura').snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: _corAcai),
                  );
                }

                final docs = snap.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FontAwesomeIcons.boxOpen,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 15),
                        Text(
                          "Nenhum pacote criado ainda.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360, // Largura do Card
                    childAspectRatio: 0.95, // Altura do Card
                    crossAxisSpacing: 25,
                    mainAxisSpacing: 25,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) => _buildPacoteCard(docs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- CARD VISUAL DO PACOTE ---
  Widget _buildPacoteCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    bool isAtivo = data['ativo'] ?? true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header do Card (Preço e Status)
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isAtivo ? _corAcai.withOpacity(0.05) : Colors.grey[100],
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isAtivo ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(10),
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _corAcai,
                  ),
                ),
              ],
            ),
          ),

          // Corpo do Card
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
                  Row(
                    children: [
                      Icon(FontAwesomeIcons.dog, size: 12, color: Colors.grey),
                      SizedBox(width: 5),
                      Text(
                        data['porte'] ?? 'Qualquer porte',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  Divider(height: 25),

                  // Lista Resumida de Itens
                  Expanded(
                    child: ListView(
                      physics: BouncingScrollPhysics(),
                      children: [
                        if ((data['vouchers_banho'] ?? 0) > 0)
                          _itemResumo(
                            "Banho",
                            data['vouchers_banho'],
                            FontAwesomeIcons.shower,
                            Colors.blue,
                          ),
                        if ((data['vouchers_tosa'] ?? 0) > 0)
                          _itemResumo(
                            "Tosa",
                            data['vouchers_tosa'],
                            FontAwesomeIcons.scissors,
                            Colors.orange,
                          ),
                        if (data['itens_extra'] != null)
                          ...((data['itens_extra'] as List).map(
                            (e) => _itemResumo(
                              e['servico'],
                              e['qtd'],
                              FontAwesomeIcons.plus,
                              Colors.purple,
                            ),
                          )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Rodapé (Ações)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.edit, size: 16),
                    label: Text("Editar"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _corAcai,
                      side: BorderSide(color: _corAcai.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () =>
                        _abrirEditorPacote(context, docId: doc.id, data: data),
                  ),
                ),
                SizedBox(width: 10),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                  tooltip: "Excluir Pacote",
                  onPressed: () => _confirmarExclusao(doc),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemResumo(String label, int qtd, IconData icon, Color cor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 12, color: cor),
          ),
          SizedBox(width: 10),
          Text(
            "$qtd x ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- EDITOR DE PACOTES (MODAL COMPACTO) ---
  void _abrirEditorPacote(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? data,
  }) {
    final _nomeCtrl = TextEditingController(text: data?['nome']);
    final _precoCtrl = TextEditingController(text: data?['preco']?.toString());
    final _descCtrl = TextEditingController(text: data?['descricao']);
    String _porteSelecionado = data?['porte'] ?? 'Pequeno Porte';
    bool _ativo = data?['ativo'] ?? true;

    List<Map<String, dynamic>> _itens = [];

    if (data != null) {
      if ((data['vouchers_banho'] ?? 0) > 0)
        _itens.add({
          'servico': 'Banho',
          'qtd': data['vouchers_banho'],
          'isFixed': true,
        });
      if ((data['vouchers_tosa'] ?? 0) > 0)
        _itens.add({
          'servico': 'Tosa',
          'qtd': data['vouchers_tosa'],
          'isFixed': true,
        });
      if (data['itens_extra'] != null) {
        for (var item in data['itens_extra']) {
          _itens.add({
            'servico': item['servico'],
            'qtd': item['qtd'],
            'isFixed': false,
          });
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          void _alterarQtd(int index, int delta) {
            setStateDialog(() {
              int novaQtd = (_itens[index]['qtd'] as int) + delta;
              if (novaQtd <= 0) {
                _itens.removeAt(index);
              } else {
                _itens[index]['qtd'] = novaQtd;
              }
            });
          }

          void _adicionarItem(String servico, int qtd) {
            setStateDialog(() {
              int index = _itens.indexWhere((e) => e['servico'] == servico);
              if (index != -1) {
                _itens[index]['qtd'] = (_itens[index]['qtd'] as int) + qtd;
              } else {
                _itens.add({
                  'servico': servico,
                  'qtd': qtd,
                  'isFixed': servico == 'Banho' || servico == 'Tosa',
                });
              }
            });
          }

          final screenSize = MediaQuery.of(context).size;
          final double dialogWidth = screenSize.width * 0.9 > 900
              ? 900
              : screenSize.width * 0.9;
          final double dialogHeight = screenSize.height * 0.85;

          return AlertDialog(
            backgroundColor: Color(0xFFFAFAFA),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: EdgeInsets.zero,
            content: Container(
              width: dialogWidth,
              height: dialogHeight,
              child: Column(
                children: [
                  // 1. CABEÇALHO FIXO
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
                      children: [
                        Icon(
                          docId == null ? Icons.add_circle : Icons.edit,
                          color: _corAcai,
                        ),
                        SizedBox(width: 10),
                        Text(
                          docId == null ? "Criar Novo Pacote" : "Editar Pacote",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _corAcai,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // 2. CORPO DIVIDIDO
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- COLUNA ESQUERDA: DADOS BÁSICOS (COMPACTO) ---
                        Expanded(
                          flex: 4,
                          child: Container(
                            color: Colors.white,
                            padding: EdgeInsets.all(20), // Padding menor
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Informações Básicas",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 10),

                                _inputLabel("Nome Comercial"),
                                _buildCompactField(
                                  _nomeCtrl,
                                  "Ex: Pacote Gold",
                                ),

                                SizedBox(height: 10),

                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _inputLabel("Preço (R\$)"),
                                          _buildCompactField(
                                            _precoCtrl,
                                            "0.00",
                                            isNumber: true,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _inputLabel("Porte"),
                                          Container(
                                            height: 40, // Altura fixa menor
                                            child: DropdownButtonFormField<String>(
                                              value: _porteSelecionado,
                                              isExpanded: true,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                    ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
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
                                                          child: Text(
                                                            e,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                              onChanged: (v) => setStateDialog(
                                                () => _porteSelecionado = v!,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 10),
                                _inputLabel("Descrição (App)"),
                                _buildCompactField(
                                  _descCtrl,
                                  "Benefícios...",
                                  lines: 2,
                                ), // Apenas 2 linhas

                                Spacer(), // Empurra o switch para baixo se sobrar espaço
                                Divider(),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true, // Switch compacto
                                  title: Text(
                                    "Pacote Ativo?",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "Se desativado, some do App.",
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  activeColor: Colors.green,
                                  value: _ativo,
                                  onChanged: (v) =>
                                      setStateDialog(() => _ativo = v),
                                ),
                              ],
                            ),
                          ),
                        ),

                        VerticalDivider(width: 1, color: Colors.grey[300]),

                        // --- COLUNA DIREITA: COMPOSIÇÃO ---
                        Expanded(
                          flex: 5,
                          child: Container(
                            color: Color(0xFFF5F7FA),
                            padding: EdgeInsets.all(25),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Composição do Pacote",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 15),

                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _buildQuickAddBtn(
                                      "Banho",
                                      FontAwesomeIcons.shower,
                                      Colors.blue,
                                      () => _adicionarItem("Banho", 1),
                                    ),
                                    _buildQuickAddBtn(
                                      "Tosa",
                                      FontAwesomeIcons.scissors,
                                      Colors.orange,
                                      () => _adicionarItem("Tosa", 1),
                                    ),
                                    _buildExtraAddBtn(
                                      setStateDialog,
                                      _adicionarItem,
                                    ),
                                  ],
                                ),

                                SizedBox(height: 20),
                                Text(
                                  "Itens Inclusos:",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 10),

                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: _itens.isEmpty
                                        ? _buildEmptyListState()
                                        : ListView.separated(
                                            padding: EdgeInsets.all(10),
                                            separatorBuilder: (_, __) =>
                                                SizedBox(height: 8),
                                            itemCount: _itens.length,
                                            itemBuilder: (ctx, i) {
                                              final item = _itens[i];
                                              return Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.02),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        item['servico'],
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.remove_circle,
                                                        color: Colors.grey[300],
                                                        size: 20,
                                                      ),
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          BoxConstraints(),
                                                      onPressed: () =>
                                                          _alterarQtd(i, -1),
                                                    ),
                                                    Container(
                                                      width: 30,
                                                      alignment:
                                                          Alignment.center,
                                                      child: Text(
                                                        "${item['qtd']}",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.add_circle,
                                                        color: _corAcai,
                                                        size: 20,
                                                      ),
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          BoxConstraints(),
                                                      onPressed: () =>
                                                          _alterarQtd(i, 1),
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

                  // 3. RODAPÉ DE AÇÃO FIXO
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            "Cancelar",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        SizedBox(width: 15),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _corAcai,
                            padding: EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _salvarPacote(
                            docId,
                            _nomeCtrl.text,
                            _precoCtrl.text,
                            _porteSelecionado,
                            _descCtrl.text,
                            _ativo,
                            _itens,
                          ),
                          child: Text(
                            "SALVAR PACOTE",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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

  // --- WIDGETS AUXILIARES ---

  Widget _inputLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 5), // Menos padding
    child: Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: Colors.grey[700],
      ),
    ),
  );

  // Campo de texto compacto
  Widget _buildCompactField(
    TextEditingController c,
    String hint, {
    bool isNumber = false,
    int lines = 1,
  }) {
    return Container(
      height: lines == 1 ? 40 : null, // Altura fixa se for 1 linha
      child: TextField(
        controller: c,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: lines,
        style: TextStyle(fontSize: 13), // Fonte menor
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ), // Padding interno reduzido
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ), // Borda menor
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  Widget _buildQuickAddBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(height: 4),
            Text(
              "Add $label",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraAddBtn(
    StateSetter setStateDialog,
    Function(String, int) onAdd,
  ) {
    return FutureBuilder<QuerySnapshot>(
      future: _db.collection('servicos_extras').get(),
      builder: (context, snapshot) {
        return PopupMenuButton<String>(
          offset: Offset(0, 50),
          tooltip: "Selecionar outro serviço",
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: 100,
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.purple, size: 20),
                SizedBox(height: 4),
                Text(
                  "Outros...",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          itemBuilder: (context) {
            List<String> opcoes = [];
            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) opcoes.add(doc['nome']);
            }
            if (opcoes.isEmpty)
              return [
                PopupMenuItem(
                  enabled: false,
                  child: Text("Sem serviços extras"),
                ),
              ];

            return opcoes
                .map(
                  (e) => PopupMenuItem(
                    value: e,
                    child: Text(e),
                    onTap: () =>
                        Future.delayed(Duration.zero, () => onAdd(e, 1)),
                  ),
                )
                .toList();
          },
        );
      },
    );
  }

  Widget _buildEmptyListState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 40,
            color: Colors.grey[300],
          ),
          SizedBox(height: 10),
          Text(
            "Adicione itens ao pacote",
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE SALVAMENTO ---
  void _salvarPacote(
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
        SnackBar(
          content: Text("Preencha nome, preço e adicione itens."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      double preco = double.tryParse(precoStr.replaceAll(',', '.')) ?? 0.0;

      int totalBanho = 0;
      int totalTosa = 0;
      List<Map<String, dynamic>> extrasVisual = [];
      Map<String, int> vouchersDinamicos = {};

      for (var item in itens) {
        String servico = item['servico'];
        int qtd = item['qtd'];
        String key = servico.toLowerCase();

        if (key.contains('banho')) {
          totalBanho += qtd;
        } else if (key.contains('tosa')) {
          totalTosa += qtd;
        } else {
          extrasVisual.add({'servico': servico, 'qtd': qtd});
          String safeKey =
              "vouchers_" +
              key
                  .replaceAll(RegExp(r'[áàâãä]'), 'a')
                  .replaceAll(RegExp(r'[éèêë]'), 'e')
                  .replaceAll('ç', 'c')
                  .replaceAll(' ', '_');
          vouchersDinamicos[safeKey] = (vouchersDinamicos[safeKey] ?? 0) + qtd;
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
        await _db.collection('pacotes_assinatura').add(data);
      } else {
        await _db.collection('pacotes_assinatura').doc(docId).update(data);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Pacote Salvo com Sucesso! 🚀"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao salvar: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmarExclusao(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Excluir Pacote?"),
        content: Text(
          "Isso removerá o pacote do App. Clientes que já compraram não serão afetados.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(ctx);
            },
            child: Text(
              "Confirmar Exclusão",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
