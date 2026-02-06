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

  // Helper para identificar o tipo (para badge)
  String _getServiceType(DocumentSnapshot doc) {
    final path = doc.reference.parent.id;
    if (path == 'reservas_hotel') return 'HOTEL';
    if (path == 'reservas_creche') return 'CRECHE';
    return 'BANHO & TOSA';
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
        height: 70, // Altura um pouco maior para acomodar melhor
        padding: EdgeInsets.symmetric(vertical: 15),
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
                  color: isSelected ? Colors.white : _corAcai,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
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
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : _corAcai.withOpacity(0.2),
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              elevation: isSelected ? 4 : 0,
              pressElevation: 2,
            );
          },
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: _corAcai,
      expandedHeight: 120.0,
      floating: true,
      pinned: true, // Fixado para melhor UX
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: 20, bottom: 16),
        centerTitle: false,
        title: Text(
          "Minhas Agendas",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _corAcai,
                Color(0xFF6A1B9A), // Um tom mais claro
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  FontAwesomeIcons.paw,
                  size: 150,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ],
          ),
        ),
      ),
      automaticallyImplyLeading: true,
      iconTheme: IconThemeData(color: Colors.white),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12, left: 5),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _corAcai,
          letterSpacing: 0.5,
        ),
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
    final String serviceType = _getServiceType(doc); // "HOTEL", "CRECHE", "BANHO"

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
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _corAcai.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _abrirRecibo(context, data, doc),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // 1. Coluna Hora (Estilo Timeline Clean)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(dataInicio),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                     Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: corTema.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, size: 18, color: corTema),
                    ),
                  ],
                ),

                SizedBox(width: 20),

                // 2. Info Principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Badge do Tipo
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _corAcai.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _corAcai.withOpacity(0.1)),
                            ),
                            child: Text(
                              serviceType,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _corAcai,
                              ),
                            ),
                          ),
                          // Status Texto
                          Text(
                            textoStatus.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: corTema,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            petType == 'gato'
                                ? FontAwesomeIcons.cat
                                : FontAwesomeIcons.dog,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                          SizedBox(width: 6),
                          Text(
                            petName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 10),

                // 3. Ícone de Ação
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey[300],
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
                size: 60,
                color: _corAcai.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: 30),
            Text(
              isFilterEmpty ? "Nenhum resultado" : "Nenhum agendamento",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              isFilterEmpty
                  ? "Não encontramos agendamentos para este filtro.\nTente selecionar outra categoria."
                  : "Seu pet está merecendo um cuidado especial.\nQue tal agendar algo agora?",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
                height: 1.5,
              ),
            ),
            SizedBox(height: 40),
            if (!isFilterEmpty)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _corAcai,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: _corAcai.withOpacity(0.4),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "AGENDAR NOVO HORÁRIO",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.0,
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
