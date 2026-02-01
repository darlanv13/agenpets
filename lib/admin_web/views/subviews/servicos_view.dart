import 'package:agenpet/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ServicosView extends StatefulWidget {
  const ServicosView({super.key});

  @override
  _ServicosViewState createState() => _ServicosViewState();
}

class _ServicosViewState extends State<ServicosView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

  String _filtroBusca = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Fundo controlado pelo parent
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 30),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('servicos_extras')
          .orderBy('nome')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: _corAcai));
        }

        var docs = snapshot.data!.docs;

        // Filtro de Busca
        if (_filtroBusca.isNotEmpty) {
          docs = docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String nome = (data['nome'] ?? '').toString().toLowerCase();
            return nome.contains(_filtroBusca.toLowerCase());
          }).toList();
        }

        // Cálculos de Resumo
        double mediaPreco = 0;
        double somaPreco = 0;
        if (docs.isNotEmpty) {
          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            somaPreco += (data['preco'] ?? 0).toDouble();
          }
          mediaPreco = somaPreco / docs.length;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCards(docs.length, mediaPreco),
            SizedBox(height: 30),
            _buildActionsSection(),
            SizedBox(height: 20),
            Expanded(child: _buildTable(docs)),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Catálogo de Serviços",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: _corAcai,
          ),
        ),
        Text(
          "Gerencie os serviços avulsos disponíveis para venda e pacotes",
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(int totalServicos, double mediaPreco) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        _buildKpiCard(
          "Total de Serviços",
          "$totalServicos itens",
          Colors.blue,
          FontAwesomeIcons.list,
        ),
        _buildKpiCard(
          "Preço Médio",
          "R\$ ${mediaPreco.toStringAsFixed(2)}",
          Colors.green,
          FontAwesomeIcons.tag,
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, Color color, IconData icon) {
    return Container(
      width: 220,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(icon, color: color.withOpacity(0.5), size: 20),
            ],
          ),
          SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (val) => setState(() => _filtroBusca = val),
            decoration: InputDecoration(
              hintText: "Buscar serviço...",
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 20),
            ),
          ),
        ),
        SizedBox(width: 15),
        ElevatedButton.icon(
          icon: Icon(Icons.add, size: 18),
          label: Text("NOVO SERVIÇO"),
          style: ElevatedButton.styleFrom(
            backgroundColor: _corAcai,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => _abrirEditorServico(context),
        ),
      ],
    );
  }

  Widget _buildTable(List<DocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Text(
          "Nenhum serviço encontrado.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: 800),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                dataRowMinHeight: 60,
                dataRowMaxHeight: 60,
                columns: [
                  DataColumn(label: Text("Serviço")),
                  DataColumn(label: Text("Preço")),
                  DataColumn(label: Text("Ações")),
                ],
                rows: docs.map((doc) => _buildDataRow(doc)).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildDataRow(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String nome = data['nome'] ?? 'Serviço';
    String? porte = data['porte'];
    String? pelagem = data['pelagem'];
    double preco = (data['preco'] ?? 0).toDouble();

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _corAcai.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.cleaning_services, color: _corAcai, size: 18),
              ),
              SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    nome,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  if (porte != null || pelagem != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          if (porte != null)
                            Container(
                              margin: EdgeInsets.only(right: 5),
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue[100]!),
                              ),
                              child: Text(
                                porte,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ),
                          if (pelagem != null)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange[100]!),
                              ),
                              child: Text(
                                "Pelo $pelagem",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange[800],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            "R\$ ${preco.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: Colors.grey, size: 20),
                onPressed: () =>
                    _abrirEditorServico(context, docId: doc.id, data: data),
                tooltip: "Editar",
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red[300],
                  size: 20,
                ),
                onPressed: () => _confirmarExclusao(doc),
                tooltip: "Excluir",
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- EDITOR DE SERVIÇO ---
  void _abrirEditorServico(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? data,
  }) {
    final nomeCtrl = TextEditingController(text: data?['nome']);
    final precoCtrl = TextEditingController(text: data?['preco']?.toString());

    // State for Dropdowns
    String? porteSelecionado = data?['porte'];
    String? pelagemSelecionada = data?['pelagem'];

    final List<String> opcoesPorte = [
      'Todos',
      'Pequeno Porte',
      'Médio Porte',
      'Grande Porte',
    ];
    final List<String> opcoesPelagem = ['Todos', 'Curta', 'Média', 'Longa'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text(docId == null ? "Novo Serviço" : "Editar Serviço"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomeCtrl,
                    decoration: InputDecoration(
                      labelText: "Nome do Serviço",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: precoCtrl,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: "Preço (R\$)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: porteSelecionado,
                    decoration: InputDecoration(
                      labelText: "Porte Atendido",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: opcoesPorte.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setStateDialog(() {
                        porteSelecionado = newValue;
                      });
                    },
                  ),
                  SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: pelagemSelecionada,
                    decoration: InputDecoration(
                      labelText: "Tipo de Pelagem",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: opcoesPelagem.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setStateDialog(() {
                        pelagemSelecionada = newValue;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  if (nomeCtrl.text.isEmpty || precoCtrl.text.isEmpty) return;

                  double preco =
                      double.tryParse(precoCtrl.text.replaceAll(',', '.')) ??
                      0.0;
                  final payload = {
                    'nome': nomeCtrl.text,
                    'preco': preco,
                    'porte': porteSelecionado,
                    'pelagem': pelagemSelecionada,
                  };

                  if (docId == null) {
                    await _db
                        .collection('tenants')
                        .doc(AppConfig.tenantId)
                        .collection('servicos_extras')
                        .add(payload);
                  } else {
                    await _db
                        .collection('tenants')
                        .doc(AppConfig.tenantId)
                        .collection('servicos_extras')
                        .doc(docId)
                        .update(payload);
                  }

                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Serviço salvo!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Text("Salvar", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmarExclusao(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Excluir Serviço?"),
        content: Text("Tem certeza? Essa ação não pode ser desfeita."),
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
