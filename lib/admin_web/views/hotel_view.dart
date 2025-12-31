import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HotelView extends StatefulWidget {
  @override
  _HotelViewState createState() => _HotelViewState();
}

class _HotelViewState extends State<HotelView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // --- CORES AÇAÍ & LILÁS ---
  final Color _corAcai = Color(0xFF4A148C); // Roxo Escuro
  final Color _corLavanda = Color(0xFFAB47BC); // Roxo Médio
  final Color _corLilas = Color(0xFFF3E5F5); // Roxo Claríssimo
  final Color _corFundo = Color(0xFFFAFAFA);

  final int _capacidadeTotal = 60;
  final double _valorDiaria = 80.00;

  // --- CÁLCULO FINANCEIRO INTELIGENTE ---
  Map<String, dynamic> _calcularSituacaoFinanceira(Map<String, dynamic> data) {
    final checkIn = (data['check_in'] as Timestamp).toDate();
    final agora = DateTime.now();

    // 1. Calcula dias REAIS até agora (mínimo 1 dia)
    int diasReais = agora.difference(checkIn).inDays;
    if (diasReais < 1) diasReais = 1;

    // 2. Calcula valor que DEVERIA ser pago até agora
    double valorDevidoAtual = diasReais * _valorDiaria;

    // 3. Verifica quanto JÁ FOI PAGO
    double valorJaPago = 0.0;
    if (data['payment_status'] == 'paid') {
      // Se pagou pelo app, assumimos que pagou o previsto na reserva original
      valorJaPago = (data['valor_previsto'] ?? valorDevidoAtual).toDouble();
    }
    // Se tiver pagamentos parciais no futuro, somaria aqui.

    // 4. Calcula Diferença
    double saldoDevedor = valorDevidoAtual - valorJaPago;

    // Margem de erro pequena para evitar float points (ex: 0.000001)
    if (saldoDevedor < 0.1) saldoDevedor = 0;

    return {
      'dias_ficados': diasReais,
      'valor_total_atual': valorDevidoAtual,
      'valor_ja_pago': valorJaPago,
      'saldo_devedor': saldoDevedor,
      'tem_excedente': saldoDevedor > 0,
      'esta_totalmente_pago':
          saldoDevedor == 0 && data['payment_status'] == 'paid',
    };
  }

  // --- AÇÕES ---

  void _fazerCheckIn(String docId) async {
    await _db.collection('reservas_hotel').doc(docId).update({
      'status': 'hospedado',
      'check_in_real': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Check-in realizado! 🏠")));
  }

  void _processarSaida(String docId, Map<String, dynamic> data) {
    final fin = _calcularSituacaoFinanceira(data);

    if (fin['tem_excedente']) {
      // CASO 1: Tem que pagar diferença (Excedente ou Total)
      _abrirCaixa(
        docId,
        fin['saldo_devedor'],
        isExcedente: data['payment_status'] == 'paid',
      );
    } else {
      // CASO 2: Tudo pago, só sair
      _confirmarSaidaSimples(docId);
    }
  }

  void _confirmarSaidaSimples(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Check-out Liberado ✨", style: TextStyle(color: _corAcai)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 15),
            Text(
              "A conta está em dia.",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text("Deseja finalizar a hospedagem?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Voltar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _corAcai,
              padding: EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () async {
              await _db.collection('reservas_hotel').doc(docId).update({
                'status': 'concluido',
                'check_out_real': FieldValue.serverTimestamp(),
              });
              Navigator.pop(ctx);
            },
            child: Text("FINALIZAR ESTADIA"),
          ),
        ],
      ),
    );
  }

  void _abrirCaixa(
    String docId,
    double valorCobrar, {
    required bool isExcedente,
  }) {
    String metodo = 'dinheiro';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              isExcedente ? "Cobrar Diárias Extras 🕒" : "Receber Pagamento 💰",
              style: TextStyle(color: _corAcai, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isExcedente)
                  Container(
                    padding: EdgeInsets.all(10),
                    margin: EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "O cliente excedeu o tempo original. Cobre a diferença.",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                Text(
                  "Valor a Receber:",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                Text(
                  "R\$ ${valorCobrar.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: _corAcai,
                  ),
                ),

                SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: metodo,
                  decoration: InputDecoration(
                    labelText: "Forma de Pagamento",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.payment, color: _corAcai),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'dinheiro',
                      child: Text("Dinheiro"),
                    ),
                    DropdownMenuItem(
                      value: 'pix_balcao',
                      child: Text("Pix (Maquininha/Celular)"),
                    ),
                    DropdownMenuItem(
                      value: 'cartao_credito',
                      child: Text("Cartão de Crédito"),
                    ),
                    DropdownMenuItem(
                      value: 'cartao_debito',
                      child: Text("Cartão de Débito"),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => metodo = v!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Cancelar"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
                onPressed: () async {
                  await _db.collection('reservas_hotel').doc(docId).update({
                    'status': 'concluido',
                    'check_out_real': FieldValue.serverTimestamp(),
                    'payment_status': 'paid',
                    'metodo_pagamento_final': metodo,
                    'valor_total_final':
                        valorCobrar, // Salva quanto foi cobrado no final
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Recebido com sucesso!")),
                  );
                },
                child: Text("RECEBER & CHECK-OUT"),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- CADASTRO RÁPIDO (BALCÃO) - TEMA AÇAÍ ---
  Future<void> _abrirCadastroRapido(
    BuildContext context,
    String cpfPreenchido,
    Function(String, List<Map<String, dynamic>>) onSucesso,
  ) async {
    final _nomeController = TextEditingController();
    final _telController = TextEditingController();
    final _petNomeController = TextEditingController();
    final _petRacaController = TextEditingController();
    String _petTipo = 'cao';
    bool _salvando = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              "Cadastro Rápido ⚡",
              style: TextStyle(color: _corAcai, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Dados do Cliente (CPF: $cpfPreenchido)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _nomeController,
                      decoration: InputDecoration(
                        labelText: "Nome Completo",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person, color: _corAcai),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _telController,
                      decoration: InputDecoration(
                        labelText: "WhatsApp / Telefone",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone, color: _corAcai),
                      ),
                    ),

                    Divider(height: 30, color: _corLilas, thickness: 2),

                    Text(
                      "Dados do Primeiro Pet",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _corAcai,
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _petNomeController,
                      decoration: InputDecoration(
                        labelText: "Nome do Pet",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pets, color: _corAcai),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _petRacaController,
                      decoration: InputDecoration(
                        labelText: "Raça (Opcional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Text("Tipo: "),
                        Radio<String>(
                          activeColor: _corAcai,
                          value: 'cao',
                          groupValue: _petTipo,
                          onChanged: (v) => setStateModal(() => _petTipo = v!),
                        ),
                        Text("Cão"),
                        Radio<String>(
                          activeColor: _corAcai,
                          value: 'gato',
                          groupValue: _petTipo,
                          onChanged: (v) => setStateModal(() => _petTipo = v!),
                        ),
                        Text("Gato"),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _salvando
                    ? null
                    : () async {
                        if (_nomeController.text.isEmpty ||
                            _petNomeController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Preencha os nomes obrigatórios."),
                            ),
                          );
                          return;
                        }

                        setStateModal(() => _salvando = true);

                        try {
                          // 1. Criar Usuário
                          await _db.collection('users').doc(cpfPreenchido).set({
                            'cpf': cpfPreenchido,
                            'nome': _nomeController.text,
                            'telefone': _telController.text,
                            'criado_em': FieldValue.serverTimestamp(),
                          });

                          // 2. Criar Pet
                          final petRef = await _db
                              .collection('users')
                              .doc(cpfPreenchido)
                              .collection('pets')
                              .add({
                                'nome': _petNomeController.text,
                                'raca': _petRacaController.text.isEmpty
                                    ? 'SRD'
                                    : _petRacaController.text,
                                'tipo': _petTipo,
                                'donoCpf': cpfPreenchido,
                              });

                          // 3. Retornar
                          final novoPet = {
                            'id': petRef.id,
                            'nome': _petNomeController.text,
                            'tipo': _petTipo,
                            'raca': _petRacaController.text,
                          };

                          Navigator.pop(ctx);
                          onSucesso(_nomeController.text, [novoPet]);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Erro ao salvar: $e")),
                          );
                        }
                      },
                child: _salvando
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Text("SALVAR E USAR"),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- NOVA HOSPEDAGEM (BALCÃO) - TEMA AÇAÍ ---
  void _novaHospedagemManual() {
    String? _cpfBusca;
    String? _petIdSelecionado;
    List<Map<String, dynamic>> _petsEncontrados = [];
    DateTimeRange? _datas;
    bool _buscando = false;
    String? _nomeCliente;
    bool _clienteNaoEncontrado = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) {
          // Calcula valor em tempo real
          double valorEstimado = 0;
          if (_datas != null) {
            int dias = _datas!.duration.inDays;
            if (dias < 1) dias = 1;
            valorEstimado = dias * _valorDiaria;
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _corLilas,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.store, color: _corAcai),
                ),
                SizedBox(width: 10),
                Text(
                  "Hospedagem de Balcão",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _corAcai,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. BUSCA DE CLIENTE
                    Text(
                      "1. Localizar Tutor",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: "CPF do Cliente",
                              hintText: "000.000.000-00",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: _corAcai,
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (v) {
                              _cpfBusca = v;
                              if (_clienteNaoEncontrado)
                                setStateModal(
                                  () => _clienteNaoEncontrado = false,
                                );
                            },
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            if (_cpfBusca == null || _cpfBusca!.isEmpty) return;
                            setStateModal(() => _buscando = true);

                            final userDoc = await _db
                                .collection('users')
                                .doc(_cpfBusca)
                                .get();

                            if (userDoc.exists) {
                              _nomeCliente = userDoc.data()!['nome'];
                              _clienteNaoEncontrado = false;
                              final petsSnap = await _db
                                  .collection('users')
                                  .doc(_cpfBusca)
                                  .collection('pets')
                                  .get();
                              _petsEncontrados = petsSnap.docs
                                  .map((d) => {'id': d.id, ...d.data()})
                                  .toList();
                              _petIdSelecionado = null;
                            } else {
                              _petsEncontrados = [];
                              _nomeCliente = null;
                              _clienteNaoEncontrado = true;
                            }
                            setStateModal(() => _buscando = false);
                          },
                          child: _buscando
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text("BUSCAR"),
                        ),
                      ],
                    ),

                    // FEEDBACK DA BUSCA
                    if (_nomeCliente != null)
                      Container(
                        margin: EdgeInsets.only(top: 10),
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Cliente: $_nomeCliente",
                              style: TextStyle(
                                color: Colors.green[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_clienteNaoEncontrado)
                      Container(
                        margin: EdgeInsets.only(top: 10),
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Cliente não encontrado.",
                              style: TextStyle(color: Colors.red[800]),
                            ),
                            Spacer(),
                            TextButton.icon(
                              icon: Icon(Icons.person_add, color: _corAcai),
                              label: Text(
                                "CADASTRAR AGORA",
                                style: TextStyle(
                                  color: _corAcai,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                _abrirCadastroRapido(context, _cpfBusca!, (
                                  nome,
                                  pets,
                                ) {
                                  setStateModal(() {
                                    _nomeCliente = nome;
                                    _petsEncontrados = pets;
                                    _clienteNaoEncontrado = false;
                                    if (pets.isNotEmpty)
                                      _petIdSelecionado = pets.first['id'];
                                  });
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 20),

                    // 2. SELEÇÃO DE PET
                    Text(
                      "2. Selecionar Pet",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _petIdSelecionado,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 15),
                      ),
                      hint: Text(
                        _petsEncontrados.isEmpty ? "..." : "Escolha o pet...",
                      ),
                      items: _petsEncontrados
                          .map(
                            (p) => DropdownMenuItem(
                              value: p['id'] as String,
                              child: Row(
                                children: [
                                  Icon(
                                    p['tipo'] == 'cao'
                                        ? FontAwesomeIcons.dog
                                        : FontAwesomeIcons.cat,
                                    size: 16,
                                    color: _corAcai,
                                  ),
                                  SizedBox(width: 10),
                                  Text("${p['nome']} (${p['raca'] ?? ''})"),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _petsEncontrados.isEmpty
                          ? null
                          : (v) => setStateModal(() => _petIdSelecionado = v),
                    ),

                    SizedBox(height: 20),

                    // 3. DATAS
                    Text(
                      "3. Período da Estadia",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now().subtract(Duration(days: 1)),
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
                          setStateModal(() => _datas = picked);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 15,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _datas == null
                                  ? "Clique para selecionar datas"
                                  : "${DateFormat('dd/MM/yyyy').format(_datas!.start)}  até  ${DateFormat('dd/MM/yyyy').format(_datas!.end)}",
                              style: TextStyle(fontSize: 16),
                            ),
                            Icon(Icons.calendar_month, color: _corAcai),
                          ],
                        ),
                      ),
                    ),

                    if (_datas != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Container(
                          padding: EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: _corLilas,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Valor Previsto:",
                                style: TextStyle(fontSize: 16, color: _corAcai),
                              ),
                              Text(
                                "R\$ ${valorEstimado.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _corAcai,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed:
                    (_nomeCliente != null &&
                        _petIdSelecionado != null &&
                        _datas != null)
                    ? () async {
                        await _db.collection('reservas_hotel').add({
                          'cpf_user': _cpfBusca,
                          'pet_id': _petIdSelecionado,
                          'check_in': Timestamp.fromDate(_datas!.start),
                          'check_out': Timestamp.fromDate(_datas!.end),
                          'status': 'reservado',
                          'criado_em': FieldValue.serverTimestamp(),
                          'origem': 'balcao_admin',
                          'payment_status': 'pending',
                          'valor_previsto': valorEstimado,
                        });

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Reserva confirmada!")),
                        );
                      }
                    : null,
                child: Text(
                  "CONFIRMAR HOSPEDAGEM",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Padding(
        padding: const EdgeInsets.all(0), // O padding vem do parent
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Container(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 5),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hotelzinho AgenPet 💜",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _corAcai,
                        ),
                      ),
                      Text(
                        "Painel de Controle de Estadias",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.add_circle),
                    label: Text("NOVA RESERVA"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _corAcai,
                      padding: EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                    ),
                    onPressed: _novaHospedagemManual,
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),

            // --- CARDS ---
            StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('reservas_hotel')
                  .where('status', whereIn: ['reservado', 'hospedado'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return SizedBox(height: 100);
                int hospedados = 0;
                int reservado = 0;
                for (var doc in snapshot.data!.docs) {
                  if (doc['status'] == 'hospedado')
                    hospedados++;
                  else
                    reservado++;
                }
                return Row(
                  children: [
                    _buildCardKPI(
                      "Hóspedes Ativos",
                      "$hospedados",
                      FontAwesomeIcons.dog,
                      _corAcai,
                    ),
                    SizedBox(width: 20),
                    _buildCardKPI(
                      "Vagas Livres",
                      "${_capacidadeTotal - hospedados}",
                      FontAwesomeIcons.doorOpen,
                      Colors.green,
                    ),
                    SizedBox(width: 20),
                    _buildCardKPI(
                      "Chegando Hoje",
                      "$reservado",
                      FontAwesomeIcons.clock,
                      _corLavanda,
                    ),
                  ],
                );
              },
            ),

            SizedBox(height: 30),

            // --- TABELA ESTILIZADA ---
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.05),
                      blurRadius: 20,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Quadro de Hóspedes",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _corAcai,
                      ),
                    ),
                    SizedBox(height: 15),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _db
                            .collection('reservas_hotel')
                            .orderBy('check_in')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return Center(
                              child: CircularProgressIndicator(color: _corAcai),
                            );

                          final docs = snapshot.data!.docs;

                          return Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(
                                  _corLilas,
                                ),
                                dataRowColor: MaterialStateProperty.resolveWith(
                                  (states) => Colors.white,
                                ),
                                columnSpacing: 20,
                                columns: [
                                  DataColumn(
                                    label: Text(
                                      "PET / TUTOR",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _corAcai,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      "PERÍODO",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _corAcai,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      "FINANCEIRO",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _corAcai,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      "STATUS",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _corAcai,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      "AÇÃO",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _corAcai,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: docs
                                    .map((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final status =
                                          data['status'] ?? 'reservado';
                                      if (status == 'cancelado') return null;

                                      final fin = _calcularSituacaoFinanceira(
                                        data,
                                      );

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            FutureBuilder<DocumentSnapshot>(
                                              future: _db
                                                  .collection('users')
                                                  .doc(data['cpf_user'])
                                                  .collection('pets')
                                                  .doc(data['pet_id'])
                                                  .get(),
                                              builder: (c, s) {
                                                if (!s.hasData)
                                                  return Text("...");
                                                final pet =
                                                    s.data!.data() as Map;
                                                return Row(
                                                  children: [
                                                    CircleAvatar(
                                                      backgroundColor:
                                                          _corLilas,
                                                      child: FaIcon(
                                                        pet['tipo'] == 'cao'
                                                            ? FontAwesomeIcons
                                                                  .dog
                                                            : FontAwesomeIcons
                                                                  .cat,
                                                        size: 16,
                                                        color: _corAcai,
                                                      ),
                                                      radius: 18,
                                                    ),
                                                    SizedBox(width: 10),
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          pet['nome'],
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          data['cpf_user'],
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                          DataCell(
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Ent: ${DateFormat('dd/MM HH:mm').format((data['check_in'] as Timestamp).toDate())}",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                Text(
                                                  "Sai: ${DateFormat('dd/MM HH:mm').format((data['check_out'] as Timestamp).toDate())}",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // CÉLULA FINANCEIRA
                                          DataCell(
                                            fin['saldo_devedor'] > 0
                                                ? Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 5,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange[50],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            Colors.orange[200]!,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      "Falta R\$ ${fin['saldo_devedor'].toStringAsFixed(2)}",
                                                      style: TextStyle(
                                                        color:
                                                            Colors.orange[900],
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  )
                                                : Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 5,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green[50],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.check,
                                                          size: 12,
                                                          color: Colors.green,
                                                        ),
                                                        SizedBox(width: 5),
                                                        Text(
                                                          "PAGO",
                                                          style: TextStyle(
                                                            color: Colors
                                                                .green[800],
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                          ),

                                          DataCell(_buildStatusBadge(status)),

                                          // BOTÕES DE AÇÃO LÓGICA
                                          DataCell(
                                            status == 'reservado'
                                                ? ElevatedButton(
                                                    onPressed: () =>
                                                        _fazerCheckIn(doc.id),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.green,
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 15,
                                                          ),
                                                    ),
                                                    child: Text("Entrada"),
                                                  )
                                                : (status == 'hospedado'
                                                      ? ElevatedButton.icon(
                                                          onPressed: () =>
                                                              _processarSaida(
                                                                doc.id,
                                                                data,
                                                              ),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                fin['tem_excedente']
                                                                ? Colors
                                                                      .orange[800]
                                                                : _corAcai,
                                                            padding:
                                                                EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      15,
                                                                ),
                                                          ),
                                                          icon: Icon(
                                                            fin['tem_excedente']
                                                                ? Icons
                                                                      .attach_money
                                                                : Icons
                                                                      .exit_to_app,
                                                            size: 16,
                                                          ),
                                                          label: Text(
                                                            fin['tem_excedente']
                                                                ? "Pagar & Sair"
                                                                : "Saída",
                                                          ),
                                                        )
                                                      : Icon(
                                                          Icons.check_circle,
                                                          color:
                                                              Colors.grey[300],
                                                        )),
                                          ),
                                        ],
                                      );
                                    })
                                    .where((e) => e != null)
                                    .cast<DataRow>()
                                    .toList(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardKPI(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: FaIcon(icon, color: color, size: 28),
            ),
            SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    switch (status) {
      case 'reservado':
        bg = Colors.blue[50]!;
        text = Colors.blue[800]!;
        break;
      case 'hospedado':
        bg = _corLilas;
        text = _corAcai;
        break;
      case 'concluido':
        bg = Colors.grey[100]!;
        text = Colors.grey;
        break;
      default:
        bg = Colors.grey;
        text = Colors.white;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
