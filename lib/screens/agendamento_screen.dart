import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/firebase_service.dart';

class AgendamentoScreen extends StatefulWidget {
  @override
  _AgendamentoScreenState createState() => _AgendamentoScreenState();
}

class _AgendamentoScreenState extends State<AgendamentoScreen> {
  // Conexão com o Banco de Dados
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Conexão com Funções (Região SP - Brasil)
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  // Instância do nosso Serviço para lógicas extras
  final _firebaseService = FirebaseService();

  // --- PREÇOS ---
  double _precoBanho = 0.0;
  double _precoTosa = 0.0;

  // Variáveis de Estado
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
    _carregarPrecosAtualizados();
    _gerarListaDias();

    // Garante que a data inicial não seja domingo
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
      // Pula domingos
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

  Future<void> _carregarPrecosAtualizados() async {
    try {
      final doc = await _db.collection('config').doc('parametros').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          // Usa toDouble() para evitar erros se vier int do banco
          _precoBanho = (data['preco_banho'] ?? 49.90).toDouble();
          _precoTosa = (data['preco_tosa'] ?? 119.90).toDouble();
        });
      }
    } catch (e) {
      print("Erro ao carregar preços: $e");
      // Fallback seguro
      setState(() {
        _precoBanho = 49.90;
        _precoTosa = 119.90;
      });
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

    // Pega o primeiro disponível (lógica simples de fila)
    final escolhido = candidatos.first;
    setState(() {
      _profissionalIdSelecionadoPeloSistema = escolhido['id'];
      _nomeProfissionalDoSistema = escolhido['nome'];
    });

    _buscarHorarios();
  }

  Future<void> _buscarHorarios() async {
    if (_profissionalIdSelecionadoPeloSistema == null) return;

    setState(() {
      _isLoading = true;
      _horariosDisponiveis = [];
      _horarioSelecionado = null;
    });

    try {
      final dataString = DateFormat('yyyy-MM-dd').format(_dataSelecionada);

      // Chamada Cloud Function (Região SP)
      final result = await _functions.httpsCallable('buscarHorarios').call({
        'dataConsulta': dataString,
        'profissionalId': _profissionalIdSelecionadoPeloSistema,
        'servico': _servicoSelecionado.toLowerCase(),
      });

      if (mounted) {
        setState(() {
          _horariosDisponiveis = List<String>.from(result.data['horarios']);
        });
      }
    } catch (e) {
      print("Erro cloud: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LÓGICA DE PAGAMENTO E FINALIZAÇÃO ---

  void _mostrarOpcoesPagamento(int saldoVouchers) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.all(25),
          height: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Como deseja pagar?",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(
                "Escolha a melhor forma para você.",
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 25),

              // OPÇÃO 1: VOUCHER (Condicional)
              if (saldoVouchers > 0) ...[
                _buildBotaoPagamento(
                  icon: FontAwesomeIcons.ticket,
                  cor: Colors.purple,
                  titulo: "USAR MEU VOUCHER",
                  subtitulo: "Você tem $saldoVouchers disponíveis",
                  onTap: () {
                    Navigator.pop(ctx);
                    _finalizarAgendamento('voucher');
                  },
                ),
                SizedBox(height: 15),
              ],

              // OPÇÃO 2: PIX
              _buildBotaoPagamento(
                icon: FontAwesomeIcons.pix,
                cor: Color(0xFF32BCAD),
                titulo: "PAGAR COM PIX",
                subtitulo: "Liberação imediata",
                onTap: () {
                  Navigator.pop(ctx);
                  _finalizarAgendamento('pix');
                },
              ),

              SizedBox(height: 15),

              // OPÇÃO 3: BALCÃO
              _buildBotaoPagamento(
                icon: FontAwesomeIcons.store,
                cor: Colors.orange,
                titulo: "PAGAR NO BALCÃO",
                subtitulo: "Dinheiro ou Cartão na loja",
                onTap: () {
                  Navigator.pop(ctx);
                  _finalizarAgendamento('dinheiro');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _finalizarAgendamento(String metodo) async {
    setState(() => _isLoading = true);

    try {
      // Prepara os dados
      final dataHoraString =
          "${DateFormat('yyyy-MM-dd').format(_dataSelecionada)} $_horarioSelecionado";
      final dataInicio = DateFormat('yyyy-MM-dd HH:mm').parse(dataHoraString);
      double valorFinal = _servicoSelecionado == 'Banho'
          ? _precoBanho
          : _precoTosa;

      // Chama o Backend via Service
      final result = await _firebaseService.criarAgendamento(
        servico: _servicoSelecionado,
        dataHora: dataInicio,
        cpfUser: _userCpf!,
        petId: _petId!,
        metodoPagamento: metodo,
        valor: valorFinal,
      );

      // Tratamento do Resultado
      if (metodo == 'voucher') {
        _mostrarSucesso("Voucher utilizado com sucesso! 🎟️");
        Navigator.pop(context); // Volta pra Home
      } else if (metodo == 'pix') {
        // Vai para tela de pagamento com o QR Code recebido
        Navigator.pushReplacementNamed(
          context,
          '/pagamento',
          arguments: result,
        );
      } else {
        _mostrarSucesso("Agendado! Pague no balcão.");
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro: ${e.toString().replaceAll('Exception: ', '')}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarSucesso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text(msg),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- MODAL CADASTRO PET ---
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
                  // 1. PET
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

                  // 2. SERVIÇO
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

                  // 3. DIA
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

                  // 4. HORÁRIO
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

                  // BOTÃO DE CONFIRMAÇÃO (COM MONITORAMENTO DE VOUCHER)
                  StreamBuilder<Map<String, int>>(
                    stream: _userCpf != null
                        ? _firebaseService.getSaldoVouchers(_userCpf!)
                        : Stream.value({'banho': 0, 'tosa': 0}), // Fallback
                    builder: (context, snapshot) {
                      int saldoVouchers = 0;
                      if (snapshot.hasData) {
                        saldoVouchers = _servicoSelecionado == 'Banho'
                            ? snapshot.data!['banho']!
                            : snapshot.data!['tosa']!;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed:
                                (_horarioSelecionado != null &&
                                    _petId != null &&
                                    !_isLoading)
                                ? () => _mostrarOpcoesPagamento(saldoVouchers)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 5,
                            ),
                            child: Text(
                              "CONTINUAR PARA PAGAMENTO",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  // --- WIDGETS AUXILIARES DE UI ---

  Widget _buildBotaoPagamento({
    required IconData icon,
    required Color cor,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: FaIcon(icon, color: cor, size: 20),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    subtitulo,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
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

  Widget _buildServicoCard(
    String label,
    IconData icon,
    Color cor,
    double preco,
  ) {
    final isSelected = _servicoSelecionado == label;
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
