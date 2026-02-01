import 'package:agenpet/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../widgets/product_editor_dialog.dart';

class GestaoEstoqueView extends StatefulWidget {
  const GestaoEstoqueView({super.key});

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
      stream: _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('produtos')
          .orderBy('nome')
          .snapshots(),
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
            DateTime? validade;
            if (data['data_validade'] != null) {
              validade = (data['data_validade'] as Timestamp).toDate();
            }

            if (_filtroStatus == 'Sem Estoque') return estoque <= 0;
            if (_filtroStatus == 'Baixo Estoque') {
              return estoque > 0 && estoque < 5;
            }
            if (_filtroStatus == 'Vencidos') {
              if (validade == null) return false;
              return validade.isBefore(DateTime.now());
            }
            return true;
          }).toList();
        }

        // Cálculos de Resumo (Calcula sobre TUDO antes do filtro de status ou sobre o filtrado?
        // Geralmente KPI é sobre o todo, mas aqui estamos iterando sobre 'docs' que já pode estar filtrado por busca.
        // Vamos iterar sobre o resultado atual para manter consistência visual.)
        double valorTotalEstoque = 0;
        int itensBaixoEstoque = 0;
        int itensSemEstoque = 0;
        int itensVencidos = 0;

        for (var doc in docs) {
          var data = doc.data() as Map<String, dynamic>;
          int estoque = (data['qtd_estoque'] ?? 0);
          double custo = (data['preco_custo'] ?? 0).toDouble();
          DateTime? validade;
          if (data['data_validade'] != null) {
            validade = (data['data_validade'] as Timestamp).toDate();
          }

          if (estoque <= 0) itensSemEstoque++;
          if (estoque > 0 && estoque < 5) itensBaixoEstoque++;
          if (validade != null && validade.isBefore(DateTime.now())) {
            itensVencidos++;
          }

          valorTotalEstoque += (estoque * custo);
        }

        return Column(
          children: [
            _buildSummaryCards(
              docs.length,
              valorTotalEstoque,
              itensBaixoEstoque,
              itensSemEstoque,
              itensVencidos,
            ),
            SizedBox(height: 30),
            Expanded(child: _buildStockTable(docs)),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isSmall = constraints.maxWidth < 800;
        return isSmall
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(),
                  SizedBox(height: 20),
                  _buildActionsSection(isSmall: true),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTitleSection(),
                  _buildActionsSection(isSmall: false),
                ],
              );
      },
    );
  }

  Widget _buildTitleSection() {
    return Column(
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
    );
  }

  Widget _buildActionsSection({required bool isSmall}) {
    return Wrap(
      spacing: 15,
      runSpacing: 15,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Botão Novo Produto
        ElevatedButton.icon(
          icon: Icon(Icons.add, size: 18),
          label: Text("NOVO PRODUTO"),
          style: ElevatedButton.styleFrom(
            backgroundColor: _corAcai,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => ProductEditorDialog(),
            );
          },
        ),
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
              items: [
                'Todos',
                'Baixo Estoque',
                'Sem Estoque',
                'Vencidos',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _filtroStatus = v!),
            ),
          ),
        ),
        SizedBox(
          width: isSmall ? double.infinity : 300,
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
    );
  }

  Widget _buildSummaryCards(
    int totalItens,
    double valorTotal,
    int baixoEstoque,
    int semEstoque,
    int vencidos,
  ) {
    // Usando LayoutBuilder ou Wrap para responsividade
    // Aqui vamos usar um Wrap com tamanhos fixos mínimos para simular o Grid responsivo
    // Ou simplesmente usar Expanded se for Row (padrão) e mudar para Wrap/Column se pequeno.
    // Para simplificar "dinâmico", vamos usar Wrap.

    final cardWidth = 220.0;

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        _buildKpiCard(
          "Total de Produtos",
          "$totalItens itens",
          Colors.blue,
          FontAwesomeIcons.boxesStacked,
          width: cardWidth,
        ),
        _buildKpiCard(
          "Baixo Estoque",
          "$baixoEstoque alertas",
          Colors.orange,
          FontAwesomeIcons.triangleExclamation,
          width: cardWidth,
        ),
        _buildKpiCard(
          "Sem Estoque",
          "$semEstoque itens",
          Colors.red,
          FontAwesomeIcons.ban,
          width: cardWidth,
        ),
        _buildKpiCard(
          "Vencidos",
          "$vencidos itens",
          Colors.purple,
          FontAwesomeIcons.calendarXmark,
          width: cardWidth,
        ),
      ],
    );
  }

  Widget _buildKpiCard(
    String title,
    String value,
    Color color,
    IconData icon, {
    double width = 200,
  }) {
    return Container(
      width: width,
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
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: 800),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
              dataRowMinHeight: 50,
              dataRowMaxHeight: 50,
              columns: [
                DataColumn(label: Text("Produto")),
                DataColumn(label: Text("Marca")),
                DataColumn(label: Text("Preço Custo")),
                DataColumn(label: Text("Preço Venda")),
                DataColumn(label: Text("Estoque")),
                DataColumn(label: Text("Validade")),
                DataColumn(label: Text("Status")),
                DataColumn(label: Text("Ações")),
              ],
              rows: docs.map((doc) => _buildDataRow(doc)).toList(),
            ),
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
    DateTime? validade;
    if (data['data_validade'] != null) {
      validade = (data['data_validade'] as Timestamp).toDate();
    }

    // Status
    Color statusColor = Colors.green;
    String statusText = "Em Estoque";

    // Lógica de Prioridade de Status
    if (validade != null && validade.isBefore(DateTime.now())) {
      statusColor = Colors.purple;
      statusText = "Vencido";
    } else if (estoque <= 0) {
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
          Text(
            validade != null ? DateFormat('dd/MM/yy').format(validade) : "-",
            style: TextStyle(
              color: (validade != null && validade.isBefore(DateTime.now()))
                  ? Colors.red
                  : Colors.black87,
              fontWeight:
                  (validade != null && validade.isBefore(DateTime.now()))
                  ? FontWeight.bold
                  : FontWeight.normal,
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
                  showDialog(
                    context: context,
                    builder: (ctx) => ProductEditorDialog(produto: doc),
                  );
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
    TextEditingController qtdCtrl = TextEditingController();
    bool isAdicionar = true; // true = Adicionar, false = Remover

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
                          onTap: () => setStateDialog(() => isAdicionar = true),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isAdicionar
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isAdicionar
                                    ? Colors.green
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.add_circle,
                                  color: isAdicionar
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                Text(
                                  "Entrada",
                                  style: TextStyle(
                                    color: isAdicionar
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
                              setStateDialog(() => isAdicionar = false),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !isAdicionar
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !isAdicionar
                                    ? Colors.red
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.remove_circle,
                                  color: !isAdicionar
                                      ? Colors.red
                                      : Colors.grey,
                                ),
                                Text(
                                  "Saída/Perda",
                                  style: TextStyle(
                                    color: !isAdicionar
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
                    controller: qtdCtrl,
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
                    int qtd = int.tryParse(qtdCtrl.text) ?? 0;
                    if (qtd <= 0) return;

                    int novoEstoque = isAdicionar ? atual + qtd : atual - qtd;
                    if (novoEstoque < 0) novoEstoque = 0;

                    await _db
                        .collection('tenants')
                        .doc(AppConfig.tenantId)
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
