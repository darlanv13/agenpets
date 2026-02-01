import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

class PagamentoScreen extends StatefulWidget {
  const PagamentoScreen({super.key});

  @override
  _PagamentoScreenState createState() => _PagamentoScreenState();
}

class _PagamentoScreenState extends State<PagamentoScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  bool _isPaid = false;
  Map<String, dynamic>? args;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
  }

  @override
  Widget build(BuildContext context) {
    if (args == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Erro")),
        body: Center(child: Text("Dados do pagamento não encontrados.")),
      );
    }

    final String pixCopiaCola = args!['pix_copia_cola'] ?? '';
    final String? imagemQrcodeBase64 = args!['imagem_qrcode']; // Se vier base64
    final double valor = (args!['valor'] ?? 0).toDouble();
    final String vendaId = args!['vendaId'] ?? '';
    final String descricao = args!['descricao'] ?? 'Pagamento AgenPet';
    final String tenantId = args!['tenantId'] ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Realizar Pagamento"),
        backgroundColor: Color(0xFF4A148C),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db
            .collection('tenants')
            .doc(tenantId)
            .collection('vendas_assinaturas')
            .doc(vendaId)
            .snapshots(),
        builder: (context, snapshot) {
          // Verifica se pagou
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            if (data['status'] == 'pago') {
              // Se detectou pagamento, mudamos o estado para exibir sucesso
              if (!_isPaid) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() => _isPaid = true);
                });
              }
            }
          }

          if (_isPaid) {
            return _buildSuccessView();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cartão de Resumo
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                      Icon(
                        FontAwesomeIcons.pix,
                        color: Color(0xFF32BCAD), // Cor PIX
                        size: 40,
                      ),
                      SizedBox(height: 10),
                      Text(
                        descricao,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        "R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A148C),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 30),

                Text(
                  "Escaneie o QR Code",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 20),

                // QR CODE
                Center(
                  child: Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: imagemQrcodeBase64 != null
                        ? Image.memory(
                            base64Decode(imagemQrcodeBase64.split(',').last),
                            width: 220,
                            height: 220,
                            errorBuilder: (_, __, ___) => QrImageView(
                              data: pixCopiaCola,
                              version: QrVersions.auto,
                              size: 220.0,
                            ),
                          )
                        : QrImageView(
                            data: pixCopiaCola,
                            version: QrVersions.auto,
                            size: 220.0,
                          ),
                  ),
                ),

                SizedBox(height: 30),

                // Botão Copia e Cola
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF32BCAD),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: Icon(Icons.copy),
                  label: Text(
                    "COPIAR CÓDIGO PIX",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pixCopiaCola));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Código Pix copiado!"),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),

                SizedBox(height: 20),

                // Texto de espera
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Aguardando confirmação...",
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 80,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 30),
            Text(
              "Pagamento Aprovado!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            SizedBox(height: 15),
            Text(
              "Seu pacote já está ativo e os vouchers estão disponíveis na sua conta.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], fontSize: 16),
            ),
            SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4A148C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Volta para tela anterior
                  // Ou Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                },
                child: Text("VOLTAR", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
