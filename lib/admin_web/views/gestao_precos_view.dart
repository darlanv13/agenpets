import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// IMPORTANTE: Ajuste os imports conforme onde você salvar os arquivos novos
import 'tabs/precos_base_tab.dart';
import 'tabs/servicos_extras_tab.dart';
import 'tabs/pacotes_assinatura_tab.dart';

class GestaoPrecosView extends StatefulWidget {
  @override
  _GestaoPrecosViewState createState() => _GestaoPrecosViewState();
}

class _GestaoPrecosViewState extends State<GestaoPrecosView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color _corAcai = Color(0xFF4A148C);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: Column(
        children: [
          // HEADER
          Container(
            padding: EdgeInsets.symmetric(vertical: 25, horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.price_change, color: _corAcai, size: 28),
                ),
                SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Gestão de Preços",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _corAcai,
                      ),
                    ),
                    Text(
                      "Configure serviços, preços e pacotes",
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // TABS
          Container(
            margin: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              indicator: BoxDecoration(
                color: _corAcai,
                borderRadius: BorderRadius.circular(50),
              ),
              padding: EdgeInsets.all(5),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tune, size: 18),
                      SizedBox(width: 8),
                      Text("Preços Base"),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, size: 18),
                      SizedBox(width: 8),
                      Text("Extras"),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FontAwesomeIcons.boxOpen, size: 16),
                      SizedBox(width: 8),
                      Text("Pacotes (Assinatura)"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CONTEÚDO
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                PrecosBaseTab(),
                ServicosExtrasTab(),
                PacotesAssinaturaTab(), // A mágica acontece aqui
              ],
            ),
          ),
        ],
      ),
    );
  }
}
