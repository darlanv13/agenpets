import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PrecosBaseTab extends StatefulWidget {
  @override
  _PrecosBaseTabState createState() => _PrecosBaseTabState();
}

class _PrecosBaseTabState extends State<PrecosBaseTab> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Controladores
  final _precoHotelCtrl = TextEditingController();
  final _precoCrecheCtrl = TextEditingController();

  // Cores
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
          // Carrega o novo campo 'preco_creche'
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
      ); // Merge para não apagar o preço de banho/tosa se ainda existirem no banco

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Tabela de preços atualizada! ✅"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
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
    return Container(
      color: _corFundo,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(30),
          child: Column(
            children: [
              Text(
                "Tabela de Hospedagem",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _corAcai,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "Defina os valores base para estadia e day care",
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 40),

              Container(
                constraints: BoxConstraints(maxWidth: 600),
                padding: EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // ITEM 1: HOTEL
                    _buildInput(
                      "Diária Hotel",
                      "Valor por noite (24h)",
                      _precoHotelCtrl,
                      FontAwesomeIcons.hotel,
                      Colors.blue,
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Divider(height: 1),
                    ),

                    // ITEM 2: CRECHE
                    _buildInput(
                      "Diária Creche",
                      "Day Care (apenas dia)",
                      _precoCrecheCtrl,
                      FontAwesomeIcons.dog,
                      Colors.orange,
                    ),

                    SizedBox(height: 40),

                    // BOTÃO SALVAR
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.save_as, size: 20),
                        label: Text(
                          "SALVAR ALTERAÇÕES",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shadowColor: Colors.green.withOpacity(0.4),
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
            ],
          ),
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
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: FaIcon(icon, color: color, size: 24),
        ),
        SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        SizedBox(width: 15),
        Container(
          width: 130,
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          decoration: BoxDecoration(
            color: _corFundo,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: _corAcai,
            ),
            decoration: InputDecoration(
              prefixText: "R\$ ",
              prefixStyle: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
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
