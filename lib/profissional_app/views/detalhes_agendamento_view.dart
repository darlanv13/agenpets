import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agenpet/admin_web/widgets/servicos_select_dialog.dart';

class DetalhesAgendamentoView extends StatefulWidget {
  final String agendamentoId;

  const DetalhesAgendamentoView({Key? key, required this.agendamentoId})
    : super(key: key);

  @override
  _DetalhesAgendamentoViewState createState() =>
      _DetalhesAgendamentoViewState();
}

class _DetalhesAgendamentoViewState extends State<DetalhesAgendamentoView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);

  Future<void> _abrirWhatsApp(String telefone, String nomeCliente) async {
    String soNumeros = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!soNumeros.startsWith('55')) {
      soNumeros = '55$soNumeros';
    }

    final String mensagem = Uri.encodeComponent(
      "Olá $nomeCliente, tudo bem? Estamos entrando em contato sobre o agendamento na AgenPet.",
    );
    final Uri url = Uri.parse("https://wa.me/$soNumeros?text=$mensagem");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Não foi possível abrir o WhatsApp.")),
      );
    }
  }

  Future<void> _adicionarServicos(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final existingExtras = data['servicos_extras'] != null
        ? List<Map<String, dynamic>>.from(data['servicos_extras'])
        : <Map<String, dynamic>>[];

    final List<Map<String, dynamic>>? result = await showDialog(
      context: context,
      builder: (ctx) => ServicosSelectDialog(initialSelected: existingExtras),
    );

    if (result != null) {
      await _db.collection('agendamentos').doc(widget.agendamentoId).update({
        'servicos_extras': result,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Serviços atualizados com sucesso!")),
      );
    }
  }

  Future<void> _marcarComoPronto(BuildContext context) async {
    try {
      await _db.collection('agendamentos').doc(widget.agendamentoId).update({
        'status': 'pronto',
        'fim_servico': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context); // Retorna para a tela anterior
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Pet marcado como PRONTO! 🐶"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao finalizar: $e")));
    }
  }

  Future<void> _confirmarRecebimento(BuildContext context) async {
    try {
      await _db.collection('agendamentos').doc(widget.agendamentoId).update({
        'status': 'checklist_pendente',
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Recebimento confirmado! Iniciando Checklist..."),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao confirmar: $e")));
    }
  }

  Future<void> _irParaChecklist(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    // Implementar navegação ou lógica se necessário,
    // mas o usuário pode voltar para a lista e clicar em "Fazer Checklist"
    // ou podemos navegar direto se tivermos a rota/widget.
    // Como o user disse "volta para a lista e o botão de checklist fica disponível",
    // apenas voltamos.
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FC),
      appBar: AppBar(
        title: Text(
          "Detalhes do Serviço",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _corAcai,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db
            .collection('agendamentos')
            .doc(widget.agendamentoId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: _corAcai));
          }

          if (!snapshot.data!.exists) {
            return Center(child: Text("Agendamento não encontrado."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String userId = data['userId'];
          final String petId = data['pet_id'];
          final String status = data['status'] ?? 'agendado';

          final bool isEditable =
              status != 'pronto' &&
              status != 'concluido' &&
              status != 'cancelado';

          return Column(
            children: [
              // HEADER (CLIENTE & PET)
              Container(
                color: _corAcai,
                padding: EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: FutureBuilder<List<DocumentSnapshot>>(
                  future: Future.wait([
                    _db.collection('users').doc(userId).get(),
                    _db
                        .collection('users')
                        .doc(userId)
                        .collection('pets')
                        .doc(petId)
                        .get(),
                  ]),
                  builder: (context, userSnap) {
                    if (!userSnap.hasData) return SizedBox(height: 100);

                    final userData =
                        userSnap.data![0].data() as Map<String, dynamic>? ?? {};
                    final petData =
                        userSnap.data![1].data() as Map<String, dynamic>? ?? {};

                    final nomeCliente = userData['nome'] ?? 'Cliente';
                    final telefone =
                        userData['celular'] ?? userData['telefone'] ?? '';
                    final nomePet = petData['nome'] ?? 'Pet';
                    final racaPet = petData['raca'] ?? 'SRD';

                    return Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: _corLilas,
                            child: Icon(
                              FontAwesomeIcons.dog,
                              color: _corAcai,
                              size: 30,
                            ),
                          ),
                          SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nomePet,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  "$racaPet • $nomeCliente",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (telefone.isNotEmpty)
                            IconButton(
                              icon: FaIcon(
                                FontAwesomeIcons.whatsapp,
                                color: Colors.green,
                                size: 30,
                              ),
                              onPressed: () =>
                                  _abrirWhatsApp(telefone, nomeCliente),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(20),
                  children: [
                    // SERVIÇO PRINCIPAL
                    Text(
                      "SERVIÇO PRINCIPAL",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(FontAwesomeIcons.tag, color: _corAcai, size: 18),
                          SizedBox(width: 10),
                          Text(
                            (data['servicoNorm'] ?? data['servico'])
                                .toString()
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 25),

                    // EXTRAS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "SERVIÇOS EXTRAS",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                            letterSpacing: 1,
                          ),
                        ),
                        if (isEditable)
                          TextButton.icon(
                            onPressed: () => _adicionarServicos(context, data),
                            icon: Icon(Icons.add_circle_outline, size: 16),
                            label: Text("Adicionar"),
                            style: TextButton.styleFrom(
                              foregroundColor: _corAcai,
                            ),
                          ),
                      ],
                    ),
                    if (data['servicos_extras'] != null &&
                        (data['servicos_extras'] as List).isNotEmpty)
                      ...List<Widget>.from(
                        (data['servicos_extras'] as List).map((item) {
                          return Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item['nome'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  "R\$ ${(item['preco'] as num).toDouble().toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      )
                    else
                      Container(
                        padding: EdgeInsets.all(20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "Nenhum serviço extra",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),

              // FOOTER ACTIONS
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Builder(
                  builder: (context) {
                    // SE NÃO EDITÁVEL (PRONTO/CONCLUÍDO)
                    if (!isEditable) {
                      return Container(
                        height: 55,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(
                              status == 'cancelado'
                                  ? "AGENDAMENTO CANCELADO"
                                  : "SERVIÇO FINALIZADO",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (status == 'agendado' ||
                        status == 'aguardando_execucao' ||
                        status == 'aguardando_pagamento') {
                      return SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                          onPressed: () => _confirmarRecebimento(context),
                          icon: Icon(Icons.thumb_up, size: 28),
                          label: Text(
                            "CONFIRMAR RECEBIMENTO",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      );
                    } else if (status == 'checklist_pendente') {
                      return SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.playlist_add_check, size: 28),
                          label: Text(
                            "IR PARA CHECKLIST",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      );
                    } else if (status == 'banhando' || status == 'tosando') {
                      return SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                          onPressed: () => _marcarComoPronto(context),
                          icon: Icon(Icons.check_circle_outline, size: 28),
                          label: Text(
                            "PET PRONTO",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      );
                    }
                    return SizedBox();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
