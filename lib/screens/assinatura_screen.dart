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
  final _firebaseService = FirebaseService();
  String? _cpfUser;
  bool _isLoading = false;

  ///Preços da Assinatura////
  double _precoPctBanho = 180.00;
  double _precoPctCompleto = 250.00;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    if (args != null) _cpfUser = args['cpf'];
  }

  void _comprar(String plano, String nome, double valor) async {
    setState(() => _isLoading = true);
    try {
      final result = await _firebaseService.comprarAssinatura(_cpfUser!, plano);

      // Envia para tela de pagamento com os dados do PIX
      Navigator.pushNamed(
        context,
        '/pagamento',
        arguments: {
          'pix_copia_cola': result['pix_copia_cola'],
          'imagem_qrcode': result['imagem_qrcode'],
          'valor': valor,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _carregarPrecosPlanos();
  }

  Future<void> _carregarPrecosPlanos() async {
    final doc = await FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'agenpets',
    ).collection('config').doc('parametros').get();

    if (doc.exists) {
      setState(() {
        _precoPctBanho = (doc.data()!['preco_pct_banho'] ?? 180.00).toDouble();
        _precoPctCompleto = (doc.data()!['preco_pct_completo'] ?? 250.00)
            .toDouble();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(title: Text("Clube de Assinatura 👑"), centerTitle: true),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    "Economize com nossos pacotes!",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Vouchers válidos por 30 dias.",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 30),

                  // CARD BANHO
                  _buildPlanCard(
                    titulo: "Pacote Banho",
                    preco:
                        "R\$ ${_precoPctBanho.toStringAsFixed(2).replaceAll('.', ',')}",
                    beneficios: [
                      "4 Vouchers de Banho",
                      "Válido para qualquer pet",
                      "Economia garantida",
                    ],
                    cor: Colors.blue,
                    icon: FontAwesomeIcons.shower,
                    onTap: () =>
                        _comprar('pct_banho', 'Pacote Banho', _precoPctBanho),
                  ),

                  SizedBox(height: 20),

                  // CARD BANHO & TOSA
                  _buildPlanCard(
                    titulo: "Pacote Completo",
                    preco:
                        "R\$ ${_precoPctCompleto.toStringAsFixed(2).replaceAll('.', ',')}",
                    beneficios: [
                      "4 Vouchers Banho & Tosa",
                      "Cuidado completo",
                      "Prioridade na agenda",
                    ],
                    cor: Colors.purple,
                    icon: FontAwesomeIcons.scissors,
                    isDestaque: true,
                    onTap: () => _comprar(
                      'pct_completo',
                      'Pacote Completo',
                      _precoPctCompleto,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard({
    required String titulo,
    required String preco,
    required List<String> beneficios,
    required Color cor,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestaque = false,
  }) {
    return Stack(
      children: [
        Container(
          margin: EdgeInsets.only(top: isDestaque ? 0 : 10),
          padding: EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isDestaque
                ? Border.all(color: Colors.orange, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: cor.withOpacity(0.1),
                child: FaIcon(icon, color: cor, size: 25),
              ),
              SizedBox(height: 15),
              Text(
                titulo,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                preco,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: cor,
                ),
              ),
              SizedBox(height: 20),
              ...beneficios.map(
                (b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text(b),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cor,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "ASSINAR AGORA",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isDestaque)
          Positioned(
            top: 10,
            right: 20,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "MAIS VENDIDO",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
