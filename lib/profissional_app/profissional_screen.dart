import 'package:agenpet/client_app/screens/components/checklist_pet_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ProfissionalScreen extends StatefulWidget {
  @override
  _ProfissionalScreenState createState() => _ProfissionalScreenState();
}

class _ProfissionalScreenState extends State<ProfissionalScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  // --- CORES DA MARCA ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF8F9FC);

  Map<String, dynamic>? _dadosPro;
  DateTime _dataFiltro = DateTime.now();

  // Filtro de Visualização
  String _filtroServico = 'Todos';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dadosPro == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _dadosPro = args;
    }
  }

  // --- LÓGICA PRINCIPAL DO CHECKLIST E STATUS ---
  Future<void> _avancarStatus(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    String statusAtual = data['status'] ?? 'agendado';
    bool checklistFeito = data['checklist_feito'] ?? false;

    // 1. INÍCIO DO PROCESSO (Checklist -> Banho)
    if (statusAtual == 'agendado' || statusAtual == 'aguardando_pagamento') {
      if (!checklistFeito) {
        // FLUXO A: Selecionar Profissional -> Fazer Checklist
        await _selecionarProfissional(doc);
      } else {
        // FLUXO B: Já fez checklist -> Iniciar Banho
        await doc.reference.update({
          'status': 'banhando',
          'inicio_servico': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Banho iniciado! 🚿")));
      }
      return;
    }

    // 2. DEMAIS ETAPAS (Banho -> Tosa -> Pronto)
    String servicoNorm = (data['servicoNorm'] ?? data['servico'] ?? '')
        .toString()
        .toLowerCase();
    bool temTosa = servicoNorm.contains('tosa');
    String novoStatus = 'pronto';
    String mensagem = "Pet pronto! 🐶";

    if (statusAtual == 'banhando') {
      if (temTosa) {
        novoStatus = 'tosando';
        mensagem = "Indo para tosa! ✂️";
      } else {
        novoStatus = 'pronto';
      }
    } else if (statusAtual == 'tosando') {
      novoStatus = 'pronto';
    }

    if (novoStatus == 'pronto') {
      await _verificarEBaixarVouchers(doc); // Lógica de voucher existente
    } else {
      await doc.reference.update({'status': novoStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: _corAcai,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _selecionarProfissional(DocumentSnapshot doc) async {
    try {
      // Busca profissionais ativos
      QuerySnapshot prosSnapshot = await _db
          .collection('profissionais')
          .where('ativo', isEqualTo: true)
          .get();

      List<DocumentSnapshot> pros = prosSnapshot.docs;

      if (pros.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Nenhum profissional ativo encontrado.")),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Quem executará o serviço?"),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: pros.length,
              itemBuilder: (ctx, index) {
                final proData = pros[index].data() as Map<String, dynamic>;
                final String nome = proData['nome'] ?? 'Profissional';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _corAcai,
                    child: Text(
                      nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(nome),
                  onTap: () async {
                    Navigator.pop(ctx); // Fecha o dialog

                    // Atualiza o agendamento com o profissional selecionado
                    await doc.reference.update({
                      'profissional_id': pros[index].id,
                      'profissional_nome': nome,
                    });

                    // Navega para o checklist
                    final data = doc.data() as Map<String, dynamic>;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChecklistPetScreen(
                          agendamentoId: doc.id,
                          nomePet:
                              data['pet_nome'] ?? data['nome_pet'] ?? 'Pet',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancelar"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao buscar profissionais: $e")),
      );
    }
  }

  Future<void> _verificarEBaixarVouchers(
    DocumentSnapshot agendamentoDoc,
  ) async {
    final data = agendamentoDoc.data() as Map<String, dynamic>;
    final userId = data['userId'];

    if (userId == null) return;

    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    final userData = userDoc.data() as Map<String, dynamic>;
    final List<dynamic> listaPacotes = userData['voucher_assinatura'] ?? [];

    Map<String, int> saldosDisponiveis = {};
    for (var pacote in listaPacotes) {
      if (pacote is Map) {
        Timestamp? validade = pacote['validade_pacote'];
        if (validade != null && validade.toDate().isAfter(DateTime.now())) {
          pacote.forEach((key, value) {
            if (key != 'nome_pacote' &&
                key != 'validade_pacote' &&
                key != 'data_compra' &&
                value is int &&
                value > 0) {
              saldosDisponiveis[key] = (saldosDisponiveis[key] ?? 0) + value;
            }
          });
        }
      }
    }

    if (saldosDisponiveis.isNotEmpty) {
      // Abre o dialog personalizado que você gosta
      _abrirDialogoSelecaoVoucher(agendamentoDoc, saldosDisponiveis);
    } else {
      // Se não tem voucher, apenas muda para 'pronto' (não fecha financeiro)
      await agendamentoDoc.reference.update({'status': 'pronto'});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Serviço finalizado! Pet aguardando no balcão."),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // --- MANTIDO: O DIALOG PERSONALIZADO QUE VOCÊ GOSTOU ---
  void _abrirDialogoSelecaoVoucher(
    DocumentSnapshot doc,
    Map<String, int> saldos,
  ) {
    Map<String, bool> selecionados = {};
    final dataAgendamento = doc.data() as Map<String, dynamic>;

    String servicoNorm =
        (dataAgendamento['servicoNorm'] ?? dataAgendamento['servico'] ?? '')
            .toString()
            .toLowerCase();
    double valorOriginal = (dataAgendamento['valor'] ?? 0).toDouble();

    // Auto-seleção inteligente
    saldos.forEach((key, val) {
      if (servicoNorm.contains(key) ||
          (servicoNorm.contains('tosa') && key == 'tosa') ||
          (servicoNorm.contains('banho') && key == 'banhos')) {
        selecionados[key] = true;
      } else {
        selecionados[key] = false;
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Cálculo visual para o profissional saber se o cliente deve algo
          double desconto = 0;
          bool usouPrincipal = false;

          selecionados.forEach((k, usado) {
            if (usado) {
              if (k == 'banhos' || k == 'tosa') {
                usouPrincipal = true;
              }
            }
          });

          if (usouPrincipal) desconto = valorOriginal;
          double valorFinal = valorOriginal - desconto;
          if (valorFinal < 0) valorFinal = 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: EdgeInsets.zero,
            content: Container(
              width: 400,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Laranja (Assinante)
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _corAcai,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.crown,
                          color: Colors.amber,
                          size: 24,
                        ),
                        SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Cliente Assinante",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              "Selecione os itens usados",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Lista de Vouchers
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        ...saldos.entries.map((entry) {
                          String label =
                              entry.key[0].toUpperCase() +
                              entry.key.substring(1);
                          bool isChecked = selecionados[entry.key] ?? false;

                          return GestureDetector(
                            onTap: () => setDialogState(
                              () => selecionados[entry.key] = !isChecked,
                            ),
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              margin: EdgeInsets.only(bottom: 10),
                              padding: EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? Colors.green[50]
                                    : Colors.grey[50],
                                border: Border.all(
                                  color: isChecked
                                      ? Colors.green
                                      : Colors.grey[300]!,
                                  width: isChecked ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isChecked
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        color: isChecked
                                            ? Colors.green
                                            : Colors.grey,
                                      ),
                                      SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            label,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            "Saldo: ${entry.value}",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (isChecked &&
                                      (entry.key == 'banhos' ||
                                          entry.key == 'tosa'))
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        "COBRE SERVIÇO",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),

                        SizedBox(height: 15),
                        Divider(),
                        SizedBox(height: 10),

                        // Resumo Financeiro (Apenas informativo para o Pro)
                        _buildResumoRow(
                          "Valor Serviço",
                          "R\$ ${valorOriginal.toStringAsFixed(2)}",
                        ),
                        if (desconto > 0)
                          _buildResumoRow(
                            "Voucher",
                            "- R\$ ${desconto.toStringAsFixed(2)}",
                            color: Colors.green,
                          ),

                        SizedBox(height: 10),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: valorFinal > 0
                                ? Colors.orange[50]
                                : Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: valorFinal > 0
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                valorFinal > 0
                                    ? "ENVIAR AO CAIXA"
                                    : "TUDO PAGO",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: valorFinal > 0
                                      ? Colors.orange[800]
                                      : Colors.green[800],
                                ),
                              ),
                              Text(
                                "R\$ ${valorFinal.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: valorFinal > 0
                                      ? Colors.orange[900]
                                      : Colors.green[900],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  // Opção: Não usar voucher, apenas marcar pronto
                  Navigator.pop(ctx);
                  await doc.reference.update({'status': 'pronto'});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Marcado como Pronto (Sem voucher)."),
                    ),
                  );
                },
                child: Text(
                  "Não, Pagar na Loja",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  // Confirma uso do voucher e envia ao caixa
                  _processarBaixaVoucher(doc.id, selecionados);
                },
                child: Text(
                  "CONFIRMAR ✅",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResumoRow(
    String label,
    String value, {
    Color color = Colors.black87,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // --- ATUALIZADO: ENVIA FLAG PARA NÃO FECHAR O CAIXA ---
  Future<void> _processarBaixaVoucher(
    String agendamentoId,
    Map<String, bool> vouchersUsados,
  ) async {
    vouchersUsados.removeWhere((key, value) => value == false);

    if (vouchersUsados.isEmpty) {
      await _db.collection('agendamentos').doc(agendamentoId).update({
        'status': 'pronto',
      });
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) =>
            Center(child: CircularProgressIndicator(color: Colors.white)),
      );

      await _functions.httpsCallable('realizarCheckout').call({
        'agendamentoId': agendamentoId,
        'extrasIds': [],
        'metodoPagamento': 'voucher',
        'vouchersParaUsar': vouchersUsados,
        'responsavel': _dadosPro!['nome'],
        // CRUCIAL: Diz ao backend que é apenas o profissional reportando o uso
        // O status vai para 'pronto', mas o pagamento fica 'pendente' se houver extras/saldo
        'apenasMarcarComoPronto': true,
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Voucher baixado! Pet aguardando dono no balcão. 🚀"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao baixar voucher: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelarAgendamento(String docId) async {
    await _db.collection('agendamentos').doc(docId).update({
      'status': 'cancelado',
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Agendamento cancelado."),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildAgendamentoCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final hora = (data['data_inicio'] as Timestamp).toDate();
    final status = data['status'] ?? 'agendado';
    final bool checklistFeito = data['checklist_feito'] ?? false;

    final String servicoDisplay =
        (data['servicoNorm'] ?? data['servico'] ?? 'Serviço').toString();

    Color corStatus = Colors.grey;
    String textoStatus = "Aguardando";
    IconData iconeAcao = Icons.play_arrow;
    String textoAcao = "Iniciar";
    bool podeAvancar = true;
    Color corBotao = _corAcai; // Cor padrão do botão

    if (status == 'agendado' || status == 'aguardando_pagamento') {
      corStatus = Colors.blue;
      textoStatus = "Na Fila";

      // Lógica Visual do Botão: Checklist ou Banho
      if (!checklistFeito) {
        iconeAcao = Icons.playlist_add_check;
        textoAcao = "Checklist";
        corBotao = Colors.orange; // Laranja para chamar atenção
      } else {
        iconeAcao = FontAwesomeIcons.shower;
        textoAcao = "Iniciar Banho";
        corBotao = Colors.blue;
      }
    } else if (status == 'banhando') {
      corStatus = Colors.cyan;
      textoStatus = "No Banho 🛁";
      bool temTosa = servicoDisplay.toLowerCase().contains('tosa');
      iconeAcao = temTosa ? FontAwesomeIcons.scissors : Icons.check;
      textoAcao = temTosa ? "Ir p/ Tosa" : "Finalizar";
      corBotao = _corAcai;
    } else if (status == 'tosando') {
      corStatus = Colors.orange;
      textoStatus = "Na Tosa ✂️";
      iconeAcao = Icons.check_circle;
      textoAcao = "Pronto";
      corBotao = Colors.green;
    } else if (status == 'pronto') {
      corStatus = Colors.purple;
      textoStatus = "Aguardando Dono";
      podeAvancar = false;
    } else if (status == 'concluido') {
      corStatus = Colors.green;
      textoStatus = "Finalizado ✅";
      podeAvancar = false;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border(left: BorderSide(color: corStatus, width: 5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Text(
                      DateFormat('HH:mm').format(hora),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      "Hora",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            servicoDisplay,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (status != 'concluido' && status != 'pronto')
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'cancelar')
                                  _cancelarAgendamento(doc.id);
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'cancelar',
                                  child: Text(
                                    "Cancelar",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                              child: Icon(
                                Icons.more_vert,
                                size: 20,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 5),
                      if (data['checklist_feito'] == true)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize
                                .min, // Para não ocupar a largura toda
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 12,
                                color: Colors.green[800],
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Checklist OK",
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "Aguardando Inspeção",
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 10,
                              fontWeight: FontWeight
                                  .bold, // Deixei negrito para destacar
                            ),
                          ),
                        ),
                      SizedBox(height: 10),

                      // Info do Pet e Profissional
                      if (data['userId'] != null && data['pet_id'] != null)
                        FutureBuilder<List<DocumentSnapshot>>(
                          // Busca Tutor e Pet simultaneamente
                          future: Future.wait([
                            _db.collection('users').doc(data['userId']).get(),
                            _db
                                .collection('users')
                                .doc(data['userId'])
                                .collection('pets')
                                .doc(data['pet_id'])
                                .get(),
                          ]),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return Text("Carregando...");

                            final userDoc = snapshot.data![0]; // Doc do Tutor
                            final petDoc = snapshot.data![1]; // Doc do Pet

                            // Pega nome do Tutor
                            String nomeTutor = "Cliente";
                            if (userDoc.exists) {
                              final u = userDoc.data() as Map<String, dynamic>?;
                              if (u != null && u['nome'] != null) {
                                // Pega só o primeiro nome
                                nomeTutor = u['nome'].toString().split('  ')[0];
                              }
                            }

                            if (petDoc.exists) {
                              final p = petDoc.data() as Map<String, dynamic>?;
                              final nomePet = p?['nome'] ?? 'Pet';
                              final racaPet = p?['raca'] ?? 'SRD';

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // --- LINHA DO TUTOR ---
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person,
                                        size: 12,
                                        color: _corAcai,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        nomeTutor,
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2),

                                  // ----------------------
                                  Text(
                                    "$nomePet ($racaPet)",
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (data['profissional_nome'] != null)
                                    Text(
                                      "Resp: ${data['profissional_nome']}",
                                      style: TextStyle(
                                        color: _corAcai,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              );
                            }
                            return Text(
                              "Pet removido",
                              style: TextStyle(color: Colors.red, fontSize: 11),
                            );
                          },
                        )
                      else
                        Text(
                          "Dados incompletos",
                          style: TextStyle(color: Colors.red, fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: corStatus.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    textoStatus,
                    style: TextStyle(
                      color: corStatus,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (podeAvancar)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          corBotao, // Usa a cor dinâmica definida acima
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => _avancarStatus(doc),
                    icon: Icon(iconeAcao, size: 16),
                    label: Text(textoAcao),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dadosPro == null)
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: _corAcai)),
      );

    final inicioDia = DateTime(
      _dataFiltro.year,
      _dataFiltro.month,
      _dataFiltro.day,
    );
    final fimDia = DateTime(
      _dataFiltro.year,
      _dataFiltro.month,
      _dataFiltro.day,
      23,
      59,
      59,
    );

    return Scaffold(
      backgroundColor: _corFundo,
      body: Column(
        children: [
          _buildHeader(),
          Container(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            color: Colors.white,
            child: Column(
              children: [
                _buildDateSelector(),
                SizedBox(height: 15),
                _buildFilterButtons(),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('agendamentos')
                  .where(
                    'data_inicio',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia),
                  )
                  .where(
                    'data_inicio',
                    isLessThanOrEqualTo: Timestamp.fromDate(fimDia),
                  )
                  .where('status', isNotEqualTo: 'cancelado')
                  .orderBy('data_inicio')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return Center(
                    child: CircularProgressIndicator(color: _corAcai),
                  );
                var docs = snapshot.data?.docs ?? [];

                // Filtro Local
                if (_filtroServico != 'Todos') {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    String servico = (data['servicoNorm'] ?? '')
                        .toString()
                        .toLowerCase();
                    if (_filtroServico == 'Tosa')
                      return servico.contains('tosa');
                    else if (_filtroServico == 'Banho')
                      return servico.contains('banho') &&
                          !servico.contains('tosa');
                    return true;
                  }).toList();
                }

                if (docs.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 80),
                  itemCount: docs.length,
                  itemBuilder: (ctx, index) =>
                      _buildAgendamentoCard(docs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(top: 50, left: 25, right: 25, bottom: 20),
      decoration: BoxDecoration(color: Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _corAcai, width: 2),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: _corLilas,
                  child: Text(
                    _dadosPro!['nome'][0],
                    style: TextStyle(
                      color: _corAcai,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Olá, ${_dadosPro!['nome'].toString().split(' ')[0]}",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Vamos trabalhar?",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            icon: Icon(Icons.logout, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          DateFormat("dd 'de' MMMM", 'pt_BR').format(_dataFiltro).toUpperCase(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _dataFiltro,
              firstDate: DateTime.now().subtract(Duration(days: 30)),
              lastDate: DateTime.now().add(Duration(days: 30)),
              builder: (context, child) => Theme(
                data: ThemeData.light().copyWith(
                  primaryColor: _corAcai,
                  colorScheme: ColorScheme.light(primary: _corAcai),
                ),
                child: child!,
              ),
            );
            if (d != null) setState(() => _dataFiltro = d);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _corFundo,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: _corAcai),
                SizedBox(width: 5),
                Text(
                  "Mudar",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _corAcai,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButtons() {
    return Container(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip("Todos", Icons.list),
          SizedBox(width: 10),
          _buildFilterChip("Banho", FontAwesomeIcons.shower),
          SizedBox(width: 10),
          _buildFilterChip("Tosa", FontAwesomeIcons.scissors),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    bool isSelected = _filtroServico == label;
    return GestureDetector(
      onTap: () => setState(() => _filtroServico = label),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _corAcai : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _corAcai : Colors.grey[300]!),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _corAcai.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.listUl, size: 50, color: Colors.grey[300]),
          SizedBox(height: 10),
          Text(
            "Nenhum atendimento nesta categoria.",
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
