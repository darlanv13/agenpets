import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AgendamentoScreen extends StatefulWidget {
  @override
  _AgendamentoScreenState createState() => _AgendamentoScreenState();
}

class _AgendamentoScreenState extends State<AgendamentoScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // --- VALORES DOS SERVIÇOS ---
  // (Futuramente você pode carregar isso de uma coleção 'config' do Firebase)
  double _precoBanho = 49.90;
  double _precoTosa = 119.90;

  String? _userCpf;
  DateTime _dataSelecionada = DateTime.now();
  String _servicoSelecionado = 'Banho';

  String? _profissionalIdSelecionadoPeloSistema;
  String? _nomeProfissionalDoSistema;

  String? _petId;
  String? _horarioSelecionado;

  bool _isLoading = false;
  List<String> _horariosDisponiveis = [];
  List<Map<String, dynamic>> _pets = [];
  List<Map<String, dynamic>> _profissionais = [];

  late List<DateTime> _listaDias;

  @override
  void initState() {
    super.initState();
    _gerarListaDias();

    // Ajuste inicial de data para não cair em domingo
    if (_dataSelecionada.weekday == DateTime.sunday) {
      _dataSelecionada = _dataSelecionada.add(Duration(days: 1));
    }
    if (_listaDias.isNotEmpty) {
      _dataSelecionada = _listaDias.first;
    }
  }

  void _gerarListaDias() {
    _listaDias = [];
    DateTime dataBase = DateTime.now();
    int diasAdicionados = 0;
    int diasPercorridos = 0;

    while (diasAdicionados < 30) {
      DateTime data = dataBase.add(Duration(days: diasPercorridos));
      if (data.weekday != DateTime.sunday) {
        _listaDias.add(data);
        diasAdicionados++;
      }
      diasPercorridos++;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null && _userCpf == null) {
      _userCpf = args['cpf'];
      _carregarDadosIniciais();
    }
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _isLoading = true);
    try {
      await _atualizarListaPets();

      final prosSnapshot = await _db
          .collection('profissionais')
          .where('ativo', isEqualTo: true)
          .get();
      _profissionais = prosSnapshot.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      _definirProfissionalAutomatico();
      _buscarHorarios();
    } catch (e) {
      print("Erro: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _atualizarListaPets() async {
    final petsSnapshot = await _db
        .collection('users')
        .doc(_userCpf)
        .collection('pets')
        .get();

    setState(() {
      _pets = petsSnapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (_pets.isNotEmpty && _petId == null) _petId = _pets.first['id'];
    });
  }

  void _definirProfissionalAutomatico() {
    if (_profissionais.isEmpty) return;

    final candidatos = _profissionais.where((pro) {
      final habilidades = List<String>.from(pro['habilidades'] ?? []);
      return habilidades.contains(_servicoSelecionado.toLowerCase());
    }).toList();

    if (candidatos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Nenhum profissional para $_servicoSelecionado."),
        ),
      );
      setState(() {
        _profissionalIdSelecionadoPeloSistema = null;
        _horariosDisponiveis = [];
      });
      return;
    }

    final escolhido = candidatos.first;
    setState(() {
      _profissionalIdSelecionadoPeloSistema = escolhido['id'];
      _nomeProfissionalDoSistema = escolhido['nome'];
    });

    _buscarHorarios();
  }

  Future<void> _buscarHorarios() async {
    // Se o sistema ainda não escolheu ninguém, não busca
    if (_profissionalIdSelecionadoPeloSistema == null) return;

    setState(() {
      _isLoading = true;
      _horariosDisponiveis = [];
      _horarioSelecionado = null;
    });

    try {
      final dataString = DateFormat('yyyy-MM-dd').format(_dataSelecionada);

      print("Buscando horários para: $dataString"); // Log para debug

      // --- A CORREÇÃO É AQUI ---
      final result = await _functions.httpsCallable('buscarHorarios').call({
        'dataConsulta': dataString, // MUDOU DE 'data' PARA 'dataConsulta'
        'profissionalId': _profissionalIdSelecionadoPeloSistema,
        'servico': _servicoSelecionado.toLowerCase(),
      });

      if (mounted) {
        setState(() {
          // O backend retorna { "horarios": ["08:00", "09:00"] }
          _horariosDisponiveis = List<String>.from(result.data['horarios']);
        });
      }
    } catch (e) {
      print("Erro cloud: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao buscar horários. Tente outra data.")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- MODAL ADICIONAR PET ---
  void _abrirModalAdicionarPet() {
    final _nomeController = TextEditingController();
    String _tipo = 'cao';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text("Adicionar Pet Rápido ⚡"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nomeController,
                  decoration: InputDecoration(
                    labelText: "Nome do Pet",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pets),
                  ),
                ),
                SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: Text("Cão"),
                      selected: _tipo == 'cao',
                      onSelected: (v) => setModalState(() => _tipo = 'cao'),
                    ),
                    SizedBox(width: 10),
                    ChoiceChip(
                      label: Text("Gato"),
                      selected: _tipo == 'gato',
                      onSelected: (v) => setModalState(() => _tipo = 'gato'),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_nomeController.text.isNotEmpty) {
                    await _db
                        .collection('users')
                        .doc(_userCpf)
                        .collection('pets')
                        .add({
                          'nome': _nomeController.text,
                          'tipo': _tipo,
                          'raca': 'Não informada',
                          'donoCpf': _userCpf,
                        });
                    Navigator.pop(context);
                    await _atualizarListaPets();
                  }
                },
                child: Text("Salvar"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _salvarAgendamento() async {
    if (_horarioSelecionado == null || _petId == null) return;
    setState(() => _isLoading = true);

    try {
      final dataHoraString =
          "${DateFormat('yyyy-MM-dd').format(_dataSelecionada)} $_horarioSelecionado";
      final dataInicio = DateFormat('yyyy-MM-dd HH:mm').parse(dataHoraString);

      // Define qual valor salvar
      double valorFinal = _servicoSelecionado == 'Banho'
          ? _precoBanho
          : _precoTosa;

      await _db.collection('agendamentos').add({
        'userId': _userCpf,
        'cpf_user': _userCpf,
        'pet_id': _petId,
        'profissional_id': _profissionalIdSelecionadoPeloSistema,
        'profissional_nome': _nomeProfissionalDoSistema,
        'servico': _servicoSelecionado,
        'valor': valorFinal, // Salvamos o preço histórico
        'data_inicio': Timestamp.fromDate(dataInicio),
        'status': 'agendado',
        'criado_em': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Agendamento Confirmado! 🐶")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Novo Agendamento"),
        backgroundColor: Color(0xFF0056D2),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading && _pets.isEmpty
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. SELEÇÃO DE PET ---
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "1. Para quem é o carinho?",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 10),
                        _buildPetSelector(),
                      ],
                    ),
                  ),

                  // --- 2. SERVIÇO (COM PREÇO) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "2. Qual o serviço?",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildServicoCard(
                                "Banho",
                                FontAwesomeIcons.shower,
                                Colors.blue,
                                _precoBanho,
                              ),
                            ),
                            SizedBox(width: 15),
                            Expanded(
                              child: _buildServicoCard(
                                "Tosa",
                                FontAwesomeIcons.scissors,
                                Colors.orange,
                                _precoTosa,
                              ),
                            ),
                          ],
                        ),
                        if (_nomeProfissionalDoSistema != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  "Profissional: $_nomeProfissionalDoSistema",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  SizedBox(height: 25),

                  // --- 3. DATA ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "3. Escolha o dia",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),

                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _listaDias.length,
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      itemBuilder: (context, index) {
                        final dia = _listaDias[index];
                        final isSelected = DateUtils.isSameDay(
                          dia,
                          _dataSelecionada,
                        );

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _dataSelecionada = dia;
                              _horarioSelecionado = null;
                            });
                            _buscarHorarios();
                          },
                          child: Container(
                            width: 70,
                            margin: EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Color(0xFF0056D2)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Color(0xFF0056D2)
                                    : Colors.grey[300]!,
                                width: 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 5,
                                        offset: Offset(0, 3),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('EEE', 'pt_BR')
                                      .format(dia)
                                      .toUpperCase()
                                      .replaceAll('.', ''),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  DateFormat('dd').format(dia),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 25),

                  // --- 4. HORÁRIOS ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "4. Escolha o horário",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _horariosDisponiveis.isEmpty
                        ? Container(
                            padding: EdgeInsets.all(20),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Center(
                              child: _isLoading
                                  ? CircularProgressIndicator()
                                  : Text(
                                      "Sem horários livres nesta data.",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                            ),
                          )
                        : Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _horariosDisponiveis.map((horario) {
                              final isSelected = _horarioSelecionado == horario;
                              return GestureDetector(
                                onTap: () => setState(
                                  () => _horarioSelecionado = horario,
                                ),
                                child: Container(
                                  width: 80,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Color(0xFF0056D2)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? Color(0xFF0056D2)
                                          : Colors.grey[300]!,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: Colors.blue.withOpacity(
                                                0.3,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Center(
                                    child: Text(
                                      horario,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),

                  SizedBox(height: 40),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed:
                            (_horarioSelecionado != null &&
                                _petId != null &&
                                !_isLoading)
                            ? _salvarAgendamento
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 5,
                        ),
                        child: Text(
                          "CONFIRMAR AGENDAMENTO",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
    if (_pets.isEmpty) {
      return GestureDetector(
        onTap: _abrirModalAdicionarPet,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border.all(color: Colors.blue),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              FaIcon(FontAwesomeIcons.paw, size: 30, color: Colors.blue),
              SizedBox(height: 10),
              Text(
                "Cadastre seu pet primeiro!",
                style: TextStyle(
                  color: Colors.blue[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
          icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF0056D2)),
          hint: Text("Selecione seu pet"),
          items: [
            ..._pets.map((pet) {
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
            DropdownMenuItem(
              value: 'add_new',
              child: Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.blue),
                  SizedBox(width: 10),
                  Text(
                    "Adicionar outro...",
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (v) {
            if (v == 'add_new')
              _abrirModalAdicionarPet();
            else
              setState(() => _petId = v);
          },
        ),
      ),
    );
  }

  // ATUALIZADO: Agora aceita o preço
  Widget _buildServicoCard(
    String label,
    IconData icon,
    Color cor,
    double preco,
  ) {
    final isSelected = _servicoSelecionado == label;
    // Formatação de moeda simples
    final precoFormatado =
        "R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}";

    return GestureDetector(
      onTap: () {
        setState(() => _servicoSelecionado = label);
        _definirProfissionalAutomatico();
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? cor.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? cor : Colors.grey[300]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            FaIcon(icon, color: isSelected ? cor : Colors.grey, size: 28),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isSelected ? cor : Colors.grey[700],
              ),
            ),
            SizedBox(height: 4),
            // Exibição do Preço
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? cor : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                precoFormatado,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
