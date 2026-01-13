import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class GestaoPrecosView extends StatefulWidget {
  @override
  _GestaoPrecosViewState createState() => _GestaoPrecosViewState();
}

class _GestaoPrecosViewState extends State<GestaoPrecosView>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  late TabController _tabController;

  // --- PALETA DE CORES (Açaí & Lilás) ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLavanda = Color(0xFFAB47BC);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF5F7FA);

  // Controladores para Preços Base
  final _precoBanhoCtrl = TextEditingController();
  final _precoTosaCtrl = TextEditingController();
  final _precoHotelCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _carregarPrecosBase();
  }

  void _carregarPrecosBase() async {
    final doc = await _db.collection('config').doc('parametros').get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _precoBanhoCtrl.text = (data['preco_banho'] ?? 0).toString();
        _precoTosaCtrl.text = (data['preco_tosa'] ?? 0).toString();
        _precoHotelCtrl.text = (data['preco_hotel_diaria'] ?? 0).toString();
      });
    }
  }

  void _salvarPrecosBase() async {
    await _db.collection('config').doc('parametros').set({
      'preco_banho': double.tryParse(_precoBanhoCtrl.text) ?? 0,
      'preco_tosa': double.tryParse(_precoTosaCtrl.text) ?? 0,
      'preco_hotel_diaria': double.tryParse(_precoHotelCtrl.text) ?? 0,
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Preços base atualizados! ✅")));
  }

  Future<List<String>> _buscarTodosServicos() async {
    List<String> servicos = ['Banho', 'Tosa'];
    final snap = await _db.collection('servicos_extras').get();
    for (var doc in snap.docs) {
      servicos.add(doc['nome']);
    }
    return servicos;
  }

  // --- AUXILIAR: Formata "Hidratação Profunda" para "vouchers_hidratacao_profunda" ---
  String _formatarChaveVoucher(String nomeServico) {
    String limpo = nomeServico.toLowerCase().trim();

    // CORREÇÃO: As duas strings agora têm exatamente o mesmo tamanho (23 caracteres)
    var comAcento = 'áàâãäéèêëíìîïóòôõöúùûüç';
    var semAcento = 'aaaaaeeeeiiiiooooouuuuc'; // Adicionado o 'o' que faltava

    for (int i = 0; i < comAcento.length; i++) {
      limpo = limpo.replaceAll(comAcento[i], semAcento[i]);
    }

    return 'vouchers_' + limpo.replaceAll(RegExp(r'\s+'), '_');
  }

  void _abrirEditor({
    String? docId,
    required String collection,
    required String tipoItem,
    bool isAssinatura = false,
  }) async {
    final nomeCtrl = TextEditingController();
    final precoCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? porteSelecionado;

    List<Map<String, dynamic>> itensDoPacote = [];
    String? servicoSelecionadoParaAdicionar;
    final qtdCtrl = TextEditingController(text: '1');

    List<String> listaServicosDisponiveis = [];
    if (isAssinatura) {
      listaServicosDisponiveis = await _buscarTodosServicos();
    }

    if (docId != null) {
      final doc = await _db.collection(collection).doc(docId).get();
      final data = doc.data()!;
      nomeCtrl.text = data['nome'];
      precoCtrl.text = data['preco'].toString();

      if (isAssinatura) {
        descCtrl.text = data['descricao'] ?? '';
        porteSelecionado = data['porte'];
        if ((data['vouchers_banho'] ?? 0) > 0)
          itensDoPacote.add({
            'servico': 'Banho',
            'qtd': data['vouchers_banho'],
          });
        if ((data['vouchers_tosa'] ?? 0) > 0)
          itensDoPacote.add({'servico': 'Tosa', 'qtd': data['vouchers_tosa']});
        if (data['itens_extra'] != null) {
          for (var item in data['itens_extra']) {
            itensDoPacote.add({'servico': item['servico'], 'qtd': item['qtd']});
          }
        }
      }
    } else {
      if (isAssinatura && listaServicosDisponiveis.isNotEmpty) {
        servicoSelecionadoParaAdicionar = listaServicosDisponiveis[0];
      }
    }

    if (isAssinatura &&
        servicoSelecionadoParaAdicionar == null &&
        listaServicosDisponiveis.isNotEmpty) {
      servicoSelecionadoParaAdicionar = listaServicosDisponiveis[0];
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _corLilas,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isAssinatura ? FontAwesomeIcons.boxOpen : Icons.edit,
                    color: _corAcai,
                    size: 20,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  docId == null ? "Novo $tipoItem" : "Editar $tipoItem",
                  style: TextStyle(
                    color: _corAcai,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Container(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(nomeCtrl, "Nome do $tipoItem", Icons.label),
                    if (isAssinatura) ...[
                      SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        initialValue: porteSelecionado,
                        decoration: InputDecoration(
                          labelText: "Porte Atendido",
                          prefixIcon: Icon(
                            FontAwesomeIcons.dog,
                            color: _corAcai,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: _corFundo,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        hint: Text("Selecione o porte"),
                        items: ['Pequeno Porte', 'Médio Porte', 'Grande Porte']
                            .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setStateDialog(() => porteSelecionado = v),
                      ),
                    ],
                    SizedBox(height: 15),
                    _buildTextField(
                      precoCtrl,
                      "Preço (R\$)",
                      Icons.attach_money,
                      isNumber: true,
                    ),

                    if (isAssinatura) ...[
                      SizedBox(height: 15),
                      _buildTextField(
                        descCtrl,
                        "Descrição (App)",
                        Icons.description,
                        maxLines: 2,
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Divider(),
                      ),
                      Text(
                        "Composição do Pacote",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _corAcai,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 10),

                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _corFundo,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: servicoSelecionadoParaAdicionar,
                                decoration: InputDecoration(
                                  labelText: "Serviço",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 0,
                                  ),
                                ),
                                items: listaServicosDisponiveis
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setStateDialog(
                                  () => servicoSelecionadoParaAdicionar = v,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: qtdCtrl,
                                decoration: InputDecoration(
                                  labelText: "Qtd",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(width: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: _corAcai,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(Icons.add, color: Colors.white),
                                onPressed: () {
                                  if (servicoSelecionadoParaAdicionar != null &&
                                      qtdCtrl.text.isNotEmpty) {
                                    setStateDialog(() {
                                      itensDoPacote.add({
                                        'servico':
                                            servicoSelecionadoParaAdicionar,
                                        'qtd': int.parse(qtdCtrl.text),
                                      });
                                      qtdCtrl.text = '1';
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 10),

                      Container(
                        height: 150,
                        child: itensDoPacote.isEmpty
                            ? Center(
                                child: Text(
                                  "Nenhum item adicionado",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                itemCount: itensDoPacote.length,
                                itemBuilder: (context, index) {
                                  final item = itensDoPacote[index];
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 8),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: _corLilas,
                                              radius: 15,
                                              child: Text(
                                                "${item['qtd']}",
                                                style: TextStyle(
                                                  color: _corAcai,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              item['servico'],
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          onPressed: () => setStateDialog(
                                            () => itensDoPacote.removeAt(index),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ],
                ),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () async {
                  // --- INÍCIO DO BLOCO SEGURO ---
                  try {
                    // 1. Tratamento robusto do preço (troca vírgula por ponto)
                    double precoFinal = 0.0;
                    if (precoCtrl.text.isNotEmpty) {
                      String precoLimpo = precoCtrl.text.replaceAll(',', '.');
                      precoFinal = double.tryParse(precoLimpo) ?? 0.0;
                    }

                    final data = {
                      'nome': nomeCtrl.text,
                      'preco': precoFinal,
                      'ativo': true,
                    };

                    if (isAssinatura) {
                      data['descricao'] = descCtrl.text;
                      data['visivel_app'] = true;
                      data['porte'] = porteSelecionado ?? 'Pequeno Porte';

                      int totalBanho = 0;
                      int totalTosa = 0;
                      List<Map<String, dynamic>> extrasVisual = [];

                      for (var item in itensDoPacote) {
                        String nome = item['servico'].toString();
                        String nomeNorm = nome.toLowerCase();
                        // Garante que qtd seja lido como inteiro
                        int qtd = int.tryParse(item['qtd'].toString()) ?? 0;

                        if (nomeNorm.contains('banho')) {
                          // Usa contains para ser mais flexível
                          totalBanho += qtd;
                        } else if (nomeNorm.contains('tosa')) {
                          totalTosa += qtd;
                        } else {
                          // Adiciona na lista visual (para edição futura)
                          extrasVisual.add(item);

                          // Cria chave de voucher (para o checkout)
                          String chaveBanco = _formatarChaveVoucher(nome);

                          // Soma se já existir (caso tenha 2 linhas do mesmo item)
                          int atual = (data[chaveBanco] as int?) ?? 0;
                          data[chaveBanco] = atual + qtd;
                        }
                      }

                      data['vouchers_banho'] = totalBanho;
                      data['vouchers_tosa'] = totalTosa;
                      data['itens_extra'] = extrasVisual;
                    } else {
                      data['visivel_app'] = false;
                    }

                    // Salva no Firestore
                    if (docId == null) {
                      await _db.collection(collection).add(data);
                    } else {
                      await _db.collection(collection).doc(docId).update(data);
                    }

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("$tipoItem salvo com sucesso! ✅"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    // Se der erro, mostra na tela para você saber o que foi
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text("Erro ao Salvar"),
                        content: Text("Ocorreu um erro: $e"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: Text("OK"),
                          ),
                        ],
                      ),
                    );
                  }
                  // --- FIM DO BLOCO SEGURO ---
                },
                child: Text(
                  "SALVAR",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _excluirItem(String collection, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Excluir Item?"),
        content: Text("Essa ação não pode ser desfeita."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              await _db.collection(collection).doc(docId).delete();
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

  // --- UI WIDGETS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Column(
        children: [
          // Header Estilizado
          Container(
            padding: EdgeInsets.symmetric(vertical: 25, horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _corLilas,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.price_change,
                        color: _corAcai,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Gestão de Preços",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _corAcai,
                          ),
                        ),
                        Text(
                          "Configure serviços, preços e pacotes",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Abas Modernas
          Container(
            margin: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              indicator: BoxDecoration(
                color: _corAcai,
                borderRadius: BorderRadius.circular(50),
              ),
              padding: EdgeInsets.all(5),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tune, size: 18),
                      SizedBox(width: 8),
                      Text("Preços Base"),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, size: 18),
                      SizedBox(width: 8),
                      Text("Extras"),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FontAwesomeIcons.boxOpen, size: 16),
                      SizedBox(width: 8),
                      Text("Assinaturas"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Conteúdo das Abas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ABA 1
                Center(
                  child: SingleChildScrollView(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 600),
                      padding: EdgeInsets.all(30),
                      child: Column(
                        children: [
                          _buildInputCard(
                            "Banho Simples",
                            _precoBanhoCtrl,
                            FontAwesomeIcons.shower,
                          ),
                          SizedBox(height: 15),
                          _buildInputCard(
                            "Tosa Completa",
                            _precoTosaCtrl,
                            FontAwesomeIcons.scissors,
                          ),
                          SizedBox(height: 15),
                          _buildInputCard(
                            "Diária Hotel",
                            _precoHotelCtrl,
                            FontAwesomeIcons.hotel,
                          ),
                          SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.save),
                              label: Text("SALVAR ALTERAÇÕES"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              onPressed: _salvarPrecosBase,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ABA 2
                _buildListaGerenciaivel(
                  collection: 'servicos_extras',
                  tipoItem: 'Serviço Extra',
                  descricao: "Serviços avulsos para adicionar no checkout.",
                  isAssinatura: false,
                ),

                // ABA 3
                _buildListaGerenciaivel(
                  collection: 'pacotes_assinatura',
                  tipoItem: 'Pacote',
                  descricao: "Planos de assinatura disponíveis no App.",
                  isAssinatura: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _corLilas,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: _corAcai, size: 24),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          Container(
            width: 120,
            padding: EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: _corFundo,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                prefixText: "R\$ ",
                border: InputBorder.none,
              ),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaGerenciaivel({
    required String collection,
    required String tipoItem,
    required String descricao,
    required bool isAssinatura,
  }) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAssinatura ? "Planos Ativos" : "Serviços Extras",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(descricao, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text("Novo $tipoItem"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _abrirEditor(
                  collection: collection,
                  tipoItem: tipoItem,
                  isAssinatura: isAssinatura,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection(collection).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty)
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 50, color: Colors.grey[300]),
                        SizedBox(height: 10),
                        Text(
                          "Nenhum item cadastrado.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                        border: Border(
                          left: BorderSide(
                            color: isAssinatura ? _corAcai : Colors.blue,
                            width: 5,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isAssinatura
                                    ? _corLilas
                                    : Colors.blue[50],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isAssinatura
                                    ? FontAwesomeIcons.boxOpen
                                    : Icons.add_circle,
                                color: isAssinatura ? _corAcai : Colors.blue,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    data['nome'] ?? 'Sem nome',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  // --- ALTERAÇÃO AQUI ---
                                  if (isAssinatura)
                                    Row(
                                      children: [
                                        Icon(
                                          FontAwesomeIcons.dog,
                                          size: 10,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          data['porte'] ??
                                              "Porte não informado",
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      "Adicional",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  // ----------------------
                                ],
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "R\$ ${data['preco']}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.green[700],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        size: 18,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () => _abrirEditor(
                                        docId: doc.id,
                                        collection: collection,
                                        tipoItem: tipoItem,
                                        isAssinatura: isAssinatura,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.red[300],
                                      ),
                                      onPressed: () =>
                                          _excluirItem(collection, doc.id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _corAcai),
        filled: true,
        fillColor: _corFundo,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
