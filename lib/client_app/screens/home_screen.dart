import 'package:agenpet/client_app/screens/minhas_agendas.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

  Map<String, dynamic>? _dadosUsuario;
  String _primeiroNome = "";

  // Configuração da Loja (Módulos)
  bool _temBanhoTosa = true;
  bool _temHotel = false;
  bool _temCreche = false;
  bool _temLoja = false;
  bool _temVeterinario = false;
  bool _temTaxi = false;

  @override
  void initState() {
    super.initState();
    _salvarTokenNotificacao();
    _carregarConfiguracoes();
  }

  Future<void> _carregarConfiguracoes() async {
    try {
      final doc = await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('config')
          .doc('parametros')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _temBanhoTosa = data['tem_banho_tosa'] ?? true;
            _temHotel = data['tem_hotel'] ?? false;
            _temCreche = data['tem_creche'] ?? false;
            _temLoja = data['tem_loja'] ?? false;
            _temVeterinario = data['tem_veterinario'] ?? false;
            _temTaxi = data['tem_taxi'] ?? false;
          });
        }
      }
    } catch (e) {
      print("Erro ao carregar configs da loja: $e");
    }
  }

  Future<void> _salvarTokenNotificacao() async {
    if (_dadosUsuario == null) return;
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          await _db.collection('users').doc(_dadosUsuario!['cpf']).update({
            'fcmToken': token,
            'ultimo_login': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print("Erro ao salvar token FCM: $e");
    }
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

  void _navegar(String rota) async {
    if (_dadosUsuario == null) return;

    if (rota == '/minhas_agendas') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MinhasAgendas(userCpf: _dadosUsuario!['cpf']),
        ),
      );
      return;
    }

    // Funcionalidades ainda não implementadas
    if (rota == '/em_breve') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Esta funcionalidade estará disponível em breve! 🚀"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
    if (_dadosUsuario == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: _corAcai)),
      );
    }

    return Scaffold(
      backgroundColor: _corFundo,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER MINIMALISTA
            _buildMinimalHeader(),

            SizedBox(height: 10),

            // 2. STATUS RÁPIDO / CTA
            _buildStatusSection(),

            SizedBox(height: 20),

            // 3. MENU PRINCIPAL
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Menu Principal",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
            SizedBox(height: 10),

            Expanded(
              child: GridView.count(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.1,
                physics: BouncingScrollPhysics(),
                children: [
                  if (_temBanhoTosa)
                    _buildMenuCard(
                      "Agendar Banho/Tosa",
                      FontAwesomeIcons.shower,
                      _corAcai,
                      Colors.white,
                      () => _navegar('/agendamento'),
                    ),
                  if (_temHotel)
                    _buildMenuCard(
                      "Hotelzinho",
                      FontAwesomeIcons.hotel,
                      Colors.orange,
                      Colors.white,
                      () => _navegar('/hotel'),
                    ),
                  if (_temCreche)
                    _buildMenuCard(
                      "Creche",
                      FontAwesomeIcons.school,
                      Colors.teal,
                      Colors.white,
                      () => _navegar('/creche'),
                    ),
                  if (_temLoja)
                    _buildMenuCard(
                      "Loja / Pet Shop",
                      FontAwesomeIcons.shop,
                      Colors.pink,
                      Colors.white,
                      () => _navegar('/em_breve'),
                    ),
                  if (_temVeterinario)
                    _buildMenuCard(
                      "Veterinário",
                      FontAwesomeIcons.userDoctor,
                      Colors.green,
                      Colors.white,
                      () => _navegar('/em_breve'),
                    ),
                  if (_temTaxi)
                    _buildMenuCard(
                      "Táxi Dog",
                      FontAwesomeIcons.car,
                      Colors.purple,
                      Colors.white,
                      () => _navegar('/em_breve'),
                    ),

                  // Itens Fixos do Usuário
                  _buildMenuCard(
                    "Meus Agendamentos",
                    FontAwesomeIcons.calendarCheck,
                    Colors.blueAccent,
                    Colors.white,
                    () => _navegar('/minhas_agendas'),
                  ),
                  _buildMenuCard(
                    "Meus Pets",
                    FontAwesomeIcons.paw,
                    Colors.purple,
                    Colors.white,
                    () => _navegar('/meus_pets'),
                  ),
                  _buildMenuCard(
                    "Assinatura",
                    FontAwesomeIcons.crown,
                    Colors.amber,
                    Colors.white,
                    () => _navegar('/assinatura'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildMinimalHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Olá, $_primeiroNome 👋",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                "Vamos cuidar do seu pet hoje?",
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            icon: Icon(Icons.logout, color: Colors.grey[400]),
            tooltip: "Sair",
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_corAcai, Color(0xFF7B1FA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _corAcai.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navegar('/agendamento'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.calendar_today, color: Colors.white),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Novo Agendamento",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "Clique aqui para agendar agora",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    String label,
    IconData icon,
    Color color,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: FaIcon(icon, color: color, size: 28),
              ),
              SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
