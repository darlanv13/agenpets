import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CheckoutDialogPremium extends StatefulWidget {
  final String agendamentoId;
  final Map<String, dynamic> dadosAgendamento;
  final String servicoNome;
  final double valorBase; // Valor original do serviço
  final Map userData;
  final List<Map<String, dynamic>> listaExtras;
  final Color corAcai;
  final VoidCallback onSuccess;

  const CheckoutDialogPremium({
    Key? key,
    required this.agendamentoId,
    required this.dadosAgendamento,
    required this.servicoNome,
    required this.valorBase,
    required this.userData,
    required this.listaExtras,
    required this.corAcai,
    required this.onSuccess,
  }) : super(key: key);

  @override
  _CheckoutDialogPremiumState createState() => _CheckoutDialogPremiumState();
}

class _CheckoutDialogPremiumState extends State<CheckoutDialogPremium> {
  final _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  Map<String, bool> _vouchersParaUsar = {};
  Map<String, int> _saldosDisponiveis = {};

  // Controle dos Extras
  List<Map<String, dynamic>> _extrasSelecionados = [];
  List<Map<String, dynamic>> _extrasFiltrados = [];
  TextEditingController _searchController = TextEditingController();

  // PAGAMENTO AGORA É NULO NO INÍCIO (OBRIGATÓRIO SELECIONAR)
  String? _metodoPagamento;

  bool _isLoading = false;
  bool _jaConsumiuVoucher = false;
  Map _detalhesConsumo = {};

  @override
  void initState() {
    super.initState();
    _verificarConsumoAnterior();
    if (!_jaConsumiuVoucher) {
      _calcularSaldosVouchers();
    }
    _extrasFiltrados = widget.listaExtras;
  }

  void _filtrarExtras(String query) {
    if (query.isEmpty) {
      setState(() => _extrasFiltrados = widget.listaExtras);
    } else {
      setState(() {
        _extrasFiltrados = widget.listaExtras.where((item) {
          final nome = item['nome'].toString().toLowerCase();
          return nome.contains(query.toLowerCase());
        }).toList();
      });
    }
  }

  void _verificarConsumoAnterior() {
    if (widget.dadosAgendamento['vouchers_consumidos'] != null &&
        (widget.dadosAgendamento['vouchers_consumidos'] as Map).isNotEmpty) {
      _jaConsumiuVoucher = true;
      _detalhesConsumo = widget.dadosAgendamento['vouchers_consumidos'];
    }
  }

