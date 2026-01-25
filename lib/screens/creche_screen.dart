import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/firebase_service.dart';

class CrecheScreen extends StatefulWidget {
  @override
  _CrecheScreenState createState() => _CrecheScreenState();
}

class _CrecheScreenState extends State<CrecheScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final _firebaseService = FirebaseService();

  // --- CORES DA MARCA ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF8F9FC);

  // CONFIGURAÇÃO DE PREÇO
  double _valorDiaria = 0.0;

  String? _userCpf;
  String? _petId;
  DateTimeRange? _periodoSelecionado;
  Set<DateTime> _diasLotados = {};

  bool _isLoading = false;
  List<Map<String, dynamic>> _pets = [];

  @override
  void initState() {
    super.initState();
    _carregarPrecoCreche();
    _carregarDisponibilidade();
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
    final snapshot = await _db
        .collection('users')
        .doc(_userCpf)
        .collection('pets')
        .get();
    setState(() {
      _pets = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (_pets.isNotEmpty && _petId == null) _petId = _pets.first['id'];
    });
  }

  Future<void> _carregarDisponibilidade() async {
    final datas = await _firebaseService.buscarDiasLotadosCreche();
    if (mounted) {
      setState(() {
        _diasLotados = datas
            .map((d) => DateTime(d.year, d.month, d.day))
            .toSet();
      });
    }
  }

  Future<void> _carregarPrecoCreche() async {
    try {
      final preco = await _firebaseService.getPrecoCreche();
      setState(() {
        _valorDiaria = preco > 0 ? preco : 60.00;
      });
    } catch (e) {
      setState(() => _valorDiaria = 60.00);
    }
  }

  // --- LÓGICA DE SELEÇÃO DE DATAS ---
  Future<void> _escolherDatas() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 90)),
      selectableDayPredicate: (DateTime day, DateTime? start, DateTime? end) {
        final normalizedDay = DateTime(day.year, day.month, day.day);
        if (_diasLotados.contains(normalizedDay)) return false;
        return true;
      },
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: _corAcai,
            colorScheme: ColorScheme.light(
              primary: _corAcai,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Validação: Intervalo não pode conter dias lotados no meio
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
        _mostrarErroDialog(
          "O período selecionado contém dias sem vaga.\nPor favor, escolha outras datas.",
        );
      } else {
        setState(() {
          _periodoSelecionado = picked;
        });
      }
    }
  }

  Future<void> _fazerReserva() async {
    if (_petId == null || _periodoSelecionado == null) return;

    setState(() => _isLoading = true);

    try {
      await _firebaseService.reservarCreche(
        petId: _petId!,
        cpfUser: _userCpf!,
        checkIn: _periodoSelecionado!.start,
        checkOut: _periodoSelecionado!.end,
      );

      _mostrarSucessoDialog();
    } catch (e) {
      String msg = e.toString();
      if (msg.contains("message:")) msg = msg.split("message:").last.trim();
      _mostrarErroDialog("Falha ao reservar: $msg");
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
              child: Icon(Icons.check_rounded, color: Colors.green, size: 60),
            ),
            SizedBox(height: 20),
            Text(
              "Reserva Solicitada!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Aguarde a confirmação da nossa equipe.\nSeu pet vai adorar a diversão! 🎒",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text(
                  "OK, VOLTAR",
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

  void _mostrarErroDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 10),
            Text("Atenção"),
          ],
        ),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("OK")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int dias = _periodoSelecionado?.duration.inDays ?? 0;
    if (dias == 0 && _periodoSelecionado != null) dias = 1;
    double total = dias * _valorDiaria;

    return Scaffold(
      backgroundColor: _corFundo,
      appBar: AppBar(
        title: Text(
          "Creche Pet",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _corAcai,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading && _pets.isEmpty
          ? Center(child: CircularProgressIndicator(color: _corAcai))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. CABEÇALHO / BANNER
                        _buildHeaderBanner(),

                        SizedBox(height: 25),

                        // 2. SELEÇÃO DE PET
                        _buildSectionHeader("Quem vai para a escola?"),
                        SizedBox(height: 10),
                        _buildPetList(),

                        SizedBox(height: 25),

                        // 3. SELEÇÃO DE DATAS
                        _buildSectionHeader("Dias de Creche"),
                        SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildDateSelector(),
                        ),

                        SizedBox(height: 25),

                        // 4. RESUMO / ORÇAMENTO
                        if (_periodoSelecionado != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildSummaryCard(dias, total),
                          ),

                        SizedBox(height: 100), // Espaço para botão
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomSheet: _buildBottomButton(total),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // --- WIDGETS VISUAIS ---

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(
        color: _corAcai,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: FaIcon(
              FontAwesomeIcons.school,
              size: 40,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 15),
          Text(
            "Creche Divertida",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 5),
          Text(
            "Socialização e brincadeiras para gastar energia!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPetList() {
    if (_pets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                "Nenhum pet cadastrado.",
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 15),
        itemCount: _pets.length,
        itemBuilder: (context, index) {
          final pet = _pets[index];
          final isSelected = pet['id'] == _petId;

          return GestureDetector(
            onTap: () => setState(() => _petId = pet['id']),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  margin: EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? _corAcai : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? _corAcai : Colors.grey[300]!,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _corAcai.withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    pet['tipo'] == 'gato'
                        ? FontAwesomeIcons.cat
                        : FontAwesomeIcons.dog,
                    color: isSelected ? Colors.white : Colors.grey[400],
                    size: 24,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  pet['nome'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? _corAcai : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateSelector() {
    bool hasDates = _periodoSelecionado != null;

    return GestureDetector(
      onTap: _escolherDatas,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: hasDates ? _corAcai : Colors.grey[300]!,
            width: hasDates ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _corLilas,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.calendar_month, color: _corAcai),
            ),
            SizedBox(width: 20),
            Expanded(
              child: !hasDates
                  ? Text(
                      "Selecione os dias de creche",
                      style: TextStyle(color: Colors.grey[600]),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Início",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'dd/MM/yyyy',
                                ).format(_periodoSelecionado!.start),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 30,
                          width: 1,
                          color: Colors.grey[300],
                          margin: EdgeInsets.symmetric(horizontal: 10),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Fim",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'dd/MM/yyyy',
                                ).format(_periodoSelecionado!.end),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
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

  Widget _buildSummaryCard(int dias, double total) {
    return Container(
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_corAcai, Color(0xFF6A1B9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _corAcai.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Valor da Diária", style: TextStyle(color: Colors.white70)),
              Text(
                "R\$ ${_valorDiaria.toStringAsFixed(2)}",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Dias selecionados",
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                "$dias dias",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Divider(color: Colors.white24, height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TOTAL ESTIMADO",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                "R\$ ${total.toStringAsFixed(2)}",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(double total) {
    bool canSubmit =
        _petId != null && _periodoSelecionado != null && !_isLoading;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: canSubmit ? _fazerReserva : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, // Botão Verde para confirmar
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 0,
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
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "SOLICITAR CRECHE",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (canSubmit) ...[
                        SizedBox(width: 10),
                        Container(width: 1, height: 15, color: Colors.white30),
                        SizedBox(width: 10),
                        Text(
                          "R\$ ${total.toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
