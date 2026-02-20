import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:intl/intl.dart';

class FinanceiroView extends StatefulWidget {
  const FinanceiroView({super.key});

  @override
  _FinanceiroViewState createState() => _FinanceiroViewState();
}

class _FinanceiroViewState extends State<FinanceiroView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final Color _corAcai = Color(0xFF4A148C);
  final Color _corReceita = Colors.green;
  final Color _corDespesa = Colors.red;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 20),
            _buildTabs(),
            SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTransactionList(tipo: 'RECEITA'),
                  _buildTransactionList(tipo: 'DESPESA'),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _corAcai,
        icon: Icon(Icons.add),
        label: Text("NOVA TRANSAÇÃO"),
        onPressed: () => _showTransactionDialog(),
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
              "Gestão Financeira",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _corAcai,
              ),
            ),
            Text(
              "Controle suas contas a pagar e receber",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        // Aqui poderia entrar um resumo rápido (Saldo do Mês)
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: _corAcai,
        unselectedLabelColor: Colors.grey,
        indicatorColor: _corAcai,
        tabs: [
          Tab(
            icon: Icon(FontAwesomeIcons.circleArrowUp, color: _corReceita),
            text: "Contas a Receber (Receitas)",
          ),
          Tab(
            icon: Icon(FontAwesomeIcons.circleArrowDown, color: _corDespesa),
            text: "Contas a Pagar (Despesas)",
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList({required String tipo}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('financeiro_transacoes')
          .where('tipo', isEqualTo: tipo)
          .orderBy('data_vencimento', descending: false)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Erro ao carregar: ${snapshot.error}"));
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.request_quote, size: 50, color: Colors.grey[300]),
                SizedBox(height: 10),
                Text("Nenhuma transação encontrada.", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final valor = (data['valor'] ?? 0).toDouble();
            final vencimento = (data['data_vencimento'] as Timestamp).toDate();
            final isPago = data['status'] == 'PAGO';
            final categoria = data['categoria'] ?? 'Geral';

            return Card(
              margin: EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: tipo == 'RECEITA'
                      ? _corReceita.withOpacity(0.1)
                      : _corDespesa.withOpacity(0.1),
                  child: Icon(
                    tipo == 'RECEITA' ? Icons.arrow_upward : Icons.arrow_downward,
                    color: tipo == 'RECEITA' ? _corReceita : _corDespesa,
                    size: 20,
                  ),
                ),
                title: Text(data['descricao'] ?? 'Sem descrição', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("$categoria • Vence em: ${DateFormat('dd/MM/yyyy').format(vencimento)}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "R\$ ${valor.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isPago ? Colors.grey : (tipo == 'RECEITA' ? _corReceita : _corDespesa),
                        decoration: isPago ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    SizedBox(width: 10),
                    if (!isPago)
                      IconButton(
                        icon: Icon(Icons.check_circle_outline, color: Colors.grey),
                        tooltip: "Marcar como Pago",
                        onPressed: () => _marcarComoPago(docs[index].id, tipo),
                      )
                    else
                      Chip(
                        label: Text("PAGO", style: TextStyle(fontSize: 10, color: Colors.white)),
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _marcarComoPago(String docId, String tipo) {
    _db
        .collection('tenants')
        .doc(AppConfig.tenantId)
        .collection('financeiro_transacoes')
        .doc(docId)
        .update({
          'status': 'PAGO',
          'data_pagamento': FieldValue.serverTimestamp(),
        });
  }

  void _showTransactionDialog() {
    final _descCtrl = TextEditingController();
    final _valorCtrl = TextEditingController();
    String _tipoSelecionado = 'DESPESA';
    String _categoria = 'Operacional';
    DateTime _vencimento = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("Nova Transação"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text("Despesa"),
                            value: 'DESPESA',
                            groupValue: _tipoSelecionado,
                            onChanged: (v) => setStateDialog(() => _tipoSelecionado = v!),
                            activeColor: _corDespesa,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text("Receita"),
                            value: 'RECEITA',
                            groupValue: _tipoSelecionado,
                            onChanged: (v) => setStateDialog(() => _tipoSelecionado = v!),
                            activeColor: _corReceita,
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _descCtrl,
                      decoration: InputDecoration(labelText: "Descrição"),
                    ),
                    TextField(
                      controller: _valorCtrl,
                      decoration: InputDecoration(labelText: "Valor (R\$)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _categoria,
                      items: ['Operacional', 'Pessoal', 'Fornecedores', 'Impostos', 'Vendas', 'Outros']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setStateDialog(() => _categoria = v!),
                      decoration: InputDecoration(labelText: "Categoria"),
                    ),
                    SizedBox(height: 10),
                    ListTile(
                      title: Text("Vencimento: ${DateFormat('dd/MM/yyyy').format(_vencimento)}"),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _vencimento,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setStateDialog(() => _vencimento = picked);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancelar")),
                ElevatedButton(
                  onPressed: () async {
                    final valor = double.tryParse(_valorCtrl.text.replaceAll(',', '.')) ?? 0;
                    if (_descCtrl.text.isEmpty || valor <= 0) return;

                    await _db
                        .collection('tenants')
                        .doc(AppConfig.tenantId)
                        .collection('financeiro_transacoes')
                        .add({
                          'tipo': _tipoSelecionado,
                          'descricao': _descCtrl.text,
                          'valor': valor,
                          'categoria': _categoria,
                          'data_vencimento': Timestamp.fromDate(_vencimento),
                          'status': 'PENDENTE',
                          'created_at': FieldValue.serverTimestamp(),
                        });

                    if (context.mounted) Navigator.pop(ctx);
                  },
                  child: Text("Salvar"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
