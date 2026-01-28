import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

enum NivelSeveridade { nenhum, leve, medio, critico }

class ChecklistPetScreen extends StatefulWidget {
  final String agendamentoId;
  final String nomePet;

  const ChecklistPetScreen({
    Key? key,
    required this.agendamentoId,
    required this.nomePet,
  }) : super(key: key);

  @override
  _ChecklistPetScreenState createState() => _ChecklistPetScreenState();
}

class _ChecklistPetScreenState extends State<ChecklistPetScreen> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // --- ESTADO DO CHECKLIST ---
  NivelSeveridade _nivelNos = NivelSeveridade.nenhum;
  bool _temPulgas = false;

  bool _temLesoes = false;
  List<XFile> _fotosLesoes = [];

  bool _temOtite = false;
  bool _agressivo = false;
  final _obsController = TextEditingController();

  // --- SERVIÇOS EXTRAS ---
  List<Map<String, dynamic>> _availableServices = [];
  List<Map<String, dynamic>> _selectedServices = [];

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final snapshot =
          await _db.collection('servicos_extras').orderBy('nome').get();
      setState(() {
        _availableServices =
            snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'nome': data['nome'],
                'preco': (data['preco'] ?? 0).toDouble(),
                'porte': data['porte'],
                'pelagem': data['pelagem'],
              };
            }).toList();
      });
    } catch (e) {
      print("Erro ao carregar serviços: $e");
    }
  }

  // --- COMPRESSÃO ---
  Future<XFile?> _comprimirImagem(XFile file) async {
    final dir = await path_provider.getTemporaryDirectory();
    final targetPath =
        '${dir.absolute.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 60,
      minWidth: 800,
      minHeight: 800,
    );

    return result;
  }

  // --- FOTOS ---
  Future<void> _tirarFoto() async {
    try {
      final XFile? photoBruta = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photoBruta != null) {
        setState(() => _isLoading = true);

        final XFile? photoCompactada = await _comprimirImagem(photoBruta);

        if (photoCompactada != null) {
          setState(() {
            _fotosLesoes.add(photoCompactada);
            _temLesoes = true;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro na câmera: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removerFoto(int index) {
    setState(() {
      _fotosLesoes.removeAt(index);
    });
  }

  // --- SALVAR ---
  Future<void> _salvarEConfirmar() async {
    setState(() => _isLoading = true);

    try {
      List<String> urlsFotos = [];

      // 1. Upload Fotos
      if (_fotosLesoes.isNotEmpty) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('agenpetsChecklist');

        for (var xfile in _fotosLesoes) {
          final String nomeArquivo =
              '${widget.agendamentoId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final Reference refFoto = storageRef.child(nomeArquivo);

          try {
            await refFoto.putFile(File(xfile.path));
            String url = await refFoto.getDownloadURL();
            urlsFotos.add(url);
          } catch (e) {
            print("Erro no upload da foto: $e");
          }
        }
      }

      // 2. Checklist Payload
      bool temNosSimples = _nivelNos != NivelSeveridade.nenhum;

      final Map<String, dynamic> dadosChecklist = {
        'nivel_nos': _nivelNos.name,
        'tem_nos': temNosSimples,
        'tem_pulgas': _temPulgas,
        'tem_lesoes': _temLesoes,
        'fotos_lesoes_paths': urlsFotos,
        'tem_otite': _temOtite,
        'agressivo': _agressivo,
        'observacoes': _obsController.text,
        'feito_por_profissional': true,
        'versao_checklist': '3.0 (UX Refactor + Extras)',
      };

      // 3. Atualizar Agendamento com Extras (Direct Write)
      if (_selectedServices.isNotEmpty) {
        await _db.collection('agendamentos').doc(widget.agendamentoId).update({
          'servicos_extras': _selectedServices,
        });
      }

      // 4. Call Cloud Function
      final functions = FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      );

      await functions.httpsCallable('salvarChecklistPet').call({
        'agendamentoId': widget.agendamentoId,
        'checklist': dadosChecklist,
      });

      if (!mounted) return;
      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Checklist salvo com sucesso! ☁️"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String msgErro = "Erro desconhecido: $e";
      if (e.toString().contains("permission-denied")) {
        msgErro = "Erro de Permissão: Verifique as Regras.";
      } else if (e is FirebaseFunctionsException) {
        msgErro = "Erro na Função: ${e.message}";
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msgErro), backgroundColor: Colors.red));
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Checklist: ${widget.nomePet}",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF4A148C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSectionCard(
              title: "Inspeção Inicial",
              icon: FontAwesomeIcons.magnifyingGlass,
              content: _buildInspecaoContent(),
            ),
            SizedBox(height: 20),
            _buildSectionCard(
              title: "Saúde & Comportamento",
              icon: FontAwesomeIcons.heartPulse,
              content: _buildSaudeContent(),
            ),
            SizedBox(height: 20),
            _buildSectionCard(
              title: "Serviços Adicionais",
              icon: FontAwesomeIcons.plusCircle,
              content: _buildExtrasContent(),
            ),
            SizedBox(height: 20),
            _buildSectionCard(
              title: "Observações",
              icon: FontAwesomeIcons.clipboard,
              content: TextField(
                controller: _obsController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Alguma observação importante?",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ),
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : Icon(Icons.check_circle, size: 24),
                label: Text(
                  _isLoading ? "SALVANDO..." : "FINALIZAR CHECKLIST",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00C853),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed:
                    _isLoading || (_temLesoes && _fotosLesoes.isEmpty)
                        ? null
                        : _salvarEConfirmar,
              ),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Color(0xFF4A148C), size: 18),
                SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: EdgeInsets.all(16), child: content),
        ],
      ),
    );
  }

  Widget _buildInspecaoContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Condição de Nós/Embolo",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        SizedBox(height: 10),
        SegmentedButton<NivelSeveridade>(
          segments: const [
            ButtonSegment(value: NivelSeveridade.nenhum, label: Text('Liso')),
            ButtonSegment(value: NivelSeveridade.leve, label: Text('Leve')),
            ButtonSegment(value: NivelSeveridade.medio, label: Text('Médio')),
            ButtonSegment(value: NivelSeveridade.critico, label: Text('Crítico')),
          ],
          selected: {_nivelNos},
          onSelectionChanged: (Set<NivelSeveridade> newSelection) {
            setState(() => _nivelNos = newSelection.first);
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return _nivelNos == NivelSeveridade.critico
                    ? Colors.red[100]
                    : Color(0xFFE1BEE7);
              }
              return Colors.white;
            }),
          ),
        ),
        if (_nivelNos == NivelSeveridade.critico)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[800], size: 16),
                SizedBox(width: 5),
                Text(
                  "Atenção: Pode exigir taxa de desembolo.",
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSaudeContent() {
    return Column(
      children: [
        _buildSwitchItem(
          "Pulgas ou Carrapatos",
          _temPulgas,
          (v) => setState(() => _temPulgas = v),
          isAlert: true,
        ),
        Divider(),
        _buildSwitchItem("Lesões ou Feridas", _temLesoes, (v) {
          setState(() {
            _temLesoes = v;
            if (!v) _fotosLesoes.clear();
          });
        }, isAlert: true),
        if (_temLesoes) ...[
          SizedBox(height: 10),
          _buildGaleriaFotos(),
          if (_fotosLesoes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "⚠️ Obrigatório: Adicione fotos da lesão.",
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          SizedBox(height: 10),
        ],
        Divider(),
        _buildSwitchItem(
          "Otite / Ouvido Sujo",
          _temOtite,
          (v) => setState(() => _temOtite = v),
        ),
        Divider(),
        _buildSwitchItem(
          "Agressivo / Medroso",
          _agressivo,
          (v) => setState(() => _agressivo = v),
          isAlert: true,
        ),
      ],
    );
  }

  Widget _buildExtrasContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Adicionar Serviços ao Agendamento:",
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        SizedBox(height: 10),
        Autocomplete<Map<String, dynamic>>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<Map<String, dynamic>>.empty();
            }
            return _availableServices.where((option) {
              return option['nome'].toString().toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              );
            });
          },
          displayStringForOption: (option) {
            String label = option['nome'];
            if (option['porte'] != null && option['porte'] != 'Todos') {
              label += " (${option['porte']})";
            }
            if (option['pelagem'] != null && option['pelagem'] != 'Todos') {
              label += " - ${option['pelagem']}";
            }
            return "$label (R\$ ${option['preco'].toStringAsFixed(2)})";
          },
          onSelected: (Map<String, dynamic> selection) {
            setState(() {
              // Evitar duplicatas
              if (!_selectedServices.any((s) => s['id'] == selection['id'])) {
                _selectedServices.add(selection);
              }
            });
          },
          fieldViewBuilder: (
            context,
            textEditingController,
            focusNode,
            onFieldSubmitted,
          ) {
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: "Buscar serviço (ex: Hidratação)",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 15),
              ),
            );
          },
        ),
        SizedBox(height: 15),
        if (_selectedServices.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _selectedServices.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _selectedServices[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    item['nome'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "R\$ ${(item['preco'] as double).toStringAsFixed(2)}",
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[300]),
                    onPressed: () {
                      setState(() {
                        _selectedServices.removeAt(index);
                      });
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSwitchItem(
    String label,
    bool value,
    Function(bool) onChanged, {
    bool isAlert = false,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isAlert ? (value ? Colors.red : Colors.black87) : Colors.black87,
        ),
      ),
      activeColor: isAlert ? Colors.red : Color(0xFF4A148C),
    );
  }

  Widget _buildGaleriaFotos() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ..._fotosLesoes.asMap().entries.map((entry) {
          int idx = entry.key;
          XFile file = entry.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                  image: DecorationImage(
                    image: FileImage(File(file.path)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: -8,
                right: -8,
                child: InkWell(
                  onTap: () => _removerFoto(idx),
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
        InkWell(
          onTap: _tirarFoto,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey[400]!,
                style: BorderStyle.dashed,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt, color: Colors.grey[600]),
                SizedBox(height: 4),
                Text(
                  "Foto",
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
