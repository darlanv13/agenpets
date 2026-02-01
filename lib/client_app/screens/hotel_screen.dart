import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/firebase_service.dart';

class HotelScreen extends StatefulWidget {
  const HotelScreen({super.key});

  @override
  _HotelScreenState createState() => _HotelScreenState();
}

class _HotelScreenState extends State<HotelScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final _firebaseService = FirebaseService();

  // --- CORES DA MARCA ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF8F9FC);

  // CONFIGURAÇÃO DE PREÇO
  double _valorDiaria = 0.0;

  String? _userCpf;
  String? _petId;

  // Controle do Calendário (Range)
  DateTime _focusedDay = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOn;

  Set<DateTime> _diasLotados = {};

  bool _isLoading = false;
  List<Map<String, dynamic>> _pets = [];

  @override
  void initState() {
    super.initState();
    _carregarPrecoHotel();
    _carregarDisponibilidade();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null && _userCpf == null) {
      _userCpf = args['cpf'];
      _carregarPets();
    }
  }

  Future<void> _carregarPets() async {
    final snapshot = await _db
        .collection('users')
        .doc(_userCpf)
        .collection('pets')
        .get();
    setState(() {
      _pets = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (_pets.isNotEmpty && _petId == null) _petId = _pets.first['id'];
    });
  }

  Future<void> _carregarDisponibilidade() async {
    final datas = await _firebaseService.buscarDiasLotadosHotel();
    if (mounted) {
      setState(() {
        _diasLotados = datas
            .map((d) => DateTime(d.year, d.month, d.day))
            .toSet();
      });
    }
  }

  Future<void> _carregarPrecoHotel() async {
    try {
      final doc = await _db.collection('config').doc('parametros').get();
      if (doc.exists) {
        setState(() {
          _valorDiaria = (doc.data()!['preco_hotel_diaria'] ?? 80.00)
              .toDouble();
        });
      }
    } catch (e) {
      setState(() => _valorDiaria = 80.00);
    }
  }

  // --- AÇÕES ---

  bool _isDayLotado(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return _diasLotados.contains(normalized);
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      _rangeStart = start;
      _rangeEnd = end;
      _rangeSelectionMode = RangeSelectionMode.toggledOn;
    });

    // Validação: Intervalo não pode conter dias lotados no meio
    if (start != null && end != null) {
      bool intervaloInvalido = false;
      int diasNoIntervalo = end.difference(start).inDays;

      for (int i = 0; i <= diasNoIntervalo; i++) {
        DateTime diaVerificado = start.add(Duration(days: i));
        if (_isDayLotado(diaVerificado)) {
          intervaloInvalido = true;
          break;
        }
      }

      if (intervaloInvalido) {
        _mostrarErroDialog(
          "O período selecionado contém dias sem vaga.\nPor favor, escolha outras datas.",
        );
        setState(() {
          _rangeStart = null;
          _rangeEnd = null;
        });
      }
    }
  }

  Future<void> _fazerReserva() async {
    if (_petId == null || _rangeStart == null) return;

    // Se só selecionou um dia (start == end ou end == null), define end = start
    DateTime checkIn = _rangeStart!;
    DateTime checkOut = _rangeEnd ?? _rangeStart!;

    setState(() => _isLoading = true);

    try {
      await _firebaseService.reservarHotel(
        petId: _petId!,
        cpfUser: _userCpf!,
        checkIn: checkIn,
        checkOut: checkOut,
      );

      _mostrarSucessoDialog();
    } catch (e) {
      String msg = e.toString();
      if (msg.contains("message:")) msg = msg.split("message:").last.trim();
      _mostrarErroDialog("Falha ao reservar: $msg");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- DIALOGS ---

  void _mostrarSucessoDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: Colors.green, size: 60),
            ),
            SizedBox(height: 20),
            Text(
              "Reserva Solicitada!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Aguarde a confirmação da nossa equipe.\nCuidaremos muito bem do seu pet! 🐶",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text(
                  "OK, VOLTAR",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarErroDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 10),
            Text("Atenção"),
          ],
        ),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("OK")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cálculo do total
    int dias = 0;
    double total = 0.0;

    if (_rangeStart != null) {
      if (_rangeEnd != null) {
        dias = _rangeEnd!.difference(_rangeStart!).inDays;
      }
      // Pelo menos 1 dia se selecionou start (mesmo que start==end)
      if (dias == 0) dias = 1;
      total = dias * _valorDiaria;
    }

    return Scaffold(
      backgroundColor: _corFundo,
      appBar: AppBar(
        title: Text(
          "Reservar Hotel",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: _corAcai,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading && _pets.isEmpty
          ? Center(child: CircularProgressIndicator(color: _corAcai))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. SELEÇÃO DE PET (HEADER CUSTOMIZADO)
                        Container(
                          padding: EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: _corAcai,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(30),
                              bottomRight: Radius.circular(30),
                            ),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      FontAwesomeIcons.paw,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      "Quem vai se hospedar?",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 15),
                              _buildPetSelector(),
                            ],
                          ),
                        ),

                        SizedBox(height: 25),

                        // 2. CALENDÁRIO
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Período da estadia",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                "Selecione a data de entrada e saída",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 15),
                        _buildCalendar(),

                        SizedBox(height: 20),

                        // Legenda
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildLegendItem(_corAcai, "Selecionado"),
                              _buildLegendItem(Colors.red[100]!, "Lotado"),
                              _buildLegendItem(Colors.grey[200]!, "Disponível"),
                            ],
                          ),
                        ),

                        SizedBox(height: 100), // Espaço para o bottom sheet
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomSheet: _buildBottomSummary(dias, total),
    );
  }

  // --- WIDGETS ---

  Widget _buildPetSelector() {
    return SizedBox(
      height: 100, // Altura dos cards
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _pets.length + 1, // +1 para o botão de adicionar
        separatorBuilder: (_, __) => SizedBox(width: 15),
        itemBuilder: (context, index) {
          // Último item: Botão "Adicionar Pet"
          if (index == _pets.length) {
            return GestureDetector(
              onTap: () async {
                // Navega para 'Meus Pets' e espera retorno para recarregar
                await Navigator.pushNamed(
                  context,
                  '/meus_pets',
                  arguments: {'cpf': _userCpf},
                );
                _carregarPets();
              },
              child: Container(
                width: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.add, color: Colors.white, size: 24),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Novo Pet",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Itens Normais (Pets)
          final pet = _pets[index];
          final isSelected = pet['id'] == _petId;

          return GestureDetector(
            onTap: () => setState(() => _petId = pet['id']),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: 90,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white30,
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isSelected
                        ? _corAcai.withOpacity(0.1)
                        : Colors.white24,
                    child: Icon(
                      pet['tipo'] == 'gato'
                          ? FontAwesomeIcons.cat
                          : FontAwesomeIcons.dog,
                      color: isSelected ? _corAcai : Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    pet['nome'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? _corAcai : Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TableCalendar(
        locale: 'pt_BR',
        firstDay: DateTime.now(),
        lastDay: DateTime.now().add(Duration(days: 90)),
        focusedDay: _focusedDay,

        // Range Configuration
        rangeStartDay: _rangeStart,
        rangeEndDay: _rangeEnd,
        rangeSelectionMode: _rangeSelectionMode,
        onRangeSelected: _onRangeSelected,

        // Disable individual days (past and blocked)
        enabledDayPredicate: (day) {
          if (day.isBefore(DateTime.now().subtract(Duration(days: 1)))) {
            return false;
          }
          return !_isDayLotado(day);
        },

        // Styling (similar to Creche but adapting for Range)
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _corAcai,
          ),
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: _corAcai.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: _corAcai,
            fontWeight: FontWeight.bold,
          ),

          // Range Styles
          rangeStartDecoration: BoxDecoration(
            color: _corAcai,
            shape: BoxShape.circle,
          ),
          rangeEndDecoration: BoxDecoration(
            color: _corAcai,
            shape: BoxShape.circle,
          ),
          rangeHighlightColor: _corAcai.withOpacity(0.2),

          disabledTextStyle: TextStyle(color: Colors.red[200]),
          disabledDecoration: BoxDecoration(shape: BoxShape.circle),
        ),
        calendarBuilders: CalendarBuilders(
          disabledBuilder: (context, day, focusedDay) {
            if (_isDayLotado(day)) {
              return Center(
                child: Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: Colors.red[300],
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ),
              );
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildBottomSummary(int dias, double total) {
    bool canSubmit = _petId != null && dias > 0 && !_isLoading;

    return Container(
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total a Pagar",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "R\$ ${total.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _corAcai,
                        ),
                      ),
                      Text(
                        dias == 1 ? "1 diária" : "$dias diárias",
                        style: TextStyle(
                          fontSize: 12,
                          color: _corAcai.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: ElevatedButton(
                    onPressed: canSubmit ? _fazerReserva : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
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
                            "RESERVAR",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
