import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // --- AÇÕES DE NEGÓCIO ---
  void _processarPagamento(String docId, double valor) {
    String metodo = 'dinheiro';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              "Receber Pagamento 💰",
              style: TextStyle(color: _corAcai),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Total a Receber", style: TextStyle(color: Colors.grey)),
                Text(
                  "R\$ ${valor.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: metodo,
                  decoration: InputDecoration(
                    labelText: "Forma de Pagamento",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.payment, color: _corAcai),
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
                  onChanged: (v) => setDialogState(() => metodo = v!),
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
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
                onPressed: () async {
                  await _db.collection('agendamentos').doc(docId).update({
                    'status_pagamento': 'pago',
                    'metodo_pagamento': metodo,
                    'pago_em': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Pagamento registrado!")),
                  );
                },
                child: Text("CONFIRMAR RECEBIMENTO"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _liberarPet(String docId) async {
    await _db.collection('agendamentos').doc(docId).update({
      'status': 'concluido',
    });
    setState(() => _selectedAgendamentoId = null);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Pet liberado! 🐶👋")));
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
          // --- HEADER SUPERIOR ---
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
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: _corLilas,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _corAcai.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: _corAcai, size: 18),
                        SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM/yyyy').format(_dataFiltro),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _corAcai,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: _corAcai),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- CORPO SPLIT VIEW ---
          Expanded(
            child: Row(
              children: [
                // ------------------------------------------
                // COLUNA DA ESQUERDA: LISTA APRIMORADA (35%)
                // ------------------------------------------
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

                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_busy,
                                  size: 50,
                                  color: Colors.grey[300],
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "Agenda vazia hoje.",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 10,
                          ),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final isSelected = _selectedAgendamentoId == doc.id;
                            final hora = (data['data_inicio'] as Timestamp)
                                .toDate();

                            // Lógica de Pagamento
                            final bool isPago =
                                data['status_pagamento'] == 'pago' ||
                                data['metodo_pagamento'] == 'voucher' ||
                                (data['metodo_pagamento'] == 'pix' &&
                                    data['status'] != 'aguardando_pagamento');

                            // Tratamento de segurança para Serviço
                            final String servicoBruto =
                                (data['servicoNorm'] ??
                                        data['servico'] ??
                                        '---')
                                    .toString();
                            final String servicoFormatado = _capitalize(
                              servicoBruto,
                            );

                            // PROTEÇÃO CONTRA NULOS (IDs)
                            final String? userId = data['userId'];
                            final String? petId = data['pet_id'];

                            // Se faltar ID, não tenta buscar (evita crash)
                            if (userId == null || petId == null) {
                              return Card(
                                color: Colors.red[50],
                                child: ListTile(
                                  title: Text("Dados incompletos"),
                                  subtitle: Text("Cliente/Pet não vinculado"),
                                  leading: Icon(Icons.error, color: Colors.red),
                                  onTap: () => setState(
                                    () => _selectedAgendamentoId = doc.id,
                                  ),
                                ),
                              );
                            }

                            // BUSCA DADOS DO PET EM TEMPO REAL
                            return FutureBuilder<DocumentSnapshot>(
                              future: _db
                                  .collection('users')
                                  .doc(userId)
                                  .collection('pets')
                                  .doc(petId)
                                  .get(),
                              builder: (context, petSnap) {
                                String nomePet = "Carregando...";
                                String tipoPet = "cao";

                                if (petSnap.hasData && petSnap.data!.exists) {
                                  final pData = petSnap.data!.data() as Map;
                                  nomePet = pData['nome'] ?? "Pet sem nome";
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
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 5,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: IntrinsicHeight(
                                      child: Row(
                                        children: [
                                          // Barra Lateral de Status
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
                                          // Conteúdo
                                          Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                    horizontal: 12,
                                                  ),
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
                                                  VerticalDivider(
                                                    color: Colors.grey[300],
                                                    width: 25,
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          nomePet,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        SizedBox(height: 4),
                                                        Container(
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 3,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: isSelected
                                                                ? _corAcai
                                                                      .withOpacity(
                                                                        0.1,
                                                                      )
                                                                : Colors
                                                                      .grey[100],
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  5,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            servicoFormatado,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: isSelected
                                                                  ? _corAcai
                                                                  : Colors
                                                                        .grey[700],
                                                            ),
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

                // ------------------------------------------
                // COLUNA DA DIREITA: DETALHES COM SCROLL (65%)
                // ------------------------------------------
                Expanded(
                  flex: 65,
                  child: Container(
                    color: _corFundo,
                    // ADICIONEI SINGLE CHILD SCROLL VIEW PARA O BOTÃO NÃO CORTAR
                    child: _selectedAgendamentoId == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.touch_app,
                                  size: 60,
                                  color: Colors.grey[300],
                                ),
                                SizedBox(height: 20),
                                Text(
                                  "Selecione um agendamento\npara ver os detalhes",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
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
                              final bool isPago =
                                  data['status_pagamento'] == 'pago' ||
                                  (data['metodo_pagamento'] == 'pix' &&
                                      data['status'] !=
                                          'aguardando_pagamento') ||
                                  data['metodo_pagamento'] == 'voucher';
                              final bool isConcluido =
                                  data['status'] == 'concluido';

                              final String servicoBruto =
                                  (data['servicoNorm'] ??
                                          data['servico'] ??
                                          '---')
                                      .toString();
                              final String servicoFormatado = _capitalize(
                                servicoBruto,
                              );

                              final String? userId = data['userId'];
                              final String? petId = data['pet_id'];

                              // Se não tiver ID, mostra tela básica de erro sem quebrar
                              if (userId == null || petId == null) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.warning,
                                        size: 50,
                                        color: Colors.orange,
                                      ),
                                      Text("Dados corrompidos (Sem ID)"),
                                      SizedBox(height: 20),
                                      ElevatedButton(
                                        onPressed: () =>
                                            _liberarPet(snapshot.data!.id),
                                        child: Text("Forçar Finalização"),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return SingleChildScrollView(
                                padding: EdgeInsets.all(30),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // --- HEADER ---
                                    FutureBuilder<DocumentSnapshot>(
                                      future: _db
                                          .collection('users')
                                          .doc(userId)
                                          .collection('pets')
                                          .doc(petId)
                                          .get(),
                                      builder: (c, pSnap) {
                                        String pNome = "---";
                                        String pRaca = "Raça não inf.";
                                        String pTipo = "cao";
                                        if (pSnap.hasData &&
                                            pSnap.data!.exists) {
                                          final pData =
                                              pSnap.data!.data() as Map;
                                          pNome = pData['nome'] ?? "Sem Nome";
                                          pRaca =
                                              pData['raca'] ?? "Raça não inf.";
                                          pTipo = pData['tipo'] ?? "cao";
                                        }

                                        return Row(
                                          children: [
                                            Container(
                                              height: 80,
                                              width: 80,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 10,
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: FaIcon(
                                                  pTipo == 'gato'
                                                      ? FontAwesomeIcons.cat
                                                      : FontAwesomeIcons.dog,
                                                  size: 40,
                                                  color: _corAcai,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 20),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    pNome,
                                                    style: TextStyle(
                                                      fontSize: 28,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _corAcai,
                                                    ),
                                                  ),
                                                  Text(
                                                    pRaca,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 15,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isPago
                                                    ? Colors.green[50]
                                                    : Colors.orange[50],
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: isPago
                                                      ? Colors.green
                                                            .withOpacity(0.5)
                                                      : Colors.orange
                                                            .withOpacity(0.5),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isPago
                                                        ? Icons.check_circle
                                                        : Icons.pending,
                                                    size: 18,
                                                    color: isPago
                                                        ? Colors.green[800]
                                                        : Colors.orange[800],
                                                  ),
                                                  SizedBox(width: 5),
                                                  Text(
                                                    isPago
                                                        ? "PAGO"
                                                        : "A RECEBER",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isPago
                                                          ? Colors.green[800]
                                                          : Colors.orange[800],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),

                                    SizedBox(height: 30),

                                    // --- INFO CARD ---
                                    Container(
                                      padding: EdgeInsets.all(25),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 15,
                                            offset: Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          FutureBuilder<DocumentSnapshot>(
                                            future: _db
                                                .collection('users')
                                                .doc(userId)
                                                .get(),
                                            builder: (c, uSnap) {
                                              String tNome = "---";
                                              String tTel = "";
                                              if (uSnap.hasData &&
                                                  uSnap.data!.exists) {
                                                final uData =
                                                    uSnap.data!.data() as Map;
                                                tNome =
                                                    uData['nome'] ?? "Cliente";
                                                tTel = uData['telefone'] ?? "";
                                              }
                                              return Column(
                                                children: [
                                                  _buildInfoRow(
                                                    "Tutor Responsável",
                                                    tNome,
                                                    icon: Icons.person_outline,
                                                  ),
                                                  SizedBox(height: 15),
                                                  if (tTel.isNotEmpty)
                                                    InkWell(
                                                      onTap: () =>
                                                          _abrirWhatsApp(tTel),
                                                      child: Container(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              vertical: 10,
                                                              horizontal: 15,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              Colors.green[50],
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              FontAwesomeIcons
                                                                  .whatsapp,
                                                              size: 16,
                                                              color:
                                                                  Colors.green,
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text(
                                                              "Conversar com Tutor",
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .green[800],
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                          Divider(height: 40),
                                          _buildInfoRow(
                                            "Serviço Solicitado",
                                            servicoFormatado,
                                            icon: Icons.cut,
                                            isBold: true,
                                          ),
                                          SizedBox(height: 20),
                                          _buildInfoRow(
                                            "Profissional",
                                            data['profissional_nome'] ?? '---',
                                            icon: Icons.badge,
                                          ),
                                          Divider(height: 40),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Total do Serviço",
                                                style: TextStyle(
                                                  color: _corAcai,
                                                ),
                                              ),
                                              Text(
                                                "R\$ ${data['valor']}",
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: _corAcai,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(height: 30),

                                    // --- BOTÕES ---
                                    if (isConcluido)
                                      SizedBox(
                                        width: double.infinity,
                                        height: 60,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[300],
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                          ),
                                          onPressed: null,
                                          child: Text(
                                            "✅ Serviço já finalizado",
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      )
                                    else if (!isPago)
                                      SizedBox(
                                        width: double.infinity,
                                        height: 65,
                                        child: ElevatedButton.icon(
                                          icon: Icon(
                                            Icons.payments_outlined,
                                            size: 28,
                                          ),
                                          label: Text("RECEBER PAGAMENTO"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            elevation: 5,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            textStyle: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          onPressed: () => _processarPagamento(
                                            snapshot.data!.id,
                                            (data['valor'] ?? 0).toDouble(),
                                          ),
                                        ),
                                      )
                                    else
                                      SizedBox(
                                        width: double.infinity,
                                        height: 65,
                                        child: ElevatedButton.icon(
                                          icon: Icon(
                                            Icons.exit_to_app,
                                            size: 28,
                                          ),
                                          label: Text(
                                            "LIBERAR PET (FINALIZAR)",
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _corAcai,
                                            foregroundColor: Colors.white,
                                            elevation: 5,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            textStyle: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          onPressed: () =>
                                              _liberarPet(snapshot.data!.id),
                                        ),
                                      ),
                                    SizedBox(
                                      height: 30,
                                    ), // Espaço extra no final do scroll
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
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    IconData? icon,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: Colors.grey[400]),
              SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
