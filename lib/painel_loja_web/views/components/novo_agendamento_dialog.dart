import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/config/app_config.dart';

class NovoAgendamentoDialog extends StatefulWidget {
  const NovoAgendamentoDialog({super.key});

  @override
  _NovoAgendamentoDialogState createState() => _NovoAgendamentoDialogState();
}

class _NovoAgendamentoDialogState extends State<NovoAgendamentoDialog> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  final _buscaController = TextEditingController();

  // Dados
  String? _clienteId;
  String? _clienteNome;
  List<Map<String, dynamic>> _petsEncontrados = [];
  String? _petIdSelecionado;

  String? _servicoSelecionado;
  String? _profissionalIdSelecionado;
  String? _profissionalNomeSelecionado;

  DateTime _dataSelecionada = DateTime.now();
  String? _horarioSelecionado;
  bool _isLoadingHorarios = false;
  List<Map<String, dynamic>> _gradeHorarios = [];

  final List<String> _servicosDisponiveis = [
    'Banho',
    'Tosa',
    'Banho e Tosa',
    'Higiênica',
  ];

  // Cores
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    // Opcional: Se quiser carregar horários iniciais ao abrir (se já tiver serviço padrão)
  }

  // --- LÓGICA ---

  void _mudarData(int dias) {
    setState(() {
      _dataSelecionada = _dataSelecionada.add(Duration(days: dias));
      // Impede datas passadas
      if (_dataSelecionada.isBefore(
        DateTime.now().subtract(Duration(days: 1)),
      )) {
        _dataSelecionada = DateTime.now();
      }
    });
    _buscarHorariosDisponiveis();
  }

  Future<void> _selecionarDataPopup() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: _corAcai),
          ),
          child: child!,
        );
      },
    );
    if (d != null) {
      setState(() => _dataSelecionada = d);
      _buscarHorariosDisponiveis();
    }
  }

  Future<void> _buscarHorariosDisponiveis() async {
    if (_servicoSelecionado == null) return;

    setState(() {
      _isLoadingHorarios = true;
      _gradeHorarios = [];
      _horarioSelecionado = null;
    });

    try {
      final dataString = DateFormat('yyyy-MM-dd').format(_dataSelecionada);
      final servicoEnvio = _servicoSelecionado!.toLowerCase();

      final result = await _functions.httpsCallable('buscarHorarios').call({
        'dataConsulta': dataString,
        'servico': servicoEnvio,
        // 'profissionalId': _profissionalIdSelecionado
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
      // Ignora erro visualmente ou mostra snackbar discreto
      print("Erro horarios: $e");
    } finally {
      if (mounted) setState(() => _isLoadingHorarios = false);
    }
  }

  void _buscarCliente() async {
    if (_buscaController.text.isEmpty) return;
    String termo = _buscaController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (termo.isEmpty) {
      _showSnack("Digite apenas números do CPF", Colors.orange);
      return;
    }

    final snap = await _db
        .collection('users')
        .where('cpf', isEqualTo: termo)
        .get();

    if (snap.docs.isNotEmpty) {
      final userDoc = snap.docs.first;
      final uData = userDoc.data();
      final petsSnap = await _db
          .collection('users')
          .doc(userDoc.id)
          .collection('pets')
          .get();

      final petsList = petsSnap.docs
          .map(
            (p) => {
              'id': p.id,
              'nome': p['nome'],
              'raca': p['raca'] ?? 'SRD',
              'tipo': p['tipo'] ?? 'cao',
            },
          )
          .toList();

      setState(() {
        _clienteId = userDoc.id;
        _clienteNome = uData['nome'];
        _petsEncontrados = petsList;
        _petIdSelecionado = petsList.isNotEmpty ? petsList.first['id'] : null;
      });
    } else {
      _showSnack("Cliente não encontrado", Colors.red);
      setState(() {
        _clienteId = null;
        _clienteNome = null;
        _petsEncontrados = [];
      });
    }
  }

  void _salvarAgendamento() async {
    if (!_podeSalvar) return;

    final dataHoraString =
        "${DateFormat('yyyy-MM-dd').format(_dataSelecionada)} $_horarioSelecionado";
    final dataInicio = DateFormat('yyyy-MM-dd HH:mm').parse(dataHoraString);
    final dataFim = dataInicio.add(Duration(hours: 1)); // Duração estimada

    await _db
        .collection('tenants')
        .doc(AppConfig.tenantId)
        .collection('agendamentos')
        .add({
      'userId': _clienteId,
      'cliente_nome': _clienteNome, // Importante para busca funcionar
      'pet_id': _petIdSelecionado,
      // Salvar nome do pet também ajuda na busca: 'pet_nome': ...
      'servico': _servicoSelecionado!.toLowerCase(),
      'servicoNorm': _servicoSelecionado,
      'data_inicio': Timestamp.fromDate(dataInicio),
      'data_fim': Timestamp.fromDate(dataFim),
      'status': 'agendado',
      'status_pagamento': 'aguardando_pagamento',
      'criado_por_admin': true,
      'criado_em': FieldValue.serverTimestamp(),
      'profissional_id': _profissionalIdSelecionado,
      'profissional_nome': _profissionalNomeSelecionado,
      'valor': 0.0,
    });

    Navigator.pop(context);
    _showSnack("Agendamento realizado! ✅", Colors.green);
  }

  bool get _podeSalvar {
    return _clienteId != null &&
        _petIdSelecionado != null &&
        _servicoSelecionado != null &&
        _horarioSelecionado != null;
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 900,
        height: 550, // Altura reduzida para garantir que cabe em telas menores
        child: Column(
          children: [
            // HEADER
            Container(
              padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _corLilas,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.add_task, color: _corAcai, size: 22),
                      ),
                      SizedBox(width: 15),
                      Text(
                        "Novo Agendamento",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // BODY SPLIT
            Expanded(
              child: Row(
                children: [
                  // --- COLUNA 1: DADOS (40%) ---
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // BUSCA CPF
                            _label("1. Identificar Cliente"),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _buscaController,
                                    decoration: _inputDecoration(
                                      "CPF do Tutor",
                                      Icons.search,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onSubmitted: (_) => _buscarCliente(),
                                  ),
                                ),
                                SizedBox(width: 8),
                                InkWell(
                                  onTap: _buscarCliente,
                                  child: Container(
                                    padding: EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: _corAcai,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.search,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // CLIENTE ENCONTRADO
                            if (_clienteNome != null) ...[
                              SizedBox(height: 15),
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "$_clienteNome",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.green[900],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 15),
                              _label("Pet"),
                              SizedBox(height: 5),
                              DropdownButtonFormField<String>(
                                initialValue: _petIdSelecionado,
                                isDense: true,
                                decoration: _inputDecoration(
                                  "Selecione o Pet",
                                  FontAwesomeIcons.dog,
                                ),
                                items: _petsEncontrados
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p['id'] as String,
                                        child: Text("${p['nome']}"),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _petIdSelecionado = v),
                              ),
                            ],

                            Divider(height: 30),

                            // SERVIÇO
                            _label("2. Serviço"),
                            SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _servicoSelecionado,
                              isDense: true,
                              decoration: _inputDecoration(
                                "Tipo de Serviço",
                                Icons.cut,
                              ),
                              items: _servicosDisponiveis
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                setState(() => _servicoSelecionado = v);
                                _buscarHorariosDisponiveis();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- COLUNA 2: DATA E HORA COMPACTA (60%) ---
                  Expanded(
                    flex: 6,
                    child: Container(
                      color: _corFundo,
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label("3. Disponibilidade"),
                          SizedBox(height: 10),

                          // --- NAVEGADOR DE DATA COMPACTO (Aqui está a mágica da economia de espaço) ---
                          Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.chevron_left),
                                  onPressed: () => _mudarData(-1),
                                ),
                                InkWell(
                                  onTap: _selecionarDataPopup,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: _corAcai,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        DateFormat(
                                              "EEEE, dd 'de' MMMM",
                                              "pt_BR",
                                            )
                                            .format(_dataSelecionada)
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.chevron_right),
                                  onPressed: () => _mudarData(1),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 20),

                          // HEADER HORÁRIOS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Horários Disponíveis",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (_isLoadingHorarios)
                                SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 10),

                          // GRADE DE HORÁRIOS (Expansível)
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: _servicoSelecionado == null
                                  ? Center(
                                      child: Text(
                                        "Selecione o serviço para ver horários",
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 13,
                                        ),
                                      ),
                                    )
                                  : _gradeHorarios.isEmpty &&
                                        !_isLoadingHorarios
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.event_busy,
                                            color: Colors.orange[200],
                                          ),
                                          Text(
                                            "Agenda cheia ou fechada.",
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      child: Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        alignment: WrapAlignment.start,
                                        children: _gradeHorarios.map((slot) {
                                          bool livre = slot['livre'];
                                          String hora = slot['hora'];
                                          bool isSelected =
                                              _horarioSelecionado == hora;

                                          if (!livre) {
                                            return SizedBox(); // Esconde ocupados
                                          }

                                          return InkWell(
                                            onTap: () => setState(
                                              () => _horarioSelecionado = hora,
                                            ),
                                            child: Container(
                                              width: 80,
                                              padding: EdgeInsets.symmetric(
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? _corAcai
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? _corAcai
                                                      : Colors.grey[300]!,
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                hora,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // FOOTER
            Container(
              padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancelar",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _podeSalvar
                          ? Colors.green
                          : Colors.grey[300],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _podeSalvar ? _salvarAgendamento : null,
                    child: Text(
                      "CONFIRMAR AGENDAMENTO",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey[600],
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey[500], size: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      labelStyle: TextStyle(fontSize: 13),
    );
  }
}
