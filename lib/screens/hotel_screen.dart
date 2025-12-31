import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/firebase_service.dart';

class HotelScreen extends StatefulWidget {
  @override
  _HotelScreenState createState() => _HotelScreenState();
}

class _HotelScreenState extends State<HotelScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final _firebaseService = FirebaseService();

  // CONFIGURAÇÃO DE PREÇO
  double _valorDiaria = 0.0;

  String? _userCpf;
  String? _petId;
  DateTimeRange? _periodoSelecionado;

  bool _isLoading = false;
  List<Map<String, dynamic>> _pets = [];

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
    final snapshot = await _db
        .collection('users')
        .doc(_userCpf)
        .collection('pets')
        .get();
    setState(() {
      _pets = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (_pets.isNotEmpty) _petId = _pets.first['id'];
    });
  }

  Set<DateTime> _diasLotados = {}; // Usamos Set para busca rápida

  @override
  void initState() {
    super.initState();
    _carregarPrecoHotel();
    _carregarDisponibilidade();
  }

  Future<void> _carregarDisponibilidade() async {
    // Busca do backend
    final datas = await _firebaseService.buscarDiasLotadosHotel();

    if (mounted) {
      setState(() {
        // Normaliza as datas para garantir que hora/minuto/segundo sejam 00:00:00
        // Isso é crucial para a comparação do calendário funcionar
        _diasLotados = datas
            .map((d) => DateTime(d.year, d.month, d.day))
            .toSet();
      });
    }
  }

  Future<void> _carregarPrecoHotel() async {
    try {
      final doc = await _db.collection('config').doc('parametros').get();
      if (doc.exists) {
        setState(() {
          _valorDiaria = (doc.data()!['preco_hotel_diaria'] ?? 80.00)
              .toDouble();
        });
      }
    } catch (e) {
      setState(() => _valorDiaria = 80.00);
    }
  }

  // Seletor de Datas (Entrada e Saída)
  Future<void> _escolherDatas() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 60)),

      // --- CORREÇÃO AQUI ---
      // Agora aceitamos os 3 parâmetros exigidos: day, start, end
      selectableDayPredicate: (DateTime day, DateTime? start, DateTime? end) {
        // Normaliza o dia (zera as horas) para comparar corretamente
        final normalizedDay = DateTime(day.year, day.month, day.day);

        // Se o dia estiver na lista de lotados, retorna false (bloqueado)
        if (_diasLotados.contains(normalizedDay)) {
          return false;
        }
        return true; // Se não, retorna true (liberado)
      },

      // ---------------------
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.orange,
            colorScheme: ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Validação Extra: Impede que o usuário selecione um intervalo que "pule" dias lotados
      // (Ex: Dia 10 Livre -> Dia 11 Lotado -> Dia 12 Livre. Selecionar de 10 a 12 é inválido)
      bool intervaloInvalido = false;
      int diasNoIntervalo = picked.end.difference(picked.start).inDays;

      for (int i = 0; i <= diasNoIntervalo; i++) {
        DateTime diaVerificado = picked.start.add(Duration(days: i));
        DateTime diaNormalizado = DateTime(
          diaVerificado.year,
          diaVerificado.month,
          diaVerificado.day,
        );

        if (_diasLotados.contains(diaNormalizado)) {
          intervaloInvalido = true;
          break;
        }
      }

      if (intervaloInvalido) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "O período selecionado contém dias sem vaga. Por favor, escolha outras datas.",
            ),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        setState(() {
          _periodoSelecionado = picked;
        });
      }
    }
  }

  Future<void> _fazerReserva() async {
    // 1. Validação inicial
    if (_petId == null || _periodoSelecionado == null) {
      print("❌ ERRO: Pet ou Datas não selecionados.");
      return;
    }

    setState(() => _isLoading = true);
    print("🚀 Iniciando reserva...");
    print("Dados enviados: Pet=$_petId, CPF=$_userCpf");
    print(
      "Datas: ${_periodoSelecionado!.start} até ${_periodoSelecionado!.end}",
    );

    try {
      // 2. Chamada ao Backend
      final resultado = await _firebaseService.reservarHotel(
        petId: _petId!,
        cpfUser: _userCpf!,
        checkIn: _periodoSelecionado!.start,
        checkOut: _periodoSelecionado!.end,
      );

      print("✅ Sucesso! Resposta do servidor: $resultado");

      // 3. Sucesso Visual
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 50),
                Text("Reserva Confirmada!"),
              ],
            ),
            content: Text("Seu pet foi agendado com sucesso."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e, stackTrace) {
      // 4. CAPTURA DETALHADA DO ERRO
      print("🛑 ERRO AO RESERVAR (CATCH):");
      print("Mensagem: $e");
      print("Stack Trace: $stackTrace");

      String mensagemErro = "Erro desconhecido.";

      // Tenta extrair a mensagem limpa se for erro do Cloud Functions
      if (e.toString().contains("message:")) {
        mensagemErro = e.toString().split("message:").last.trim();
      } else {
        mensagemErro = e.toString();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Falha: $mensagemErro"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5), // Fica mais tempo na tela
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int dias = _periodoSelecionado?.duration.inDays ?? 0;
    // Se selecionou o mesmo dia, conta como 1 diária pelo menos, ou lógica de 0 noites
    if (dias == 0 && _periodoSelecionado != null) dias = 1;

    double total = dias * _valorDiaria;

    return Scaffold(
      backgroundColor: Colors.orange[50],
      appBar: AppBar(
        title: Text("Hotelzinho Pet 🏨"),
        backgroundColor: Colors.orange[800],
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                children: [
                  FaIcon(
                    FontAwesomeIcons.hotel,
                    size: 50,
                    color: Colors.orange,
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Hospedagem com Amor",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                  Text(
                    "Monitoramento 24h e brincadeiras",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),

            // 1. Escolha o Pet
            Text(
              "Quem vai se hospedar?",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 10),
            _buildPetSelector(),

            SizedBox(height: 25),

            // 2. Escolha as Datas
            Text(
              "Qual o período?",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 10),
            GestureDetector(
              onTap: _escolherDatas,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.orange[200]!),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: Colors.orange),
                    SizedBox(width: 15),
                    Expanded(
                      child: _periodoSelecionado == null
                          ? Text(
                              "Toque para selecionar datas",
                              style: TextStyle(color: Colors.grey),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Entrada: ${DateFormat('dd/MM/yyyy').format(_periodoSelecionado!.start)}",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "Saída:    ${DateFormat('dd/MM/yyyy').format(_periodoSelecionado!.end)}",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),

            SizedBox(height: 30),

            // Resumo do Valor
            if (_periodoSelecionado != null)
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$dias diárias x R\$ $_valorDiaria",
                      style: TextStyle(color: Colors.orange[900]),
                    ),
                    Text(
                      "Total: R\$ ${total.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.orange[900],
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 40),

            // Botão Reservar
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed:
                    (_petId != null &&
                        _periodoSelecionado != null &&
                        !_isLoading)
                    ? _fazerReserva
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "SOLICITAR RESERVA",
                        style: TextStyle(
                          fontSize: 16,
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

  Widget _buildPetSelector() {
    if (_pets.isEmpty) return Text("Cadastre um pet na tela anterior.");

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _petId,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.orange),
          items: _pets.map((pet) {
            return DropdownMenuItem(
              value: pet['id'] as String,
              child: Row(
                children: [
                  Icon(
                    pet['tipo'] == 'cao'
                        ? FontAwesomeIcons.dog
                        : FontAwesomeIcons.cat,
                    size: 18,
                    color: Colors.grey,
                  ),
                  SizedBox(width: 10),
                  Text(
                    pet['nome'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() => _petId = v),
        ),
      ),
    );
  }
}
