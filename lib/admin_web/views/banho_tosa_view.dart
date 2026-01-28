import 'package:agenpet/admin_web/widgets/unified_checkout_dialog.dart';
import 'package:agenpet/admin_web/widgets/servicos_select_dialog.dart';
import 'package:agenpet/admin_web/views/components/novo_agendamento_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BanhosTosaView extends StatefulWidget {
  @override
  _BanhosTosaViewState createState() => _BanhosTosaViewState();
}

class _BanhosTosaViewState extends State<BanhosTosaView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  DateTime _dataFiltro = DateTime.now();
  String? _selectedAgendamentoId;
  String _termoBusca = "";
  final TextEditingController _searchController = TextEditingController();

  // Stream cacheado para evitar recargas desnecessárias
  late Stream<QuerySnapshot> _agendamentosStream;

  // --- PALETA DE CORES PREMIUM ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF5F7FA);
  final Color _corSucesso = Color(0xFF00C853);
  final Color _corAtencao = Color(0xFFFF6D00);
  final Color _corProcesso = Color(0xFF2962FF);

  @override
  void initState() {
    super.initState();
    _atualizarStream();
  }

  void _atualizarStream() {
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

    _agendamentosStream = _db
        .collection('agendamentos')
        .where(
          'data_inicio',
          isGreaterThanOrEqualTo: Timestamp.fromDate(inicio),
        )
        .where('data_inicio', isLessThanOrEqualTo: Timestamp.fromDate(fim))
        .orderBy('data_inicio')
        .snapshots();
  }

  // --- AÇÕES ---

  void _abrirWhatsApp(String telefone, String nomeCliente) async {
    String soNumeros = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!soNumeros.startsWith('55')) {
      soNumeros = '55$soNumeros';
    }

    final String mensagem = Uri.encodeComponent(
      "Olá $nomeCliente, tudo bem? Estamos entrando em contato sobre o agendamento na AgenPet.",
    );
    final Uri url = Uri.parse("https://wa.me/$soNumeros?text=$mensagem");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Não foi possível abrir o WhatsApp.")),
      );
    }
  }

  void _receberPet(DocumentSnapshot agendamentoDoc) async {
    final data = agendamentoDoc.data() as Map<String, dynamic>;
    final existingExtras = data['servicos_extras'] != null
        ? List<Map<String, dynamic>>.from(data['servicos_extras'])
        : <Map<String, dynamic>>[];

    final List<Map<String, dynamic>>? result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ServicosSelectDialog(initialSelected: existingExtras),
    );

    if (result != null) {
      await agendamentoDoc.reference.update({
        'status': 'aguardando_execucao',
        'servicos_extras': result,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Pet recebido! Enviado para execução. 🚀"),
          backgroundColor: _corSucesso,
        ),
      );
    }
  }

  // --- HELPERS ---
  String _capitalize(String? s) {
    if (s == null || s.isEmpty) return "";
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  void _abrirAgendamentoBalcao() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => NovoAgendamentoDialog(),
    );
  }

  void _abrirCheckout(DocumentSnapshot agendamentoDoc) async {
    final dataAgendamento = agendamentoDoc.data() as Map<String, dynamic>;
    final String userId = dataAgendamento['userId'];
    final bool isConcluido = dataAgendamento['status'] == 'concluido';
    final double valorBase = isConcluido
        ? (dataAgendamento['valor_final_cobrado'] ?? 0).toDouble()
        : (dataAgendamento['valor'] ?? 0).toDouble();

    final String servicoNome = _capitalize(
      dataAgendamento['servicoNorm'] ?? dataAgendamento['servico'] ?? '',
    );

    final userDoc = await _db.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};

    final extrasSnap = await _db
        .collection('servicos_extras')
        .where('ativo', isEqualTo: true)
        .get();

    try {
      final List<Map<String, dynamic>> listaExtras = extrasSnap.docs.map((e) {
        final data = e.data() as Map<String, dynamic>;
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
          contextType: CheckoutContext.agenda,
          referenceId: agendamentoDoc.id,
          clientData: userData,
          baseItem: {
            'nome': servicoNome,
            'preco': valorBase,
            'servicos_extras': dataAgendamento['servicos_extras'],
          },
          availableServices: listaExtras,
          totalAlreadyPaid: 0, // Agenda typically pays at checkout
          vouchersConsumedHistory: dataAgendamento['vouchers_consumidos'],
          themeColor: _corAcai,
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Caixa Atualizado com Sucesso! 💰"),
                backgroundColor: _corSucesso,
                behavior: SnackBarBehavior.floating,
                width: 300,
              ),
            );
          },
        ),
      );
    } catch (e) {
      print("Erro ao abrir checkout: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao carregar dados do checkout: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                    Icon(
                      Icons.calendar_view_week_rounded,
                      color: _corAcai,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Agenda Diária",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat(
                            "EEEE, d MMM",
                            'pt_BR',
                          ).format(_dataFiltro).toUpperCase(),
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
                Row(
                  children: [
                    _buildHeaderButton(
                      Icons.add,
                      "Novo",
                      _corAcai,
                      Colors.white,
                      _abrirAgendamentoBalcao,
                    ),
                    SizedBox(width: 5),
                    IconButton(
                      icon: Icon(
                        Icons.calendar_month,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _dataFiltro,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) {
                          setState(() {
                            _dataFiltro = d;
                            _selectedAgendamentoId = null;
                            _atualizarStream();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // CORPO
          Expanded(
            child: Row(
              children: [
                // COLUNA DA ESQUERDA (BUSCA + LISTA)
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
                        // --- CAMPO DE BUSCA ---
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _termoBusca = val.toLowerCase();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: "Buscar cliente ou pet...",
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

                        // --- LISTA DE AGENDAMENTOS ---
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _agendamentosStream,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData)
                                return Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );

                              List<DocumentSnapshot> docs = snapshot.data!.docs;

                              if (docs.isEmpty) return _buildEmptyState();

                              // Seleção Automática Inteligente
                              if (_selectedAgendamentoId == null ||
                                  !docs.any(
                                    (d) => d.id == _selectedAgendamentoId,
                                  )) {
                                if (docs.isNotEmpty) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted &&
                                        _selectedAgendamentoId == null) {
                                      setState(() {
                                        _selectedAgendamentoId = docs.first.id;
                                      });
                                    }
                                  });
                                }
                              }

                              // ListView.builder para suportar itens ocultos na busca
                              return ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                itemCount: docs.length,
                                itemBuilder: (context, index) =>
                                    _buildAgendamentoItem(docs[index]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // PAINEL DE DETALHES (DASHBOARD)
                Expanded(
                  flex: 70,
                  child: _selectedAgendamentoId == null
                      ? _buildPlaceholder()
                      : StreamBuilder<DocumentSnapshot>(
                          key: ValueKey(_selectedAgendamentoId),
                          stream: _db
                              .collection('agendamentos')
                              .doc(_selectedAgendamentoId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || !snapshot.data!.exists)
                              return Center(child: CircularProgressIndicator());
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

  // --- ITEM DA LISTA LATERAL (COM BUSCA FETCHED) ---
  Widget _buildAgendamentoItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isSelected = _selectedAgendamentoId == doc.id;
    final hora = (data['data_inicio'] as Timestamp).toDate();
    final status = data['status'] ?? 'agendado';

    Color corStatus = Colors.grey;
    if (status == 'banhando' || status == 'tosando') corStatus = _corProcesso;
    if (status == 'pronto') corStatus = _corAtencao;
    if (status == 'concluido') corStatus = _corSucesso;

    // FutureBuilder para buscar nomes e aplicar filtro visual
    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait([
        _db.collection('users').doc(data['userId']).get(),
        _db
            .collection('users')
            .doc(data['userId'])
            .collection('pets')
            .doc(data['pet_id'])
            .get(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) return SizedBox(); // Placeholder silencioso

        String tutor = snap.data![0].exists
            ? (snap.data![0]['nome'] ?? 'Tutor').split(' ')[0]
            : 'Tutor';
        String pet = snap.data![1].exists
            ? snap.data![1]['nome'] ?? 'Pet'
            : 'Pet';

        // LÓGICA DE FILTRO: Se tem busca e não bate com nada, esconde
        if (_termoBusca.isNotEmpty) {
          bool matchNome = tutor.toLowerCase().contains(_termoBusca);
          bool matchPet = pet.toLowerCase().contains(_termoBusca);
          bool matchServico = (data['servico'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_termoBusca);

          if (!matchNome && !matchPet && !matchServico) {
            return SizedBox.shrink(); // Oculta visualmente
          }
        }

        return GestureDetector(
          onTap: () {
            if (_selectedAgendamentoId != doc.id) {
              setState(() => _selectedAgendamentoId = doc.id);
            }
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            margin: EdgeInsets.only(bottom: 8),
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
                      DateFormat('HH:mm').format(hora),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (status == 'pronto')
                      Icon(
                        Icons.notifications_active,
                        size: 14,
                        color: _corAtencao,
                      ),
                    if (status == 'concluido')
                      Icon(Icons.check_circle, size: 14, color: _corSucesso),
                  ],
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _capitalize(data['servicoNorm'] ?? data['servico']),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        "$pet ($tutor)",
                        style: TextStyle(color: Colors.grey[700], fontSize: 11),
                        overflow: TextOverflow.ellipsis,
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

  // --- PAINEL DIREITO (COM WHATSAPP) ---
  Widget _buildPainelDetalhesCompacto(DocumentSnapshot agendamentoDoc) {
    final data = agendamentoDoc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'agendado';
    final bool isPronto = status == 'pronto';
    final bool isConcluido = status == 'concluido';

    Color corStatus = Colors.grey;
    String textoStatus = "Aguardando";
    IconData iconeStatus = Icons.schedule;

    if (status == 'aguardando_execucao') {
      corStatus = Colors.blue;
      textoStatus = "Aguardando Execução";
      iconeStatus = Icons.hourglass_top;
    }
    if (status == 'checklist_pendente') {
      corStatus = Colors.orange;
      textoStatus = "Em Checklist";
      iconeStatus = Icons.playlist_add_check;
    }
    if (status == 'banhando') {
      corStatus = _corProcesso;
      textoStatus = "Em Banho";
      iconeStatus = FontAwesomeIcons.shower;
    }
    if (status == 'tosando') {
      corStatus = Colors.orange;
      textoStatus = "Em Tosa";
      iconeStatus = FontAwesomeIcons.scissors;
    }
    if (status == 'pronto') {
      corStatus = _corAtencao;
      textoStatus = "Pronto / Aguardando Dono";
      iconeStatus = Icons.notifications_active;
    }
    if (status == 'concluido') {
      corStatus = _corSucesso;
      textoStatus = "Finalizado";
      iconeStatus = Icons.check_circle;
    }

    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TIMELINE
          SizedBox(height: 40, child: _buildTimelineCompleta(status)),

          SizedBox(height: 15),

          // 2. DASHBOARD (LADO A LADO)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // CARD CLIENTE
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
                        _db.collection('users').doc(data['userId']).get(),
                        _db
                            .collection('users')
                            .doc(data['userId'])
                            .collection('pets')
                            .doc(data['pet_id'])
                            .get(),
                      ]),
                      builder: (context, snap) {
                        String cliente = "Carregando...";
                        String pet = "...";
                        String celular = "";

                        if (snap.hasData) {
                          if (snap.data![0].exists) {
                            var uData = snap.data![0].data() as Map;
                            cliente = uData['nome'] ?? 'Cliente';
                            celular =
                                uData['celular'] ?? uData['telefone'] ?? '';
                          }
                          pet = snap.data![1].exists
                              ? snap.data![1]['nome']
                              : "Pet Removido";
                        }

                        return Column(
                          children: [
                            Text(
                              "CLIENTE & PET",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1,
                              ),
                            ),
                            Spacer(),
                            Center(
                              child: CircleAvatar(
                                radius: 35,
                                backgroundColor: _corLilas,
                                child: Icon(
                                  FontAwesomeIcons.dog,
                                  size: 30,
                                  color: _corAcai,
                                ),
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              pet,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              cliente,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            Spacer(),

                            // BOTÃO WHATSAPP
                            if (celular.isNotEmpty)
                              InkWell(
                                onTap: () => _abrirWhatsApp(celular, cliente),
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

                // CARD FINANCEIRO
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
                          "RESUMO FINANCEIRO",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: 10),
                        _row(
                          "Serviço Base",
                          _capitalize(data['servico']),
                          isBold: true,
                        ),
                        _row(
                          "Profissional",
                          data['profissional_nome'] ?? '-',
                          fontSize: 11,
                        ),
                        Divider(),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                if (data['extras'] != null)
                                  ...(data['extras'] as List)
                                      .map(
                                        (e) => _row(
                                          "+ ${e['nome']}",
                                          "R\$ ${e['preco']}",
                                          color: _corAtencao,
                                          fontSize: 12,
                                        ),
                                      )
                                      .toList(),
                                if (data['servicos_extras'] != null)
                                  ...(data['servicos_extras'] as List)
                                      .map(
                                        (e) => _row(
                                          "+ ${e['nome']}",
                                          "R\$ ${e['preco']}",
                                          color: _corAtencao,
                                          fontSize: 12,
                                        ),
                                      )
                                      .toList(),
                                if ((data['extras'] == null ||
                                        (data['extras'] as List).isEmpty) &&
                                    (data['servicos_extras'] == null ||
                                        (data['servicos_extras'] as List)
                                            .isEmpty))
                                  Padding(
                                    padding: EdgeInsets.only(top: 10),
                                    child: Text(
                                      "- Sem extras -",
                                      style: TextStyle(
                                        color: Colors.grey[300],
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "TOTAL",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              "R\$ ${(isConcluido ? data['valor_final_cobrado'] : data['valor'])?.toStringAsFixed(2) ?? '0.00'}",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: _corAcai,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 15),

          // 3. BARRA DE STATUS
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
                if (isPronto)
                  ElevatedButton.icon(
                    icon: Icon(Icons.point_of_sale, size: 18),
                    label: Text(
                      "CHECKOUT",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _corSucesso,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => _abrirCheckout(agendamentoDoc),
                  )
                else if (status == 'agendado' ||
                    status == 'aguardando_pagamento')
                  ElevatedButton.icon(
                    icon: Icon(FontAwesomeIcons.dog, size: 18),
                    label: Text(
                      "RECEBER PET",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => _receberPet(agendamentoDoc),
                  )
                else if (isConcluido)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check, size: 16, color: _corSucesso),
                        SizedBox(width: 5),
                        Text(
                          "Pago",
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

  // --- WIDGETS AUXILIARES (TIMELINE, ETC) ---
  Widget _buildTimelineCompleta(String status) {
    int step = 1;
    if (status == 'banhando') step = 2;
    if (status == 'tosando') step = 3;
    if (status == 'pronto') step = 4;
    if (status == 'concluido') step = 5;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _stepWidget(1, "Agend.", step, Icons.calendar_today),
        _lineWidget(step > 1),
        _stepWidget(2, "Banho", step, FontAwesomeIcons.shower),
        _lineWidget(step > 2),
        _stepWidget(3, "Tosa", step, FontAwesomeIcons.scissors),
        _lineWidget(step > 3),
        _stepWidget(4, "Pronto", step, FontAwesomeIcons.dog),
        _lineWidget(step > 4),
        _stepWidget(5, "Fim", step, Icons.check_circle),
      ],
    );
  }

  Widget _stepWidget(int index, String label, int currentStep, IconData icon) {
    bool isActive = index == currentStep;
    Color color = isActive
        ? _corAtencao
        : (index < currentStep ? _corSucesso : Colors.grey[300]!);
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

  Widget _lineWidget(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? _corSucesso : Colors.grey[200],
      ),
    );
  }

  Widget _row(
    String k,
    String v, {
    bool isBold = false,
    Color? color,
    double fontSize = 12,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            k,
            style: TextStyle(color: Colors.grey[700], fontSize: fontSize),
          ),
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

  Widget _buildHeaderButton(
    IconData icon,
    String label,
    Color bg,
    Color fg,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 14),
      label: Text(label, style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        minimumSize: Size(0, 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: onTap,
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        "Carregando...",
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        "Nenhum agendamento",
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
    );
  }
}
