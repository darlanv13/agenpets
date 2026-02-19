import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/painel_loja_web/views/components/cadastro_rapido_dialog.dart';
import 'package:agenpet/painel_loja_web/services/client_search_service.dart';

class BuscaTutorPetDialog extends StatefulWidget {
  const BuscaTutorPetDialog({super.key});

  @override
  State<BuscaTutorPetDialog> createState() => _BuscaTutorPetDialogState();
}

class _BuscaTutorPetDialogState extends State<BuscaTutorPetDialog> {
  final _searchService = ClientSearchService();
  final _searchCtrl = TextEditingController();
  final _cpfMask = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});

  bool _isLoading = false;
  Map<String, dynamic>? _tutorEncontrado;
  List<Map<String, dynamic>> _petsDoTutor = [];
  String? _petIdSelecionado;

  Future<void> _buscarTutor() async {
    if (_searchCtrl.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _tutorEncontrado = null;
      _petsDoTutor = [];
      _petIdSelecionado = null;
    });

    try {
      final termo = _searchCtrl.text.trim();

      // A lógica do Hotel/Creche é baseada estritamente em CPF.
      // Adaptamos para usar o novo serviço que valida e busca por CPF.
      // Se o usuário digitar nome, isso falhará na validação de CPF do serviço,
      // mas como o requisito é "usar o mesmo serviço do hotel", seguimos o padrão CPF.

      final cliente = await _searchService.searchClientByCpf(termo);

      if (cliente != null) {
        final pets = await _searchService.getClientPets(cliente['cpf'] ?? termo);
        setState(() {
          _tutorEncontrado = cliente;
          _petsDoTutor = pets;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }

    } catch (e) {
      // Se não for CPF válido ou der erro
      debugPrint("Erro busca: $e");
      setState(() => _isLoading = false);
    }
  }

  void _confirmarSelecao() {
    if (_tutorEncontrado == null || _petIdSelecionado == null) return;

    final petSelecionado = _petsDoTutor.firstWhere((p) => p['id'] == _petIdSelecionado);

    Navigator.pop(context, {
      'id': petSelecionado['id'],
      'nome': petSelecionado['nome'],
      'raca': petSelecionado['raca'],
      'tutor_nome': _tutorEncontrado!['nome'],
      'tutor_id': _tutorEncontrado!['uid'] ?? _tutorEncontrado!['cpf'],
      'tutor_cpf': _tutorEncontrado!['cpf'],
    });
  }

  void _abrirCadastroRapido() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CadastroRapidoDialog(cpfInicial: _searchCtrl.text),
    );

    if (result != null && result['sucesso'] == true) {
       _searchCtrl.text = result['cpf'];
       _buscarTutor();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Iniciar Atendimento"),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          children: [
            // BUSCA (CPF)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    inputFormatters: [_cpfMask], // Força formato CPF como no Hotel
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "CPF do Tutor",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      hintText: "000.000.000-00",
                    ),
                    onSubmitted: (_) => _buscarTutor(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _buscarTutor,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    backgroundColor: const Color(0xFF4A148C)
                  ),
                  child: const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (_isLoading)
              const LinearProgressIndicator(color: Color(0xFF4A148C))
            else if (_tutorEncontrado == null && _searchCtrl.text.isNotEmpty && !_isLoading)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text("Tutor não encontrado.", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _abrirCadastroRapido,
                      icon: const Icon(Icons.person_add),
                      label: const Text("CADASTRAR NOVO TUTOR"),
                    )
                  ],
                ),
              ),

            // DADOS DO TUTOR E PETS
            if (_tutorEncontrado != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green[200]!)
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_tutorEncontrado!['nome'] ?? 'Nome não inf.', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("CPF: ${_tutorEncontrado!['cpf']}", style: TextStyle(color: Colors.green[800], fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Align(alignment: Alignment.centerLeft, child: Text("Selecione o Paciente:", style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 10),

              if (_petsDoTutor.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("Este tutor não possui pets cadastrados.", style: TextStyle(color: Colors.orange)),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _petsDoTutor.length,
                    itemBuilder: (ctx, i) {
                      final p = _petsDoTutor[i];
                      final isSelected = _petIdSelecionado == p['id'];

                      return Card(
                        color: isSelected ? const Color(0xFFE1BEE7) : Colors.white,
                        elevation: isSelected ? 4 : 1,
                        child: ListTile(
                          leading: const Icon(FontAwesomeIcons.dog),
                          title: Text(p['nome']),
                          subtitle: Text("${p['raca'] ?? 'SRD'} • ${p['tipo'] ?? ''}"),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF4A148C)) : null,
                          onTap: () => setState(() => _petIdSelecionado = p['id']),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: _petIdSelecionado != null ? _confirmarSelecao : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A148C),
            disabledBackgroundColor: Colors.grey[300]
          ),
          child: const Text("INICIAR ATENDIMENTO", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
