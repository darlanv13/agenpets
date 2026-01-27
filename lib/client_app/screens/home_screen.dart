import 'package:agenpet/client_app/screens/minhas_agendas.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // --- CORES DA MARCA ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF8F9FC);
  final Color _corLilas = Color(0xFFF3E5F5);

  Map<String, dynamic>? _dadosUsuario;
  String _primeiroNome = "";

  // Controle do Carrossel
  final PageController _pageController = PageController();
  int _currentBannerIndex = 0;
  Timer? _timer;

  // --- MAPAS PARA TRADUZIR O BANCO DE DADOS ---
  final Map<String, IconData> _mapaIcones = {
    'shower': FontAwesomeIcons.shower,
    'crown': FontAwesomeIcons.crown,
    'hotel': FontAwesomeIcons.hotel,
    'scissors': FontAwesomeIcons.scissors,
    'percentage': FontAwesomeIcons.percent,
    'syringe': FontAwesomeIcons.syringe,
    'heart': FontAwesomeIcons.heart,
    'star': FontAwesomeIcons.star,
  };

  final Map<String, Color> _mapaCores = {
    'acai': Color(0xFF4A148C),
    'laranja': Colors.orange,
    'azul': Colors.blue,
    'verde': Colors.green,
    'roxo': Colors.purple,
    'rosa': Colors.pink,
    'vermelho': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    _iniciarTimerCarrossel();
    _salvarTokenNotificacao();
  }

  // Adicione esta função na classe
  Future<void> _salvarTokenNotificacao() async {
    if (_dadosUsuario == null) return;

    try {
      // 1. Pede permissão (iOS precisa disso, Android 13+ também)
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 2. Pega o Token
        String? token = await messaging.getToken();

        if (token != null) {
          // 3. Salva no documento do usuário no Firestore
          await _db.collection('users').doc(_dadosUsuario!['cpf']).update({
            'fcmToken': token,
            'ultimo_login': FieldValue.serverTimestamp(),
          });
          print("Token de notificação salvo/atualizado!");
        }
      }
    } catch (e) {
      print("Erro ao salvar token FCM: $e");
    }
  }

  void _iniciarTimerCarrossel() {
    _timer = Timer.periodic(Duration(seconds: 5), (Timer timer) {
      if (_pageController.hasClients) {
        int proximaPagina = _currentBannerIndex + 1;
        _pageController.animateToPage(
          proximaPagina,
          duration: Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _carregarArgumentos();
  }

  void _carregarArgumentos() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      setState(() {
        _dadosUsuario = args;
        String nomeCompleto = _dadosUsuario?['nome'] ?? 'Cliente';
        _primeiroNome = nomeCompleto.split(' ')[0];
      });
    }
  }

  // --- NAVEGAÇÃO ATUALIZADA ---
  void _navegar(String rota) async {
    if (_dadosUsuario == null) return;

    // Lógica específica para abrir Minhas Agendas diretamente
    if (rota == '/minhas_agendas') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MinhasAgendas(userCpf: _dadosUsuario!['cpf']),
        ),
      );
      return;
    }

    // Navegação padrão (Named Routes)
    final result = await Navigator.pushNamed(
      context,
      rota,
      arguments: {'cpf': _dadosUsuario!['cpf']},
    );

    if (rota == '/perfil' && result == true) {
      final doc = await _db
          .collection('users')
          .doc(_dadosUsuario!['cpf'])
          .get();
      if (doc.exists) {
        setState(() {
          _dadosUsuario = doc.data();
          String nomeCompleto = _dadosUsuario?['nome'] ?? 'Cliente';
          _primeiroNome = nomeCompleto.split(' ')[0];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dadosUsuario == null)
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: _corAcai)),
      );

    return Scaffold(
      backgroundColor: _corFundo,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER
            _buildHeader(),

            SizedBox(height: 10),

            // 2. STREAM DE BANNERS
            StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('banners')
                  .where('ativo', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                List<Map<String, dynamic>> bannersData = [];

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  bannersData = snapshot.data!.docs
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .toList();
                } else {
                  bannersData = [
                    {
                      "titulo": "Bem-vindo!",
                      "subtitulo": "Cuidamos do seu pet com amor",
                      "cor_id": "acai",
                      "icone_id": "heart",
                    },
                  ];
                }

                if (_currentBannerIndex >= bannersData.length) {
                  _currentBannerIndex = 0;
                }

                return Column(
                  children: [
                    Container(
                      height: 140,
                      width: double.infinity,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(
                            () => _currentBannerIndex =
                                index % bannersData.length,
                          );
                        },
                        itemBuilder: (context, index) {
                          final banner =
                              bannersData[index % bannersData.length];

                          Color corBg =
                              _mapaCores[banner['cor_id']] ?? _corAcai;
                          IconData icone =
                              _mapaIcones[banner['icone_id']] ??
                              FontAwesomeIcons.star;

                          return _buildBannerItem(
                            titulo: banner['titulo'] ?? '',
                            subtitulo: banner['subtitulo'] ?? '',
                            cor: corBg,
                            icone: icone,
                          );
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(bannersData.length, (index) {
                        return Container(
                          width: 8.0,
                          height: 8.0,
                          margin: EdgeInsets.symmetric(
                            vertical: 10.0,
                            horizontal: 4.0,
                          ),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentBannerIndex == index
                                ? _corAcai
                                : Colors.grey[300],
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),

            SizedBox(height: 10),

            // 3. MENU GRID (Com o novo botão)
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "O que seu pet precisa?",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 15),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 3,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 0.85,
                        physics: BouncingScrollPhysics(),
                        children: [
                          _buildMenuCard(
                            "Agendar",
                            FontAwesomeIcons.calendarPlus,
                            Colors.blue,
                            () => _navegar('/agendamento'),
                          ),
                          _buildMenuCard(
                            "Hotel",
                            FontAwesomeIcons.hotel,
                            Colors.orange,
                            () => _navegar('/hotel'),
                          ),
                          _buildMenuCard(
                            "Creche",
                            FontAwesomeIcons.school,
                            Colors.teal,
                            () => _navegar('/creche'),
                          ),
                          // --- BOTÃO NOVO: MINHAS AGENDAS ---
                          _buildMenuCard(
                            "Minhas Agendas", // Nome atualizado
                            FontAwesomeIcons
                                .calendarDays, // Ícone de calendário/acompanhamento
                            Colors.green, // Verde (para indicar status/ok)
                            () => _navegar('/minhas_agendas'), // Rota nova
                          ),
                          // ----------------------------------
                          _buildMenuCard(
                            "Meus Pets",
                            FontAwesomeIcons.paw,
                            Colors.purple,
                            () => _navegar('/meus_pets'),
                          ),
                          _buildMenuCard(
                            "Assinatura",
                            FontAwesomeIcons.crown,
                            Colors.amber,
                            () => _navegar('/assinatura'),
                          ),
                          _buildMenuCard(
                            "Perfil",
                            FontAwesomeIcons.user,
                            Colors.grey,
                            () => _navegar('/perfil'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _corAcai, width: 2),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: _corLilas,
                  child: Icon(Icons.person, color: _corAcai),
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Olá, $_primeiroNome 👋",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _corAcai,
                    ),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: _db
                        .collection('users')
                        .doc(_dadosUsuario!['cpf'])
                        .collection('pets')
                        .snapshots(),
                    builder: (context, snapshot) {
                      int qtd = snapshot.hasData
                          ? snapshot.data!.docs.length
                          : 0;
                      return Text(
                        qtd == 0 ? "Cadastre seu pet" : "$qtd pets cadastrados",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Colors.grey[400]),
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerItem({
    required String titulo,
    required String subtitulo,
    required Color cor,
    required IconData icone,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cor, cor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cor.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(icone, size: 80, color: Colors.white.withOpacity(0.15)),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "NOVIDADE",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        titulo,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitulo,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: FaIcon(icon, color: color, size: 24),
            ),
            SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
