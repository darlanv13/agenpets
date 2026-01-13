import 'package:agenpet/admin_web/views/components/cadastro_rapido_dialog.dart';
import 'package:agenpet/utils/formatters.dart';
import 'package:agenpet/utils/validators.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class VendaAssinaturaView extends StatefulWidget {
  @override
  _VendaAssinaturaViewState createState() => _VendaAssinaturaViewState();
}

class _VendaAssinaturaViewState extends State<VendaAssinaturaView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // --- CONTROLE DE ESTADO ---
  int _stepAtual = 1; // 1: Buscar Cliente, 2: Escolher Pacote, 3: Pagamento

  // Dados do Fluxo
  Map<String, dynamic>? _clienteSelecionado;
  String? _clienteId;
  Map<String, dynamic>? _pacoteSelecionado;
  String? _pacoteId;
  String _metodoPagamento = 'pix'; // Valor padrão

  // Controladores
  final _cpfBuscaCtrl = TextEditingController();

  // --- PALETA DE CORES ---
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corLavanda = Color(0xFFAB47BC);
  final Color _corLilas = Color(0xFFF3E5F5);
  final Color _corFundo = Color(0xFFF5F7FA); // Fundo levemente cinza azulado

  // --- AÇÕES (Lógica mantida intacta) ---
  void _buscarCliente() async {
    String cpfLimpo = _cpfBuscaCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cpfLimpo.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Digite um CPF válido.")));
      return;
    }

    // --- Validar CPF---
    // --- VALIDAÇÃO DE CPF (COM DIALOG BONITO) ---
    if (!Validators.isCpfValido(cpfLimpo)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text(
                "Atenção",
                style: TextStyle(
                  color: Colors.red[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            "O CPF informado parece estar incorreto.\nPor favor, verifique os números e tente novamente.",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[800],
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text("OK, VOU CORRIGIR"),
            ),
          ],
        ),
      );
      return;
    }

    // Tenta buscar no banco
    final query = await _db
        .collection('users')
        .where('cpf', isEqualTo: cpfLimpo)
        .get();

    if (query.docs.isNotEmpty) {
      // Cliente encontrado!
      setState(() {
        _clienteSelecionado = query.docs.first.data();
        _clienteId = query.docs.first.id;
        _stepAtual = 2; // Avança para escolha de pacote
      });
    } else {
      // Cliente NÃO encontrado -> Abre Cadastro Rápido
      _abrirCadastroRapido(cpfLimpo);
    }
  }

  // Nova função auxiliar para chamar o Dialog
  void _abrirCadastroRapido(String cpf) async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CadastroRapidoDialog(cpfInicial: cpf),
    );

    if (result != null && result['sucesso'] == true) {
      final novoUserDoc = await _db
          .collection('users')
          .doc(result['cpf'])
          .get();

      if (novoUserDoc.exists) {
        setState(() {
          _clienteSelecionado = novoUserDoc.data();
          _clienteId = novoUserDoc.id;
          _stepAtual = 2; // Avança automaticamente
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Cliente cadastrado e selecionado! ✅"),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _finalizarCompra() async {
    if (_clienteId == null || _pacoteSelecionado == null) return;

    // Feedback de carregamento
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Center(child: CircularProgressIndicator(color: _corAcai)),
    );

    try {
      // CHAMA A CLOUD FUNCTION
      final functions = FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      );

      await functions.httpsCallable('realizarVendaAssinatura').call({
        'userId': _clienteId,
        'pacoteId':
            _pacoteId, // Agora passamos o ID para o servidor buscar os dados seguros
        'metodoPagamento': _metodoPagamento,
      });

      Navigator.pop(context); // Fecha loading

      // Data de validade calculada (apenas visual, pois o servidor já gravou)
      final dataValidade = DateTime.now().add(Duration(days: 45));

      // Feedback de Sucesso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Container(
            padding: EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green[50],
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 60,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "Venda Confirmada!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Vouchers creditados e válidos até ${DateFormat('dd/MM/yyyy').format(dataValidade)}.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _corAcai,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      // Reseta a tela para nova venda
                      setState(() {
                        _stepAtual = 1;
                        _clienteSelecionado = null;
                        _clienteId = null;
                        _pacoteSelecionado = null;
                        _cpfBuscaCtrl.clear();
                      });
                    },
                    child: Text(
                      "INICIAR NOVA VENDA",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Fecha loading
      String erro = "Erro desconhecido";
      if (e is FirebaseFunctionsException) {
        erro = e.message ?? e.code;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Falha na venda: $erro"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Column(
        children: [
          // HEADER MODERNO
          Container(
            padding: EdgeInsets.symmetric(vertical: 25, horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
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
                    color: _corLilas,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(FontAwesomeIcons.shop, color: _corAcai, size: 24),
                ),
                SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Venda de Planos",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _corAcai,
                      ),
                    ),
                    Text(
                      "Nova assinatura para cliente",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                Spacer(),
                // Se já selecionou cliente, mostra mini-badge
                if (_clienteSelecionado != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: _corFundo,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 16, color: _corAcai),
                        SizedBox(width: 8),
                        Text(
                          _clienteSelecionado!['nome'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(() {
                            _stepAtual = 1;
                            _clienteSelecionado = null;
                            _pacoteSelecionado = null;
                          }),
                          child: Icon(Icons.close, size: 16, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // STEPPER
          _buildStepper(),

          // CONTEÚDO
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.all(30),
                child: _buildConteudoPasso(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepIndicator(1, "Identificar", Icons.person_search),
          _stepLine(1),
          _stepIndicator(2, "Pacote", FontAwesomeIcons.boxOpen),
          _stepLine(2),
          _stepIndicator(3, "Pagamento", FontAwesomeIcons.creditCard),
        ],
      ),
    );
  }

  Widget _stepIndicator(int step, String label, IconData icon) {
    bool isActive = _stepAtual >= step;
    bool isCurrent = _stepAtual == step;
    return Column(
      children: [
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isActive ? _corAcai : Colors.grey[100],
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _corAcai.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : Colors.grey[400],
            size: 20,
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isActive ? _corAcai : Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(int stepAfter) {
    bool isActive = _stepAtual > stepAfter;
    return Container(
      width: 60,
      height: 2,
      color: isActive ? _corAcai : Colors.grey[200],
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 25),
    );
  }

  // --- CONTEÚDO DAS TELAS ---

  Widget _buildConteudoPasso() {
    switch (_stepAtual) {
      case 1:
        return _buildPasso1Busca();
      case 2:
        return _buildPasso2Pacotes();
      case 3:
        return _buildPasso3Checkout();
      default:
        return Container();
    }
  }

  // PASSO 1: BUSCA DE CLIENTE
  Widget _buildPasso1Busca() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 500),
        padding: EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _corLilas,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_search_rounded,
                size: 50,
                color: _corAcai,
              ),
            ),
            SizedBox(height: 20),
            Text(
              "Quem é o cliente?",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              "Busque pelo CPF para iniciar a venda",
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 30),
            TextField(
              controller: _cpfBuscaCtrl,
              style: TextStyle(fontSize: 18, letterSpacing: 1.5),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CpfInputFormatter(),
              ],
              decoration: InputDecoration(
                hintText: "000.000.000-00",
                filled: true,
                fillColor: _corFundo,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 20),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _buscarCliente(),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: _buscarCliente,
                child: Text(
                  "BUSCAR CLIENTE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PASSO 2: ESCOLHA DE PACOTE
  Widget _buildPasso2Pacotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Escolha o Plano Ideal",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          "Selecione uma das opções abaixo para ${_clienteSelecionado!['nome']}",
          style: TextStyle(color: Colors.grey[600]),
        ),
        SizedBox(height: 30),

        // Grid de Pacotes
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('pacotes_assinatura')
              .where('ativo', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;

            return GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 350,
                childAspectRatio: 0.85,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final isSelected = _pacoteId == doc.id;

                int banhos = data['vouchers_banho'] ?? 0;
                int tosas = data['vouchers_tosa'] ?? 0;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _pacoteSelecionado = data;
                      _pacoteId = doc.id;
                    });
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? _corAcai : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                        if (isSelected)
                          BoxShadow(
                            color: _corAcai.withOpacity(0.2),
                            blurRadius: 20,
                          ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Ícone do Pacote
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _corLilas,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  FontAwesomeIcons.boxOpen,
                                  size: 24,
                                  color: _corAcai,
                                ),
                              ),
                              SizedBox(height: 20),
                              Text(
                                data['nome'],
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),

                              // --- NOVO: Exibição do Porte no Card ---
                              if (data['porte'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Row(
                                    children: [
                                      Icon(
                                        FontAwesomeIcons.dog,
                                        size: 12,
                                        color: Colors.grey[600],
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        data['porte'],
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // ---------------------------------------
                              SizedBox(height: 8),
                              Text(
                                data['descricao'] ?? 'Pacote de serviços',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              Spacer(),

                              // Badges de Serviços
                              if (banhos > 0)
                                _buildServiceBadge(
                                  banhos,
                                  "Banhos",
                                  FontAwesomeIcons.shower,
                                ),
                              if (tosas > 0) SizedBox(height: 8),
                              if (tosas > 0)
                                _buildServiceBadge(
                                  tosas,
                                  "Tosas",
                                  FontAwesomeIcons.scissors,
                                ),

                              Spacer(),
                              Divider(),

                              // Preço
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Total",
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                  Text(
                                    "R\$ ${data['preco']}",
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: _corAcai,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Check Icon quando selecionado
                        if (isSelected)
                          Positioned(
                            top: 15,
                            right: 15,
                            child: CircleAvatar(
                              backgroundColor: _corAcai,
                              radius: 12,
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),

        SizedBox(height: 30),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _corAcai,
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 5,
            ),
            icon: Icon(Icons.arrow_forward, color: Colors.white),
            label: Text(
              "IR PARA PAGAMENTO",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            onPressed: _pacoteSelecionado != null
                ? () => setState(() => _stepAtual = 3)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceBadge(int qtd, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _corAcai),
        SizedBox(width: 8),
        Text(
          "$qtd $label",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  // PASSO 3: CHECKOUT / PAGAMENTO
  Widget _buildPasso3Checkout() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CARD DE RESUMO (Estilo Recibo)
            Container(
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
              ),
              child: Column(
                children: [
                  Text(
                    "RESUMO DO PEDIDO",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.grey[400],
                    ),
                  ),
                  SizedBox(height: 20),

                  _buildReciboRow(
                    "Cliente",
                    _clienteSelecionado!['nome'] ?? '---',
                  ),
                  _buildReciboRow(
                    "Pacote",
                    _pacoteSelecionado!['nome'] ?? '---',
                  ),
                  if (_pacoteSelecionado!['porte'] != null)
                    _buildReciboRow("Porte", _pacoteSelecionado!['porte']),

                  Divider(height: 30),
                  _buildReciboRow(
                    "Total a Pagar",
                    "R\$ ${_pacoteSelecionado!['preco']}",
                    isTotal: true,
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),
            Text(
              "Forma de Pagamento",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 15),

            // SELETORES DE PAGAMENTO (Botões Grandes)
            Row(
              children: [
                _buildPaymentOption('pix', "Pix", Icons.pix),
                SizedBox(width: 15),
                _buildPaymentOption(
                  'dinheiro',
                  "Dinheiro",
                  FontAwesomeIcons.moneyBill,
                ),
                SizedBox(width: 15),
                _buildPaymentOption(
                  'credito',
                  "Cartão",
                  FontAwesomeIcons.creditCard,
                ),
              ],
            ),

            SizedBox(height: 40),

            // Botão Confirmar
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                ),
                onPressed: _finalizarCompra,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      "CONFIRMAR VENDA",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),
            Center(
              child: TextButton.icon(
                icon: Icon(Icons.arrow_back, size: 16),
                onPressed: () => setState(() => _stepAtual = 2),
                label: Text(
                  "Voltar para pacotes",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReciboRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isTotal ? 24 : 16,
              color: isTotal ? _corAcai : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, String label, IconData icon) {
    bool isSelected = _metodoPagamento == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _metodoPagamento = value),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? _corAcai : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected ? _corAcai : Colors.grey[200]!,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: _corAcai.withOpacity(0.3), blurRadius: 10)]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 24,
              ),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _corAcai),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}
