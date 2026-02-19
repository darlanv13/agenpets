import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/painel_loja_web/views/vet/dialogs/fast_client_registration_dialog.dart';

class BuscaTutorPetDialog extends StatefulWidget {
  const BuscaTutorPetDialog({super.key});

  @override
  State<BuscaTutorPetDialog> createState() => _BuscaTutorPetDialogState();
}

class _BuscaTutorPetDialogState extends State<BuscaTutorPetDialog> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  final _cpfMask = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});

  bool _isLoading = false;
  List<DocumentSnapshot> _tutoresEncontrados = [];
  DocumentSnapshot? _tutorSelecionado;
  List<DocumentSnapshot> _petsDoTutor = [];
  DocumentSnapshot? _petSelecionado;

  Future<void> _buscarTutor() async {
    if (_searchCtrl.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _tutoresEncontrados = [];
      _tutorSelecionado = null;
      _petsDoTutor = [];
      _petSelecionado = null;
    });

    try {
      final termo = _searchCtrl.text.trim();
      QuerySnapshot query;

      // Se parece CPF (contém números)
      if (termo.contains(RegExp(r'[0-9]'))) {
        final cpfLimpo = termo.replaceAll(RegExp(r'[^0-9]'), '');
        // Tenta buscar pelo ID direto (CPF limpo) ou pelo campo 'cpf'
        final docById = await _db.collection('users').doc(cpfLimpo).get();
        if (docById.exists) {
           setState(() {
             _tutoresEncontrados = [docById];
             _isLoading = false;
           });
           // Auto-select se for único
           _selecionarTutor(docById);
           return;
        } else {
           // Fallback query
           query = await _db.collection('users').where('cpf', isEqualTo: cpfLimpo).get();
        }
      } else {
        // Busca por nome (prefixo simples)
        // Nota: Firestore não tem full-text search nativo bom para 'contains',
        // idealmente usar Algolia ou similar. Aqui usamos isGreaterThanOrEqualTo para prefixo.
        query = await _db.collection('users')
            .where('nome', isGreaterThanOrEqualTo: termo)
            .where('nome', isLessThan: '${termo}z')
            .limit(5)
            .get();
      }

      setState(() {
        _tutoresEncontrados = query.docs;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint("Erro busca: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selecionarTutor(DocumentSnapshot tutor) async {
    setState(() {
      _tutorSelecionado = tutor;
      _isLoading = true;
    });

    try {
      // Busca Pets do Tutor (subcoleção)
      // Ajuste para usar a subcoleção correta conforme estrutura do projeto
      // Baseado em `meus_pets_screen.dart`, a estrutura é `users/{uid}/pets`
      final petsQuery = await _db.collection('users').doc(tutor.id).collection('pets').get();

      setState(() {
        _petsDoTutor = petsQuery.docs;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint("Erro busca pets: $e");
      setState(() => _isLoading = false);
    }
  }

  void _selecionarPet(DocumentSnapshot pet) {
    setState(() => _petSelecionado = pet);
  }

  void _confirmarSelecao() {
    if (_tutorSelecionado == null || _petSelecionado == null) return;

    final tutorData = _tutorSelecionado!.data() as Map<String, dynamic>;
    final petData = _petSelecionado!.data() as Map<String, dynamic>;

    Navigator.pop(context, {
      'id': _petSelecionado!.id,
      'nome': petData['nome'],
      'raca': petData['raca'],
      'tutor_nome': tutorData['nome'],
      'tutor_id': _tutorSelecionado!.id, // UID/CPF
      'tutor_cpf': tutorData['cpf'] ?? _tutorSelecionado!.id,
    });
  }

  void _abrirCadastroRapido() async {
    final novoTutor = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const FastClientRegistrationDialog(),
    );

    if (novoTutor != null) {
       // Auto-buscar o novo tutor
       _searchCtrl.text = novoTutor['cpf'];
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
            // BUSCA
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: "Buscar Tutor (CPF ou Nome)",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
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
            else if (_tutoresEncontrados.isEmpty && _searchCtrl.text.isNotEmpty && _tutorSelecionado == null)
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

            // LISTA DE TUTORES
            if (_tutorSelecionado == null && _tutoresEncontrados.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _tutoresEncontrados.length,
                  itemBuilder: (ctx, i) {
                    final t = _tutoresEncontrados[i];
                    final d = t.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(d['nome'] ?? 'Sem Nome'),
                      subtitle: Text("CPF: ${d['cpf'] ?? t.id}"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _selecionarTutor(t),
                    );
                  },
                ),
              ),

            // SELEÇÃO DE PET (QUANDO TUTOR SELECIONADO)
            if (_tutorSelecionado != null) ...[
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
                title: Text((_tutorSelecionado!.data() as Map)['nome']),
                subtitle: const Text("Tutor Selecionado"),
                trailing: TextButton(
                  onPressed: () => setState(() {
                    _tutorSelecionado = null;
                    _petsDoTutor = [];
                    _petSelecionado = null;
                  }),
                  child: const Text("Trocar"),
                ),
              ),
              const Divider(),
              const Text("Selecione o Paciente:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              if (_petsDoTutor.isEmpty && !_isLoading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("Este tutor não possui pets cadastrados. Cadastre pelo App ou Painel Admin.", style: TextStyle(color: Colors.orange)),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _petsDoTutor.length,
                    itemBuilder: (ctx, i) {
                      final p = _petsDoTutor[i];
                      final d = p.data() as Map<String, dynamic>;
                      final isSelected = _petSelecionado?.id == p.id;

                      return Card(
                        color: isSelected ? const Color(0xFFE1BEE7) : Colors.white,
                        elevation: isSelected ? 4 : 1,
                        child: ListTile(
                          leading: const Icon(FontAwesomeIcons.dog),
                          title: Text(d['nome']),
                          subtitle: Text("${d['raca'] ?? 'SRD'} • ${d['sexo'] ?? ''}"),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF4A148C)) : null,
                          onTap: () => _selecionarPet(p),
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
          onPressed: _petSelecionado != null ? _confirmarSelecao : null,
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
