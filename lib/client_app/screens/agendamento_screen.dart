import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class AgendamentoScreen extends StatefulWidget {
  @override
  _AgendamentoScreenState createState() => _AgendamentoScreenState();
}

class _AgendamentoScreenState extends State<AgendamentoScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  // --- CORES ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF8F9FC);

  // --- CONTROLLERS ---
  final _obsController = TextEditingController();
  final PageController _pageController = PageController();

  // --- ESTADO ---
  int _currentStep = 0;
  String? _userCpf;
  DateTime _dataSelecionada = DateTime.now();
  String? _servicoSelecionado;
  String? _petId;
  String? _petNome; // Para exibição no resumo
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
      _dataSelecionada = _dataSelecionada.add(Duration(days: 1));
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
      final result = await _functions.httpsCallable('buscarHorarios').call({
        'dataConsulta': dataString,
        'servico': _servicoSelecionado!.toLowerCase(),
      });

      if (mounted) {
        setState(() {
          List<dynamic> dados = result.data['grade'];
          _gradeHorarios = dados
              .map(
                (item) => {
                  "hora": item['hora'].toString(),
                  "livre": item['livre'] as bool,
                },
              )
              .toList();
        });
      }
    } catch (e) {
      print("Erro: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmarAgendamento() async {
    if (_petId == null || _horarioSelecionado == null) return;
    setState(() => _isLoading = true);

    try {
      final dataHoraString =
          "${DateFormat('yyyy-MM-dd').format(_dataSelecionada)} $_horarioSelecionado";

      await _functions.httpsCallable('criarAgendamento').call({
        'servico': _servicoSelecionado,
        'data_hora': dataHoraString,
        'cpf_user': _userCpf,
        'pet_id': _petId,
        'metodo_pagamento': 'na_loja',
        'valor': 0,
        'observacoes': _obsController.text.trim(),
      });

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
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: Colors.green, size: 40),
            ),
            SizedBox(height: 20),
            Text(
              "Agendado com Sucesso!",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Seu pet vai ficar lindo! O pagamento é realizado na recepção.",
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

  // --- NAVEGAÇÃO ENTRE PASSOS ---
  void _proximoPasso() {
    if (_currentStep == 0 && _petId == null) return;
    if (_currentStep == 1 && _servicoSelecionado == null) return;
    if (_currentStep == 2 && _horarioSelecionado == null) return;

    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      // Se for para o passo de horário (2), buscar horários
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
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  // --- UI PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header com Navegação e Progresso
            _buildHeader(),

            // 2. Conteúdo (Stepper)
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _buildStepPets(),
                  _buildStepServico(),
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
          SizedBox(height: 15),
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
        return "Qual o serviço?";
      case 2:
        return "Qual o melhor horário?";
      case 3:
        return "Confirme o agendamento";
      default:
        return "Agendamento";
    }
  }

  // --- PASSOS ---

  // PASSO 1: SELEÇÃO DE PET
  Widget _buildStepPets() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _corAcai));
    }

    return Column(
      children: [
        Expanded(
          child:
              _pets.isEmpty
                  ? _buildEmptyPets()
                  : ListView.builder(
                    padding: EdgeInsets.all(20),
                    itemCount: _pets.length + 1, // +1 botão adicionar
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
        _proximoPasso(); // Auto-avanço
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
                color:
                    pet['tipo'] == 'cao'
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
          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
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

  // PASSO 2: SELEÇÃO DE SERVIÇO
  Widget _buildStepServico() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildServiceBigCard(
                    "Banho",
                    FontAwesomeIcons.shower,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: _buildServiceBigCard(
                    "Tosa",
                    FontAwesomeIcons.scissors,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 15),
          // Botão Voltar (Opcional, pois tem no header)
        ],
      ),
    );
  }

  Widget _buildServiceBigCard(String label, IconData icon, Color color) {
    bool isSelected = _servicoSelecionado == label;
    return GestureDetector(
      onTap: () {
        setState(() => _servicoSelecionado = label);
        _proximoPasso();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
          border: isSelected ? null : Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, size: 50, color: isSelected ? Colors.white : color),
            SizedBox(height: 20),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PASSO 3: DATA E HORA
  Widget _buildStepDataHora() {
    return Column(
      children: [
        // Lista de Dias (Horizontal)
        Container(
          height: 90,
          color: Colors.white,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
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
                  duration: Duration(milliseconds: 200),
                  width: 60,
                  margin: EdgeInsets.only(right: 10),
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
                              offset: Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE', 'pt_BR')
                            .format(dia)
                            .substring(0, 3)
                            .toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white.withOpacity(0.8)
                              : Colors.grey,
                        ),
                      ),
                      SizedBox(height: 4),
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
                      SizedBox(height: 10),
                      Text(
                        "Sem horários livres nesta data.",
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.all(20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                              setState(() => _horarioSelecionado = item['hora']);
                              _proximoPasso(); // Auto-avanço ao selecionar hora
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
                                : (isLivre
                                      ? Colors.black87
                                      : Colors.grey[400]),
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
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSummaryRow(Icons.pets, "Pet", _petNome ?? ""),
                Divider(height: 30),
                _buildSummaryRow(
                  Icons.cut,
                  "Serviço",
                  _servicoSelecionado ?? "",
                ),
                Divider(height: 30),
                _buildSummaryRow(
                  Icons.calendar_today,
                  "Data",
                  DateFormat('dd/MM/yyyy').format(_dataSelecionada),
                ),
                Divider(height: 30),
                _buildSummaryRow(
                  Icons.access_time,
                  "Horário",
                  _horarioSelecionado ?? "",
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          TextField(
            controller: _obsController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: "Observações (Opcional)",
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
          SizedBox(height: 30),
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
                  ? CircularProgressIndicator(color: Colors.white)
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
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _corAcai.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _corAcai, size: 20),
        ),
        SizedBox(width: 15),
        Column(
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
      ],
    );
  }

  // --- FUNÇÕES AUXILIARES ---
  void _abrirModalAdicionarPet() {
    // Reutilizando lógica simples, ou idealmente chamar o modal da tela de Pets
    // Por brevidade, implementação simples inline:
    final _nomeController = TextEditingController();
    String _tipoSelecionado = 'cao';

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
                  controller: _nomeController,
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
                        onTap: () => setModalState(() => _tipoSelecionado = 'cao'),
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _tipoSelecionado == 'cao' ? _corAcai : Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                              child: Text("Cão", style: TextStyle(color: _tipoSelecionado == 'cao' ? Colors.white : Colors.black))),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => _tipoSelecionado = 'gato'),
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _tipoSelecionado == 'gato' ? _corAcai : Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                              child: Text("Gato", style: TextStyle(color: _tipoSelecionado == 'gato' ? Colors.white : Colors.black))),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancelar")),
              ElevatedButton(
                onPressed: () async {
                  if (_nomeController.text.isNotEmpty) {
                    await _db
                        .collection('users')
                        .doc(_userCpf)
                        .collection('pets')
                        .add({
                          'nome': _nomeController.text.trim(),
                          'tipo': _tipoSelecionado,
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
}
