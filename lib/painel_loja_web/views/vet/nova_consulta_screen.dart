import 'package:flutter/material.dart';
import 'components/anamnese_form.dart';
import 'components/exame_fisico_form.dart';
import 'components/receita_laudo_form.dart';
import 'services/vet_service.dart';

class NovaConsultaScreen extends StatefulWidget {
  final Map<String, dynamic> petData;
  const NovaConsultaScreen({super.key, required this.petData});

  @override
  _NovaConsultaScreenState createState() => _NovaConsultaScreenState();
}

class _NovaConsultaScreenState extends State<NovaConsultaScreen> {
  // Estado Global da Consulta
  final _anamneseKey = GlobalKey<AnamneseFormState>();
  final _fisicoKey = GlobalKey<ExameFisicoFormState>();
  final _receitaKey = GlobalKey<ReceitaLaudoFormState>();

  final VetService _service = VetService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF4A148C),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Atendimento: ${widget.petData['nome']}",
                style: TextStyle(fontSize: 18),
              ),
              Text(
                "Tutor: ${widget.petData['tutor_nome']}",
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          bottom: TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "1. Anamnese"),
              Tab(text: "2. Exame Físico"),
              Tab(text: "3. Diagnóstico & Receita"),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: Icon(Icons.save, color: Colors.white),
              label: Text(
                "FINALIZAR",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _finalizarAtendimento,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            AnamneseForm(key: _anamneseKey),
            ExameFisicoForm(key: _fisicoKey),
            ReceitaLaudoForm(key: _receitaKey),
          ],
        ),
      ),
    );
  }

  void _finalizarAtendimento() async {
    setState(() => _isLoading = true);

    // Coleta dados dos componentes filhos
    final anamneseData = _anamneseKey.currentState?.getData() ?? {};
    final fisicoData = _fisicoKey.currentState?.getData() ?? {};
    final receitaData = _receitaKey.currentState?.getData() ?? {};
    final cobrancaData = _receitaKey.currentState?.getCobranca() ?? [];

    await _service.salvarConsultaCompleta(
      petData: widget.petData,
      anamnese: anamneseData,
      fisico: fisicoData,
      receita: receitaData,
      itensCobranca: cobrancaData,
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Atendimento Salvo!")));
      Navigator.pop(context);
    }
  }
}
