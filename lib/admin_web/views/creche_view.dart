import 'package:agenpet/admin_web/widgets/unified_checkout_dialog.dart';
import 'package:agenpet/admin_web/views/components/nova_reserva_creche_dialog.dart';
import 'package:agenpet/admin_web/views/components/registrar_pagamento_creche_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CrecheView extends StatefulWidget {
  const CrecheView({super.key});

  @override
  _CrecheViewState createState() => _CrecheViewState();
}

class _CrecheViewState extends State<CrecheView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Cores
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF5F7FA);
  final Color _corSucesso = Color(0xFF00C853);
  final Color _corAtencao = Color(0xFFFF6D00);
  final Color _corProcesso = Color(0xFF2962FF);

  // Controle
  String? _selectedReservaId;
  double _precoDiariaCache = 0.0;

  // Busca
  final TextEditingController _searchController = TextEditingController();
  String _termoBusca = "";

  @override
  void initState() {
    super.initState();
    _carregarPrecoDiaria();
  }

  void _carregarPrecoDiaria() async {
    final doc = await _db.collection('config').doc('parametros').get();
    if (doc.exists) {
      setState(() {
        _precoDiariaCache = (doc.data()?['preco_creche'] ?? 0).toDouble();
      });
    }
  }

  // --- AÇÕES ---

  void _abrirWhatsApp(String telefone, String nomeCliente) async {
    String soNumeros = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!soNumeros.startsWith('55')) soNumeros = '55$soNumeros';
    final String mensagem = Uri.encodeComponent(
      "Olá $nomeCliente, tudo bem? Estamos entrando em contato sobre a Creche AgenPet.",
    );
    final Uri url = Uri.parse("https://wa.me/$soNumeros?text=$mensagem");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao abrir WhatsApp")));
    }
  }

  void _fazerCheckIn(String docId) async {
    await _db.collection('reservas_creche').doc(docId).update({
      'status':
          'na creche', // Mantemos 'na creche' ou usamos 'presente' - para consistência com Hotel, manterei 'na creche'
      'check_in_real': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Check-in realizado! 🎒"),
        backgroundColor: _corSucesso,
      ),
    );
  }

  void _abrirCheckoutCreche(String docId, Map<String, dynamic> data) async {
    // 1. Calculate Base Price
    final checkIn = data['check_in_real'] != null
        ? (data['check_in_real'] as Timestamp).toDate()
        : (data['check_in'] as Timestamp).toDate();
    final checkOut = DateTime.now();
    int dias = checkOut.difference(checkIn).inDays;
    if (dias < 1) dias = 1;
    double totalEstadia = dias * _precoDiariaCache;

    // 2. Fetch User Data
    Map<String, dynamic> clientData = {};
    if (data['cpf_user'] != null) {
      final userDoc = await _db.collection('users').doc(data['cpf_user']).get();
      if (userDoc.exists) clientData = userDoc.data()!;
    }

    // 3. Fetch Extras
    final extrasSnap = await _db
        .collection('servicos_extras')
        .where('ativo', isEqualTo: true)
        .get();

    final List<Map<String, dynamic>> listaExtras = extrasSnap.docs.map((e) {
      final data = e.data();
      return {
        'id': e.id,
        'nome': data['nome'],
        'preco': (data['preco'] ?? 0).toDouble(),
        'porte': data['porte'],
        'pelagem': data['pelagem'],
      };
    }).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UnifiedCheckoutDialog(
        contextType: CheckoutContext.creche,
        referenceId: docId,
        clientData: clientData,
        baseItem: {'nome': "Creche ($dias dias)", 'preco': totalEstadia},
        availableServices: listaExtras,
        totalAlreadyPaid: (data['valor_pago'] ?? 0).toDouble(),
        themeColor: _corAcai,
        onSuccess: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Diária finalizada! 🏠"),
            backgroundColor: _corSucesso,
          ),
        ),
      ),
    );
  }

  void _novaHospedagemManual() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => NovaReservaCrecheDialog(),
    );
  }

  void _registrarPagamentoParcial(String docId) async {
    await showDialog(
      context: context,
      builder: (c) =>
          RegistrarPagamentoCrecheDialog(reservaId: docId, nomePet: "Aluno"),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Column(
        children: [
          // HEADER
          Container(
            height: 60,
            padding: EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(FontAwesomeIcons.school, color: _corAcai, size: 24),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Gestão de Creche",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Check-ins e Diárias",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.add, size: 16),
                  label: Text("Nova Reserva"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _corAcai,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _novaHospedagemManual,
                ),
              ],
            ),
          ),

          // CORPO
          Expanded(
            child: Row(
              children: [
                // LISTA LATERAL
                Expanded(
                  flex: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        right: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) =>
                                setState(() => _termoBusca = val.toLowerCase()),
                            decoration: InputDecoration(
                              hintText: "Buscar por Nome, Pet ou CPF...",
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey[400],
                              ),
                              filled: true,
                              fillColor: _corFundo,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 0,
                                horizontal: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _db
                                .collection('reservas_creche')
                                .orderBy('check_in', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              }

                              List<DocumentSnapshot> docs = snapshot.data!.docs;

                              if (docs.isEmpty) {
                                return Center(
                                  child: Text(
                                    "Nenhuma reserva encontrada",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                );
                              }

                              // Seleção Automática (apenas se nenhum estiver selecionado e a lista não for vazia)
                              if (_selectedReservaId == null &&
                                  docs.isNotEmpty) {
                                // Pequeno delay para evitar erro de build
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted && _selectedReservaId == null) {
                                    setState(
                                      () => _selectedReservaId = docs.first.id,
                                    );
                                  }
                                });
                              }

                              // Mudei para ListView.builder para gerenciar melhor os itens escondidos
                              return ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                itemCount: docs.length,
                                itemBuilder: (context, index) =>
                                    _buildReservaItem(docs[index]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // PAINEL DE DETALHES
                Expanded(
                  flex: 70,
                  child: _selectedReservaId == null
                      ? Center(
                          child: Text(
                            "Selecione uma reserva",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : StreamBuilder<DocumentSnapshot>(
                          key: ValueKey(_selectedReservaId),
                          stream: _db
                              .collection('reservas_creche')
                              .doc(_selectedReservaId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || !snapshot.data!.exists) {
                              return Center(child: CircularProgressIndicator());
                            }
                            return _buildPainelDetalhesCompacto(snapshot.data!);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ITEM DA LISTA LATERAL COM FILTRO DE BUSCA ---
  Widget _buildReservaItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isSelected = _selectedReservaId == doc.id;
    final status = data['status'] ?? 'reservado';
    final cpfUser = data['cpf_user'] ?? '';

    Color corStatus = Colors.grey;
    if (status == 'reservado') corStatus = Colors.blue;
    if (status == 'na creche') corStatus = _corAcai;
    if (status == 'concluido') corStatus = _corSucesso;

    // FutureBuilder Interno para filtrar visualmente
    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait([
        _db.collection('users').doc(cpfUser).get(),
        _db
            .collection('users')
            .doc(cpfUser)
            .collection('pets')
            .doc(data['pet_id'])
            .get(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return SizedBox(); // Carregando (invisível para não piscar)
        }

        String tutor = snap.data![0].exists
            ? (snap.data![0]['nome'] ?? 'Tutor')
            : 'Tutor';
        String pet = snap.data![1].exists
            ? snap.data![1]['nome'] ?? 'Pet'
            : 'Pet';

        // LÓGICA DE FILTRO: Se tem busca e não bate com nada, retorna Container vazio (tamanho 0)
        if (_termoBusca.isNotEmpty) {
          bool matchNome = tutor.toLowerCase().contains(_termoBusca);
          bool matchPet = pet.toLowerCase().contains(_termoBusca);
          bool matchCpf = cpfUser.toString().contains(_termoBusca);

          if (!matchNome && !matchPet && !matchCpf) {
            return SizedBox.shrink(); // Some da lista visualmente
          }
        }

        // Se passou no filtro, desenha o item
        return GestureDetector(
          onTap: () => setState(() => _selectedReservaId = doc.id),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            margin: EdgeInsets.only(
              bottom: 8,
            ), // Margem aqui pois não usamos mais separator
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? _corLilas : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? _corAcai : Colors.transparent,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: [
                if (!isSelected)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 35,
                  decoration: BoxDecoration(
                    color: corStatus,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 8),
                Column(
                  children: [
                    Text(
                      DateFormat(
                        'dd/MM',
                      ).format((data['check_in'] as Timestamp).toDate()),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Icon(
                      status == 'na creche'
                          ? FontAwesomeIcons.dog
                          : Icons.calendar_today,
                      size: 14,
                      color: corStatus,
                    ),
                  ],
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$pet ($tutor)",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: corStatus,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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
    );
  }

  // --- PAINEL DIREITO ---
  Widget _buildPainelDetalhesCompacto(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'reservado';

    Color corStatus = Colors.blue;
    String textoStatus = "Reserva Confirmada";
    IconData iconeStatus = Icons.calendar_today;

    if (status == 'na creche') {
      corStatus = _corAcai;
      textoStatus = "Presente na Creche";
      iconeStatus = FontAwesomeIcons.dog;
    }
    if (status == 'concluido') {
      corStatus = _corSucesso;
      textoStatus = "Diária Finalizada";
      iconeStatus = Icons.check_circle;
    }

    final checkIn = (data['check_in'] as Timestamp).toDate();
    final checkOut = (data['check_out'] as Timestamp).toDate();
    final dias = checkOut.difference(checkIn).inDays;

    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TIMELINE
          SizedBox(height: 40, child: _buildTimelineCreche(status)),
          SizedBox(height: 15),

          // 2. DASHBOARD
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // CARD 1: ALUNO
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: FutureBuilder<List<DocumentSnapshot>>(
                      future: Future.wait([
                        _db.collection('users').doc(data['cpf_user']).get(),
                        _db
                            .collection('users')
                            .doc(data['cpf_user'])
                            .collection('pets')
                            .doc(data['pet_id'])
                            .get(),
                      ]),
                      builder: (context, snap) {
                        String tutor = "Carregando...";
                        String pet = "...";
                        String raca = "-";
                        String celular = "";
                        IconData iconPet = FontAwesomeIcons.paw;

                        if (snap.hasData) {
                          if (snap.data![0].exists) {
                            var uData = snap.data![0].data() as Map;
                            tutor = uData['nome'] ?? 'Tutor';
                            celular =
                                uData['celular'] ?? uData['telefone'] ?? '';
                          }
                          if (snap.data![1].exists) {
                            var pData = snap.data![1].data() as Map;
                            pet = pData['nome'];
                            raca = pData['raca'] ?? '';
                            if (pData['tipo'] == 'gato') {
                              iconPet = FontAwesomeIcons.cat;
                            }
                            if (pData['tipo'] == 'cao') {
                              iconPet = FontAwesomeIcons.dog;
                            }
                          }
                        }

                        return Column(
                          children: [
                            Text(
                              "ALUNO & TUTOR",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1,
                              ),
                            ),
                            Spacer(),
                            CircleAvatar(
                              radius: 35,
                              backgroundColor: _corLilas,
                              child: Icon(iconPet, size: 30, color: _corAcai),
                            ),
                            SizedBox(height: 10),
                            Text(
                              pet,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "$raca • $tutor",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Spacer(),

                            if (celular.isNotEmpty)
                              InkWell(
                                onTap: () => _abrirWhatsApp(celular, tutor),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.green.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        FontAwesomeIcons.whatsapp,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        celular,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "Sem número",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: 15),

                // CARD 2: ESTADIA
                Expanded(
                  flex: 6,
                  child: Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "RESUMO DA CRECHE",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _dateBox("Check-in", checkIn),
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: Colors.grey[300],
                            ),
                            _dateBox("Check-out", checkOut),
                          ],
                        ),
                        SizedBox(height: 10),
                        Center(
                          child: Text(
                            "$dias Diárias",
                            style: TextStyle(
                              color: _corAcai,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Divider(),
                        _row(
                          "Valor Diária",
                          "R\$ ${_precoDiariaCache.toStringAsFixed(2)}",
                        ),
                        _row(
                          "Total Pago",
                          "R\$ ${(data['valor_pago'] ?? 0).toStringAsFixed(2)}",
                          color: Colors.green,
                        ),
                        Spacer(),
                        if (status != 'concluido')
                          SizedBox(
                            width: double.infinity,
                            height: 35,
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.attach_money, size: 16),
                              label: Text("Registrar Pagamento"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green,
                                side: BorderSide(color: Colors.green),
                              ),
                              onPressed: () =>
                                  _registrarPagamentoParcial(doc.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 15),

          // 3. STATUS E AÇÃO
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: corStatus.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: corStatus.withOpacity(0.3)),
            ),
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children: [
                Icon(iconeStatus, color: corStatus, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "STATUS ATUAL",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: corStatus,
                        ),
                      ),
                      Text(
                        textoStatus,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status == 'reservado')
                  ElevatedButton.icon(
                    icon: Icon(Icons.login, size: 18),
                    label: Text("REALIZAR CHECK-IN"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => _fazerCheckIn(doc.id),
                  ),
                if (status == 'na creche')
                  ElevatedButton.icon(
                    icon: Icon(FontAwesomeIcons.fileInvoiceDollar, size: 18),
                    label: Text("CHECK-OUT E PAGAR"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _corAcai,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => _abrirCheckoutCreche(doc.id, data),
                  ),
                if (status == 'concluido')
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: _corSucesso),
                        SizedBox(width: 5),
                        Text(
                          "Finalizado",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _corSucesso,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---
  Widget _buildTimelineCreche(String status) {
    int step = 1;
    if (status == 'na creche') step = 2;
    if (status == 'concluido') step = 3;

    return Row(
      children: [
        _stepWidget(1, "Reserva", step, Icons.calendar_today),
        _lineWidget(step > 1),
        _stepWidget(2, "Na Creche", step, FontAwesomeIcons.dog),
        _lineWidget(step > 2),
        _stepWidget(3, "Finalizado", step, Icons.check_circle),
      ],
    );
  }

  Widget _stepWidget(int index, String label, int currentStep, IconData icon) {
    bool isActive = index == currentStep;
    bool isPast = index < currentStep;
    Color color = isActive
        ? _corAtencao
        : (isPast ? _corSucesso : Colors.grey[300]!);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: color,
          child: Icon(icon, size: 10, color: Colors.white),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _lineWidget(bool isActive) => Expanded(
    child: Container(
      height: 2,
      color: isActive ? _corSucesso : Colors.grey[200],
    ),
  );

  Widget _dateBox(String label, DateTime date) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          DateFormat('dd/MM').format(date),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          DateFormat('HH:mm').format(date),
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _row(String k, String v, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          Text(
            v,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
