import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'subviews/precos_base_view.dart';
import 'subviews/servicos_view.dart';
import 'subviews/pacotes_view.dart';

class GestaoPrecosView extends StatefulWidget {
  @override
  _GestaoPrecosViewState createState() => _GestaoPrecosViewState();
}

class _GestaoPrecosViewState extends State<GestaoPrecosView> {
  int _selectedIndex = 0;
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

  final List<Widget> _views = [
    PrecosBaseView(),
    ServicosView(),
    PacotesView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Row(
        children: [
          // SIDE MENU
          Container(
            width: 260,
            color: Colors.white,
            child: Column(
              children: [
                _buildMenuHeader(),
                SizedBox(height: 20),
                _buildMenuItem(0, "Tabela Base", FontAwesomeIcons.table),
                _buildMenuItem(1, "Serviços", FontAwesomeIcons.listCheck),
                _buildMenuItem(2, "Pacotes", FontAwesomeIcons.boxesStacked),
              ],
            ),
          ),

          // SEPARATOR
          VerticalDivider(width: 1, color: Colors.grey[200]),

          // CONTENT
          Expanded(
            child: Container(
              color: _corFundo,
              child: _views[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuHeader() {
    return Container(
      padding: EdgeInsets.all(30),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _corAcai.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.price_change, color: _corAcai, size: 28),
          ),
          SizedBox(height: 15),
          Text(
            "Gestão de\nPreços",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, String label, IconData icon) {
    bool isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 18),
          decoration: BoxDecoration(
            color: isSelected ? _corAcai.withValues(alpha: 0.05) : Colors.transparent,
            border: Border(
              right: BorderSide(
                color: isSelected ? _corAcai : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? _corAcai : Colors.grey[500],
              ),
              SizedBox(width: 15),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? _corAcai : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
