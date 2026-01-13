import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart'; // Importante para a verificação real
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class NovoAgendamentoDialog extends StatefulWidget {
  @override
  _NovoAgendamentoDialogState createState() => _NovoAgendamentoDialogState();
}

class _NovoAgendamentoDialogState extends State<NovoAgendamentoDialog> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Conexão com Funções (Mesma região do App)
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  final _cpfController = TextEditingController();

  // Dados do Agendamento
  String? _clienteId;
  String? _clienteNome;
  List<Map<String, dynamic>> _petsEncontrados = [];
  String? _petIdSelecionado;

  String? _servicoSelecionado;
  String? _profissionalIdSelecionado;
  String? _profissionalNomeSelecionado;

  DateTime _dataSelecionada = DateTime.now();
  String? _horarioSelecionado; // String "HH:mm" vinda do servidor

  bool _isLoadingHorarios = false;
  List<Map<String, dynamic>> _gradeHorarios = []; // Grade vinda do servidor

  // Lista de Serviços
  final List<String> _servicosDisponiveis = [
    'Banho',
    'Tosa',
    'Banho + Tosa',
    'Hidratação',
    'Corte de Unhas',
  ];

  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);

  // --- LÓGICA DE SERVIDOR (Igual ao App) ---
  Future<void> _buscarHorariosDisponiveis() async {
    if (_servicoSelecionado == null) return;

    setState(() {
      _isLoadingHorarios = true;
      _gradeHorarios = [];
      _horarioSelecionado = null; // Reseta seleção anterior
    });

    try {
      final dataString = DateFormat('yyyy-MM-dd').format(_dataSelecionada);
      final servicoEnvio = _servicoSelecionado!.toLowerCase();

      // Chama a mesma função que o App usa
      final result = await _functions.httpsCallable('buscarHorarios').call({
        'dataConsulta': dataString,
        'servico': servicoEnvio,
        // Se sua cloud function suportar filtro por profissional, envie aqui:
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao buscar horários: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingHorarios = false);
    }
  }

  void _salvarAgendamento() async {
    // Validações
    if (_clienteId == null || _petIdSelecionado == null) {
      _showSnack("Identifique o cliente e o pet", Colors.orange);
      return;
    }
    if (_servicoSelecionado == null) {
      _showSnack("Selecione o serviço", Colors.orange);
      return;
    }
    if (_horarioSelecionado == null) {
      _showSnack("Selecione um horário disponível", Colors.orange);
      return;
    }

    // Monta Data Final combinando o dia selecionado com a hora escolhida
    final dataHoraString =
        "${DateFormat('yyyy-MM-dd').format(_dataSelecionada)} $_horarioSelecionado";
    final dataInicio = DateFormat('yyyy-MM-dd HH:mm').parse(dataHoraString);
    final dataFim = dataInicio.add(Duration(hours: 1)); // Duração estimada

    // Salva
    await _db.collection('agendamentos').add({
      'userId': _clienteId,
      'pet_id': _petIdSelecionado,
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
    _showSnack("Agendamento realizado com sucesso! ✅", Colors.green);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _buscarCliente() async {
    if (_cpfController.text.isEmpty) return;
    String cpfLimpo = _cpfController.text.replaceAll(RegExp(r'[^0-9]'), '');

    final snap = await _db
        .collection('users')
        .where('cpf', isEqualTo: cpfLimpo)
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
            (p) => {'id': p.id, 'nome': p['nome'], 'raca': p['raca'] ?? 'SRD'},
          )
          .toList();

      setState(() {
        _clienteId = userDoc.id;
        _clienteNome = uData['nome'];
        _petsEncontrados = petsList;
        _petIdSelecionado = null;
      });
    } else {
      _showSnack("Cliente não encontrado", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _corLilas,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.calendar_month, color: _corAcai),
          ),
          SizedBox(width: 10),
          Text(
            "Novo Agendamento",
            style: TextStyle(color: _corAcai, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Container(
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- 1. CLIENTE ---
              _buildSectionTitle("1. Cliente e Pet"),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cpfController,
                      decoration: _inputDecoration(
                        "CPF do Tutor",
                        Icons.search,
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _buscarCliente(),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _corAcai,
                      padding: EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 20,
                      ),
                    ),
                    onPressed: _buscarCliente,
                    child: Icon(Icons.search, color: Colors.white),
                  ),
                ],
              ),
              if (_clienteNome != null) ...[
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Cliente: $_clienteNome",
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _petIdSelecionado,
                  decoration: _inputDecoration(
                    "Selecione o Pet",
                    FontAwesomeIcons.dog,
                  ),
                  items: _petsEncontrados
                      .map(
                        (p) => DropdownMenuItem(
                          value: p['id'] as String,
                          child: Text("${p['nome']} (${p['raca']})"),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _petIdSelecionado = v),
                ),
              ],

              SizedBox(height: 20),

              // --- 2. SERVIÇO E PROFISSIONAL ---
              _buildSectionTitle("2. Detalhes do Serviço"),
              DropdownButtonFormField<String>(
                value: _servicoSelecionado,
                decoration: _inputDecoration("Serviço", Icons.cut),
                items: _servicosDisponiveis
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _servicoSelecionado = v);
                  _buscarHorariosDisponiveis(); // Atualiza horários ao mudar serviço
                },
              ),
              SizedBox(height: 10),

              StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('profissionais')
                    .where('ativo', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return LinearProgressIndicator();
                  var pros = snapshot.data!.docs;
                  return DropdownButtonFormField<String>(
                    value: _profissionalIdSelecionado,
                    decoration: _inputDecoration(
                      "Profissional (Opcional)",
                      Icons.person,
                    ),
                    items: pros.map((d) {
                      final data = d.data() as Map;
                      return DropdownMenuItem(
                        value: d.id,
                        child: Text(data['nome']),
                        onTap: () =>
                            _profissionalNomeSelecionado = data['nome'],
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() => _profissionalIdSelecionado = v);
                      // Se a cloud function suportar filtro por ID, descomente abaixo:
                      // _buscarHorariosDisponiveis();
                    },
                  );
                },
              ),

              SizedBox(height: 20),

              // --- 3. DATA E HORÁRIO (SERVER SIDE) ---
              _buildSectionTitle("3. Data e Horário (Verificado)"),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _dataSelecionada,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) {
                    setState(() => _dataSelecionada = d);
                    _buscarHorariosDisponiveis(); // Atualiza horários ao mudar data
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: _corAcai),
                      SizedBox(width: 10),
                      Text(
                        DateFormat(
                          'dd/MM/yyyy - EEEE',
                          'pt_BR',
                        ).format(_dataSelecionada),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 15),

              // GRADE DE HORÁRIOS
              if (_isLoadingHorarios)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_servicoSelecionado == null)
                Text(
                  "Selecione um serviço para ver horários.",
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else if (_gradeHorarios.isEmpty)
                Container(
                  padding: EdgeInsets.all(10),
                  width: double.infinity,
                  color: Colors.orange[50],
                  child: Text(
                    "Sem horários disponíveis nesta data.",
                    style: TextStyle(color: Colors.orange[800]),
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _gradeHorarios.map((slot) {
                    bool livre = slot['livre'];
                    String hora = slot['hora'];
                    bool isSelected = _horarioSelecionado == hora;

                    return ChoiceChip(
                      label: Text(hora),
                      selected: isSelected,
                      onSelected: livre
                          ? (selected) {
                              setState(
                                () => _horarioSelecionado = selected
                                    ? hora
                                    : null,
                              );
                            }
                          : null,
                      selectedColor: _corAcai,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (livre ? Colors.black : Colors.grey),
                      ),
                      disabledColor: Colors.grey[200],
                      backgroundColor: Colors.white,
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancelar"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
          ),
          onPressed: _isLoadingHorarios ? null : _salvarAgendamento,
          child: Text(
            "CONFIRMAR AGENDAMENTO",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
          fontSize: 14,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _corAcai, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
    );
  }
}
