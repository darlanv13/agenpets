import 'package:agenpet/client_app/screens/tabs/meus_vouchers_tab.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/firebase_service.dart';

class AssinaturaScreen extends StatefulWidget {
  @override
  _AssinaturaScreenState createState() => _AssinaturaScreenState();
}

class _AssinaturaScreenState extends State<AssinaturaScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final _firebaseService = FirebaseService();
  late TabController _tabController;

  // --- PALETA DE CORES VIBRANTE ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corRoxoClaro = Color(0xFF7B1FA2);
  final Color _corFundo = Color(0xFFF0F2F5);

  String? _cpfUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    if (args != null) _cpfUser = args['cpf'];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _comprar(String pacoteId, String nomePacote, double valor) async {
    setState(() => _isLoading = true);
    try {
      final result = await _firebaseService.comprarAssinatura(
        _cpfUser!,
        pacoteId,
      );

      Navigator.pushNamed(
        context,
        '/pagamento',
        arguments: {
          'pix_copia_cola': result['pix_copia_cola'],
          'imagem_qrcode': result['imagem_qrcode'],
          'vendaId': result['vendaId'],
          'valor': valor,
          'descricao': "Assinatura $nomePacote",
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao iniciar compra: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cpfUser == null)
      return Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: _corFundo,
      appBar: AppBar(
        title: Text(
          "Clube Da Fazendinha",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: _corAcai,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          indicatorWeight: 4,
          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: "LOJA DE PLANOS"),
            Tab(text: "MEUS PACOTES"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _corAcai))
          : TabBarView(
              controller: _tabController,
              children: [
                // ABA 1: VITRINE DE PLANOS
                _buildTabPlanos(),

                // ABA 2: VOUCHERS (Sua Tab existente)
                MeusVouchersTab(userCpf: _cpfUser!),
              ],
            ),
    );
  }

  // ===========================================================================
  // ABA 1: PLANOS (REDESENHADA - VISUAL "VITRINE")
  // ===========================================================================
  Widget _buildTabPlanos() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('pacotes_assinatura')
          .where('ativo', isEqualTo: true)
          .orderBy('preco', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text("Erro ao carregar planos"));
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator(color: _corAcai));

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("Nenhum plano disponível."));
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [
            _buildHeaderPromocional(), // Banner de topo
            SizedBox(height: 20),

            ...snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildPlanCardVibrante(doc.id, data);
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildHeaderPromocional() {
    return Container(
      margin: EdgeInsets.only(top: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_corAcai, _corRoxoClaro]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _corAcai.withOpacity(0.4),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(FontAwesomeIcons.crown, color: Colors.amber, size: 30),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Seja Membro VIP",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Garanta descontos exclusivos e prioridade na agenda do seu pet!",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCardVibrante(String docId, Map<String, dynamic> data) {
    String nome = data['nome'] ?? 'Pacote';
    // --- NOVO: Extração do Porte ---
    String porte = data['porte'] ?? '';
    double preco = (data['preco'] ?? 0).toDouble();
    bool destaque = data['destaque'] ?? false;

    // --- DESIGN SYSTEM DO CARD ---
    Color bgCard = destaque ? _corAcai : Colors.white;
    Color corTextoTitulo = destaque ? Colors.white : Colors.black87;
    Color corTextoDesc = destaque ? Colors.white70 : Colors.grey[600]!;
    Color corIconeCheck = destaque ? Colors.amber : Colors.green;
    Color btnBg = destaque ? Colors.amber : _corAcai;
    Color btnTexto = destaque ? Colors.black87 : Colors.white;

    // Ícone Principal do Plano
    IconData iconePlano = FontAwesomeIcons.paw;
    if (nome.toLowerCase().contains('tosa'))
      iconePlano = FontAwesomeIcons.scissors;
    if (nome.toLowerCase().contains('vip') || destaque)
      iconePlano = FontAwesomeIcons.crown;

    // --- LISTAGEM DINÂMICA DE BENEFÍCIOS ---
    List<Widget> listaBeneficios = [];

    // 1. Varre o mapa 'data' procurando chaves que começam com 'vouchers_'
    data.forEach((key, value) {
      if (key.startsWith('vouchers_') && value is int && value > 0) {
        // Formata o nome: vouchers_corte_unha -> Corte Unha
        String labelRaw = key.replaceAll('vouchers_', '').replaceAll('_', ' ');
        String labelFormatada = labelRaw
            .split(' ')
            .map(
              (str) => str.isNotEmpty
                  ? '${str[0].toUpperCase()}${str.substring(1)}'
                  : '',
            )
            .join(' ');

        // Escolhe um ícone bonitinho baseado no nome
        IconData iconeItem = FontAwesomeIcons.check;
        if (key.contains('banho'))
          iconeItem = FontAwesomeIcons.shower;
        else if (key.contains('tosa'))
          iconeItem = FontAwesomeIcons.scissors;
        else if (key.contains('hidratacao'))
          iconeItem = FontAwesomeIcons.droplet;
        else if (key.contains('taxi') || key.contains('transporte'))
          iconeItem = FontAwesomeIcons.car;
        else if (key.contains('unha'))
          iconeItem = FontAwesomeIcons.handScissors;
        else if (key.contains('hotel'))
          iconeItem = FontAwesomeIcons.hotel;
        else
          iconeItem = Icons.star;

        listaBeneficios.add(
          _buildBeneficioRow(
            "${value}x $labelFormatada",
            corIconeCheck,
            corTextoDesc,
            customIcon: iconeItem,
          ),
        );
      }
    });

    // 2. Adiciona Descrição (se houver) no final
    if (data['descricao'] != null && data['descricao'].toString().isNotEmpty) {
      listaBeneficios.add(
        _buildBeneficioRow(
          data['descricao'],
          corIconeCheck,
          corTextoDesc,
          customIcon: Icons.info_outline,
        ),
      );
    }

    return Stack(
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 25, top: destaque ? 15 : 0),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
            gradient: destaque
                ? LinearGradient(
                    colors: [_corAcai, Color(0xFF6A1B9A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Column(
            children: [
              // Cabeçalho do Card
              Padding(
                padding: EdgeInsets.all(25),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ícone, Nome e PORTE
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: destaque
                                      ? Colors.white.withOpacity(0.15)
                                      : Color(0xFFF3E5F5),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: FaIcon(
                                  iconePlano,
                                  color: destaque ? Colors.white : _corAcai,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nome,
                                      style: TextStyle(
                                        color: corTextoTitulo,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    // --- NOVO: Exibição do Porte ---
                                    if (porte.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          "Para $porte",
                                          style: TextStyle(
                                            color: corTextoDesc,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    else if (!destaque)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          "Plano Mensal",
                                          style: TextStyle(
                                            color: corTextoDesc,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Preço
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "R\$",
                              style: TextStyle(
                                color: corTextoDesc,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              preco.toStringAsFixed(0),
                              style: TextStyle(
                                color: corTextoTitulo,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 25),
                    Divider(
                      color: destaque ? Colors.white24 : Colors.grey[200],
                    ),
                    SizedBox(height: 20),

                    // Benefícios Dinâmicos
                    if (listaBeneficios.isNotEmpty)
                      ...listaBeneficios
                    else
                      Text(
                        "Nenhum item listado",
                        style: TextStyle(color: corTextoDesc),
                      ),

                    SizedBox(height: 30),

                    // Botão de Ação
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: btnBg,
                          foregroundColor: btnTexto,
                          elevation: 8,
                          shadowColor: btnBg.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () => _comprar(docId, nome, preco),
                        child: Text(
                          destaque ? "QUERO SER VIP" : "ASSINAR PLANO",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Badge de "Mais Vendido"
        if (destaque)
          Positioned(
            top: 0,
            right: 30,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 14, color: Colors.black87),
                  SizedBox(width: 5),
                  Text(
                    "MAIS VENDIDO",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBeneficioRow(
    String texto,
    Color corIcone,
    Color corTexto, {
    IconData? customIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: corIcone.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(customIcon ?? Icons.check, size: 14, color: corIcone),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 15,
                color: corTexto,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
