import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/painel_loja_web/widgets/servicos_select_dialog.dart';
import 'components/vitals_widget.dart';
import 'components/systems_review_widget.dart';
import 'components/prescription_widget.dart';
import 'components/vaccine_widget.dart';
import 'services/vet_service.dart';

class NovaConsultaScreen extends StatefulWidget {
  final Map<String, dynamic> petData;
  const NovaConsultaScreen({super.key, required this.petData});

  @override
  State<NovaConsultaScreen> createState() => _NovaConsultaScreenState();
}

class _NovaConsultaScreenState extends State<NovaConsultaScreen> {
  final _service = VetService();
  bool _isLoading = false;

  // --- STATE DATA ---
  Map<String, dynamic> _vitalsData = {};
  Map<String, dynamic> _systemsData = {};
  List<Map<String, dynamic>> _prescriptionData = [];
  List<Map<String, dynamic>> _vaccineData = [];
  List<Map<String, dynamic>> _itensCobranca = [];

  // Controllers
  final _queixaCtrl = TextEditingController();
  final _historicoCtrl = TextEditingController();
  final _suspeitaCtrl = TextEditingController();
  final _diagnosticoCtrl = TextEditingController();
  final _planoCtrl = TextEditingController();

  final Color _primaryColor = const Color(0xFF4A148C);

  @override
  void initState() {
    super.initState();
    _validarDadosIniciais();
  }

  void _validarDadosIniciais() {
    // Enforce required fields from Dashboard selection
    if (widget.petData['id'] == null || widget.petData['tutor_id'] == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erro: Dados do Paciente incompletos."),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        title: Row(
          children: [
            const Icon(
              FontAwesomeIcons.fileMedical,
              size: 20,
              color: Color(0xFF4A148C),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.petData['nome'] ?? 'Paciente',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Tutor: ${widget.petData['tutor_nome'] ?? 'Desconhecido'}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _finalizarConsulta,
            icon: const Icon(Icons.check_circle, color: Colors.green),
            label: const Text(
              "FINALIZAR",
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. ANAMNESE
            _buildSectionHeader(
              "1. Anamnese & Queixa Principal",
              FontAwesomeIcons.clipboardQuestion,
            ),
            const SizedBox(height: 10),
            _buildCard(
              child: Column(
                children: [
                  _buildTextField(
                    "Queixa Principal (Motivo da Consulta)",
                    _queixaCtrl,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    "Histórico da Moléstia Atual (HMA)",
                    _historicoCtrl,
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // 2. EXAME FÍSICO
            _buildSectionHeader(
              "2. Exame Físico",
              FontAwesomeIcons.stethoscope,
            ),
            const SizedBox(height: 10),
            VitalsWidget(onChanged: (data) => _vitalsData = data),
            const SizedBox(height: 15),
            SystemsReviewWidget(onChanged: (data) => _systemsData = data),
            const SizedBox(height: 25),

            // 3. DIAGNÓSTICO & PLANO
            _buildSectionHeader(
              "3. Avaliação Clínica",
              FontAwesomeIcons.userDoctor,
            ),
            const SizedBox(height: 10),
            _buildCard(
              child: Column(
                children: [
                  _buildTextField(
                    "Suspeita Clínica (Diferencial)",
                    _suspeitaCtrl,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    "Diagnóstico Definitivo",
                    _diagnosticoCtrl,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    "Plano Diagnóstico/Terapêutico",
                    _planoCtrl,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // 4. PRESCRIÇÃO & VACINAS
            _buildSectionHeader(
              "4. Conduta, Prescrição e Vacinas",
              FontAwesomeIcons.prescriptionBottleMedical,
            ),
            const SizedBox(height: 10),
            PrescriptionWidget(onChanged: (data) => _prescriptionData = data),
            const SizedBox(height: 15),
            VaccineWidget(onChanged: (data) => _vaccineData = data),
            const SizedBox(height: 25),

            // 5. SERVIÇOS & COBRANÇA
            _buildSectionHeader(
              "5. Serviços Realizados (Cobrança)",
              FontAwesomeIcons.fileInvoiceDollar,
            ),
            const SizedBox(height: 10),
            _buildBillingCard(),

            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _finalizarConsulta,
        backgroundColor: _primaryColor,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save),
        label: const Text("SALVAR PRONTUÁRIO"),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _primaryColor),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.all(15),
      ),
    );
  }

  Widget _buildBillingCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Itens a Cobrar",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: const Text("ADICIONAR SERVIÇOS"),
                onPressed: () async {
                  final result = await showDialog<List<Map<String, dynamic>>>(
                    context: context,
                    builder: (ctx) =>
                        ServicosSelectDialog(initialSelected: _itensCobranca),
                  );
                  if (result != null) {
                    setState(() => _itensCobranca = result);
                  }
                },
              ),
            ],
          ),
          const Divider(),
          if (_itensCobranca.isEmpty)
            const Padding(
              padding: EdgeInsets.all(15),
              child: Center(
                child: Text(
                  "Nenhum serviço lançado.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _itensCobranca.length,
              itemBuilder: (context, index) {
                final item = _itensCobranca[index];
                return ListTile(
                  dense: true,
                  title: Text(item['nome']),
                  trailing: Text(
                    "R\$ ${item['preco']}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  leading: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  ),
                );
              },
            ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                "Total Estimado: ",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "R\$ ${_itensCobranca.fold<double>(0, (sum, item) => sum + (item['preco'] as num).toDouble()).toStringAsFixed(2)}",
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _finalizarConsulta() async {
    if (_queixaCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preencha a Queixa Principal."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final anamnese = {
        'queixa': _queixaCtrl.text,
        'historico': _historicoCtrl.text,
      };

      final diagnostico = {
        'suspeita': _suspeitaCtrl.text,
        'definitivo': _diagnosticoCtrl.text,
        'plano': _planoCtrl.text,
      };

      await _service.salvarConsultaCompleta(
        petData: widget.petData,
        anamnese: anamnese,
        fisico: {'sinais_vitais': _vitalsData, 'sistemas': _systemsData},
        diagnostico: diagnostico,
        receita: _prescriptionData,
        vacinas: _vaccineData,
        itensCobranca: _itensCobranca,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Prontuário salvo com sucesso!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao salvar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
