import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PrecosBaseView extends StatefulWidget {
  @override
  _PrecosBaseViewState createState() => _PrecosBaseViewState();
}

class _PrecosBaseViewState extends State<PrecosBaseView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final _precoHotelCtrl = TextEditingController();
  final _precoCrecheCtrl = TextEditingController();

  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() async {
    try {
      final doc = await _db.collection('config').doc('parametros').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _precoHotelCtrl.text = (data['preco_hotel_diaria'] ?? 0).toString();
          _precoCrecheCtrl.text = (data['preco_creche'] ?? 0).toString();
        });
      }
    } catch (e) {
      print("Erro ao carregar preços: $e");
    }
  }

  void _salvar() async {
    try {
      await _db.collection('config').doc('parametros').set(
        {
          'preco_hotel_diaria':
              double.tryParse(_precoHotelCtrl.text.replaceAll(',', '.')) ?? 0,
          'preco_creche':
              double.tryParse(_precoCrecheCtrl.text.replaceAll(',', '.')) ?? 0,
        },
        SetOptions(merge: true),
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Tabela de preços atualizada! ✅"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao salvar: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tabela Base",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _corAcai,
              ),
            ),
            Text(
              "Defina os valores padrão para serviços recorrentes (Hotel e Creche)",
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 40),

            Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: 800),
                padding: EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInput(
                      "Diária Hotel",
                      "Valor cobrado por noite (24h)",
                      _precoHotelCtrl,
                      FontAwesomeIcons.hotel,
                      Colors.blue,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 25),
                      child: Divider(height: 1),
                    ),
                    _buildInput(
                      "Diária Creche",
                      "Valor cobrado pelo Day Care (apenas dia)",
                      _precoCrecheCtrl,
                      FontAwesomeIcons.dog,
                      Colors.orange,
                    ),
                    SizedBox(height: 50),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.save, size: 22),
                        label: Text(
                          "SALVAR ALTERAÇÕES",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: _salvar,
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

  Widget _buildInput(
    String label,
    String sublabel,
    TextEditingController ctrl,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: FaIcon(icon, color: color, size: 28),
        ),
        SizedBox(width: 25),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 5),
              Text(
                sublabel,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        SizedBox(width: 20),
        Container(
          width: 150,
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          decoration: BoxDecoration(
            color: _corFundo,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: _corAcai,
            ),
            decoration: InputDecoration(
              prefixText: "R\$ ",
              prefixStyle: TextStyle(
                color: Colors.grey[500],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
