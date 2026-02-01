import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/config/app_config.dart';

class ConfiguracaoAgendaView extends StatefulWidget {
  const ConfiguracaoAgendaView({super.key});

  @override
  _ConfiguracaoAgendaViewState createState() => _ConfiguracaoAgendaViewState();
}

class _ConfiguracaoAgendaViewState extends State<ConfiguracaoAgendaView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Cores do Tema
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF5F7FA);

  bool _isLoading = true;
  bool _isSaving = false;

  // Variáveis de Estado
  TimeOfDay? _abertura;
  TimeOfDay? _fechamento;
  final _tempoBanhoController = TextEditingController();
  final _tempoTosaController = TextEditingController();

  // Dias da Semana (1 = Seg, 7 = Dom)
  List<int> _diasFuncionamento = [1, 2, 3, 4, 5, 6];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final doc = await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('config')
          .doc('parametros')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _abertura = _stringToTime(data['horario_abertura'] ?? "08:00");
          _fechamento = _stringToTime(data['horario_fechamento'] ?? "18:00");
          _tempoBanhoController.text = (data['tempo_banho_min'] ?? 60)
              .toString();
          _tempoTosaController.text = (data['tempo_tosa_min'] ?? 90).toString();
          if (data['dias_funcionamento'] != null) {
            _diasFuncionamento = List<int>.from(data['dias_funcionamento']);
          }
        });
      }
    } catch (e) {
      print("Erro: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _salvar() async {
    setState(() => _isSaving = true);
    try {
      await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('config')
          .doc('parametros')
          .set({
        'horario_abertura': _timeToString(_abertura),
        'horario_fechamento': _timeToString(_fechamento),
        'tempo_banho_min': int.tryParse(_tempoBanhoController.text) ?? 60,
        'tempo_tosa_min': int.tryParse(_tempoTosaController.text) ?? 90,
        'dias_funcionamento': _diasFuncionamento,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Configurações Salvas com Sucesso! 💾"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao salvar: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // --- HELPERS LÓGICOS ---

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

  int _calculaMinutosAbertos() {
    if (_abertura == null || _fechamento == null) return 0;
    int inicio = _abertura!.hour * 60 + _abertura!.minute;
    int fim = _fechamento!.hour * 60 + _fechamento!.minute;
    return (fim - inicio) > 0 ? (fim - inicio) : 0;
  }

  void _ajustarTempo(TextEditingController ctrl, int delta) {
    int atual = int.tryParse(ctrl.text) ?? 60;
    int novo = atual + delta;
    if (novo < 15) novo = 15; // Mínimo 15 min
    setState(() {
      ctrl.text = novo.toString();
    });
  }

  Future<void> _pickTime(bool isAbertura) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isAbertura
          ? (_abertura ?? TimeOfDay(hour: 8, minute: 0))
          : (_fechamento ?? TimeOfDay(hour: 18, minute: 0)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          primaryColor: _corAcai,
          colorScheme: ColorScheme.light(
            primary: _corAcai,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isAbertura) {
          _abertura = picked;
        } else {
          _fechamento = picked;
        }
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
      _diasFuncionamento.sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _corAcai));
    }

    // Cálculos para o Resumo
    int totalMinutos = _calculaMinutosAbertos();
    int tBanho = int.tryParse(_tempoBanhoController.text) ?? 60;
    int tTosa = int.tryParse(_tempoTosaController.text) ?? 90;

    // Capacidade teórica (sem intervalos)
    int capBanho = tBanho > 0 ? (totalMinutos / tBanho).floor() : 0;
    int capTosa = tTosa > 0 ? (totalMinutos / tTosa).floor() : 0;

    return Scaffold(
      backgroundColor: _corFundo,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 10),
                    ],
                  ),
                  child: Icon(
                    FontAwesomeIcons.clock,
                    color: _corAcai,
                    size: 30,
                  ),
                ),
                SizedBox(width: 20),
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
                      "Defina a disponibilidade da sua loja",
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 40),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // COLUNA DA ESQUERDA (Configurações)
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // 1. HORÁRIOS DE FUNCIONAMENTO
                      _buildSectionTitle("Horário de Atendimento"),
                      Container(
                        padding: EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildTimeSelector("Abertura", _abertura, true),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.grey[300],
                              size: 30,
                            ),
                            _buildTimeSelector(
                              "Fechamento",
                              _fechamento,
                              false,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 30),

                      // 2. DIAS DA SEMANA
                      _buildSectionTitle("Dias de Funcionamento"),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildDayCircle("S", 1),
                            _buildDayCircle("T", 2),
                            _buildDayCircle("Q", 3),
                            _buildDayCircle("Q", 4),
                            _buildDayCircle("S", 5),
                            _buildDayCircle("S", 6),
                            _buildDayCircle("D", 7),
                          ],
                        ),
                      ),

                      SizedBox(height: 30),

                      // 3. DURAÇÃO DOS SERVIÇOS
                      _buildSectionTitle("Duração dos Serviços"),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDurationCard(
                              "Banho",
                              FontAwesomeIcons.shower,
                              Colors.blue,
                              _tempoBanhoController,
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: _buildDurationCard(
                              "Tosa",
                              FontAwesomeIcons.scissors,
                              Colors.orange,
                              _tempoTosaController,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 40),

                // COLUNA DA DIREITA (Resumo / Capacidade)
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildSectionTitle(
                        "Capacidade Diária (Por Profissional)",
                      ),
                      Container(
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
                              color: _corAcai.withOpacity(0.4),
                              blurRadius: 15,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Simulação de Vagas",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              "${(totalMinutos / 60).toStringAsFixed(1)} horas",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "de funcionamento diário",
                              style: TextStyle(color: Colors.white70),
                            ),
                            Divider(color: Colors.white24, height: 30),

                            _buildCapacityRow(
                              "Banhos / dia",
                              "$capBanho vagas",
                              FontAwesomeIcons.shower,
                            ),
                            SizedBox(height: 15),
                            _buildCapacityRow(
                              "Tosas / dia",
                              "$capTosa vagas",
                              FontAwesomeIcons.scissors,
                            ),

                            SizedBox(height: 20),
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Essa é a base para o sistema calcular slots livres automaticamente.",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          icon: _isSaving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(Icons.save),
                          label: Text(
                            _isSaving ? "SALVANDO..." : "SALVAR CONFIGURAÇÕES",
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                            shadowColor: Colors.green.withOpacity(0.4),
                          ),
                          onPressed: _isSaving ? null : _salvar,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay? time, bool isAbertura) {
    return InkWell(
      onTap: () => _pickTime(isAbertura),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _corFundo,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            SizedBox(height: 5),
            Text(
              _timeToString(time),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _corAcai,
              ),
            ),
            Text(
              "Toque para mudar",
              style: TextStyle(fontSize: 10, color: _corAcai.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCircle(String label, int diaIdx) {
    bool ativo = _diasFuncionamento.contains(diaIdx);
    return GestureDetector(
      onTap: () => _toggleDia(diaIdx),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: ativo ? _corAcai : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: ativo ? _corAcai : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: ativo
              ? [
                  BoxShadow(
                    color: _corAcai.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ativo ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationCard(
    String label,
    IconData icon,
    Color cor,
    TextEditingController ctrl,
  ) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: cor.withOpacity(0.1),
            child: FaIcon(icon, color: cor, size: 18),
          ),
          SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepBtn(Icons.remove, () => _ajustarTempo(ctrl, -5)),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: ctrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    suffixText: "m",
                  ),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              _buildStepBtn(Icons.add, () => _ajustarTempo(ctrl, 5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: _corFundo,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: Colors.grey[700]),
      ),
    );
  }

  Widget _buildCapacityRow(String label, String value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            FaIcon(icon, color: Colors.white70, size: 16),
            SizedBox(width: 10),
            Text(label, style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}
