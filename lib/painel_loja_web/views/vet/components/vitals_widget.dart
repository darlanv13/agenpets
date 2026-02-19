import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class VitalsWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onChanged;
  const VitalsWidget({super.key, required this.onChanged});

  @override
  State<VitalsWidget> createState() => _VitalsWidgetState();
}

class _VitalsWidgetState extends State<VitalsWidget> {
  final _weightCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _hrCtrl = TextEditingController();
  final _rrCtrl = TextEditingController();
  final _crtCtrl = TextEditingController();

  String _mucosaColor = 'Rosa'; // Default

  final List<Map<String, dynamic>> _mucosaOptions = [
    {'label': 'Rosa (Normal)', 'color': Colors.pink[100]},
    {'label': 'Pálida', 'color': Colors.grey[200]},
    {'label': 'Cianótica', 'color': Colors.blue[100]},
    {'label': 'Ictérica', 'color': Colors.yellow[100]},
    {'label': 'Congesta', 'color': Colors.red[100]},
  ];

  void _notifyChange() {
    widget.onChanged({
      'peso': _weightCtrl.text,
      'temp': _tempCtrl.text,
      'fc': _hrCtrl.text,
      'fr': _rrCtrl.text,
      'tpc': _crtCtrl.text,
      'mucosas': _mucosaColor,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Sinais Vitais & Triagem",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A148C),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                _buildVitalInput(
                  "Peso (kg)",
                  _weightCtrl,
                  FontAwesomeIcons.weightScale,
                  width: 120,
                ),
                _buildVitalInput(
                  "Temp (°C)",
                  _tempCtrl,
                  FontAwesomeIcons.temperatureHalf,
                  width: 120,
                ),
                _buildVitalInput(
                  "FC (bpm)",
                  _hrCtrl,
                  FontAwesomeIcons.heartPulse,
                  width: 120,
                ),
                _buildVitalInput(
                  "FR (mpm)",
                  _rrCtrl,
                  FontAwesomeIcons.lungs,
                  width: 120,
                ),
                _buildVitalInput(
                  "TPC (seg)",
                  _crtCtrl,
                  Icons.timer,
                  width: 120,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Mucosas",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: _mucosaOptions.map((opt) {
                final bool isSelected = _mucosaColor == opt['label'];
                return ChoiceChip(
                  label: Text(opt['label']),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _mucosaColor = opt['label']);
                    _notifyChange();
                  },
                  avatar: CircleAvatar(
                    backgroundColor: opt['color'],
                    radius: 5,
                  ),
                  selectedColor: const Color(0xFF4A148C).withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? const Color(0xFF4A148C)
                        : Colors.black87,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalInput(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    double width = 100,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => _notifyChange(),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 14, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          isDense: true,
        ),
      ),
    );
  }
}
