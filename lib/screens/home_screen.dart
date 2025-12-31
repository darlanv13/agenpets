import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Conexão segura com o banco 'agenpets'
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  Map<String, dynamic>? _dadosUsuario;
  String _primeiroNome = "";

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
        // Pega apenas o primeiro nome
        String nomeCompleto = _dadosUsuario?['nome'] ?? 'Cliente';
        _primeiroNome = nomeCompleto.split(' ')[0];
      });
    }
  }

  void _navegar(String rota) async {
    if (_dadosUsuario == null) return;

    // O await aqui serve para esperar o retorno da tela de perfil (caso o nome mude)
    final result = await Navigator.pushNamed(
      context,
      rota,
      arguments: {'cpf': _dadosUsuario!['cpf']},
    );

    // Se voltou da tela de perfil com alteração, atualizamos o nome aqui
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
      return Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor:
          Colors.grey[100], // Fundo levemente cinza para destacar os cards
      body: Column(
        children: [
          // --- HEADER PERSONALIZADO (UX APRIMORADA) ---
          Container(
            padding: EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 25),
            decoration: BoxDecoration(
              color: Color(0xFF0056D2), // Azul da marca
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                // FOTO DO USUÁRIO
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.blue[100],
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.blue[700],
                    ),
                    // No futuro: backgroundImage: NetworkImage(fotoUrl),
                  ),
                ),
                SizedBox(width: 15),

                // NOME E QUANTIDADE DE PETS
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Olá, $_primeiroNome!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      // Contador de Pets em Tempo Real
                      StreamBuilder<QuerySnapshot>(
                        stream: _db
                            .collection('users')
                            .doc(_dadosUsuario!['cpf'])
                            .collection('pets')
                            .snapshots(),
                        builder: (context, snapshot) {
                          int qtdPets = 0;
                          if (snapshot.hasData)
                            qtdPets = snapshot.data!.docs.length;

                          return Row(
                            children: [
                              FaIcon(
                                FontAwesomeIcons.paw,
                                color: Colors.blue[100],
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "$qtdPets pets cadastrados",
                                style: TextStyle(
                                  color: Colors.blue[100],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // BOTÕES DE AÇÃO (PERFIL E SAIR)
                Row(
                  children: [
                    _buildHeaderButton(Icons.edit, () => _navegar('/perfil')),
                    SizedBox(width: 10),
                    _buildHeaderButton(
                      Icons.logout,
                      () => Navigator.pushReplacementNamed(context, '/login'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- CORPO DA HOME ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Serviços Disponíveis",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 15),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio:
                          1.1, // Deixa os cards um pouco mais retangulares
                      children: [
                        _buildCard(
                          icon: FontAwesomeIcons.shower,
                          color: Colors.blue,
                          label: "Banho & Tosa",
                          onTap: () => _navegar('/agendamento'),
                        ),
                        _buildCard(
                          icon: FontAwesomeIcons.hotel,
                          color: Colors.orange, // Laranja combina com hotel
                          label: "Hotelzinho",
                          onTap: () => _navegar('/hotel'),
                        ),
                        _buildCard(
                          icon: FontAwesomeIcons.paw,
                          color: Colors.purple,
                          label: "Meus Pets",
                          onTap: () => _navegar('/meus_pets'),
                        ),
                        _buildCard(
                          icon: FontAwesomeIcons.crown,
                          color: Colors.amber, // Dourado
                          label: "Clube AgenPet",
                          onTap: () => _navegar('/assinatura'),
                        ),
                        _buildCard(
                          icon: FontAwesomeIcons.fileInvoiceDollar,
                          color: Colors.green,
                          label: "Histórico",
                          onTap: () =>
                              _navegar('/historico'), // AGORA CONECTADO
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
    );
  }

  // Botão pequeno transparente no Header
  Widget _buildHeaderButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
        constraints: BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
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
            SizedBox(height: 15),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
