import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class GestaoEstoqueView extends StatefulWidget {
  @override
  _GestaoEstoqueViewState createState() => _GestaoEstoqueViewState();
}

class _GestaoEstoqueViewState extends State<GestaoEstoqueView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

  String _filtroBusca = '';
  String _filtroStatus = 'Todos'; // Todos, Baixo Estoque, Sem Estoque

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
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
      stream: _db.collection('produtos').orderBy('nome').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: _corAcai));
        }

        var docs = snapshot.data!.docs;

        // Filtros
        if (_filtroBusca.isNotEmpty) {
          docs = docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String nome = (data['nome'] ?? '').toString().toLowerCase();
            String codigo = (data['codigo_barras'] ?? '').toString();
            String marca = (data['marca'] ?? '').toString().toLowerCase();
            String busca = _filtroBusca.toLowerCase();
            return nome.contains(busca) ||
                codigo.contains(busca) ||
                marca.contains(busca);
          }).toList();
        }

        if (_filtroStatus != 'Todos') {
          docs = docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            int estoque = (data['qtd_estoque'] ?? 0);
            if (_filtroStatus == 'Sem Estoque') return estoque <= 0;
            if (_filtroStatus == 'Baixo Estoque')
              return estoque > 0 && estoque < 5;
            return true;
          }).toList();
        }

        // Cálculos de Resumo
        double valorTotalEstoque = 0;
        int itensBaixoEstoque = 0;
        int itensSemEstoque = 0;

        for (var doc in docs) {
          var data = doc.data() as Map<String, dynamic>;
          int estoque = (data['qtd_estoque'] ?? 0);
          double custo = (data['preco_custo'] ?? 0).toDouble();

          if (estoque <= 0) itensSemEstoque++;
          if (estoque > 0 && estoque < 5) itensBaixoEstoque++;

          valorTotalEstoque += (estoque * custo);
        }

        return Column(
          children: [
            _buildSummaryCards(
              docs.length,
              valorTotalEstoque,
              itensBaixoEstoque,
              itensSemEstoque,
            ),
            SizedBox(height: 30),
            Expanded(child: _buildStockTable(docs)),
          ],
        );
      },
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
              "Gestão de Estoque",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _corAcai,
              ),
            ),
            Text(
              "Gerencie quantidades e valores do seu inventário",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        Row(
            children: [
                // Filter Dropdown
                Container(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                            value: _filtroStatus,
                            items: ['Todos', 'Baixo Estoque', 'Sem Estoque']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (v) => setState(() => _filtroStatus = v!),
                        ),
                    ),
                ),
                SizedBox(width: 20),
                SizedBox(
                  width: 300,
                  child: TextField(
                    onChanged: (val) => setState(() => _filtroBusca = val),
                    decoration: InputDecoration(
                      hintText: "Buscar produto...",
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
            ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(
    int totalItens,
    double valorTotal,
    int baixoEstoque,
    int semEstoque,
  ) {
    return Row(
      children: [
        _buildKpiCard(
          "Total de Produtos",
          "$totalItens itens",
          Colors.blue,
          FontAwesomeIcons.boxesStacked,
        ),
        SizedBox(width: 20),
        _buildKpiCard(
          "Valor em Estoque",
          "R\$ ${valorTotal.toStringAsFixed(2)}",
          Colors.green,
          FontAwesomeIcons.moneyBillTrendUp,
        ),
        SizedBox(width: 20),
        _buildKpiCard(
          "Baixo Estoque",
          "$baixoEstoque alertas",
          Colors.orange,
          FontAwesomeIcons.triangleExclamation,
        ),
        SizedBox(width: 20),
        _buildKpiCard(
          "Sem Estoque",
          "$semEstoque itens",
          Colors.red,
          FontAwesomeIcons.ban,
        ),
      ],
    );
  }

  Widget _buildKpiCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
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
                fontSize: 20, // Ajustado para caber melhor
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockTable(List<DocumentSnapshot> docs) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
            dataRowMinHeight: 70,
            dataRowMaxHeight: 70,
            columns: [
              DataColumn(label: Text("Produto")),
              DataColumn(label: Text("Marca")),
              DataColumn(label: Text("Preço Custo")),
              DataColumn(label: Text("Preço Venda")),
              DataColumn(label: Text("Estoque")),
              DataColumn(label: Text("Status")),
              DataColumn(label: Text("Ações")),
            ],
            rows: docs.map((doc) => _buildDataRow(doc)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildDataRow(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String nome = data['nome'] ?? 'Sem Nome';
    String marca = data['marca'] ?? '-';
    double custo = (data['preco_custo'] ?? 0).toDouble();
    double venda = (data['preco'] ?? 0).toDouble();
    int estoque = (data['qtd_estoque'] ?? 0);

    // Status
    Color statusColor = Colors.green;
    String statusText = "Em Estoque";
    if (estoque <= 0) {
      statusColor = Colors.red;
      statusText = "Esgotado";
    } else if (estoque < 5) {
      statusColor = Colors.orange;
      statusText = "Baixo";
    }

    return DataRow(
      cells: [
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nome,
                style: TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (data['codigo_barras'] != null)
                Text(
                  data['codigo_barras'],
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
            ],
          ),
        ),
        DataCell(Text(marca)),
        DataCell(Text("R\$ ${custo.toStringAsFixed(2)}")),
        DataCell(
          Text(
            "R\$ ${venda.toStringAsFixed(2)}",
            style: TextStyle(fontWeight: FontWeight.bold, color: _corAcai),
          ),
        ),
        DataCell(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "$estoque",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: Colors.grey, size: 20),
                onPressed: () {
                  // Implementar edição completa se necessário,
                  // ou chamar o mesmo modal da loja
                },
                tooltip: "Editar Detalhes",
              ),
              IconButton(
                icon: Icon(Icons.inventory, color: _corAcai, size: 20),
                onPressed: () => _showEditStockDialog(doc.id, nome, estoque),
                tooltip: "Ajustar Estoque",
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditStockDialog(String docId, String nome, int atual) {
    TextEditingController _qtdCtrl = TextEditingController();
    bool _isAdicionar = true; // true = Adicionar, false = Remover

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text("Ajuste de Estoque"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Produto: $nome"),
                  Text(
                    "Atual: $atual",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setStateDialog(() => _isAdicionar = true),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isAdicionar
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _isAdicionar
                                    ? Colors.green
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.add_circle,
                                  color: _isAdicionar
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                Text(
                                  "Entrada",
                                  style: TextStyle(
                                    color: _isAdicionar
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              setStateDialog(() => _isAdicionar = false),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isAdicionar
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !_isAdicionar
                                    ? Colors.red
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.remove_circle,
                                  color: !_isAdicionar
                                      ? Colors.red
                                      : Colors.grey,
                                ),
                                Text(
                                  "Saída/Perda",
                                  style: TextStyle(
                                    color: !_isAdicionar
                                        ? Colors.red
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: _qtdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Quantidade",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Cancelar"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _corAcai,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    int qtd = int.tryParse(_qtdCtrl.text) ?? 0;
                    if (qtd <= 0) return;

                    int novoEstoque = _isAdicionar ? atual + qtd : atual - qtd;
                    if (novoEstoque < 0) novoEstoque = 0;

                    await _db
                        .collection('produtos')
                        .doc(docId)
                        .update({'qtd_estoque': novoEstoque});

                    // Idealmente aqui salvaríamos no histórico 'movimentacoes_estoque'
                    // Mas para manter simples e dentro do escopo do pedido, ficamos por aqui.

                    if (!context.mounted) return;

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Estoque atualizado para $novoEstoque"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: Text("Confirmar"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
