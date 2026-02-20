import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agenpet/services/firebase_service.dart';

class VetAgendamentoScreen extends StatefulWidget {
  const VetAgendamentoScreen({super.key});

  @override
  _VetAgendamentoScreenState createState() => _VetAgendamentoScreenState();
}

class _VetAgendamentoScreenState extends State<VetAgendamentoScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final _firebaseService = FirebaseService();

  // --- CORES ---
  final Color _corAcai = const Color(0xFF4A148C);
  final Color _corFundo = const Color(0xFFF8F9FC);

  // --- CONTROLLERS ---
  final _obsController = TextEditingController();
  final PageController _pageController = PageController();

  // --- ESTADO ---
  int _currentStep = 0;
  String? _userCpf;
  DateTime _dataSelecionada = DateTime.now();
  String? _servicoSelecionado; // "Consulta" ou "Vacina"
  String? _petId;
  String? _petNome;
  String? _horarioSelecionado;

  bool _isLoading = false;
  List<Map<String, dynamic>> _gradeHorarios = [];
  List<Map<String, dynamic>> _pets = [];
  late List<DateTime> _listaDias;

  @override
  void initState() {
    super.initState();
    _gerarListaDias();
    if (_dataSelecionada.weekday == DateTime.sunday) {
      _dataSelecionada = _dataSelecionada.add(const Duration(days: 1));
    }
    if (_listaDias.isNotEmpty) {
      _dataSelecionada = _listaDias.first;
    }
  }

  void _gerarListaDias() {
    _listaDias = [];
    DateTime dataBase = DateTime.now();
    int diasAdicionados = 0;
    int diasPercorridos = 0;
    while (diasAdicionados < 30) {
      DateTime data = dataBase.add(Duration(days: diasPercorridos));
      if (data.weekday != DateTime.sunday) {
        _listaDias.add(data);
        diasAdicionados++;
      }
      diasPercorridos++;
    }
  }

  @override
  void dispose() {
    _obsController.dispose();
    _pageController.dispose();
    super.dispose();
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

  Future<void> _buscarHorarios() async {
    if (_servicoSelecionado == null) return;
    setState(() {
      _isLoading = true;
      _gradeHorarios = [];
      _horarioSelecionado = null;
    });

    try {
      final dataString = DateFormat('yyyy-MM-dd').format(_dataSelecionada);
      // Backend expects 'consulta' or 'vacina' (lowercase)
      final servicoBackend = _servicoSelecionado == "Consulta" ? "consulta" : "vacina";

      final grade = await _firebaseService.buscarHorariosDisponiveis(
        dataString,
        servicoBackend,
      );

      if (mounted) {
        setState(() {
          _gradeHorarios = grade;
        });
      }
    } catch (e) {
      print("Erro ao buscar horários: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmarAgendamento() async {
    if (_petId == null || _horarioSelecionado == null) return;

    setState(() => _isLoading = true);

    try {
      final timeParts = _horarioSelecionado!.split(':');
      final dataHora = DateTime(
        _dataSelecionada.year,
        _dataSelecionada.month,
        _dataSelecionada.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      // Map selection to backend expected values
      final servicoBackend = _servicoSelecionado == "Consulta" ? "consulta" : "vacina";

      await _firebaseService.criarAgendamento(
        servico: servicoBackend,
        dataHora: dataHora,
        cpfUser: _userCpf!,
        petId: _petId!,
        metodoPagamento: 'na_loja', // Default for now
        valor: 0, // Price calculated at store or fetched later if needed
        taxiDog: false, // Vet usually doesn't involve taxi dog logic in this flow
      );

      _mostrarSucessoDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao agendar: $e"),
          backgroundColor: Colors.red,
        ),
      );
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.green, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              "Agendado com Sucesso!",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Aguardamos você na clínica! O pagamento é realizado na recepção.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
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

  void _proximoPasso() {
    if (_currentStep == 0 && _petId == null) return;
    if (_currentStep == 1 && _servicoSelecionado == null) return;
    if (_currentStep == 2 && _horarioSelecionado == null) return;

    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      if (_currentStep == 2) {
        _buscarHorarios();
      }
    }
  }

  void _passoAnterior() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStepPets(),
                  _buildStepServico(), // Custom for Vet
                  _buildStepDataHora(),
                  _buildStepResumo(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: _passoAnterior,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 15),
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
                      "Passo ${_currentStep + 1} de 4",
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
          const SizedBox(height: 15),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 4,
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
        return "Quem será atendido?";
      case 1:
        return "Qual o procedimento?";
      case 2:
        return "Qual o melhor horário?";
      case 3:
        return "Confirme o agendamento";
      default:
        return "Agendamento Veterinário";
    }
  }

  // PASSO 1: SELEÇÃO DE PET (Reused logic)
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
                  padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 20),
          Text(
            "Você ainda não tem pets.",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          // Add Pet logic omitted for brevity, assuming user has pets or can add via other screen
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
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
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
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
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
            const SizedBox(width: 15),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
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
          const Icon(Icons.add, color: Colors.grey),
          const SizedBox(width: 10),
          Text(
            "Adicionar outro pet",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // PASSO 2: SELEÇÃO DE SERVIÇO (VET SPECIFIC)
  Widget _buildStepServico() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildServiceBigCard(
                    "Consulta",
                    "Avaliação Clínica",
                    FontAwesomeIcons.userDoctor,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildServiceBigCard(
                    "Vacinação",
                    "Imunização e Prevenção",
                    FontAwesomeIcons.syringe,
                    Colors.teal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  Widget _buildServiceBigCard(
    String label,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    bool isSelected = _servicoSelecionado == label;
    return GestureDetector(
      onTap: () {
        setState(() => _servicoSelecionado = label);
        _proximoPasso();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: isSelected ? null : Border.all(color: Colors.grey[100]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                icon,
                size: 30,
                color: isSelected ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isSelected ? Colors.white70 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PASSO 3: DATA E HORA (Reused)
  Widget _buildStepDataHora() {
    return Column(
      children: [
        Container(
          height: 90,
          color: Colors.white,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            itemCount: _listaDias.length,
            itemBuilder: (ctx, index) {
              final dia = _listaDias[index];
              final isSelected = DateUtils.isSameDay(dia, _dataSelecionada);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _dataSelecionada = dia;
                    _horarioSelecionado = null;
                  });
                  _buscarHorarios();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? _corAcai : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isSelected ? _corAcai : Colors.grey[200]!,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _corAcai.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat(
                          'EEE',
                          'pt_BR',
                        ).format(dia).substring(0, 3).toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white.withOpacity(0.8)
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd').format(dia),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: _corAcai))
              : _gradeHorarios.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 50, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text(
                        "Sem horários livres nesta data.",
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _gradeHorarios.length,
                  itemBuilder: (ctx, idx) {
                    final item = _gradeHorarios[idx];
                    final isLivre = item['livre'];
                    final isSelected = _horarioSelecionado == item['hora'];
                    return GestureDetector(
                      onTap: isLivre
                          ? () {
                              setState(
                                () => _horarioSelecionado = item['hora'],
                              );
                              _proximoPasso();
                            }
                          : null,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _corAcai
                              : (isLivre ? Colors.white : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? _corAcai
                                : (isLivre
                                      ? Colors.grey[300]!
                                      : Colors.transparent),
                          ),
                          boxShadow: (isLivre && !isSelected)
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 5,
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          item['hora'],
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isLivre ? Colors.black87 : Colors.grey[400]),
                            decoration: !isLivre
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // PASSO 4: RESUMO
  Widget _buildStepResumo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                  decoration: BoxDecoration(
                    color: _corAcai,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.confirmation_number_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Revisão do Agendamento",
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
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    children: [
                      _buildSummaryRow(Icons.pets, "Pet", _petNome ?? ""),
                      const SizedBox(height: 20),
                      _buildSummaryRow(
                        Icons.local_hospital,
                        "Procedimento",
                        _servicoSelecionado ?? "",
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Colors.transparent),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryBox(
                              Icons.calendar_today,
                              "Data",
                              DateFormat('dd/MM').format(_dataSelecionada),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _buildSummaryBox(
                              Icons.access_time,
                              "Horário",
                              _horarioSelecionado ?? "",
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
          const SizedBox(height: 30),

          TextField(
            controller: _obsController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: "Observações (Sintomas, Histórico...)",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _confirmarAgendamento,
              style: ElevatedButton.styleFrom(
                backgroundColor: _corAcai,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      "CONFIRMAR AGENDAMENTO",
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
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.grey[700], size: 20),
        ),
        const SizedBox(width: 15),
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
      padding: const EdgeInsets.all(15),
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
              const SizedBox(width: 5),
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
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
