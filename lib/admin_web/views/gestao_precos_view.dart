import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class GestaoPrecosView extends StatefulWidget {
  @override
  _GestaoPrecosViewState createState() => _GestaoPrecosViewState();
}

class _GestaoPrecosViewState extends State<GestaoPrecosView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Cores do Tema
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);

  // Controllers
  final _banhoController = TextEditingController();
  final _tosaController = TextEditingController();
  final _hotelController = TextEditingController();
  final _pctBanhoController = TextEditingController(); // Plano Banho
  final _pctCompletoController = TextEditingController(); // Plano Completo

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarPrecosAtuais();
  }

  Future<void> _carregarPrecosAtuais() async {
    try {
      final doc = await _db.collection('config').doc('parametros').get();
      if (doc.exists) {
        final data = doc.data()!;
        _banhoController.text = (data['preco_banho'] ?? 49.90).toString();
        _tosaController.text = (data['preco_tosa'] ?? 119.90).toString();
        _hotelController.text = (data['preco_hotel_diaria'] ?? 80.00)
            .toString();
        _pctBanhoController.text = (data['preco_pct_banho'] ?? 180.00)
            .toString();
        _pctCompletoController.text = (data['preco_pct_completo'] ?? 250.00)
            .toString();
      }
    } catch (e) {
      print("Erro ao carregar: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarPrecos() async {
    setState(() => _isLoading = true);
    try {
      // Converte texto para double (aceita ponto ou vírgula)
      double parse(String v) => double.tryParse(v.replaceAll(',', '.')) ?? 0.0;

      await _db.collection('config').doc('parametros').set({
        'preco_banho': parse(_banhoController.text),
        'preco_tosa': parse(_tosaController.text),
        'preco_hotel_diaria': parse(_hotelController.text),
        'preco_pct_banho': parse(_pctBanhoController.text),
        'preco_pct_completo': parse(_pctCompletoController.text),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Preços atualizados! O App do cliente já está refletindo os novos valores.",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return Center(child: CircularProgressIndicator(color: _corAcai));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- HEADER ---
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _corLilas,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.price_change, color: _corAcai, size: 30),
            ),
            SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Gestão de Preços",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _corAcai,
                  ),
                ),
                Text(
                  "Altere os valores cobrados no App em tempo real",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),

        SizedBox(height: 40),

        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // LINHA 1: SERVIÇOS AVULSOS
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPriceCard(
                      "Banho Avulso",
                      FontAwesomeIcons.shower,
                      _banhoController,
                      Colors.blue,
                    ),
                    SizedBox(width: 20),
                    _buildPriceCard(
                      "Tosa Completa",
                      FontAwesomeIcons.scissors,
                      _tosaController,
                      Colors.orange,
                    ),
                    SizedBox(width: 20),
                    _buildPriceCard(
                      "Diária Hotel",
                      FontAwesomeIcons.hotel,
                      _hotelController,
                      Colors.purple,
                    ),
                  ],
                ),

                SizedBox(height: 30),

                // LINHA 2: CLUBE DE ASSINATURA
                Text(
                  "Pacotes & Assinaturas",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    _buildPriceCard(
                      "Pacote Banho (4x)",
                      FontAwesomeIcons.ticket,
                      _pctBanhoController,
                      Colors.teal,
                      isWide: true,
                    ),
                    SizedBox(width: 20),
                    _buildPriceCard(
                      "Pacote Completo (4x)",
                      FontAwesomeIcons.crown,
                      _pctCompletoController,
                      Colors.amber,
                      isWide: true,
                    ),
                  ],
                ),

                SizedBox(height: 40),

                // BOTÃO SALVAR
                SizedBox(
                  width: 300,
                  height: 55,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text(
                      "SALVAR ALTERAÇÕES",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _corAcai,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                    ),
                    onPressed: _salvarPrecos,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard(
    String titulo,
    IconData icon,
    TextEditingController controller,
    Color cor, {
    bool isWide = false,
  }) {
    return Expanded(
      flex: isWide ? 1 : 1,
      child: Container(
        padding: EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
          border: Border(top: BorderSide(color: cor, width: 5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cor, size: 24),
                SizedBox(width: 10),
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _corAcai,
              ),
              decoration: InputDecoration(
                prefixText: "R\$ ",
                prefixStyle: TextStyle(fontSize: 18, color: Colors.grey),
                filled: true,
                fillColor: _corLilas.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
