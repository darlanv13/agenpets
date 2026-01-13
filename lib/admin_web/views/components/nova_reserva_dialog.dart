import 'package:agenpet/admin_web/views/components/cadastro_rapido_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class NovaReservaDialog extends StatefulWidget {
  @override
  _NovaReservaDialogState createState() => _NovaReservaDialogState();
}

class _NovaReservaDialogState extends State<NovaReservaDialog> {
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

  // Controladores
  final _cpfController = TextEditingController();

  // Estado
  bool _buscandoCliente = false;
  bool _enviandoReserva = false;
  bool _clienteNaoEncontrado = false;

  String? _nomeCliente;
  String? _petIdSelecionado;
  List<Map<String, dynamic>> _petsEncontrados = [];
  DateTimeRange? _datasSelecionadas;
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
        _valorDiaria = (doc.data()?['preco_hotel_diaria'] ?? 0).toDouble();
      });
    }
  }

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
          _petIdSelecionado = null; // Reseta seleção
        });
      } else {
        setState(() {
          _nomeCliente = null;
          _petsEncontrados = [];
          _clienteNaoEncontrado = true;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Cliente não encontrado.")));
      }
    } catch (e) {
      print(e);
    } finally {
      setState(() => _buscandoCliente = false);
    }
  }

  // Método para abrir o Dialog de Cadastro
  void _abrirCadastroRapido() async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CadastroRapidoDialog(cpfInicial: _cpfController.text),
    );

    if (result != null && result['sucesso'] == true) {
      // Cadastro feito! Já preenche os dados e carrega o pet novo
      setState(() {
        _clienteNaoEncontrado = false;
        _nomeCliente = result['nome_cliente'];
        _cpfController.text =
            result['cpf']; // Atualiza CPF caso tenha corrigido

        // Adiciona o pet recém criado na lista e seleciona
        _petsEncontrados = [result['pet_novo']];
        _petIdSelecionado = result['pet_novo']['id'];
      });

      // Opcional: Recarregar do banco pra garantir (mas o result já traz os dados)
    }
  }

  Future<void> _confirmarReserva() async {
    if (_petIdSelecionado == null || _datasSelecionadas == null) return;

    setState(() => _enviandoReserva = true);

    try {
      // Chama a Cloud Function 'reservarHotel'
      // Ela já valida lotação e cria o registro com segurança
      await _functions.httpsCallable('reservarHotel').call({
        'cpf_user': _cpfController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'pet_id': _petIdSelecionado,
        'check_in': _datasSelecionadas!.start.toIso8601String(),
        'check_out': _datasSelecionadas!.end.toIso8601String(),
      });

      Navigator.pop(context); // Fecha o Dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Reserva realizada com sucesso! 🏨"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      String erro = "Erro desconhecido";
      if (e is FirebaseFunctionsException) erro = e.message ?? e.code;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Não foi possível reservar"),
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

  @override
  Widget build(BuildContext context) {
    // Cálculo Estimado
    double valorEstimado = 0;
    int dias = 0;
    if (_datasSelecionadas != null) {
      dias = _datasSelecionadas!.duration.inDays;
      if (dias < 1) dias = 1;
      valorEstimado = dias * _valorDiaria;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 550,
        padding: EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _corLilas,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.hotel_rounded, color: _corAcai),
                ),
                SizedBox(width: 15),
                Text(
                  "Nova Reserva",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _corAcai,
                  ),
                ),
              ],
            ),
            SizedBox(height: 25),

            // 1. Busca Cliente
            Text(
              "1. Identificar Tutor",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cpfController,
                    decoration: InputDecoration(
                      labelText: "CPF (somente números)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 0,
                      ),
                      prefixIcon: Icon(Icons.search),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _buscarCliente(),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _corAcai,
                    padding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _buscandoCliente ? null : _buscarCliente,
                  child: _buscandoCliente
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.check, color: Colors.white),
                ),
              ],
            ),
            // ALERTA DE CLIENTE NÃO ENCONTRADO
            if (_clienteNaoEncontrado)
              Container(
                margin: EdgeInsets.only(top: 15),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red[100]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Cliente não encontrado.",
                        style: TextStyle(color: Colors.red[800]),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _corAcai,
                        padding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                      ),
                      onPressed: _abrirCadastroRapido,
                      child: Text(
                        "Cadastrar Cliente",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Resultado Cliente
            if (_nomeCliente != null) ...[
              SizedBox(height: 15),
              Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.green[800]),
                    SizedBox(width: 8),
                    Text(
                      "Cliente: $_nomeCliente",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // 2. Selecionar Pet
              Text(
                "2. Selecionar Pet",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _petIdSelecionado,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 15),
                  hintText: "Escolha o hóspede",
                ),
                items: _petsEncontrados
                    .map(
                      (p) => DropdownMenuItem(
                        value: p['id'] as String,
                        child: Text("${p['nome']} (${p['tipo'] ?? 'pet'})"),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _petIdSelecionado = v),
              ),

              SizedBox(height: 20),

              // 3. Datas
              Text(
                "3. Período da Estadia",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          primaryColor: _corAcai,
                          colorScheme: ColorScheme.light(
                            primary: _corAcai,
                            onPrimary: Colors.white,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null)
                    setState(() => _datasSelecionadas = picked);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _datasSelecionadas == null
                            ? "Selecionar Entrada e Saída"
                            : "${DateFormat('dd/MM').format(_datasSelecionadas!.start)}  até  ${DateFormat('dd/MM').format(_datasSelecionadas!.end)}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _datasSelecionadas != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      Icon(Icons.calendar_month, color: _corAcai),
                    ],
                  ),
                ),
              ),

              // 4. Resumo Valor
              if (_datasSelecionadas != null)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "$dias diárias x R\$ $_valorDiaria = ",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        "R\$ ${valorEstimado.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: _corAcai,
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            SizedBox(height: 30),

            // Botões
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _corAcai,
                    padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed:
                      (_petIdSelecionado != null &&
                          _datasSelecionadas != null &&
                          !_enviandoReserva)
                      ? _confirmarReserva
                      : null,
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
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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
