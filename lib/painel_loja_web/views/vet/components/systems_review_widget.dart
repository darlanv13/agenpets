import 'package:flutter/material.dart';

class SystemsReviewWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onChanged;
  const SystemsReviewWidget({super.key, required this.onChanged});

  @override
  State<SystemsReviewWidget> createState() => _SystemsReviewWidgetState();
}

class _SystemsReviewWidgetState extends State<SystemsReviewWidget> {
  final List<String> _systems = [
    "Estado Geral",
    "Pele & Anexos",
    "Oftálmico (Olhos)",
    "Otorrino (Ouvidos)",
    "Respiratório",
    "Cardiovascular",
    "Gastrointestinal",
    "Genitourinário",
    "Musculoesquelético",
    "Neurológico",
    "Linfonodos",
  ];

  final Map<String, bool> _isAbnormal = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (var s in _systems) {
      _isAbnormal[s] = false;
      _controllers[s] = TextEditingController();
    }
  }

  void _notifyChange() {
    Map<String, dynamic> data = {};
    for (var s in _systems) {
      if (_isAbnormal[s] == true) {
        data[s] = _controllers[s]?.text ?? '';
      }
    }
    widget.onChanged(data);
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
              "Exame Físico & Sistemas",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4A148C)),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _systems.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final system = _systems[index];
                final isAbnormal = _isAbnormal[system] ?? false;

                return Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      system,
                      style: TextStyle(
                        fontWeight: isAbnormal ? FontWeight.bold : FontWeight.normal,
                        color: isAbnormal ? Colors.red[700] : Colors.black87,
                      ),
                    ),
                    leading: Icon(
                      isAbnormal ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      color: isAbnormal ? Colors.red : Colors.green,
                    ),
                    trailing: Switch(
                      value: !isAbnormal, // Switch represents "Normal"
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                      activeTrackColor: Colors.green[100],
                      inactiveTrackColor: Colors.red[100],
                      onChanged: (val) {
                        setState(() {
                          _isAbnormal[system] = !val;
                          if (!val) { // If turning abnormal
                             // Auto-expand logically handled by user interaction usually
                          } else {
                            _controllers[system]?.clear();
                          }
                        });
                        _notifyChange();
                      },
                    ),
                    children: [
                      if (isAbnormal)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: TextField(
                            controller: _controllers[system],
                            maxLines: 2,
                            onChanged: (_) => _notifyChange(),
                            decoration: InputDecoration(
                              hintText: "Descreva as alterações em $system...",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.red[50],
                              prefixIcon: const Icon(Icons.edit_note, color: Colors.red),
                            ),
                          ),
                        ),
                    ],
                    initiallyExpanded: isAbnormal,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
