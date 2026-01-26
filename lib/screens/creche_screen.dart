import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/firebase_service.dart';

class CrecheScreen extends StatefulWidget {
  @override
  _CrecheScreenState createState() => _CrecheScreenState();
}

class _CrecheScreenState extends State<CrecheScreen> {
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

  // Controle do Calendário
  DateTime _focusedDay = DateTime.now();
  final Set<DateTime> _selectedDays = {};
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.disabled;

  Set<DateTime> _diasLotados = {};

  bool _isLoading = false;
  List<Map<String, dynamic>> _pets = [];

  @override
  void initState() {
    super.initState();
    _carregarPrecoCreche();
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
    final datas = await _firebaseService.buscarDiasLotadosCreche();
    if (mounted) {
      setState(() {
        _diasLotados = datas
            .map((d) => DateTime(d.year, d.month, d.day))
            .toSet();
      });
    }
  }

  Future<void> _carregarPrecoCreche() async {
    try {
      final preco = await _firebaseService.getPrecoCreche();
      setState(() {
        _valorDiaria = preco > 0 ? preco : 60.00;
      });
    } catch (e) {
      setState(() => _valorDiaria = 60.00);
    }
  }

  // --- AÇÕES ---

  bool _isDayLotado(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return _diasLotados.contains(normalized);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      final normalized = DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
      );

      if (_isDayLotado(normalized)) {
        return;
      }

      if (_selectedDays.contains(normalized)) {
        _selectedDays.remove(normalized);
      } else {
        _selectedDays.add(normalized);
      }
    });
  }

  Future<void> _fazerReserva() async {
    if (_petId == null || _selectedDays.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _firebaseService.reservarCreche(
        petId: _petId!,
        cpfUser: _userCpf!,
        dates: _selectedDays.toList(),
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
              "Solicitação Enviada!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Estamos ansiosos para brincar com seu pet!\nAguarde a confirmação.",
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
                  Navigator.pop(ctx); // Fecha dialog
                  Navigator.pop(context); // Volta pra home
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
            Text("Ops!"),
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
    return StreamBuilder<Map<String, int>>(
      stream: _userCpf != null
          ? _firebaseService.getSaldoVouchers(_userCpf!)
          : Stream.value({'banho': 0, 'tosa': 0, 'creche': 0}),
      builder: (context, snapshot) {
        final vouchers = snapshot.data ?? {'banho': 0, 'tosa': 0, 'creche': 0};
        final int vouchersCreche = vouchers['creche'] ?? 0;

        // Cálculos de Preço
        int diasTotais = _selectedDays.length;
        int diasPagantes = (diasTotais - vouchersCreche).clamp(0, diasTotais);
        int vouchersUsados = (diasTotais - diasPagantes).clamp(
          0,
          vouchersCreche,
        );

        double total = diasPagantes * _valorDiaria;

        return Scaffold(
          backgroundColor: _corFundo,
          appBar: AppBar(
            title: Text(
              "Reservar Creche",
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
                                          "Quem vai se divertir?",
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Escolha os dias",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    "Selecione os dias desejados no calendário",
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildLegendItem(
                                    Colors.green[100]!,
                                    "Selecionado",
                                  ),
                                  _buildLegendItem(
                                    Colors.red[100]!,
                                    "Lotado/Indisp.",
                                  ),
                                  _buildLegendItem(
                                    Colors.grey[200]!,
                                    "Disponível",
                                  ),
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
          bottomSheet: _buildBottomSummary(diasTotais, total, vouchersUsados),
        );
      },
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
        selectedDayPredicate: (day) =>
            _selectedDays.contains(DateTime(day.year, day.month, day.day)),
        rangeSelectionMode: RangeSelectionMode.disabled,
        onDaySelected: _onDaySelected,
        enabledDayPredicate: (day) {
          // Desabilita dias passados e lotados
          if (day.isBefore(DateTime.now().subtract(Duration(days: 1))))
            return false;
          return !_isDayLotado(day);
        },
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
          // Estilo do dia de Hoje
          todayDecoration: BoxDecoration(
            color: _corAcai.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: _corAcai,
            fontWeight: FontWeight.bold,
          ),

          // Estilo de dias selecionados
          selectedDecoration: BoxDecoration(
            color: _corAcai,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(color: Colors.white),

          // Estilo de dias bloqueados/desabilitados
          disabledTextStyle: TextStyle(color: Colors.red[200]),
          disabledDecoration: BoxDecoration(shape: BoxShape.circle),
        ),
        calendarBuilders: CalendarBuilders(
          // Marcador customizado para dias lotados (opcional, já usamos enabledDayPredicate)
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
            return null; // Usa estilo padrão disabled
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

  Widget _buildBottomSummary(int dias, double total, int vouchersUsados) {
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
            // Feedback de Vouchers
            if (vouchersUsados > 0)
              Container(
                margin: EdgeInsets.only(bottom: 15),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.confirmation_number,
                      size: 16,
                      color: Colors.orange[800],
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        total == 0
                            ? "Coberto por $vouchersUsados vouchers!"
                            : "$vouchersUsados dias cobertos por voucher.",
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        total == 0 && vouchersUsados > 0
                            ? "Custo Total"
                            : "Valor a Pagar",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        total == 0 && vouchersUsados > 0
                            ? "GRÁTIS"
                            : "R\$ ${total.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: total == 0 ? Colors.green : _corAcai,
                        ),
                      ),
                      Text(
                        dias == 1
                            ? "1 dia selecionado"
                            : "$dias dias selecionados",
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
