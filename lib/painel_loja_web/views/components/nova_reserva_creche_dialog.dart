import 'package:agenpet/painel_loja_web/views/components/cadastro_rapido_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:agenpet/utils/validators.dart';
import 'package:table_calendar/table_calendar.dart';

class NovaReservaCrecheDialog extends StatefulWidget {
  const NovaReservaCrecheDialog({super.key});

  @override
  _NovaReservaCrecheDialogState createState() =>
      _NovaReservaCrecheDialogState();
}

class _NovaReservaCrecheDialogState extends State<NovaReservaCrecheDialog> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );
  final _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  // Cores
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF5F7FA);

  // Controladores
  final _cpfController = TextEditingController();

  // Estado
  bool _buscandoCliente = false;
  bool _enviandoReserva = false;
  bool _clienteNaoEncontrado = false;

  String? _nomeCliente;
  String? _petIdSelecionado;
  List<Map<String, dynamic>> _petsEncontrados = [];

  // Datas (Seleção Múltipla)
  final Set<DateTime> _selectedDates = {};
  DateTime _focusedDay = DateTime.now();

  double _valorDiaria = 0.0;

  @override
  void initState() {
    super.initState();
    _carregarConfig();
  }

  void _carregarConfig() async {
    final doc = await _db
        .collection('tenants')
        .doc(AppConfig.tenantId)
        .collection('config')
        .doc('parametros')
        .get();
    if (doc.exists) {
      setState(() {
        _valorDiaria = (doc.data()?['preco_creche'] ?? 0).toDouble();
      });
    }
  }

  // --- LÓGICA DE DATAS ---

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      // Normaliza para remover hora
      final normalized = DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
      );

      if (_selectedDates.contains(normalized)) {
        _selectedDates.remove(normalized);
      } else {
        _selectedDates.add(normalized);
      }
    });
  }

  // --- LÓGICA DE CLIENTE ---

  Future<void> _buscarCliente() async {
    if (_cpfController.text.isEmpty) return;

    String cpfLimpo = _cpfController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (!Validators.isCpfValido(cpfLimpo)) {
      _showSnack("CPF inválido", Colors.red);
      return;
    }

    setState(() {
      _buscandoCliente = true;
      _clienteNaoEncontrado = false;
    });

    try {
      final userDoc = await _db.collection('users').doc(cpfLimpo).get();

      if (userDoc.exists) {
        final petsSnap = await _db
            .collection('users')
            .doc(cpfLimpo)
            .collection('pets')
            .get();
        setState(() {
          _nomeCliente = userDoc.data()?['nome'];
          _petsEncontrados = petsSnap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _petIdSelecionado = _petsEncontrados.isNotEmpty
              ? _petsEncontrados.first['id']
              : null;
        });
      } else {
        setState(() {
          _nomeCliente = null;
          _petsEncontrados = [];
          _clienteNaoEncontrado = true;
        });
        _showSnack("Cliente não encontrado.", Colors.orange);
      }
    } catch (e) {
      print(e);
    } finally {
      setState(() => _buscandoCliente = false);
    }
  }

  void _abrirCadastroRapido() async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CadastroRapidoDialog(cpfInicial: _cpfController.text),
    );

    if (result != null && result['sucesso'] == true) {
      setState(() {
        _clienteNaoEncontrado = false;
        _nomeCliente = result['nome_cliente'];
        _cpfController.text = result['cpf'];
        _petsEncontrados = [result['pet_novo']];
        _petIdSelecionado = result['pet_novo']['id'];
      });
    }
  }

  Future<void> _confirmarReserva() async {
    setState(() => _enviandoReserva = true);

    try {
      // Converte para lista de strings ISO8601
      List<String> dates =
          _selectedDates.map((d) => d.toIso8601String()).toList();

      await _functions.httpsCallable('reservarCreche').call({
        'tenantId': AppConfig.tenantId,
        'cpf_user': _cpfController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'pet_id': _petIdSelecionado,
        'dates': dates, // <--- Agora enviamos array de datas
      });

      Navigator.pop(context);
      _showSnack("Reserva Creche realizada com sucesso! 🎒", Colors.green);
    } catch (e) {
      String erro = "Erro desconhecido";
      if (e is FirebaseFunctionsException) erro = e.message ?? e.code;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Erro na Reserva"),
          content: Text(erro),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text("OK")),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _enviandoReserva = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  bool get _podeSalvar =>
      _petIdSelecionado != null &&
      _selectedDates.isNotEmpty &&
      !_enviandoReserva;

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    int dias = _selectedDates.length;
    double valorEstimado = dias * _valorDiaria;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 900,
        height: 600, // Aumentado um pouco para caber o calendário
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
                        child: Icon(
                          FontAwesomeIcons.school,
                          color: _corAcai,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Nova Reserva Creche",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            "Selecione os dias da estadia",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
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
                  // --- COLUNA 1: DADOS (35%) ---
                  Expanded(
                    flex: 35,
                    child: Container(
                      padding: EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label("1. Identificar Tutor"),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _cpfController,
                                    decoration: _inputDecoration(
                                      "CPF",
                                      Icons.search,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onSubmitted: (_) => _buscarCliente(),
                                  ),
                                ),
                                SizedBox(width: 8),
                                InkWell(
                                  onTap: _buscandoCliente
                                      ? null
                                      : _buscarCliente,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _corAcai,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: _buscandoCliente
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(
                                            Icons.search,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                  ),
                                ),
                              ],
                            ),

                            // Alerta Não Encontrado
                            if (_clienteNaoEncontrado) ...[
                              SizedBox(height: 15),
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red[100]!),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      "Cliente não encontrado",
                                      style: TextStyle(
                                        color: Colors.red[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        minimumSize: Size(double.infinity, 35),
                                      ),
                                      onPressed: _abrirCadastroRapido,
                                      child: Text("Cadastrar Agora"),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Cliente Encontrado
                            if (_nomeCliente != null) ...[
                              SizedBox(height: 20),
                              Container(
                                padding: EdgeInsets.all(12),
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
                                      Icons.person,
                                      size: 18,
                                      color: Colors.green[800],
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _nomeCliente!,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.green[900],
                                            ),
                                          ),
                                          Text(
                                            "Cadastro verificado",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green[800],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 20),
                              _label("2. Selecionar Pet"),
                              SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _petIdSelecionado,
                                isDense: true,
                                decoration: _inputDecoration(
                                  "Escolha o Aluno",
                                  FontAwesomeIcons.dog,
                                ),
                                items: _petsEncontrados
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p['id'] as String,
                                        child: Text(
                                          "${p['nome']} (${p['tipo'] ?? 'pet'})",
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _petIdSelecionado = v),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- COLUNA 2: CALENDÁRIO (65%) ---
                  Expanded(
                    flex: 65,
                    child: Container(
                      color: _corFundo,
                      padding: EdgeInsets.all(25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label("3. Selecione os dias no calendário"),
                          SizedBox(height: 10),

                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: TableCalendar(
                                locale: 'pt_BR',
                                firstDay: DateTime.now(),
                                lastDay: DateTime.now().add(
                                  Duration(days: 90),
                                ),
                                focusedDay: _focusedDay,
                                selectedDayPredicate: (day) =>
                                    _selectedDates.contains(
                                      DateTime(day.year, day.month, day.day),
                                    ),
                                onDaySelected: _onDaySelected,
                                calendarStyle: CalendarStyle(
                                  selectedDecoration: BoxDecoration(
                                    color: _corAcai,
                                    shape: BoxShape.circle,
                                  ),
                                  todayDecoration: BoxDecoration(
                                    color: _corAcai.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                headerStyle: HeaderStyle(
                                  formatButtonVisible: false,
                                  titleCentered: true,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 20),

                          // RESUMO FINANCEIRO CARD
                          Container(
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.blue[100]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
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
                                      "Dias Selecionados",
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    Text(
                                      "$dias dias",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "Valor Estimado",
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    Text(
                                      "R\$ ${valorEstimado.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 24,
                                        color: _corAcai,
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
                    onPressed: _podeSalvar ? _confirmarReserva : null,
                    child: _enviandoReserva
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "CONFIRMAR RESERVA",
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

  // --- WIDGETS AUXILIARES ---

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
