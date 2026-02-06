import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'recibo_screen.dart'; // Certifique-se de que este arquivo existe

class MinhasAgendas extends StatefulWidget {
  final String userCpf;

  const MinhasAgendas({super.key, required this.userCpf});

  @override
  State<MinhasAgendas> createState() => _MinhasAgendasState();
}

class _MinhasAgendasState extends State<MinhasAgendas> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

  Map<String, Map<String, dynamic>> _petsCache = {};

  // Gerenciamento de Múltiplos Streams
  List<StreamSubscription> _subscriptions = [];
  List<DocumentSnapshot> _agendamentos = [];
  List<DocumentSnapshot> _reservasHotel = [];
  List<DocumentSnapshot> _reservasCreche = [];
  List<DocumentSnapshot> _allDocs = [];

  // Filtros
  String _filtroSelecionado = 'Todos';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarPets();
    _setupListeners();
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _carregarPets() async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(widget.userCpf)
          .collection('pets')
          .get();

      final Map<String, Map<String, dynamic>> pets = {};
      for (var doc in snapshot.docs) {
        pets[doc.id] = doc.data();
      }

      if (mounted) {
        setState(() {
          _petsCache = pets;
        });
      }
    } catch (e) {
      // Erro silencioso ou log
    }
  }

  void _setupListeners() {
    // 1. Agendamentos (Banho/Tosa)
    final subAgendamentos = _db
        .collection('tenants')
        .doc(AppConfig.tenantId)
        .collection('agendamentos')
        .where('userId', isEqualTo: widget.userCpf)
        .orderBy('data_inicio', descending: true)
        .snapshots()
        .listen((snapshot) {
      _agendamentos = snapshot.docs;
      _rebuildList();
    });
    _subscriptions.add(subAgendamentos);

    // 2. Hotel
    final subHotel = _db
        .collection('tenants')
        .doc(AppConfig.tenantId)
        .collection('reservas_hotel')
        .where('cpf_user', isEqualTo: widget.userCpf)
        // .orderBy('check_in', descending: true) // Removido para evitar erro de índice inexistente
        .snapshots()
        .listen(
      (snapshot) {
        _reservasHotel = snapshot.docs;
        _rebuildList();
      },
      onError: (e) => print("Erro stream Hotel: $e"),
    );
    _subscriptions.add(subHotel);

    // 3. Creche
    final subCreche = _db
        .collection('tenants')
        .doc(AppConfig.tenantId)
        .collection('reservas_creche')
        .where('cpf_user', isEqualTo: widget.userCpf)
        // .orderBy('check_in', descending: true) // Removido para evitar erro de índice inexistente
        .snapshots()
        .listen(
      (snapshot) {
        _reservasCreche = snapshot.docs;
        _rebuildList();
      },
      onError: (e) => print("Erro stream Creche: $e"),
    );
    _subscriptions.add(subCreche);
  }

  void _rebuildList() {
    final List<DocumentSnapshot> combined = [
      ..._agendamentos,
      ..._reservasHotel,
      ..._reservasCreche,
    ];

    // Ordenação unificada por data
    combined.sort((a, b) {
      final dateA = _getDate(a);
      final dateB = _getDate(b);
      return dateB.compareTo(dateA); // Descending (mais recente primeiro)
    });

    if (mounted) {
      setState(() {
        _allDocs = combined;
        _isLoading = false;
      });
    }
  }

  // --- Filtros ---
  List<DocumentSnapshot> get _listaFiltrada {
    if (_filtroSelecionado == 'Todos') {
      return _allDocs;
    }

    return _allDocs.where((doc) {
      final path = doc.reference.parent.id;
      if (_filtroSelecionado == 'Banho & Tosa') {
        return path == 'agendamentos';
      } else if (_filtroSelecionado == 'Hotel') {
        return path == 'reservas_hotel';
      } else if (_filtroSelecionado == 'Creche') {
        return path == 'reservas_creche';
      }
      return true;
    }).toList();
  }

  // --- Helpers de Unificação ---

  DateTime _getDate(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    if (data.containsKey('data_inicio')) {
      return (data['data_inicio'] as Timestamp).toDate();
    } else if (data.containsKey('check_in')) {
      return (data['check_in'] as Timestamp).toDate();
    }
    return DateTime.now(); // Fallback
  }

  String _getService(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Agendamentos normais
    if (data.containsKey('servicoNorm')) {
        return _capitalize(data['servicoNorm']);
    }
    if (data.containsKey('servico')) {
        return _capitalize(data['servico']);
    }

    // Identifica pela coleção
    final path = doc.reference.parent.id;
    if (path == 'reservas_hotel') return 'Hotel';
    if (path == 'reservas_creche') return 'Creche';

    return 'Serviço';
  }

  Map<String, List<DocumentSnapshot>> _groupAppointmentsByDate(
    List<DocumentSnapshot> docs,
  ) {
    final Map<String, List<DocumentSnapshot>> grouped = {};

    for (var doc in docs) {
      final date = _getDate(doc);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(Duration(days: 1));
      final itemDate = DateTime(date.year, date.month, date.day);

      String key;
      if (itemDate == today) {
        key = "Hoje";
      } else if (itemDate == tomorrow) {
        key = "Amanhã";
      } else {
        key = DateFormat('dd/MM - EEEE', 'pt_BR').format(date);
        key = key[0].toUpperCase() + key.substring(1);
      }

      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(doc);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Builder(
        builder: (context) {
          // --- ESTADO DE CARREGAMENTO ---
          if (_isLoading && _allDocs.isEmpty) {
            return Center(child: CircularProgressIndicator(color: _corAcai));
          }

          final filteredDocs = _listaFiltrada;
          final groupedDocs = _groupAppointmentsByDate(filteredDocs);

          // --- Custom Scroll View Principal ---
          return CustomScrollView(
            physics: BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),

              // Filtros
              _buildFilterBar(),

              // --- ESTADO DE VAZIO (Considerando Filtros) ---
              if (filteredDocs.isEmpty)
                 SliverFillRemaining(
                   hasScrollBody: false,
                   child: _buildEmptyState(isFilterEmpty: _allDocs.isNotEmpty),
                 )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final sectionKey = groupedDocs.keys.elementAt(index);
                      final sectionDocs = groupedDocs[sectionKey]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(sectionKey),
                          ...sectionDocs.map((doc) => _buildCardModerno(doc)),
                          SizedBox(height: 10),
                        ],
                      );
                    }, childCount: groupedDocs.keys.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ["Todos", "Banho & Tosa", "Hotel", "Creche"];

    return SliverToBoxAdapter(
      child: Container(
        height: 60,
        padding: EdgeInsets.symmetric(vertical: 10),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 20),
          itemCount: filters.length,
          separatorBuilder: (c, i) => SizedBox(width: 10),
          itemBuilder: (context, index) {
            final filter = filters[index];
            final isSelected = _filtroSelecionado == filter;

            return ChoiceChip(
              label: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (bool selected) {
                if (selected) {
                  setState(() {
                    _filtroSelecionado = filter;
                  });
                }
              },
              backgroundColor: Colors.white,
              selectedColor: _corAcai,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : Colors.grey[300]!,
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: isSelected ? 2 : 0,
              pressElevation: 0,
            );
          },
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: _corFundo,
      expandedHeight: 80.0,
      floating: true,
      pinned: false,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: 20, bottom: 10),
        title: Text(
          "Minhas Agendas",
          style: TextStyle(
            color: _corAcai,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      centerTitle: false,
      automaticallyImplyLeading:
          true,
      iconTheme: IconThemeData(color: _corAcai),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 10, left: 5),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: _corAcai.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // --- O NOVO DESIGN DO CARD ---
  Widget _buildCardModerno(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Tratamento de Dados
    final DateTime dataInicio = _getDate(doc);
    final String status = data['status'] ?? 'agendado';
    final String servico = _getService(doc);

    // Recupera dados do Pet do Cache
    final String? petId = data['pet_id'];
    final Map<String, dynamic>? petData = (petId != null)
        ? _petsCache[petId]
        : null;
    final String petName = petData?['nome'] ?? 'Seu Pet';
    final String petType = petData?['tipo'] ?? 'dog'; // default to dog icon

    // Configuração Visual baseada no Status
    Color corTema = Colors.grey;
    String textoStatus = "Agendado";
    IconData statusIcon = FontAwesomeIcons.calendarCheck;

    // --- Mapeamento de Status ---
    if (status == 'banhando') {
      corTema = Colors.blue;
      textoStatus = "No Banho";
      statusIcon = FontAwesomeIcons.shower;
    } else if (status == 'tosando') {
      corTema = Colors.orange;
      textoStatus = "Na Tosa";
      statusIcon = FontAwesomeIcons.scissors;
    } else if (status == 'pronto') {
      corTema = Colors.purple;
      textoStatus = "Pronto";
      statusIcon = FontAwesomeIcons.dog;
    } else if (status == 'concluido') {
      corTema = Colors.green;
      textoStatus = "Finalizado";
      statusIcon = FontAwesomeIcons.checkDouble;
    } else if (status == 'cancelado') {
      corTema = Colors.red;
      textoStatus = "Cancelado";
      statusIcon = FontAwesomeIcons.xmark;
    }
    // --- Status Hotel/Creche ---
    else if (status == 'reservado') {
      corTema = Colors.blueGrey;
      textoStatus = "Reservado";
      statusIcon = FontAwesomeIcons.calendarCheck;
    } else if (status == 'hospedado') {
      corTema = Colors.green;
      textoStatus = "Hospedado";
      statusIcon = FontAwesomeIcons.houseUser;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          // Recibo talvez precise de adaptação, mas mantemos o padrão por enquanto
          onTap: () => _abrirRecibo(context, data, doc),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 1. Coluna Hora (Estilo Timeline)
                Column(
                  children: [
                    Text(
                      DateFormat('HH:mm').format(dataInicio),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: corTema.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, size: 8, color: corTema),
                          SizedBox(width: 4),
                          Text(
                            textoStatus.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: corTema,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(width: 16),

                // Divisória Vertical
                Container(width: 1, height: 40, color: Colors.grey[200]),

                SizedBox(width: 16),

                // 2. Info Principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            petType == 'gato'
                                ? FontAwesomeIcons.cat
                                : FontAwesomeIcons.dog,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          SizedBox(width: 6),
                          Text(
                            petName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        servico,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // 3. Ícone de Ação
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _corFundo,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _abrirRecibo(
    BuildContext context,
    Map<String, dynamic> rawData,
    DocumentSnapshot doc,
  ) {
    // Cria uma cópia mutável dos dados para injetar campos faltantes se necessário
    final data = Map<String, dynamic>.from(rawData);

    // Normaliza Data (para o ReciboScreen que espera data_inicio como Timestamp)
    if (!data.containsKey('data_inicio')) {
      final date = _getDate(doc);
      data['data_inicio'] = Timestamp.fromDate(date);
    }

    // Normaliza Serviço
    if (!data.containsKey('servico')) {
      data['servico'] = _getService(doc);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReciboScreen(data: data, docId: doc.id),
      ),
    );
  }

  Widget _buildEmptyState({bool isFilterEmpty = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(35),
              decoration: BoxDecoration(
                color: _corAcai.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                FontAwesomeIcons.calendarXmark,
                size: 50,
                color: _corAcai.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: 24),
            Text(
              isFilterEmpty ? "Nenhum resultado" : "Nenhum agendamento",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              isFilterEmpty
                  ? "Não encontramos agendamentos para este filtro."
                  : "Seu pet está merecendo um cuidado especial. Que tal agendar algo agora?",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 32),
            if (!isFilterEmpty)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _corAcai,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Agendar Novo Horário",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return "";
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}
