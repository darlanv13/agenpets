import 'package:agenpet/admin_web/views/components/cadastro_rapido_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class NovaReservaCrecheDialog extends StatefulWidget {
  @override
  _NovaReservaCrecheDialogState createState() => _NovaReservaCrecheDialogState();
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

  // Datas (Inicia: Hoje -> Amanhã)
  DateTime _checkIn = DateTime.now();
  DateTime _checkOut = DateTime.now().add(Duration(days: 1));

  double _valorDiaria = 0.0;

  @override
  void initState() {
    super.initState();
    _carregarConfig();
  }

  void _carregarConfig() async {
    final doc = await _db.collection('config').doc('parametros').get();
    if (doc.exists) {
      setState(() {
        _valorDiaria = (doc.data()?['preco_creche_diaria'] ?? 0).toDouble();
      });
    }
  }

  // --- LÓGICA DE DATAS ---

  void _ajustarCheckIn(int dias) {
    setState(() {
      _checkIn = _checkIn.add(Duration(days: dias));
      // Validação: Não permite passado
      if (_checkIn.isBefore(DateTime.now().subtract(Duration(days: 1)))) {
        _checkIn = DateTime.now();
      }
      // Validação: Empurra o checkout se encostar
      if (!_checkOut.isAfter(_checkIn)) {
        _checkOut = _checkIn.add(Duration(days: 1));
      }
    });
  }

  void _ajustarCheckOut(int dias) {
    setState(() {
      DateTime novaData = _checkOut.add(Duration(days: dias));
      // Validação: Checkout deve ser > Checkin
      if (novaData.isAfter(_checkIn)) {
        _checkOut = novaData;
      }
    });
  }

  Future<void> _selecionarDataPopup(bool isCheckIn) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isCheckIn ? _checkIn : _checkOut,
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
    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkIn = picked;
          if (!_checkOut.isAfter(_checkIn))
            _checkOut = _checkIn.add(Duration(days: 1));
        } else {
          if (picked.isAfter(_checkIn)) _checkOut = picked;
        }
      });
    }
  }

  // --- LÓGICA DE CLIENTE ---

  Future<void> _buscarCliente() async {
    if (_cpfController.text.isEmpty) return;

    setState(() {
      _buscandoCliente = true;
      _clienteNaoEncontrado = false;
    });
    String cpfLimpo = _cpfController.text.replaceAll(RegExp(r'[^0-9]'), '');

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
      await _functions.httpsCallable('reservarCreche').call({
        'cpf_user': _cpfController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'pet_id': _petIdSelecionado,
        'check_in': _checkIn.toIso8601String(),
        'check_out': _checkOut.toIso8601String(),
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

  bool get _podeSalvar => _petIdSelecionado != null && !_enviandoReserva;

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    // Cálculos em tempo real
    int dias = _checkOut.difference(_checkIn).inDays;
    if (dias < 1) dias = 1;
    double valorEstimado = dias * _valorDiaria;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        width: 900,
        height: 550, // Altura otimizada
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
                            "Preencha os dados da estadia",
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
                  // --- COLUNA 1: DADOS (40%) ---
                  Expanded(
                    flex: 4,
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
                                      "CPF (apenas números)",
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
                                value: _petIdSelecionado,
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

                  // --- COLUNA 2: DATAS E VALORES (60%) ---
                  Expanded(
                    flex: 6,
                    child: Container(
                      color: _corFundo,
                      padding: EdgeInsets.all(25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label("3. Período da Estadia"),
                          SizedBox(height: 10),

                          // NAVEGADOR DE DATAS (Compacto e Funcional)
                          // Check-in
                          _buildDateNavigator(
                            "CHECK-IN (ENTRADA)",
                            _checkIn,
                            (d) => _ajustarCheckIn(d),
                            () => _selecionarDataPopup(true),
                          ),
                          SizedBox(height: 10),
                          // Check-out
                          _buildDateNavigator(
                            "CHECK-OUT (SAÍDA)",
                            _checkOut,
                            (d) => _ajustarCheckOut(d),
                            () => _selecionarDataPopup(false),
                          ),

                          Spacer(),

                          // RESUMO FINANCEIRO CARD
                          Container(
                            padding: EdgeInsets.all(20),
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
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Duração",
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    Text(
                                      "$dias diárias",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                          Spacer(),
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

  Widget _buildDateNavigator(
    String label,
    DateTime date,
    Function(int) onArrowClick,
    VoidCallback onTextClick,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 5, horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: Colors.grey[600]),
            onPressed: () => onArrowClick(-1),
            tooltip: "-1 dia",
          ),
          InkWell(
            onTap: onTextClick,
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: _corAcai),
                    SizedBox(width: 8),
                    Text(
                      DateFormat(
                        "dd/MM/yyyy (EEE)",
                        "pt_BR",
                      ).format(date).toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: Colors.grey[600]),
            onPressed: () => onArrowClick(1),
            tooltip: "+1 dia",
          ),
        ],
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
