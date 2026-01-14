import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/firebase_service.dart';

class AgendamentoScreen extends StatefulWidget {
  @override
  _AgendamentoScreenState createState() => _AgendamentoScreenState();
}

class _AgendamentoScreenState extends State<AgendamentoScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Instância das Functions (Certifique-se que a região é a mesma do deploy, ex: southamerica-east1)
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  // --- CORES DA MARCA ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF8F9FC);

  // --- ESTADO ---
  double _precoBanho = 0.0;
  double _precoTosa = 0.0;

  String? _userCpf;
  DateTime _dataSelecionada = DateTime.now();
  String _servicoSelecionado = 'Banho';

  // Nota: Não precisamos mais selecionar o profissional aqui no front para salvar,
  // o Backend decide o melhor profissional livre.

  String? _petId;
  String? _horarioSelecionado;

  bool _isLoading = false;
  List<Map<String, dynamic>> _gradeHorarios = [];
  List<Map<String, dynamic>> _pets = [];
  late List<DateTime> _listaDias;

  @override
  void initState() {
    super.initState();
    _carregarPrecosAtualizados();
    _gerarListaDias();

    // Ajusta para não começar no domingo se a loja fecha domingo
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
      _carregarDadosIniciais();
    }
  }

  Future<void> _carregarPrecosAtualizados() async {
    try {
      final doc = await _db.collection('config').doc('parametros').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _precoBanho = (data['preco_banho'] ?? 0.0).toDouble();
          _precoTosa = (data['preco_tosa'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      print("Erro ao carregar preços: $e");
    }
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _isLoading = true);
    try {
      await _atualizarListaPets();
      // Não precisamos carregar lista de profissionais aqui, a function buscarHorarios resolve isso
      _buscarHorarios();
    } catch (e) {
      print("Erro: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _atualizarListaPets() async {
    final petsSnapshot = await _db
        .collection('users')
        .doc(_userCpf)
        .collection('pets')
        .get();

    setState(() {
      _pets = petsSnapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (_pets.isNotEmpty && _petId == null) _petId = _pets.first['id'];
    });
  }

  Future<void> _buscarHorarios() async {
    if (_servicoSelecionado.isEmpty) return;

    setState(() {
      _isLoading = true;
      _gradeHorarios = [];
      _horarioSelecionado = null;
    });

    try {
      final dataString = DateFormat('yyyy-MM-dd').format(_dataSelecionada);

      // Chama a Cloud Function 'buscarHorarios' (já existente no seu backend)
      final result = await _functions.httpsCallable('buscarHorarios').call({
        'dataConsulta': dataString,
        'servico': _servicoSelecionado.toLowerCase(),
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
      print("Erro ao buscar horários: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro de conexão ao buscar horários.")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- CONFIRMAÇÃO VIA CLOUD FUNCTION ---
  Future<void> _confirmarAgendamento() async {
    if (_petId == null || _horarioSelecionado == null) return;

    setState(() => _isLoading = true);

    try {
      // Formata a data completa para envio
      final dataHoraString =
          "${DateFormat('yyyy-MM-dd').format(_dataSelecionada)} $_horarioSelecionado";
      // Converte para DateTime para validar, mas enviaremos string ISO ou compatível
      // O backend espera 'data_hora'

      double valorFinal = _servicoSelecionado == 'Banho'
          ? _precoBanho
          : _precoTosa;

      // CHAMA A FUNCTION 'criarAgendamento'
      // Isso substitui a gravação direta no banco
      final HttpsCallable callable = _functions.httpsCallable(
        'criarAgendamento',
      );

      await callable.call({
        'servico': _servicoSelecionado,
        'data_hora': dataHoraString, // O backend faz "new Date(data_hora)"
        'cpf_user': _userCpf,
        'pet_id': _petId,
        'metodo_pagamento': 'na_loja', // Padrão: Paga na recepção
        'valor': valorFinal,
      });

      _mostrarSucessoDialog();
    } catch (e) {
      String msgErro = "Erro desconhecido ao agendar.";
      if (e is FirebaseFunctionsException) {
        msgErro = e.message ?? e.details.toString();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Falha: $msgErro"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
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
              child: Icon(Icons.check_circle, color: Colors.green, size: 50),
            ),
            SizedBox(height: 15),
            Text(
              "Agendamento Confirmado!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              "Esperamos vocês no horário marcado.\nO pagamento será feito na recepção.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text(
                  "OK",
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

  // --- MODAL ADICIONAR PET ---
  void _abrirModalAdicionarPet() {
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
            title: Text(
              "Adicionar Novo Pet",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _corAcai,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nomeController,
                  decoration: InputDecoration(
                    labelText: "Nome do Pet",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.pets, size: 20, color: Colors.grey),
                    isDense: true,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "Qual a espécie?",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTipoChip(
                      "Cão",
                      "cao",
                      _tipoSelecionado,
                      (v) => setModalState(() => _tipoSelecionado = v),
                    ),
                    SizedBox(width: 15),
                    _buildTipoChip(
                      "Gato",
                      "gato",
                      _tipoSelecionado,
                      (v) => setModalState(() => _tipoSelecionado = v),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  if (_nomeController.text.isNotEmpty) {
                    // Salva no Firestore
                    final docRef = await _db
                        .collection('users')
                        .doc(_userCpf)
                        .collection('pets')
                        .add({
                          'nome': _nomeController.text.trim(),
                          'tipo': _tipoSelecionado,
                          'raca': 'SRD', // Padrão
                          'donoCpf': _userCpf,
                          'created_at': FieldValue.serverTimestamp(),
                        });

                    Navigator.pop(context);
                    await _atualizarListaPets(); // Recarrega lista
                    setState(
                      () => _petId = docRef.id,
                    ); // Já seleciona o novo pet
                  }
                },
                child: Text("Salvar", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTipoChip(
    String label,
    String valor,
    String selecionado,
    Function(String) onTap,
  ) {
    bool isSelected = valor == selecionado;
    return GestureDetector(
      onTap: () => onTap(valor),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _corAcai : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _corAcai : Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(
              valor == 'cao' ? FontAwesomeIcons.dog : FontAwesomeIcons.cat,
              size: 14,
              color: isSelected ? Colors.white : Colors.grey,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final petSelecionado = _pets.firstWhere(
      (p) => p['id'] == _petId,
      orElse: () => {'nome': '...'},
    );

    return Scaffold(
      backgroundColor: _corFundo,
      body: Column(
        children: [
          // 1. CABEÇALHO IMERSIVO
          Container(
            padding: EdgeInsets.only(top: 45, left: 20, right: 20, bottom: 20),
            decoration: BoxDecoration(
              color: _corAcai,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
              boxShadow: [
                BoxShadow(
                  color: _corAcai.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Agendar Horário",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Rápido e fácil",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading && _pets.isEmpty
                ? Center(child: CircularProgressIndicator(color: _corAcai))
                : SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20),

                        // 2. SELEÇÃO DE PET
                        _sectionTitle("Para quem é?"),
                        SizedBox(height: 10),
                        _buildPetList(),

                        SizedBox(height: 20),

                        // 3. SELEÇÃO DE SERVIÇO
                        _sectionTitle("Serviço"),
                        SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildServicoCard(
                                  "Banho",
                                  "Higiene",
                                  FontAwesomeIcons.shower,
                                  Colors.blue,
                                ),
                              ),
                              SizedBox(width: 15),
                              Expanded(
                                child: _buildServicoCard(
                                  "Tosa",
                                  "Completa",
                                  FontAwesomeIcons.scissors,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20),

                        // 4. DATA E HORA
                        _sectionTitle("Quando?"),
                        SizedBox(height: 10),
                        _buildCalendarList(),
                        SizedBox(height: 15),

                        if (_gradeHorarios.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              "Horários:",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          _buildTimeGrid(),
                        ] else ...[
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                "Selecione um dia para ver horários.",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],

                        SizedBox(height: 20),

                        // 5. RESUMO FINAL
                        if (_petId != null && _horarioSelecionado != null)
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: 20),
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: _corAcai.withOpacity(0.1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      color: _corAcai,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "Resumo",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: _corAcai,
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(height: 15),
                                _buildSummaryRow("Pet", petSelecionado['nome']),
                                _buildSummaryRow(
                                  "Serviço",
                                  _servicoSelecionado,
                                ),
                                _buildSummaryRow(
                                  "Data",
                                  "${DateFormat('dd/MM').format(_dataSelecionada)} às $_horarioSelecionado",
                                ),
                                SizedBox(height: 10),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.store,
                                        size: 14,
                                        color: Colors.amber[800],
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        "Pagamento na loja",
                                        style: TextStyle(
                                          color: Colors.amber[900],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        SizedBox(height: 80),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomSheet: _buildBottomButton(),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  // --- WIDGETS PERSONALIZADOS ---

  Widget _buildPetList() {
    return SizedBox(
      height: 85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 15),
        itemCount: _pets.length + 1, // +1 para botão adicionar
        itemBuilder: (context, index) {
          // Botão Adicionar Pet
          if (index == _pets.length) {
            return GestureDetector(
              onTap: _abrirModalAdicionarPet,
              child: Container(
                width: 60,
                margin: EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Icon(Icons.add, color: _corAcai),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Adicionar",
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          final pet = _pets[index];
          final isSelected = pet['id'] == _petId;
          final isDog = pet['tipo'] == 'cao';

          return GestureDetector(
            onTap: () => setState(() => _petId = pet['id']),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: isSelected ? _corAcai : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _corAcai : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: Icon(
                      isDog ? FontAwesomeIcons.dog : FontAwesomeIcons.cat,
                      color: isSelected ? Colors.white : Colors.grey[400],
                      size: 22,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    pet['nome'],
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? _corAcai : Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServicoCard(
    String label,
    String subtitle,
    IconData icon,
    Color themeColor,
  ) {
    final isSelected = _servicoSelecionado == label;

    return GestureDetector(
      onTap: () {
        setState(() => _servicoSelecionado = label);
        _buscarHorarios(); // Recarrega horários ao mudar serviço
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? _corAcai : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? _corAcai : Colors.grey[200]!),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _corAcai.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            FaIcon(
              icon,
              color: isSelected ? Colors.white : themeColor,
              size: 24,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? Colors.white : Colors.grey[800],
              ),
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white70 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarList() {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 15),
        itemCount: _listaDias.length,
        itemBuilder: (context, index) {
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
              width: 50,
              margin: EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? _corAcai : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? _corAcai : Colors.grey[300]!,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat(
                      'EEE',
                      'pt_BR',
                    ).format(dia).toUpperCase().substring(0, 3),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white70 : Colors.grey[400],
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    DateFormat('dd').format(dia),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _gradeHorarios.map((item) {
          final horario = item['hora'];
          final isLivre = item['livre'];
          final isSelected = _horarioSelecionado == horario;

          return GestureDetector(
            onTap: isLivre
                ? () => setState(() => _horarioSelecionado = horario)
                : null,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? _corAcai
                    : (isLivre ? Colors.white : Colors.grey[50]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? _corAcai
                      : (isLivre ? Colors.grey[300]! : Colors.transparent),
                ),
              ),
              child: Text(
                horario,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Colors.white
                      : (isLivre ? Colors.grey[700] : Colors.grey[300]),
                  fontWeight: FontWeight.bold,
                  decoration: !isLivre ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    bool canSubmit =
        _petId != null && _horarioSelecionado != null && !_isLoading;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: canSubmit ? _confirmarAgendamento : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _corAcai,
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: canSubmit ? 4 : 0,
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
                    "CONFIRMAR AGENDAMENTO",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
