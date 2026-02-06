import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';

class CrecheScreen extends StatefulWidget {
  const CrecheScreen({super.key});

  @override
  _CrecheScreenState createState() => _CrecheScreenState();
}

class _CrecheScreenState extends State<CrecheScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final _firebaseService = FirebaseService();
  final PageController _pageController = PageController();

  // --- CORES ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF8F9FC);

  // --- ESTADO ---
  int _currentStep = 0;
  bool _isLoading = false;

  // DADOS
  String? _userCpf;
  double _valorDiaria = 0.0;
  List<Map<String, dynamic>> _pets = [];
  Set<DateTime> _diasLotados = {};

  // SELEÇÃO
  String? _petId;
  String? _petNome;

  // CALENDÁRIO
  DateTime _focusedDay = DateTime.now();
  final Set<DateTime> _selectedDays = {};

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
    setState(() => _isLoading = true);
    final snap = await _db
        .collection('users')
        .doc(_userCpf)
        .collection('pets')
        .get();
    setState(() {
      _pets = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _isLoading = false;
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

  // --- LOGICA CALENDARIO ---
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

  // --- NAVEGAÇÃO ---
  void _proximoPasso() {
    if (_currentStep == 0 && _petId == null) return;
    if (_currentStep == 1 && _selectedDays.isEmpty) return;

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _passoAnterior() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<bool> _onWillPop() async {
    if (_currentStep > 0) {
      _passoAnterior();
      return false;
    }
    return true;
  }

  // --- ACTIONS ---
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
              child: Icon(Icons.check_rounded, color: Colors.green, size: 40),
            ),
            SizedBox(height: 20),
            Text(
              "Solicitação Enviada!",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Estamos ansiosos para brincar com seu pet!\nAguarde a confirmação.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text(
                  "VOLTAR PARA O MENU",
                  style: GoogleFonts.poppins(
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

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: _corFundo,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    _buildStepPets(),
                    _buildStepData(),
                    _buildStepResumo(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: _passoAnterior,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStepTitle(),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _corAcai,
                      ),
                    ),
                    Text(
                      "Passo ${_currentStep + 1} de 3",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            backgroundColor: Colors.grey[100],
            valueColor: AlwaysStoppedAnimation<Color>(_corAcai),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return "Quem vai se divertir?";
      case 1:
        return "Quais dias?";
      case 2:
        return "Confirmar Creche";
      default:
        return "Creche";
    }
  }

  // PASSO 1: PETS (Reutilizando estrutura do Hotel/Agendamento)
  Widget _buildStepPets() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _corAcai));
    }

    return Column(
      children: [
        Expanded(
          child: _pets.isEmpty
              ? _buildEmptyPets()
              : ListView.builder(
                  padding: EdgeInsets.all(20),
                  itemCount: _pets.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _pets.length) {
                      return _buildAddPetCard();
                    }
                    final pet = _pets[index];
                    return _buildPetSelectionCard(pet);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyPets() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.paw, size: 50, color: Colors.grey[300]),
          SizedBox(height: 20),
          Text(
            "Você ainda não tem pets.",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          TextButton(
            onPressed: _abrirModalAdicionarPet,
            child: Text("Cadastrar Pet Agora"),
          ),
        ],
      ),
    );
  }

  Widget _buildPetSelectionCard(Map<String, dynamic> pet) {
    bool isSelected = _petId == pet['id'];
    return GestureDetector(
      onTap: () {
        setState(() {
          _petId = pet['id'];
          _petNome = pet['nome'];
        });
        _proximoPasso();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 15),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? _corAcai.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _corAcai : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pet['tipo'] == 'cao'
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                pet['tipo'] == 'cao'
                    ? FontAwesomeIcons.dog
                    : FontAwesomeIcons.cat,
                color: pet['tipo'] == 'cao' ? Colors.blue : Colors.orange,
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Text(
                pet['nome'],
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPetCard() {
    return GestureDetector(
      onTap: _abrirModalAdicionarPet,
      child: Container(
        margin: EdgeInsets.only(bottom: 15),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey[300]!,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.grey),
            SizedBox(width: 10),
            Text(
              "Adicionar outro pet",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModalAdicionarPet() {
    final nomeController = TextEditingController();
    String tipoSelecionado = 'cao';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text("Novo Pet"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: InputDecoration(
                    labelText: "Nome",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setModalState(() => tipoSelecionado = 'cao'),
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: tipoSelecionado == 'cao'
                                ? _corAcai
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              "Cão",
                              style: TextStyle(
                                color: tipoSelecionado == 'cao'
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setModalState(() => tipoSelecionado = 'gato'),
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: tipoSelecionado == 'gato'
                                ? _corAcai
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              "Gato",
                              style: TextStyle(
                                color: tipoSelecionado == 'gato'
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nomeController.text.isNotEmpty) {
                    await _db
                        .collection('users')
                        .doc(_userCpf)
                        .collection('pets')
                        .add({
                          'nome': nomeController.text.trim(),
                          'tipo': tipoSelecionado,
                          'created_at': FieldValue.serverTimestamp(),
                        });
                    Navigator.pop(context);
                    _carregarPets();
                  }
                },
                child: Text("Salvar"),
              ),
            ],
          );
        },
      ),
    );
  }

  // PASSO 2: DATA (CALENDÁRIO)
  Widget _buildStepData() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
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

                      selectedDayPredicate: (day) => _selectedDays.contains(
                        DateTime(day.year, day.month, day.day),
                      ),
                      rangeSelectionMode: RangeSelectionMode.disabled,
                      onDaySelected: _onDaySelected,

                      enabledDayPredicate: (day) {
                        if (day.isBefore(
                          DateTime.now().subtract(Duration(days: 1)),
                        )) {
                          return false;
                        }
                        return !_isDayLotado(day);
                      },

                      headerStyle: HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                        titleTextStyle: GoogleFonts.poppins(
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
                        todayTextStyle: GoogleFonts.poppins(
                          color: _corAcai,
                          fontWeight: FontWeight.bold,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: _corAcai,
                          shape: BoxShape.circle,
                        ),
                        selectedTextStyle: GoogleFonts.poppins(
                          color: Colors.white,
                        ),
                        disabledTextStyle: GoogleFonts.poppins(
                          color: Colors.red[200],
                        ),
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
                                    style: GoogleFonts.poppins(
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
                  ),
                  SizedBox(height: 20),
                  // Legenda
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLegendItem(_corAcai, "Selecionado"),
                      _buildLegendItem(Colors.red[100]!, "Lotado"),
                      _buildLegendItem(Colors.grey[200]!, "Disponível"),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedDays.isNotEmpty ? _proximoPasso : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _corAcai,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "CONTINUAR (${_selectedDays.length} dias)",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
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
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // PASSO 3: RESUMO
  Widget _buildStepResumo() {
    return StreamBuilder<Map<String, int>>(
      stream: _userCpf != null
          ? _firebaseService.getSaldoVouchers(_userCpf!)
          : Stream.value({'banho': 0, 'tosa': 0, 'creche': 0}),
      builder: (context, snapshot) {
        final vouchers = snapshot.data ?? {'banho': 0, 'tosa': 0, 'creche': 0};
        final int vouchersCreche = vouchers['creche'] ?? 0;

        // Cálculos
        int diasTotais = _selectedDays.length;
        int diasPagantes = (diasTotais - vouchersCreche).clamp(0, diasTotais);
        int vouchersUsados = (diasTotais - diasPagantes).clamp(
          0,
          vouchersCreche,
        );
        double total = diasPagantes * _valorDiaria;

        return SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 25,
                      ),
                      decoration: BoxDecoration(
                        color: _corAcai,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            FontAwesomeIcons.clipboardCheck,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Revisão da Reserva",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Verifique os dados abaixo",
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(25),
                      child: Column(
                        children: [
                          _buildSummaryRow(
                            FontAwesomeIcons.paw,
                            "Pet",
                            _petNome ?? "",
                          ),
                          SizedBox(height: 20),
                          Divider(color: Colors.grey[100]),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryBox(
                                  FontAwesomeIcons.calendarCheck,
                                  "Dias",
                                  "$diasTotais",
                                ),
                              ),
                              SizedBox(width: 15),
                              Expanded(
                                child: _buildSummaryBox(
                                  FontAwesomeIcons.tag,
                                  "Vouchers",
                                  "-$vouchersUsados",
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total a pagar",
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                total == 0
                                    ? "R\$ 0.0"
                                    : "R\$ ${total.toStringAsFixed(2)}",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: total == 0 ? Colors.green : _corAcai,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _fazerReserva,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "CONFIRMAR RESERVA",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.grey[700], size: 20),
        ),
        SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.check_circle, color: Colors.green[400], size: 18),
      ],
    );
  }

  Widget _buildSummaryBox(IconData icon, String label, String value) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: _corAcai),
              SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _corAcai,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
