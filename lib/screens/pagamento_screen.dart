// lib/screens/pagamento_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PagamentoScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Simulação dos dados que viriam da Cloud Function
    final String pixCopiaCola = "00020126580014br.gov.bcb.pix0136...";

    return Scaffold(
      appBar: AppBar(title: Text("Pagamento")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              "Escaneie o QR Code ou copie o código abaixo:",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),

            // Exibe o QR Code
            QrImageView(
              data: pixCopiaCola,
              version: QrVersions.auto,
              size: 200.0,
            ),

            SizedBox(height: 30),

            // Botão Copia e Cola
            ElevatedButton.icon(
              icon: Icon(Icons.copy),
              label: Text("COPIAR CÓDIGO PIX"),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: pixCopiaCola));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Código Pix copiado!")));
              },
            ),

            Spacer(),
            Text(
              "Após o pagamento, seu agendamento será confirmado automaticamente!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
