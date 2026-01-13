import 'package:agenpet/admin_web/views/components/checkout_hotel_dialog.dart';
import 'package:agenpet/admin_web/views/components/nova_reserva_dialog.dart';
import 'package:agenpet/admin_web/views/components/registrar_pagamento_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HotelView extends StatefulWidget {
  @override
  _HotelViewState createState() => _HotelViewState();
}

class _HotelViewState extends State<HotelView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Cores
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLavanda = Color(0xFFAB47BC);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF5F7FA);

  // Variáveis de Controle
  String? _selectedReservaId;
  Map<String, dynamic>? _selectedReservaData;
  double _precoDiariaCache = 0.0;

  // Controle de Busca
  TextEditingController _searchController = TextEditingController();
  String _filtroTexto = "";

  @override
  void initState() {
    super.initState();
    _carregarPrecoDiaria();
  }

  void _carregarPrecoDiaria() async {
    final doc = await _db.collection('config').doc('parametros').get();
    if (doc.exists) {
      setState(() {
        _precoDiariaCache = (doc.data()?['preco_hotel_diaria'] ?? 0).toDouble();
      });
    }
  }

  void _fazerCheckIn(String docId) async {
    await _db.collection('reservas_hotel').doc(docId).update({
      'status': 'hospedado',
      'check_in_real': FieldValue.serverTimestamp(),
    });
    _refreshSelection(docId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Check-in realizado! Bem-vindo! 🐶")),
    );
  }

  void _refreshSelection(String docId) async {
    final doc = await _db.collection('reservas_hotel').doc(docId).get();
    if (doc.exists) {
      setState(() {
        _selectedReservaData = doc.data();
      });
    }
  }

  void _abrirCheckoutHotel(String docId, Map<String, dynamic> data) async {
    final extrasSnap = await _db
        .collection('servicos_extras')
        .where('ativo', isEqualTo: true)
        .get();
    final List<Map<String, dynamic>> extrasDisponiveis = extrasSnap.docs
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
      builder: (ctx) => CheckoutHotelDialog(
        reservaId: docId,
        dadosReserva: data,
        precoDiaria: _precoDiariaCache,
        listaExtras: extrasDisponiveis,
        corAcai: _corAcai,
        onSuccess: () {
          setState(() {
            _selectedReservaId = null;
            _selectedReservaData = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Estadia finalizada com sucesso! 🏨"),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _novaHospedagemManual() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => NovaReservaDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Column(
        children: [
          _buildHeaderAndKPIs(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: _buildListaReservas()),
                if (_selectedReservaId != null)
                  Expanded(flex: 4, child: _buildPainelDetalhes()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAndKPIs() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hotel & Estadia",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _corAcai,
                    ),
                  ),
                  Text(
                    "Gerencie check-ins, check-outs e serviços do hotel",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text("NOVA RESERVA"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
                onPressed: _novaHospedagemManual,
              ),
            ],
          ),
          SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('reservas_hotel')
                .where('status', whereIn: ['reservado', 'hospedado'])
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return SizedBox();
              int hospedados = 0;
              int chegando = 0;
              for (var doc in snapshot.data!.docs) {
                if (doc['status'] == 'hospedado')
                  hospedados++;
                else
                  chegando++;
              }
              return Row(
                children: [
                  _kpiCard(
                    "Hóspedes Atuais",
                    "$hospedados",
                    FontAwesomeIcons.dog,
                    _corAcai,
                  ),
                  SizedBox(width: 15),
                  _kpiCard(
                    "Chegando Hoje",
                    "$chegando",
                    FontAwesomeIcons.suitcase,
                    _corLavanda,
                  ),
                  SizedBox(width: 15),
                  _kpiCard(
                    "Valor Diária",
                    "R\$ $_precoDiariaCache",
                    Icons.attach_money,
                    Colors.green,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _corFundo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 18),
            ),
            SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- LISTA DE RESERVAS COM BUSCA ---
  Widget _buildListaReservas() {
    return Container(
      margin: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          // 1. CAMPO DE BUSCA
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Buscar hóspede por Nome ou CPF",
                prefixIcon: Icon(Icons.search, color: _corAcai),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 0,
                ),
                filled: true,
                fillColor: _corFundo,
              ),
              onChanged: (v) {
                setState(() => _filtroTexto = v.toLowerCase());
              },
            ),
          ),

          Divider(height: 1),

          // 2. LISTA
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('reservas_hotel')
                  .orderBy('check_in', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: EdgeInsets.all(10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isSelected = _selectedReservaId == doc.id;
                    final cpfUser = data['cpf_user'] ?? '';

                    // FutureBuilder para pegar User (Tutor) e Pet
                    return FutureBuilder<List<DocumentSnapshot>>(
                      future: Future.wait([
                        _db
                            .collection('users')
                            .doc(cpfUser)
                            .get(), // Index 0: Tutor
                        _db
                            .collection('users')
                            .doc(cpfUser)
                            .collection('pets')
                            .doc(data['pet_id'])
                            .get(), // Index 1: Pet
                      ]),
                      builder: (c, s) {
                        if (!s.hasData)
                          return SizedBox(); // Carregando silencioso para não pular a tela

                        // Extrai dados
                        final userDoc = s.data![0];
                        final petDoc = s.data![1];

                        final nomeTutor = userDoc.exists
                            ? (userDoc.get('nome') ?? 'Desconhecido')
                            : 'Desconhecido';
                        final nomePet = petDoc.exists
                            ? (petDoc.get('nome') ?? 'Pet Removido')
                            : 'Pet Removido';
                        final tipoPet = petDoc.exists
                            ? (petDoc.data() as Map)['tipo']
                            : 'cao';

                        // --- FILTRO DE BUSCA (Visual) ---
                        // Se tiver texto de busca e NÃO bater com CPF nem Nome, esconde este item
                        if (_filtroTexto.isNotEmpty) {
                          bool matchCpf = cpfUser.toString().contains(
                            _filtroTexto,
                          );
                          bool matchNome =
                              nomeTutor.toLowerCase().contains(_filtroTexto) ||
                              nomePet.toLowerCase().contains(_filtroTexto);
                          if (!matchCpf && !matchNome) {
                            return SizedBox.shrink();
                          }
                        }

                        // Renderiza Item
                        return Container(
                          margin: EdgeInsets.only(
                            bottom: 8,
                          ), // Margem ao invés de separador
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _corAcai.withOpacity(0.05)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            selected: isSelected,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            leading: _buildStatusBadge(
                              data['status'] ?? 'reservado',
                            ),
                            title: Row(
                              children: [
                                FaIcon(
                                  tipoPet == 'gato'
                                      ? FontAwesomeIcons.cat
                                      : FontAwesomeIcons.dog,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  nomePet,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 5),
                                Text("•", style: TextStyle(color: Colors.grey)),
                                SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    "Tutor: $nomeTutor",
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              "${DateFormat('dd/MM').format((data['check_in'] as Timestamp).toDate())} até ${DateFormat('dd/MM').format((data['check_out'] as Timestamp).toDate())}",
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: isSelected ? _corAcai : Colors.grey[300],
                            ),
                            onTap: () {
                              setState(() {
                                _selectedReservaId = doc.id;
                                _selectedReservaData = data;
                              });
                            },
                          ),
                        );
                      },
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

  // --- PAINEL DE DETALHES FIXO (SEM SCROLL) ---
  Widget _buildPainelDetalhes() {
    final data = _selectedReservaData!;
    final docId = _selectedReservaId!;
    final status = data['status'] ?? 'reservado';
    final cpfUser = data['cpf_user'];
    final petId = data['pet_id'];

    return Container(
      margin: EdgeInsets.only(top: 20, right: 20, bottom: 20),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. CABEÇALHO COMPACTO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Reserva",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _corAcai,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                icon: Icon(Icons.close, size: 20, color: Colors.grey),
                onPressed: () => setState(() {
                  _selectedReservaId = null;
                  _selectedReservaData = null;
                }),
              ),
            ],
          ),
          Divider(height: 15),

          // 2. CONTEÚDO DISTRIBUÍDO (Expanded ocupa o resto da altura)
          Expanded(
            child: FutureBuilder<List<DocumentSnapshot>>(
              future: Future.wait([
                _db
                    .collection('users')
                    .doc(cpfUser)
                    .collection('pets')
                    .doc(petId)
                    .get(),
              ]),
              builder: (context, snapshot) {
                String tipoAnimalStr = "...";
                IconData iconeAnimal = FontAwesomeIcons.paw;

                if (snapshot.hasData && snapshot.data![0].exists) {
                  var petData = snapshot.data![0].data() as Map;
                  String tipo = petData['tipo'] ?? 'cao';
                  if (tipo == 'gato') {
                    tipoAnimalStr = "Gatinho";
                    iconeAnimal = FontAwesomeIcons.cat;
                  } else {
                    tipoAnimalStr = "Cãozinho";
                    iconeAnimal = FontAwesomeIcons.dog;
                  }
                }

                return Column(
                  children: [
                    // A. BADGE DO PET
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 15,
                      ),
                      decoration: BoxDecoration(
                        color: _corLilas,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(iconeAnimal, color: _corAcai, size: 14),
                          SizedBox(width: 8),
                          Text(
                            tipoAnimalStr,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _corAcai,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Spacer(flex: 2), // Espaço flexível
                    // B. TABELA DE DADOS (Compacta)
                    _buildCompactInfoRow(
                      "Status",
                      status.toString().toUpperCase(),
                      isBadge: true,
                      badgeColor: _getStatusColor(status),
                    ),
                    SizedBox(height: 8),
                    _buildCompactInfoRow(
                      "Check-in",
                      DateFormat(
                        'dd/MM/yy',
                      ).format((data['check_in'] as Timestamp).toDate()),
                    ),
                    SizedBox(height: 8),
                    _buildCompactInfoRow(
                      "Check-out",
                      DateFormat(
                        'dd/MM/yy',
                      ).format((data['check_out'] as Timestamp).toDate()),
                    ),

                    if (data['check_in_real'] != null) ...[
                      SizedBox(height: 8),
                      _buildCompactInfoRow(
                        "Entrada",
                        DateFormat(
                          'dd/MM HH:mm',
                        ).format((data['check_in_real'] as Timestamp).toDate()),
                        valueColor: Colors.green[700],
                      ),
                    ],

                    Spacer(flex: 3),

                    // C. CARD FINANCEIRO (Compacto)
                    Builder(
                      builder: (context) {
                        double valorPago = (data['valor_pago'] ?? 0).toDouble();
                        return Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.blue[100]!),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "JÁ PAGO",
                                    style: TextStyle(
                                      color: Colors.blue[900],
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "R\$ ${valorPago.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              if (status != 'concluido') ...[
                                SizedBox(height: 8),
                                SizedBox(
                                  height: 30, // Botão bem fininho
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: Colors.blue[300]!,
                                      ),
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    onPressed: () async {
                                      var res = await showDialog(
                                        context: context,
                                        builder: (c) =>
                                            RegistrarPagamentoDialog(
                                              reservaId: docId,
                                              nomePet: "o Pet",
                                            ),
                                      );
                                      if (res == true)
                                        setState(() {
                                          _refreshSelection(docId);
                                        });
                                    },
                                    child: Text(
                                      "REGISTRAR PAGAMENTO",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),

                    Spacer(flex: 3),

                    // D. BOTÃO DE AÇÃO PRINCIPAL
                    if (status == 'reservado')
                      _buildMainActionButton(
                        label: "CHECK-IN (ENTRADA)",
                        icon: Icons.login,
                        color: Colors.green,
                        onTap: () => _fazerCheckIn(docId),
                      ),

                    if (status == 'hospedado')
                      _buildMainActionButton(
                        label: "CHECK-OUT (SAÍDA)",
                        icon: FontAwesomeIcons.fileInvoiceDollar,
                        color: _corAcai,
                        onTap: () => _abrirCheckoutHotel(docId, data),
                      ),

                    if (status == 'concluido')
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            "FINALIZADO ✅",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES DO PAINEL ---

  Widget _buildCompactInfoRow(
    String label,
    String value, {
    bool isBadge = false,
    Color? badgeColor,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        isBadge
            ? Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor!.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: valueColor ?? Colors.black87,
                ),
              ),
      ],
    );
  }

  Widget _buildMainActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 4,
          shadowColor: color.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'reservado':
        return Colors.blue[700]!;
      case 'hospedado':
        return _corAcai;
      case 'concluido':
        return Colors.green[700]!;
      default:
        return Colors.grey;
    }
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    switch (status) {
      case 'reservado':
        color = Colors.blue;
        break;
      case 'hospedado':
        color = _corAcai;
        break;
      case 'concluido':
        color = Colors.green;
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
