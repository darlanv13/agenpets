import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/firebase_service.dart';

class AssinaturaScreen extends StatefulWidget {
  @override
  _AssinaturaScreenState createState() => _AssinaturaScreenState();
}

class _AssinaturaScreenState extends State<AssinaturaScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final _firebaseService = FirebaseService();

  // --- CORES DA MARCA ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF8F9FC);

  String? _cpfUser;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    if (args != null) _cpfUser = args['cpf'];
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
          'valor': valor,
          'descricao': "Assinatura $nomePacote",
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao iniciar compra: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      appBar: AppBar(
        title: Text(
          "Clube de Assinatura",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _corAcai,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeaderBanner(),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _corAcai))
                : StreamBuilder<QuerySnapshot>(
                    // ATENÇÃO: Se der erro, verifique o console para criar o índice no Firebase
                    stream: _db
                        .collection('pacotes_assinatura')
                        .where('ativo', isEqualTo: true)
                        .orderBy('preco', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      // 1. TRATAMENTO DE ERRO (Para você ver o que está acontecendo)
                      if (snapshot.hasError) {
                        print(
                          "ERRO FIREBASE: ${snapshot.error}",
                        ); // Olhe o console!
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              "Erro ao carregar pacotes.\nVerifique se o Índice foi criado no Firebase.\n\nDetalhe: ${snapshot.error}",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(color: _corAcai),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                FontAwesomeIcons.boxOpen,
                                size: 50,
                                color: Colors.grey[300],
                              ),
                              SizedBox(height: 20),
                              Text(
                                "Nenhum pacote disponível no momento.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      return ListView.builder(
                        padding: EdgeInsets.all(20),
                        physics: BouncingScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (ctx, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final docId = docs[index].id;

                          // Mapeamento dos dados do seu Print
                          String nome = data['nome'] ?? 'Pacote';
                          String porte =
                              data['porte'] ?? ''; // Pego do seu print
                          double preco = (data['preco'] ?? 0).toDouble();
                          String descricao = data['descricao'] ?? '';
                          bool destaque = data['destaque'] ?? false;

                          // Monta benefícios dinamicamente
                          List<String> beneficios = [];

                          if ((data['vouchers_banho'] ?? 0) > 0) {
                            beneficios.add("${data['vouchers_banho']}x Banhos");
                          }
                          if ((data['vouchers_tosa'] ?? 0) > 0) {
                            beneficios.add("${data['vouchers_tosa']}x Tosas");
                          }
                          // Adicionado conforme seu print (Hidratação)
                          if ((data['vouchers_hidratacao'] ?? 0) > 0) {
                            beneficios.add(
                              "${data['vouchers_hidratacao']}x Hidratação",
                            );
                          }

                          if (descricao.isNotEmpty) beneficios.add(descricao);
                          beneficios.add("Válido por 30 dias");

                          // Ícone dinâmico
                          IconData icon = FontAwesomeIcons.paw;
                          Color corTema = _corAcai;

                          if (nome.toLowerCase().contains('supremo') ||
                              destaque) {
                            corTema = Colors.purple;
                            icon = FontAwesomeIcons.crown;
                          } else if ((data['vouchers_tosa'] ?? 0) > 0) {
                            icon = FontAwesomeIcons.scissors;
                            corTema = Colors.orange[800]!;
                          } else {
                            icon = FontAwesomeIcons.shower;
                            corTema = Colors.blue;
                          }

                          return _buildPlanCard(
                            pacoteId: docId,
                            titulo: nome,
                            subtitulo: porte.isNotEmpty
                                ? "Ideal para $porte"
                                : null,
                            preco:
                                "R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}",
                            valorNumerico: preco,
                            beneficios: beneficios,
                            cor: corTema,
                            icon: icon,
                            isDestaque: destaque,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(25, 10, 25, 30),
      decoration: BoxDecoration(
        color: _corAcai,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: _corAcai.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(FontAwesomeIcons.crown, size: 35, color: Colors.amber),
          ),
          SizedBox(height: 15),
          Text(
            "Seja Premium",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 5),
          Text(
            "Assine nossos pacotes e garanta descontos exclusivos e prioridade na agenda.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String pacoteId,
    required String titulo,
    String? subtitulo,
    required String preco,
    required double valorNumerico,
    required List<String> beneficios,
    required Color cor,
    required IconData icon,
    bool isDestaque = false,
  }) {
    return Stack(
      children: [
        Container(
          margin: EdgeInsets.only(top: isDestaque ? 0 : 15, bottom: 15),
          padding: EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isDestaque
                ? Border.all(color: Colors.amber, width: 2)
                : Border.all(color: Colors.transparent),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: FaIcon(icon, color: cor, size: 20),
                  ),
                  if (isDestaque)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "MAIS VENDIDO",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[900],
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(height: 15),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (subtitulo != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitulo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  preco,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: cor,
                  ),
                ),
              ),

              SizedBox(height: 20),
              Divider(height: 1),
              SizedBox(height: 20),

              ...beneficios.map(
                (b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          b,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _comprar(pacoteId, titulo, valorNumerico),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cor,
                    elevation: 4,
                    shadowColor: cor.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    "ASSINAR AGORA",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