  void _calcularSaldosVouchers() {
    _saldosDisponiveis = {};
    List<dynamic> listaPacotes = widget.userData['voucher_assinatura'] ?? [];

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
              _saldosDisponiveis[key] = (_saldosDisponiveis[key] ?? 0) + value;
            }
          });
        }
      }
    }

    _saldosDisponiveis.forEach((key, value) {
      bool autoSelect = widget.servicoNome.toLowerCase().contains(
        key.toLowerCase(),
      );
      _vouchersParaUsar[key] = autoSelect;
    });
  }

  void _confirmarCheckout() async {
    setState(() => _isLoading = true);
    try {
      List<String> extrasIds = _extrasSelecionados
          .map((e) => e['id'] as String)
          .toList();

      await _functions.httpsCallable('realizarCheckout').call({
        'agendamentoId': widget.agendamentoId,
        'extrasIds': extrasIds,
        'metodoPagamento': _metodoPagamento, // Envia o selecionado nos botões
        'vouchersParaUsar': _jaConsumiuVoucher ? {} : _vouchersParaUsar,
        'responsavel': 'Admin/Balcão',
      });

      Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro no checkout: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lógica Financeira
    double valorFinalServico = widget.valorBase;
    bool descontoAplicado = false;

    if (_jaConsumiuVoucher) {
      if (widget.dadosAgendamento['usou_voucher'] == true) {
        valorFinalServico = 0;
        descontoAplicado = true;
      }
    } else {
      _vouchersParaUsar.forEach((key, usar) {
        if (usar && (key == 'banhos' || key == 'tosa')) {
          valorFinalServico = 0;
          descontoAplicado = true;
        }
      });
    }

    double valorExtrasNovos = _extrasSelecionados.fold(
      0,
      (sum, item) => sum + item['preco'],
    );
    double totalPagar = valorFinalServico + valorExtrasNovos;

    // Se o total for zero (tudo pago por voucher), o pagamento não é necessário
    bool precisaPagar = totalPagar > 0;

    // Se não precisa pagar, definimos automaticamente como 'isento' ou mantemos null para logica interna
    // Mas visualmente o usuario deve ver que está "Pago".

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // --- HEADER COM BOTÕES DE PAGAMENTO ---
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Título Esquerda
          Row(
            children: [
              Icon(Icons.point_of_sale, color: widget.corAcai, size: 28),
              SizedBox(width: 10),
              Text(
                "Checkout",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 20,
                ),
              ),
            ],
          ),

          // Botões Direita (Aparecem só se houver valor a pagar)
          if (precisaPagar)
            Row(
              children: [
                _buildPaymentOption("Pix", FontAwesomeIcons.pix, "pix_balcao"),
                SizedBox(width: 8),
                _buildPaymentOption(
                  "Dinheiro",
                  FontAwesomeIcons.moneyBillWave,
                  "dinheiro",
                ),
                SizedBox(width: 8),
                _buildPaymentOption(
                  "Cartão",
                  FontAwesomeIcons.creditCard,
                  "cartao",
                ),
              ],
            ),
        ],
      ),
      content: Container(
        width: 500,
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. VOUCHERS
                    Text(
                      "Vouchers & Assinatura",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 10),
                    if (_jaConsumiuVoucher)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green,
                            ),
                            SizedBox(width: 5),
                            Text(
                              "Voucher aplicado",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_saldosDisponiveis.isNotEmpty)
                      Column(
                        children: _saldosDisponiveis.keys
                            .map(
                              (key) => CheckboxListTile(
                                title: Text(
                                  key.toUpperCase(),
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  "Disponível: ${_saldosDisponiveis[key]}",
                                ),
                                value: _vouchersParaUsar[key] ?? false,
                                activeColor: widget.corAcai,
                                onChanged: (v) =>
                                    setState(() => _vouchersParaUsar[key] = v!),
                                secondary: Icon(
                                  FontAwesomeIcons.ticket,
                                  color: Colors.orange,
                                ),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            )
                            .toList(),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Sem vouchers disponíveis.",
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ),

                    Divider(height: 30),

                    // 2. EXTRAS
                    Text(
                      "Adicionar Extras",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      onChanged: _filtrarExtras,
                      decoration: InputDecoration(
                        hintText: "Buscar item...",
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _filtrarExtras('');
                                },
                              )
                            : null,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    SizedBox(height: 5),
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _extrasFiltrados.isEmpty
                          ? Center(
                              child: Text(
                                "Nenhum item encontrado",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _extrasFiltrados.length,
                              separatorBuilder: (_, __) => Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _extrasFiltrados[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    item['nome'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: Text(
                                    "+ R\$ ${item['preco']}",
                                    style: TextStyle(
                                      color: widget.corAcai,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _extrasSelecionados.add(item);
                                      _searchController.clear();
                                      _filtrarExtras('');
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    SizedBox(height: 10),
                    if (_extrasSelecionados.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _extrasSelecionados
                            .asMap()
                            .entries
                            .map(
                              (entry) => Chip(
                                label: Text(
                                  "${entry.value['nome']} (R\$ ${entry.value['preco']})",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: widget.corAcai,
                                deleteIcon: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                onDeleted: () => setState(
                                  () => _extrasSelecionados.removeAt(entry.key),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: EdgeInsets.all(4),
                              ),
                            )
                            .toList(),
                      ),

                    Divider(height: 30, thickness: 2),

                    // 3. RESUMO
                    _buildResumoRow(
                      "Valor Serviço",
                      "R\$ ${widget.valorBase.toStringAsFixed(2)}",
                    ),
                    if (descontoAplicado)
                      _buildResumoRow(
                        "Desconto Voucher",
                        "- R\$ ${widget.valorBase.toStringAsFixed(2)}",
                        color: Colors.green,
                      ),
                    if (valorExtrasNovos > 0)
                      _buildResumoRow(
                        "Extras Adicionados",
                        "+ R\$ ${valorExtrasNovos.toStringAsFixed(2)}",
                      ),

                    SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "TOTAL A PAGAR",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "R\$ ${totalPagar.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: widget.corAcai,
                          ),
                        ),
                      ],
                    ),

                    // AVISO SE NÃO TIVER FORMA DE PAGAMENTO SELECIONADA
                    if (precisaPagar && _metodoPagamento == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 15),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_upward,
                              size: 16,
                              color: Colors.red,
                            ),
                            SizedBox(width: 5),
                            Text(
                              "Selecione o pagamento no topo à direita",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (!precisaPagar)
                      Container(
                        margin: EdgeInsets.only(top: 20),
                        padding: EdgeInsets.all(10),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "✅ Tudo pago com voucher/isenção.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: (precisaPagar && _metodoPagamento == null)
                ? Colors.grey[300]
                : Colors.green, // Desabilitado visualmente
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Só habilita se não tiver que pagar OU se tiver selecionado pagamento
          onPressed: _isLoading || (precisaPagar && _metodoPagamento == null)
              ? null
              : _confirmarCheckout,
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  "CONFIRMAR E FINALIZAR",
                  style: TextStyle(
                    color: (precisaPagar && _metodoPagamento == null)
                        ? Colors.grey[600]
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  // Widget Auxiliar para os Botões de Pagamento
  Widget _buildPaymentOption(String label, IconData icon, String value) {
    bool isSelected = _metodoPagamento == value;
    return InkWell(
      onTap: () => setState(() => _metodoPagamento = value),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? widget.corAcai : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? widget.corAcai : Colors.grey[300]!,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: widget.corAcai.withOpacity(0.3),
                    blurRadius: 4,
                    offset: Offset(0, 2),
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
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
