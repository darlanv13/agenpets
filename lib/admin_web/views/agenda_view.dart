import 'package:agenpet/admin_web/views/components/novo_agendamento_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart'; // <--- IMPORT NOVO
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AgendaView extends StatefulWidget {
  @override
  _AgendaViewState createState() => _AgendaViewState();
}

class _AgendaViewState extends State<AgendaView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Instância do Cloud Functions (Ajuste a região se necessário, ex: southamerica-east1)
  final _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  DateTime _dataFiltro = DateTime.now();
  String? _selectedAgendamentoId;

  // --- PALETA DE CORES (Açaí & Lilás) ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLavanda = Color(0xFFAB47BC);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFFAFAFA);

  // --- HELPERS ---
  void _abrirWhatsApp(String? telefone) async {
    if (telefone == null || telefone.isEmpty) return;
    String num = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!num.startsWith('55')) num = "55$num";
    final uri = Uri.parse("https://wa.me/$num");
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String _capitalize(String? s) {
    if (s == null || s.isEmpty) return "";
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  // --- AGENDAMENTO BALCÃO ---
  void _abrirAgendamentoBalcao() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => NovoAgendamentoDialog(),
    );
  }

  // --- CHECKOUT INTELIGENTE (VIA CLOUD FUNCTIONS) ---
  // --- CHECKOUT INTELIGENTE (ATUALIZADO) ---
  void _abrirCheckout(DocumentSnapshot agendamentoDoc) async {
    final dataAgendamento = agendamentoDoc.data() as Map<String, dynamic>;
    final String userId = dataAgendamento['userId'];
    final double valorOriginal = (dataAgendamento['valor'] ?? 0).toDouble();
    final String servicoNome = _capitalize(
      dataAgendamento['servicoNorm'] ?? dataAgendamento['servico'] ?? '',
    );

    // Busca dados
    final userDoc = await _db.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};

    final extrasSnap = await _db
        .collection('servicos_extras')
        .where('ativo', isEqualTo: true)
        .get();
    final List<Map<String, dynamic>> listaExtrasDisponiveis = extrasSnap.docs
        .map(
          (e) => {
            'id': e.id,
            'nome': e['nome'],
            'preco': (e['preco'] ?? 0).toDouble(),
          },
        )
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CheckoutDialogPremium(
        // <--- NOVA CLASSE AQUI
        agendamentoId: agendamentoDoc.id,
        servicoNome: servicoNome,
        valorOriginal: valorOriginal,
        userData: userData,
        listaExtras: listaExtrasDisponiveis,
        corAcai: _corAcai,
        onSuccess: () {
          setState(() => _selectedAgendamentoId = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Checkout Realizado com Sucesso! 🚀"),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inicio = DateTime(
      _dataFiltro.year,
      _dataFiltro.month,
      _dataFiltro.day,
    );
    final fim = DateTime(
      _dataFiltro.year,
      _dataFiltro.month,
      _dataFiltro.day,
      23,
      59,
      59,
    );

    return Scaffold(
      backgroundColor: _corFundo,
      body: Column(
        children: [
          // HEADER
          Container(
            padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_view_week_rounded, color: _corAcai),
                    SizedBox(width: 10),
                    Text(
                      "Gestão de Agenda",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _corAcai,
                      ),
                    ),
                  ],
                ),

                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.add_circle_outline, size: 18),
                      label: Text("Agendar Balcão"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _corAcai,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _abrirAgendamentoBalcao,
                    ),
                    SizedBox(width: 15),

                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _dataFiltro,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setState(() => _dataFiltro = d);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _corLilas,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _corAcai.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month,
                              color: _corAcai,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              DateFormat('dd/MM/yyyy').format(_dataFiltro),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _corAcai,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // SPLIT VIEW
          Expanded(
            child: Row(
              children: [
                // ESQUERDA: LISTA
                Expanded(
                  flex: 35,
                  child: Container(
                    color: Colors.white,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _db
                          .collection('agendamentos')
                          .where(
                            'data_inicio',
                            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio),
                          )
                          .where(
                            'data_inicio',
                            isLessThanOrEqualTo: Timestamp.fromDate(fim),
                          )
                          .orderBy('data_inicio')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return Center(child: CircularProgressIndicator());
                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty)
                          return Center(
                            child: Text(
                              "Sem agendamentos hoje.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          );

                        return ListView.builder(
                          padding: EdgeInsets.all(10),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final isSelected = _selectedAgendamentoId == doc.id;
                            final hora = (data['data_inicio'] as Timestamp)
                                .toDate();
                            final isPago =
                                data['status_pagamento'] == 'pago' ||
                                (data['metodo_pagamento'] == 'pix' &&
                                    data['status'] != 'aguardando_pagamento') ||
                                data['metodo_pagamento'] == 'voucher';
                            final servicoFormatado = _capitalize(
                              data['servicoNorm'] ?? data['servico'],
                            );

                            // Busca dados do Pet
                            return FutureBuilder<DocumentSnapshot>(
                              future: _db
                                  .collection('users')
                                  .doc(data['userId'])
                                  .collection('pets')
                                  .doc(data['pet_id'])
                                  .get(),
                              builder: (context, petSnap) {
                                String nomePet = "Carregando...";
                                String tipoPet = "cao";
                                if (petSnap.hasData && petSnap.data!.exists) {
                                  final pData = petSnap.data!.data() as Map;
                                  nomePet = pData['nome'] ?? "Pet";
                                  tipoPet = pData['tipo'] ?? 'cao';
                                }

                                return GestureDetector(
                                  onTap: () => setState(
                                    () => _selectedAgendamentoId = doc.id,
                                  ),
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: 200),
                                    margin: EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _corLilas
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? _corAcai
                                            : Colors.grey[200]!,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: IntrinsicHeight(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            decoration: BoxDecoration(
                                              color: isPago
                                                  ? Colors.green
                                                  : Colors.orange,
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(12),
                                                bottomLeft: Radius.circular(12),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Row(
                                                children: [
                                                  Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        DateFormat(
                                                          'HH:mm',
                                                        ).format(hora),
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                          color: isSelected
                                                              ? _corAcai
                                                              : Colors.black87,
                                                        ),
                                                      ),
                                                      SizedBox(height: 5),
                                                      CircleAvatar(
                                                        radius: 18,
                                                        backgroundColor:
                                                            isSelected
                                                            ? Colors.white
                                                            : _corFundo,
                                                        child: FaIcon(
                                                          tipoPet == 'gato'
                                                              ? FontAwesomeIcons
                                                                    .cat
                                                              : FontAwesomeIcons
                                                                    .dog,
                                                          size: 16,
                                                          color: _corAcai,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  VerticalDivider(),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          nomePet,
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          servicoFormatado,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey[700],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.chevron_right,
                                                    color: isSelected
                                                        ? _corAcai
                                                        : Colors.grey[300],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),

                Container(width: 1, color: Colors.grey[200]),

                // DIREITA: DETALHES DO AGENDAMENTO
                Expanded(
                  flex: 65,
                  child: Container(
                    color: _corFundo,
                    child: _selectedAgendamentoId == null
                        ? Center(
                            child: Text(
                              "Selecione um agendamento",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : StreamBuilder<DocumentSnapshot>(
                            stream: _db
                                .collection('agendamentos')
                                .doc(_selectedAgendamentoId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || !snapshot.data!.exists)
                                return Center(
                                  child: CircularProgressIndicator(),
                                );
                              final data =
                                  snapshot.data!.data() as Map<String, dynamic>;
                              final bool isConcluido =
                                  data['status'] == 'concluido';
                              final String? userId = data['userId'];
                              final String? petId = data['pet_id'];

                              if (userId == null || petId == null)
                                return Center(child: Text("Dados Incompletos"));

                              return FutureBuilder<List<DocumentSnapshot>>(
                                future: Future.wait([
                                  _db.collection('users').doc(userId).get(),
                                  _db
                                      .collection('users')
                                      .doc(userId)
                                      .collection('pets')
                                      .doc(petId)
                                      .get(),
                                ]),
                                builder: (context, futures) {
                                  if (!futures.hasData)
                                    return Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  final userDoc = futures.data![0];
                                  final petDoc = futures.data![1];

                                  return SingleChildScrollView(
                                    padding: EdgeInsets.all(30),
                                    child: Column(
                                      children: [
                                        _buildResumoCard(userDoc, petDoc, data),
                                        SizedBox(height: 30),
                                        _buildDetalhesServico(
                                          data,
                                          isConcluido,
                                        ),
                                        SizedBox(height: 30),
                                        if (isConcluido)
                                          Container(
                                            padding: EdgeInsets.all(15),
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[300],
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Center(
                                              child: Text(
                                                "✅ Serviço Finalizado",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          SizedBox(
                                            width: double.infinity,
                                            height: 60,
                                            child: ElevatedButton.icon(
                                              icon: Icon(
                                                Icons.check_circle_outline,
                                              ),
                                              label: Text(
                                                "FINALIZAR SERVIÇO / CHECKOUT",
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                ),
                                                textStyle: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              onPressed: () => _abrirCheckout(
                                                snapshot.data!,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- RESUMO CARD ---
  Widget _buildResumoCard(
    DocumentSnapshot userDoc,
    DocumentSnapshot petDoc,
    Map agendamentoData,
  ) {
    final uData = userDoc.data() as Map? ?? {};
    final pData = petDoc.data() as Map? ?? {};
    bool isAssinante =
        (uData['vouchers_banho'] ?? 0) > 0 ||
        (uData['vouchers_tosa'] ?? 0) > 0 ||
        (uData['assinante_ativo'] == true);
    String origem = agendamentoData['criado_por_admin'] == true
        ? 'Loja/Balcão'
        : 'Aplicativo';

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Resumo do Agendamento",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _corAcai,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  origem.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 25),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _corLilas,
                radius: 25,
                child: Icon(Icons.person, color: _corAcai),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uData['nome'] ?? 'Tutor Desconhecido',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          pData['tipo'] == 'gato'
                              ? FontAwesomeIcons.cat
                              : FontAwesomeIcons.dog,
                          size: 12,
                          color: Colors.grey,
                        ),
                        SizedBox(width: 5),
                        Text(
                          pData['nome'] ?? 'Pet',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isAssinante)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text(
                        "ASSINANTE",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetalhesServico(Map data, bool isConcluido) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _row("Serviço", _capitalize(data['servicoNorm'] ?? data['servico'])),
          _row("Profissional", data['profissional_nome'] ?? '--'),
          _row("Valor Base", "R\$ ${data['valor']}"),
          if (isConcluido && data['extras'] != null) ...[
            Divider(),
            Text(
              "Detalhes do Fechamento",
              style: TextStyle(fontWeight: FontWeight.bold, color: _corAcai),
            ),
            ...(data['extras'] as List)
                .map((e) => _row("+ ${e['nome']}", "R\$ ${e['preco']}"))
                .toList(),
            Divider(),
            if (data['vouchers_consumidos'] != null)
              _row(
                "Vouchers Usados",
                _formatarVouchersUsados(data['vouchers_consumidos']),
                isBold: true,
                color: Colors.green,
              ),
            _row(
              "Total Pago",
              "R\$ ${data['valor_final_cobrado']}",
              isBold: true,
              fontSize: 18,
            ),
          ],
        ],
      ),
    );
  }

  String _formatarVouchersUsados(Map v) {
    List<String> s = [];
    v.forEach((key, val) {
      if (val == true) {
        String label = key.replaceAll('vouchers_', '');
        s.add(label[0].toUpperCase() + label.substring(1));
      }
    });
    return s.isEmpty ? "Nenhum" : s.join(" + ");
  }

  Widget _row(
    String k,
    String v, {
    bool isBold = false,
    Color? color,
    double fontSize = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: Colors.grey)),
          Text(
            v,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black87,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}

// --- ITEM 03: DIÁLOGO DE CHECKOUT (VISUAL MANTIDO, LÓGICA ATUALIZADA) ---
class _CheckoutDialogContent extends StatefulWidget {
  final String servicoNome;
  final double valorOriginal;
  final Map userData;
  final List<Map<String, dynamic>> listaExtras;
  final Color corAcai;
  final Color corLilas;
  final Function(Map<String, bool>, List<Map<String, dynamic>>, String, double)
  onConfirm;

  const _CheckoutDialogContent({
    required this.servicoNome,
    required this.valorOriginal,
    required this.userData,
    required this.listaExtras,
    required this.corAcai,
    required this.corLilas,
    required this.onConfirm,
  });

  @override
  __CheckoutDialogContentState createState() => __CheckoutDialogContentState();
}

class __CheckoutDialogContentState extends State<_CheckoutDialogContent> {
  Map<String, bool> _vouchersParaUsar = {};
  List<Map<String, dynamic>> _extrasSelecionados = [];
  String? _extraSelecionadoId;
  String _metodoPagamento = 'dinheiro';

  // Variável para controlar o estado de carregamento do botão
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _identificarVouchersDisponiveis().forEach((key) {
      _vouchersParaUsar[key] = false;
    });
  }

  List<String> _identificarVouchersDisponiveis() {
    List<String> vouchers = [];
    widget.userData.forEach((key, value) {
      if (key.toString().startsWith('vouchers_') && value is int && value > 0) {
        vouchers.add(key);
      }
    });
    return vouchers;
  }

  @override
  Widget build(BuildContext context) {
    List<String> vouchersDisponiveis = _identificarVouchersDisponiveis();
    double descontoVoucher = 0;

    bool usouAlgumVoucher = _vouchersParaUsar.containsValue(true);
    if (usouAlgumVoucher) {
      descontoVoucher = widget.valorOriginal;
    }

    double valorBaseAposVoucher = widget.valorOriginal - descontoVoucher;
    if (valorBaseAposVoucher < 0) valorBaseAposVoucher = 0;

    double valorExtras = _extrasSelecionados.fold(
      0,
      (sum, item) => sum + item['preco'],
    );
    double valorTotal = valorBaseAposVoucher + valorExtras;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.shopping_cart_checkout, color: widget.corAcai),
          SizedBox(width: 10),
          Text(
            "Checkout",
            style: TextStyle(
              color: widget.corAcai,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Container(
          width: 450,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Serviço Realizado: ${widget.servicoNome}",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Divider(),

              if (vouchersDisponiveis.isNotEmpty) ...[
                Text(
                  "Pacote de Assinatura (Vouchers Disponíveis)",
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: vouchersDisponiveis.map((chaveVoucher) {
                      String nomeVoucher = chaveVoucher
                          .replaceAll('vouchers_', '')
                          .toUpperCase();
                      int saldo = widget.userData[chaveVoucher] ?? 0;

                      return CheckboxListTile(
                        activeColor: Colors.green,
                        title: Text("Descontar 1 $nomeVoucher"),
                        subtitle: Text("Saldo atual: $saldo"),
                        value: _vouchersParaUsar[chaveVoucher] ?? false,
                        onChanged: (v) => setState(
                          () => _vouchersParaUsar[chaveVoucher] = v!,
                        ),
                        secondary: Icon(
                          Icons.confirmation_number,
                          color: Colors.green,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 20),
              ] else ...[
                Container(
                  padding: EdgeInsets.all(10),
                  width: double.infinity,
                  color: Colors.grey[100],
                  child: Text(
                    "Cliente não possui vouchers ativos.",
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 20),
              ],

              Text(
                "Adicionar Extras (Opcional):",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.corAcai,
                  fontSize: 12,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _extraSelecionadoId,
                      hint: Text("Selecione..."),
                      isDense: true,
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: widget.listaExtras
                          .map(
                            (e) => DropdownMenuItem(
                              value: e['id'].toString(),
                              child: Text("${e['nome']} (+ R\$ ${e['preco']})"),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _extraSelecionadoId = v),
                    ),
                  ),
                  SizedBox(width: 10),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle,
                      color: widget.corAcai,
                      size: 30,
                    ),
                    onPressed: () {
                      if (_extraSelecionadoId != null) {
                        final item = widget.listaExtras.firstWhere(
                          (e) => e['id'] == _extraSelecionadoId,
                        );
                        setState(() {
                          _extrasSelecionados.add(item);
                          _extraSelecionadoId = null;
                        });
                      }
                    },
                  ),
                ],
              ),

              if (_extrasSelecionados.isNotEmpty)
                Column(
                  children: _extrasSelecionados.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "+ ${e['nome']}",
                        style: TextStyle(fontSize: 13),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "R\$ ${e['preco']}",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 10),
                          InkWell(
                            onTap: () =>
                                setState(() => _extrasSelecionados.removeAt(i)),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

              Divider(height: 30, thickness: 2),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Valor Serviço:"),
                  Text("R\$ ${widget.valorOriginal.toStringAsFixed(2)}"),
                ],
              ),
              if (descontoVoucher > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Desconto Voucher:",
                      style: TextStyle(color: Colors.green),
                    ),
                    Text(
                      "- R\$ ${descontoVoucher.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              if (valorExtras > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Extras:"),
                    Text("+ R\$ ${valorExtras.toStringAsFixed(2)}"),
                  ],
                ),

              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "TOTAL FINAL:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    "R\$ ${valorTotal.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: widget.corAcai,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              if (valorTotal > 0)
                DropdownButtonFormField<String>(
                  value: _metodoPagamento,
                  decoration: InputDecoration(
                    labelText: "Forma de Pagamento",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.payment, color: widget.corAcai),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'dinheiro',
                      child: Text("Dinheiro / Débito"),
                    ),
                    DropdownMenuItem(
                      value: 'pix_balcao',
                      child: Text("Pix (Balcão)"),
                    ),
                    DropdownMenuItem(
                      value: 'cartao_credito',
                      child: Text("Cartão de Crédito"),
                    ),
                  ],
                  onChanged: (v) => setState(() => _metodoPagamento = v!),
                ),

              if (valorTotal == 0 && usouAlgumVoucher)
                Container(
                  padding: EdgeInsets.all(10),
                  width: double.infinity,
                  color: Colors.green[50],
                  child: Text(
                    "Totalmente coberto pelo Plano 🌟",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text("Cancelar"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
          ),
          onPressed: _isLoading
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  await widget.onConfirm(
                    _vouchersParaUsar,
                    _extrasSelecionados,
                    _metodoPagamento,
                    valorTotal,
                  );
                  // Se o onConfirm não fechar o modal, paramos o loading aqui
                  if (mounted) setState(() => _isLoading = false);
                },
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  "CONFIRMAR CHECKOUT",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}

// --- NOVO DIALOG PREMIUM DE CHECKOUT ---
class CheckoutDialogPremium extends StatefulWidget {
  final String agendamentoId;
  final String servicoNome;
  final double valorOriginal;
  final Map userData;
  final List<Map<String, dynamic>> listaExtras;
  final Color corAcai;
  final VoidCallback onSuccess;

  const CheckoutDialogPremium({
    required this.agendamentoId,
    required this.servicoNome,
    required this.valorOriginal,
    required this.userData,
    required this.listaExtras,
    required this.corAcai,
    required this.onSuccess,
  });

  @override
  _CheckoutDialogPremiumState createState() => _CheckoutDialogPremiumState();
}

class _CheckoutDialogPremiumState extends State<CheckoutDialogPremium> {
  final _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  Map<String, bool> _vouchersParaUsar = {};
  List<Map<String, dynamic>> _extrasSelecionados = [];
  String? _extraSelecionadoId;
  String _metodoPagamento = 'dinheiro'; // Padrão
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Inicializa vouchers disponíveis desmarcados
    _identificarVouchersDisponiveis().forEach((key) {
      _vouchersParaUsar[key] = false;
    });
  }

  List<String> _identificarVouchersDisponiveis() {
    List<String> vouchers = [];
    widget.userData.forEach((key, value) {
      if (key.toString().startsWith('vouchers_') && value is int && value > 0) {
        vouchers.add(key);
      }
    });
    return vouchers;
  }

  void _confirmarCheckout() async {
    setState(() => _isLoading = true);

    try {
      List<String> extrasIds = _extrasSelecionados
          .map((e) => e['id'] as String)
          .toList();

      final result = await _functions.httpsCallable('realizarCheckout').call({
        'agendamentoId': widget.agendamentoId,
        'extrasIds': extrasIds,
        'metodoPagamento': _metodoPagamento,
        'vouchersParaUsar': _vouchersParaUsar,
      });

      final retorno = result.data as Map;
      print("Sucesso: ${retorno['mensagem']}");

      Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      setState(() => _isLoading = false);
      String erroMsg = "Erro desconhecido";
      if (e is FirebaseFunctionsException) erroMsg = e.message ?? e.code;

      _mostrarErro(erroMsg);
    }
  }

  void _mostrarErro(String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("Ops!", style: TextStyle(color: Colors.red)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text("OK")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- LÓGICA DE CÁLCULO VISUAL ---
    double descontoVoucher = _vouchersParaUsar.containsValue(true)
        ? widget.valorOriginal
        : 0;
    double valorBase = (widget.valorOriginal - descontoVoucher).clamp(
      0,
      double.infinity,
    );
    double valorExtras = _extrasSelecionados.fold(
      0,
      (sum, item) => sum + item['preco'],
    );
    double valorTotal = valorBase + valorExtras;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      elevation: 10,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500, // Largura fixa ideal para web/desktop
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- HEADER (Topo Colorido) ---
            Container(
              padding: EdgeInsets.fromLTRB(25, 25, 25, 20),
              decoration: BoxDecoration(
                color: widget.corAcai,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Finalizar Atendimento",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text(
                    "TOTAL A COBRAR",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    "R\$ ${valorTotal.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (descontoVoucher > 0)
                    Container(
                      margin: EdgeInsets.only(top: 5),
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Voucher Aplicado",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // --- CORPO DO DIALOG ---
            Flexible(
              // Permite scroll se a tela for pequena
              child: SingleChildScrollView(
                padding: EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. SERVIÇO PRINCIPAL
                    _buildSectionTitle("Serviço Realizado"),
                    Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: widget.corAcai.withOpacity(
                                  0.1,
                                ),
                                child: Icon(
                                  FontAwesomeIcons.paw,
                                  color: widget.corAcai,
                                  size: 16,
                                ),
                              ),
                              SizedBox(width: 15),
                              Text(
                                widget.servicoNome,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "R\$ ${widget.valorOriginal.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: Colors.grey[600],
                              decoration: descontoVoucher > 0
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 25),

                    // 2. VOUCHERS (Se houver)
                    if (_vouchersParaUsar.isNotEmpty) ...[
                      _buildSectionTitle("Assinatura / Vouchers"),
                      ..._vouchersParaUsar.keys.map((key) {
                        String nome = key
                            .replaceAll('vouchers_', '')
                            .toUpperCase();
                        int saldo = widget.userData[key] ?? 0;
                        bool isActive = _vouchersParaUsar[key]!;

                        return GestureDetector(
                          onTap: () => setState(
                            () => _vouchersParaUsar[key] = !isActive,
                          ),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            margin: EdgeInsets.only(bottom: 10),
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green[50] : Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: isActive
                                    ? Colors.green
                                    : Colors.grey[300]!,
                                width: isActive ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.confirmation_number,
                                  color: isActive ? Colors.green : Colors.grey,
                                ),
                                SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Usar Voucher de $nome",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isActive
                                              ? Colors.green[900]
                                              : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        "Saldo Disponível: $saldo",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isActive
                                              ? Colors.green[700]
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isActive,
                                  activeColor: Colors.green,
                                  onChanged: (v) => setState(
                                    () => _vouchersParaUsar[key] = v,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      SizedBox(height: 15),
                    ],

                    // 3. EXTRAS
                    _buildSectionTitle("Extras e Adicionais"),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 15),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _extraSelecionadoId,
                                hint: Text(
                                  "Selecionar extra...",
                                  style: TextStyle(fontSize: 14),
                                ),
                                isExpanded: true,
                                items: widget.listaExtras
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e['id'].toString(),
                                        child: Text(
                                          "${e['nome']} (+ R\$ ${e['preco']})",
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _extraSelecionadoId = v),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.corAcai,
                            shape: CircleBorder(),
                            padding: EdgeInsets.all(12),
                          ),
                          onPressed: () {
                            if (_extraSelecionadoId != null) {
                              final item = widget.listaExtras.firstWhere(
                                (e) => e['id'] == _extraSelecionadoId,
                              );
                              setState(() {
                                _extrasSelecionados.add(item);
                                _extraSelecionadoId = null;
                              });
                            }
                          },
                          child: Icon(Icons.add, color: Colors.white),
                        ),
                      ],
                    ),

                    if (_extrasSelecionados.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 15),
                        child: Column(
                          children: _extrasSelecionados
                              .asMap()
                              .entries
                              .map(
                                (e) => Container(
                                  margin: EdgeInsets.only(bottom: 8),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "+ ${e.value['nome']}",
                                        style: TextStyle(
                                          color: Colors.orange[900],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            "R\$ ${e.value['preco']}",
                                            style: TextStyle(
                                              color: Colors.orange[900],
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          InkWell(
                                            onTap: () => setState(
                                              () => _extrasSelecionados
                                                  .removeAt(e.key),
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              color: Colors.orange[900],
                                              size: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),

                    SizedBox(height: 25),

                    // 4. FORMA DE PAGAMENTO
                    if (valorTotal > 0) ...[
                      _buildSectionTitle("Pagamento"),
                      Row(
                        children: [
                          _buildPaymentCard(
                            'dinheiro',
                            "Dinheiro",
                            FontAwesomeIcons.moneyBill,
                          ),
                          SizedBox(width: 10),
                          _buildPaymentCard('pix_balcao', "Pix", Icons.pix),
                          SizedBox(width: 10),
                          _buildPaymentCard(
                            'cartao_credito',
                            "Cartão",
                            FontAwesomeIcons.creditCard,
                          ),
                        ],
                      ),
                    ] else
                      Container(
                        padding: EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "Totalmente Coberto pelo Plano ✨",
                            style: TextStyle(
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // --- BOTÃO FINAL ---
            Padding(
              padding: EdgeInsets.all(25),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                    shadowColor: Colors.green.withOpacity(0.4),
                  ),
                  onPressed: _isLoading ? null : _confirmarCheckout,
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "CONFIRMAR E FINALIZAR",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para os cartões de pagamento
  Widget _buildPaymentCard(String value, String label, IconData icon) {
    bool isSelected = _metodoPagamento == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _metodoPagamento = value),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isSelected ? widget.corAcai : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? widget.corAcai : Colors.grey[300]!,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: widget.corAcai.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 20,
              ),
              SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
