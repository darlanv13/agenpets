import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/pet_model.dart';
import '../services/firebase_service.dart';

class MeusPetsScreen extends StatefulWidget {
  @override
  _MeusPetsScreenState createState() => _MeusPetsScreenState();
}

class _MeusPetsScreenState extends State<MeusPetsScreen> {
  final _firebaseService = FirebaseService();
  late String _userCpf;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      // Recebe o CPF do usuário logado (passado pela Home)
      final args = ModalRoute.of(context)!.settings.arguments as Map;
      _userCpf = args['cpf'];
      _init = true;
    }
  }

  // --- Modal para Adicionar Novo Pet ---
  void _mostrarFormularioAdicionar() {
    final _nomeController = TextEditingController();
    final _racaController = TextEditingController();
    String _tipoSelecionado = 'cao'; // Padrão

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          // Necessário para atualizar o RadioButton dentro do Dialog
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text("Novo Pet 🐾"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nomeController,
                    decoration: InputDecoration(labelText: "Nome do Pet"),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _racaController,
                    decoration: InputDecoration(
                      labelText: "Raça (Ex: Poodle, SRD)",
                    ),
                  ),
                  SizedBox(height: 20),
                  Text("Tipo de Animal:"),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildRadioOpcao(
                        "Cão",
                        "cao",
                        _tipoSelecionado,
                        setModalState,
                      ),
                      _buildRadioOpcao(
                        "Gato",
                        "gato",
                        _tipoSelecionado,
                        setModalState,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("CANCELAR"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_nomeController.text.isNotEmpty) {
                      final novoPet = PetModel(
                        donoCpf: _userCpf,
                        nome: _nomeController.text,
                        raca: _racaController.text,
                        tipo: _tipoSelecionado,
                      );

                      await _firebaseService.addPet(novoPet);
                      Navigator.pop(context); // Fecha o modal
                    }
                  },
                  child: Text("SALVAR"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRadioOpcao(
    String label,
    String valor,
    String grupo,
    Function setStateModal,
  ) {
    return Row(
      children: [
        Radio(
          value: valor,
          groupValue: grupo,
          onChanged: (v) => setStateModal(() => grupo = v.toString()),
        ),
        Text(label),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Meus Pets")),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarFormularioAdicionar,
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<List<PetModel>>(
        stream: _firebaseService.getPetsStream(_userCpf),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(FontAwesomeIcons.paw, size: 50, color: Colors.grey),
                  SizedBox(height: 20),
                  Text("Você ainda não tem pets cadastrados."),
                  Text("Clique no + para adicionar."),
                ],
              ),
            );
          }

          final pets = snapshot.data!;

          return ListView.builder(
            padding: EdgeInsets.all(10),
            itemCount: pets.length,
            itemBuilder: (ctx, index) {
              final pet = pets[index];
              return Card(
                elevation: 3,
                margin: EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: pet.tipo == 'cao'
                        ? Colors.orange[100]
                        : Colors.purple[100],
                    child: FaIcon(
                      pet.tipo == 'cao'
                          ? FontAwesomeIcons.dog
                          : FontAwesomeIcons.cat,
                      color: pet.tipo == 'cao' ? Colors.orange : Colors.purple,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    pet.nome,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("${pet.raca} • ${pet.tipo.toUpperCase()}"),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
