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

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  // --- CORES ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF8F9FC);

  // --- CONTROLLERS ---
  final _obsController = TextEditingController();

  // --- ESTADO ---
  String? _userCpf;
  DateTime _dataSelecionada = DateTime.now();
  String _servicoSelecionado = 'Banho';
  String? _petId;
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
      _carregarDadosIniciais();
    }
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _isLoading = true);
    await _atualizarListaPets();
    _buscarHorarios();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _atualizarListaPets() async {
    final snap = await _db
        .collection('users')
        .doc(_userCpf)
        .collection('pets')
        .get();
    setState(() {
      _pets = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
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
            Icon(Icons.check_circle, color: Colors.green, size: 50),
            SizedBox(height: 10),
            Text(
              "Agendamento Confirmado!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Text(
              "Pagamento na recepção.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _corAcai),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // --- FUNÇÃO DE ADICIONAR PET (REINCLUÍDA) ---
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
              "Novo Pet",
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
                    labelText: "Nome",
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTipoChip(
                      "Cão",
                      "cao",
                      _tipoSelecionado,
                      (v) => setModalState(() => _tipoSelecionado = v),
                    ),
                    SizedBox(width: 10),
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
                style: ElevatedButton.styleFrom(backgroundColor: _corAcai),
                onPressed: () async {
                  if (_nomeController.text.isNotEmpty) {
                    final docRef = await _db
                        .collection('users')
                        .doc(_userCpf)
                        .collection('pets')
                        .add({
                          'nome': _nomeController.text.trim(),
                          'tipo': _tipoSelecionado,
                          'raca': 'SRD',
                          'donoCpf': _userCpf,
                          'created_at': FieldValue.serverTimestamp(),
                        });
                    Navigator.pop(context);
                    await _atualizarListaPets();
                    setState(() => _petId = docRef.id);
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
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _corAcai : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _corAcai : Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(
              valor == 'cao' ? FontAwesomeIcons.dog : FontAwesomeIcons.cat,
              size: 12,
              color: isSelected ? Colors.white : Colors.grey,
            ),
            SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Column(
        children: [
          // 1. Cabeçalho Compacto
          Container(
            padding: EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 15),
            decoration: BoxDecoration(
              color: _corAcai,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Agendar Horário",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.calendar_today, color: Colors.white, size: 18),
              ],
            ),
          ),

          // 2. Conteúdo Flexível
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SELEÇÃO DE PET (Com botão Adicionar) ---
                  _sectionTitle("Para quem é?"),
                  SizedBox(height: 5),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      // +1 para o botão adicionar
                      itemCount: _pets.length + 1,
                      itemBuilder: (ctx, index) {
                        // Lógica do Botão Adicionar (Fica no final)
                        if (index == _pets.length) {
                          return GestureDetector(
                            onTap: _abrirModalAdicionarPet,
                            child: Container(
                              width: 60,
                              margin: EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, color: _corAcai, size: 20),
                                  Text(
                                    "Novo",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _corAcai,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        // Lógica dos Pets
                        final pet = _pets[index];
                        final isSelected = pet['id'] == _petId;
                        return GestureDetector(
                          onTap: () => setState(() => _petId = pet['id']),
                          child: Container(
                            margin: EdgeInsets.only(right: 10),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? _corAcai : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? _corAcai
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  pet['tipo'] == 'cao'
                                      ? FontAwesomeIcons.dog
                                      : FontAwesomeIcons.cat,
                                  size: 14,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  pet['nome'],
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[800],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 10),

                  // --- SELEÇÃO DE SERVIÇO ---
                  _sectionTitle("Serviço"),
                  SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactServiceCard(
                          "Banho",
                          FontAwesomeIcons.shower,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildCompactServiceCard(
                          "Tosa",
                          FontAwesomeIcons.scissors,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 10),

                  // --- DATA ---
                  _sectionTitle("Quando?"),
                  SizedBox(height: 5),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _listaDias.length,
                      itemBuilder: (ctx, index) {
                        final dia = _listaDias[index];
                        final isSelected = DateUtils.isSameDay(
                          dia,
                          _dataSelecionada,
                        );
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _dataSelecionada = dia;
                              _horarioSelecionado = null;
                            });
                            _buscarHorarios();
                          },
                          child: Container(
                            width: 45,
                            margin: EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: isSelected ? _corAcai : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? _corAcai
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('dd').format(dia),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'EEE',
                                    'pt_BR',
                                  ).format(dia).substring(0, 3).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: isSelected
                                        ? Colors.white70
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 10),

                  // --- HORÁRIOS ---
                  _sectionTitle("Horários"),
                  SizedBox(height: 5),
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(color: _corAcai),
                          )
                        : _gradeHorarios.isEmpty
                        ? Center(
                            child: Text(
                              "Nenhum horário livre.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  childAspectRatio: 1.8,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: _gradeHorarios.length,
                            itemBuilder: (ctx, idx) {
                              final item = _gradeHorarios[idx];
                              final isLivre = item['livre'];
                              final isSelected =
                                  _horarioSelecionado == item['hora'];
                              return GestureDetector(
                                onTap: isLivre
                                    ? () => setState(
                                        () =>
                                            _horarioSelecionado = item['hora'],
                                      )
                                    : null,
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _corAcai
                                        : (isLivre
                                              ? Colors.white
                                              : Colors.grey[100]),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? _corAcai
                                          : (isLivre
                                                ? Colors.grey[300]!
                                                : Colors.transparent),
                                    ),
                                  ),
                                  child: Text(
                                    item['hora'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
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

                  // Campo de Obs e Aviso
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _obsController,
                        style: TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "Observações (Opcional)...",
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 0,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 12, color: Colors.blue),
                        SizedBox(width: 5),
                        Text(
                          "Valor sob avaliação na recepção.",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Botão Fixo
          Container(
            padding: EdgeInsets.all(15),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed:
                    (_petId != null &&
                        _horarioSelecionado != null &&
                        !_isLoading)
                    ? _confirmarAgendamento
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey[700],
      ),
    );
  }

  Widget _buildCompactServiceCard(String label, IconData icon) {
    final isSelected = _servicoSelecionado == label;
    return GestureDetector(
      onTap: () {
        setState(() => _servicoSelecionado = label);
        _buscarHorarios();
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _corAcai : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? _corAcai : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : _corAcai),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
