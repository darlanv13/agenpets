import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ConfiguracaoAgendaView extends StatefulWidget {
  @override
  _ConfiguracaoAgendaViewState createState() => _ConfiguracaoAgendaViewState();
}

class _ConfiguracaoAgendaViewState extends State<ConfiguracaoAgendaView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Cores
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);

  bool _isLoading = true;

  // Variáveis de Estado
  TimeOfDay? _abertura;
  TimeOfDay? _fechamento;
  final _tempoBanhoController = TextEditingController();
  final _tempoTosaController = TextEditingController();

  // Dias da Semana (1 = Seg, 7 = Dom)
  // Inicialmente todos marcados
  List<int> _diasFuncionamento = [1, 2, 3, 4, 5, 6];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final doc = await _db.collection('config').doc('parametros').get();
      if (doc.exists) {
        final data = doc.data()!;

        setState(() {
          // Carrega Horários (Salvos como String "HH:mm")
          _abertura = _stringToTime(data['horario_abertura'] ?? "08:00");
          _fechamento = _stringToTime(data['horario_fechamento'] ?? "18:00");

          // Carrega Tempos
          _tempoBanhoController.text = (data['tempo_banho_min'] ?? 60)
              .toString();
          _tempoTosaController.text = (data['tempo_tosa_min'] ?? 90).toString();

          // Carrega Dias (Array de inteiros)
          if (data['dias_funcionamento'] != null) {
            _diasFuncionamento = List<int>.from(data['dias_funcionamento']);
          }
        });
      }
    } catch (e) {
      print("Erro ao carregar config: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _salvar() async {
    setState(() => _isLoading = true);
    try {
      await _db.collection('config').doc('parametros').set({
        'horario_abertura': _timeToString(_abertura),
        'horario_fechamento': _timeToString(_fechamento),
        'tempo_banho_min': int.tryParse(_tempoBanhoController.text) ?? 60,
        'tempo_tosa_min': int.tryParse(_tempoTosaController.text) ?? 90,
        'dias_funcionamento': _diasFuncionamento, // Salva quais dias abre
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Configurações de Agenda salvas!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Auxiliares de Tempo
  TimeOfDay _stringToTime(String s) {
    final parts = s.split(":");
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _timeToString(TimeOfDay? t) {
    if (t == null) return "08:00";
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  Future<void> _pickTime(bool isAbertura) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isAbertura
          ? (_abertura ?? TimeOfDay(hour: 8, minute: 0))
          : (_fechamento ?? TimeOfDay(hour: 18, minute: 0)),
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
    if (picked != null) {
      setState(() {
        if (isAbertura)
          _abertura = picked;
        else
          _fechamento = picked;
      });
    }
  }

  void _toggleDia(int dia) {
    setState(() {
      if (_diasFuncionamento.contains(dia)) {
        _diasFuncionamento.remove(dia);
      } else {
        _diasFuncionamento.add(dia);
      }
      _diasFuncionamento.sort(); // Mantém ordem (Seg, Ter...)
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return Center(child: CircularProgressIndicator(color: _corAcai));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _corLilas,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_month, color: _corAcai, size: 30),
            ),
            SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Configuração de Agenda",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _corAcai,
                  ),
                ),
                Text(
                  "Defina horários e dias de funcionamento",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 40),

        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. DIAS DE FUNCIONAMENTO
                Text(
                  "Dias de Funcionamento",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _corAcai,
                  ),
                ),
                SizedBox(height: 15),
                Wrap(
                  spacing: 10,
                  children: [
                    _buildDiaChip("Segunda", 1),
                    _buildDiaChip("Terça", 2),
                    _buildDiaChip("Quarta", 3),
                    _buildDiaChip("Quinta", 4),
                    _buildDiaChip("Sexta", 5),
                    _buildDiaChip("Sábado", 6),
                    _buildDiaChip("Domingo", 7),
                  ],
                ),

                SizedBox(height: 40),
                Divider(),
                SizedBox(height: 20),

                // 2. HORÁRIOS DE ABERTURA
                Text(
                  "Horário de Atendimento",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _corAcai,
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    _buildTimeCard("Abertura", _abertura, true),
                    SizedBox(width: 20),
                    Icon(Icons.arrow_forward, color: Colors.grey),
                    SizedBox(width: 20),
                    _buildTimeCard("Fechamento", _fechamento, false),
                  ],
                ),

                SizedBox(height: 40),
                Divider(),
                SizedBox(height: 20),

                // 3. DURAÇÃO DOS SERVIÇOS
                Text(
                  "Duração dos Serviços (Minutos)",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _corAcai,
                  ),
                ),
                Text(
                  "O sistema usa isso para calcular quantas vagas existem.",
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputDuracao(
                        "Banho",
                        _tempoBanhoController,
                        FontAwesomeIcons.shower,
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: _buildInputDuracao(
                        "Tosa",
                        _tempoTosaController,
                        FontAwesomeIcons.scissors,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 50),

                // BOTÃO SALVAR
                SizedBox(
                  width: 300,
                  height: 55,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text("SALVAR CONFIGURAÇÃO"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _corAcai,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: _salvar,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiaChip(String label, int valor) {
    bool selecionado = _diasFuncionamento.contains(valor);
    return FilterChip(
      label: Text(label),
      selected: selecionado,
      onSelected: (_) => _toggleDia(valor),
      selectedColor: _corAcai,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selecionado ? Colors.white : Colors.black87,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: Colors.grey[200],
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  Widget _buildTimeCard(String label, TimeOfDay? time, bool isAbertura) {
    return InkWell(
      onTap: () => _pickTime(isAbertura),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _corAcai.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: _corLilas, blurRadius: 10)],
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.grey[700])),
            SizedBox(height: 5),
            Text(
              _timeToString(time),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _corAcai,
              ),
            ),
            Text(
              "Toque para alterar",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputDuracao(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: "min",
        prefixIcon: Icon(icon, color: _corAcai),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
