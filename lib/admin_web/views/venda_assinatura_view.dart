import 'package:agenpet/admin_web/views/components/cadastro_rapido_dialog.dart';
import 'package:agenpet/utils/formatters.dart';
import 'package:agenpet/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class VendaAssinaturaView extends StatefulWidget {
  const VendaAssinaturaView({super.key});

  @override
  _VendaAssinaturaViewState createState() => _VendaAssinaturaViewState();
}

class _VendaAssinaturaViewState extends State<VendaAssinaturaView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // --- CONTROLE DE ESTADO ---
  int _stepAtual = 1;

  // Dados do Fluxo
  Map<String, dynamic>? _clienteSelecionado;
  String? _clienteId;
  Map<String, dynamic>? _pacoteSelecionado;
  String? _pacoteId;
  String _metodoPagamento = 'pix';

  // Controladores
  final _cpfBuscaCtrl = TextEditingController();

  // --- PALETA DE CORES (Ajustada para Contraste) ---
  final Color _corAcai = Color(0xFF4A148C);
  // Um fundo um pouco mais escuro/azulado para destacar o branco
  final Color _corFundo = Color(0xFFE8ECF2);
  final Color _corBorda = Color(0xFFD1D9E6); // Cinza médio para bordas

  // --- LÓGICA (Mantida) ---
  void _buscarCliente() async {
    String cpfLimpo = _cpfBuscaCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cpfLimpo.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Digite um CPF válido.")));
      return;
    }

    if (!Validators.isCpfValido(cpfLimpo)) {
      _mostrarAlertaErro("CPF Inválido", "Verifique os números digitados.");
      return;
    }

    final query = await _db
        .collection('users')
        .where('cpf', isEqualTo: cpfLimpo)
        .get();

    if (query.docs.isNotEmpty) {
      setState(() {
        _clienteSelecionado = query.docs.first.data();
        _clienteId = query.docs.first.id;
        _stepAtual = 2;
      });
    } else {
      _abrirCadastroRapido(cpfLimpo);
    }
  }

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
          _stepAtual = 2;
        });
      }
    }
  }

  void _mostrarAlertaErro(String titulo, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(titulo, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("OK", style: TextStyle(color: _corAcai)),
          ),
        ],
      ),
    );
  }

  void _finalizarCompra() async {
    if (_clienteId == null || _pacoteSelecionado == null) return;

    try {
      // 1. Histórico
      await _db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('vendas_assinaturas')
          .add({
            'userId': _clienteId,
            'tenantId': AppConfig.tenantId,
            'user_nome': _clienteSelecionado!['nome'],
            'pacote_nome': _pacoteSelecionado!['nome'],
            'pacote_id': _pacoteId,
            'valor': _pacoteSelecionado!['preco'],
            'metodo_pagamento': _metodoPagamento,
            'data_venda': FieldValue.serverTimestamp(),
            'atendente': 'Admin/Balcão',
          });

      // 2. Validade e Objeto
      final dataValidade = DateTime.now().add(Duration(days: 30));
      Map<String, dynamic> novoItemVoucher = {
        'nome_pacote': _pacoteSelecionado!['nome'],
        'validade_pacote': Timestamp.fromDate(dataValidade),
        'data_compra': Timestamp.now(),
      };

      // 3. Mapeamento
      _pacoteSelecionado!.forEach((key, value) {
        if (key.startsWith('vouchers_') && (value is int || value is double)) {
          String nomeServico = key.replaceFirst('vouchers_', '');
          novoItemVoucher[nomeServico] = value;
        }
      });

      // 4. Update User
      await _db.collection('users').doc(_clienteId).update({
        'ultima_compra': FieldValue.serverTimestamp(),
        'voucher_assinatura': FieldValue.arrayUnion([novoItemVoucher]),
      });

      if (mounted) {
        _mostrarDialogoSucesso(dataValidade);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  void _mostrarDialogoSucesso(DateTime validade) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, color: Colors.green, size: 40),
            ),
            SizedBox(height: 20),
            Text(
              "Venda Confirmada!",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            SizedBox(height: 10),
            Text(
              "Válido até ${DateFormat('dd/MM').format(validade)}",
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _stepAtual = 1;
                    _clienteSelecionado = null;
                    _clienteId = null;
                    _pacoteSelecionado = null;
                    _cpfBuscaCtrl.clear();
                  });
                },
                child: Text(
                  "NOVA VENDA",
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
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Barra de Progresso (Alto Contraste)
            _buildMinimalStepper(),

            // 2. Conteúdo Principal
            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                child: SingleChildScrollView(
                  key: ValueKey(_stepAtual),
                  padding: EdgeInsets.all(30),
                  child: _buildConteudoPasso(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalStepper() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: _corBorda),
        ), // Linha divisória clara
      ),
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      child: Row(
        children: [
          if (_stepAtual > 1)
            IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: Colors.grey[800],
              ), // Ícone mais escuro
              onPressed: () => setState(() => _stepAtual--),
            )
          else
            SizedBox(width: 40),

          Expanded(
            child: Column(
              children: [
                Text(
                  _stepAtual == 1
                      ? "1. IDENTIFICAÇÃO"
                      : _stepAtual == 2
                      ? "2. SELEÇÃO DO PACOTE"
                      : "3. PAGAMENTO",
                  style: TextStyle(
                    color: _corAcai,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 10),
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      height: 6,
                      width: _stepAtual == 1
                          ? 100
                          : _stepAtual == 2
                          ? 200
                          : 300, // Ajuste visual aproximado
                      decoration: BoxDecoration(
                        color: _corAcai,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_clienteSelecionado != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _corAcai), // Borda visível
              ),
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: _corAcai),
                  SizedBox(width: 8),
                  Text(
                    _clienteSelecionado!['nome'].toString().split(' ')[0],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _corAcai,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(width: 40),
        ],
      ),
    );
  }

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

  // --- PASSO 1: BUSCA COM CONTRASTE ---
  Widget _buildPasso1Busca() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 500),
        padding: EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _corBorda), // Borda externa
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Venda de Assinatura",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Digite o CPF do cliente para começar",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            SizedBox(height: 40),

            // Campo de Texto com Borda Definida
            TextField(
              controller: _cpfBuscaCtrl,
              style: TextStyle(
                fontSize: 22,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CpfInputFormatter(),
              ],
              decoration: InputDecoration(
                hintText: "000.000.000-00",
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 25),
                // Bordas visíveis
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[400]!, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _corAcai, width: 2),
                ),
                prefixIcon: Icon(Icons.search, color: Colors.transparent),
                suffixIcon: Icon(Icons.search, color: Colors.transparent),
              ),
              onSubmitted: (_) => _buscarCliente(),
            ),

            SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _buscarCliente,
                child: Text(
                  "CONTINUAR",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
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

  // --- PASSO 2: PACOTES (MOSTRANDO TUDO) ---
  Widget _buildPasso2Pacotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Selecione o Plano",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        SizedBox(height: 30),

        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('tenants')
              .doc(AppConfig.tenantId)
              .collection('pacotes')
              .where('ativo', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator(color: _corAcai));
            }
            final docs = snapshot.data!.docs;

            return GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 350,
                childAspectRatio: 0.85, // Card mais alto para caber todos itens
                crossAxisSpacing: 22,
                mainAxisSpacing: 22,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final isSelected = _pacoteId == doc.id;

                // Extração Completa dos Itens
                int banhos = data['vouchers_banho'] ?? 0;
                int tosas = data['vouchers_tosa'] ?? 0;
                List<dynamic> extras = data['itens_extra'] ?? [];

                return GestureDetector(
                  onTap: () => setState(() {
                    _pacoteSelecionado = data;
                    _pacoteId = doc.id;
                  }),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isSelected
                            ? _corAcai
                            : _corBorda, // Borda cinza se não selecionado
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabeçalho Card
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(
                              FontAwesomeIcons.boxOpen,
                              color: isSelected ? _corAcai : Colors.grey[600],
                              size: 28,
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: _corAcai,
                                size: 24,
                              ),
                          ],
                        ),
                        SizedBox(height: 20),

                        Text(
                          data['nome'],
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                            color: Colors.grey[900],
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          data['porte'] ?? 'Todos os Portes',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),

                        Divider(height: 25, color: Colors.grey[300]),

                        // --- LISTA COMPLETA DE ITENS ---
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (banhos > 0)
                                  _itemListaClean("$banhos x Banho", true),
                                if (tosas > 0)
                                  _itemListaClean("$tosas x Tosa", true),
                                // Loop nos Extras
                                ...extras
                                    .map(
                                      (e) => _itemListaClean(
                                        "${e['qtd']}x ${e['servico']}",
                                        false,
                                      ),
                                    )
                                    ,
                              ],
                            ),
                          ),
                        ),

                        Divider(height: 25, color: Colors.grey[300]),

                        Text(
                          "R\$ ${data['preco']}",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _corAcai,
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

        SizedBox(height: 40),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _corAcai,
              padding: EdgeInsets.symmetric(
                horizontal: 50,
                vertical: 25,
              ), // Botão maior
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            onPressed: _pacoteSelecionado != null
                ? () => setState(() => _stepAtual = 3)
                : null,
            child: Text(
              "IR PARA PAGAMENTO",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _itemListaClean(String texto, bool destaque) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check,
            size: 16,
            color: destaque ? Colors.green[700] : Colors.grey[500],
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: destaque ? Colors.black87 : Colors.grey[700],
                fontSize: 14,
                fontWeight: destaque ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- PASSO 3: CHECKOUT (RECIBO) ---
  Widget _buildPasso3Checkout() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 550),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Resumo do Pedido",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            SizedBox(height: 25),

            // Recibo visual
            Container(
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _corBorda),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _rowRecibo("Cliente", _clienteSelecionado!['nome']),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: Colors.grey[200]),
                  ),
                  _rowRecibo("Plano", _pacoteSelecionado!['nome']),
                  // Detalhamento Rápido
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        "Inclui: ${_pacoteSelecionado!['vouchers_banho'] ?? 0} Banhos, ${_pacoteSelecionado!['vouchers_tosa'] ?? 0} Tosas...",
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(color: Colors.black, thickness: 1),
                  ),
                  _rowRecibo(
                    "Total a Pagar",
                    "R\$ ${_pacoteSelecionado!['preco']}",
                    isTotal: true,
                  ),
                ],
              ),
            ),

            SizedBox(height: 40),
            Text(
              "Forma de Pagamento",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 15),

            Row(
              children: [
                _opcaoPagamento('pix', "Pix", Icons.pix),
                SizedBox(width: 15),
                _opcaoPagamento(
                  'dinheiro',
                  "Dinheiro",
                  FontAwesomeIcons.moneyBill,
                ),
                SizedBox(width: 15),
                _opcaoPagamento(
                  'credito',
                  "Cartão",
                  FontAwesomeIcons.creditCard,
                ),
              ],
            ),

            SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600], // Verde mais forte
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                onPressed: _finalizarCompra,
                child: Text(
                  "CONFIRMAR VENDA",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowRecibo(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? _corAcai : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: isTotal ? 26 : 18,
          ),
        ),
      ],
    );
  }

  Widget _opcaoPagamento(String value, String label, IconData icon) {
    bool isSelected = _metodoPagamento == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _metodoPagamento = value),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          height: 100,
          decoration: BoxDecoration(
            color: isSelected ? _corAcai : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected ? _corAcai : Colors.grey[300]!,
              width: isSelected ? 0 : 1,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: _corAcai.withOpacity(0.3), blurRadius: 10)]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 28,
              ),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
