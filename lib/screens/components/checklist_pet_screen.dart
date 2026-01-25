import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
// IMPORTANTE: Importar o compactador
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart'
    as path_provider; // Para diretórios temporários

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
  // MUDANÇA: Lista de fotos em vez de uma só
  List<XFile> _fotosLesoes = [];

  bool _temOtite = false;
  bool _agressivo = false;
  final _obsController = TextEditingController();

  // --- NOVA FUNÇÃO: COMPACTADOR DE IMAGEM ---
  Future<XFile?> _comprimirImagem(XFile file) async {
    final dir = await path_provider.getTemporaryDirectory();
    final targetPath =
        '${dir.absolute.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Configuração de compressão agressiva para economizar espaço
    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 60, // Qualidade 60% (bom equilíbrio entre tamanho e visual)
      minWidth: 800, // Redimensiona se for muito grande
      minHeight: 800,
    );

    return result;
  }

  // --- AÇÃO: TIRAR FOTO E COMPACTAR ---
  Future<void> _tirarFoto() async {
    try {
      // 1. Tira a foto (aqui já usamos parâmetros do picker para ajudar)
      final XFile? photoBruta = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photoBruta != null) {
        setState(() => _isLoading = true); // Mostra loading enquanto comprime

        // 2. Passa pelo compactador
        final XFile? photoCompactada = await _comprimirImagem(photoBruta);

        if (photoCompactada != null) {
          setState(() {
            _fotosLesoes.add(photoCompactada); // Adiciona à lista
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
      if (_fotosLesoes.isEmpty) {
        // Opcional: se quiser desmarcar lesões quando ficar sem fotos
        // _temLesoes = false;
      }
    });
  }

  // --- AÇÃO: SALVAR ---
  Future<void> _salvarEConfirmar() async {
    setState(() => _isLoading = true);

    try {
      List<String> urlsFotos = [];

      // 1. UPLOAD PARA A PASTA 'agenpetsChecklist'
      if (_fotosLesoes.isNotEmpty) {
        // Aponta para a pasta que você pediu
        final storageRef = FirebaseStorage.instance.ref().child(
          'agenpetsChecklist',
        );

        for (var xfile in _fotosLesoes) {
          // Cria nome único: IDdoAgendamento_Timestamp.jpg
          final String nomeArquivo =
              '${widget.agendamentoId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final Reference refFoto = storageRef.child(nomeArquivo);

          // Faz o upload
          try {
            await refFoto.putFile(File(xfile.path));
            // Pega o link para salvar no banco
            String url = await refFoto.getDownloadURL();
            urlsFotos.add(url);
          } catch (e) {
            print("Erro no upload da foto: $e");
            // Continua o loop para tentar salvar as outras, se houver
          }
        }
      }

      // 2. PREPARAÇÃO DOS DADOS
      bool temNosSimples = _nivelNos != NivelSeveridade.nenhum;

      final Map<String, dynamic> dadosChecklist = {
        'nivel_nos': _nivelNos.name,
        'tem_nos': temNosSimples,
        'tem_pulgas': _temPulgas,
        'tem_lesoes': _temLesoes,
        'fotos_lesoes_paths': urlsFotos, // Lista de links REAIS do Storage
        'tem_otite': _temOtite,
        'agressivo': _agressivo,
        'observacoes': _obsController.text,
        'feito_por_profissional': true,
        // 'data_registro': Removido pois o backend já gera
        'versao_checklist': '2.3 (Storage: agenpetsChecklist)',
      };

      // 3. CHAMADA DA CLOUD FUNCTION
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
          content: Text("Salvo com sucesso na pasta agenpetsChecklist! ☁️"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Tratamento de erro específico para Storage vs Function
      String msgErro = "Erro desconhecido: $e";
      if (e.toString().contains("permission-denied")) {
        msgErro = "Erro de Permissão: Verifique as Regras do Storage.";
      } else if (e is FirebaseFunctionsException) {
        msgErro = "Erro na Função: ${e.message}";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msgErro), backgroundColor: Colors.red),
      );
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Checklist: ${widget.nomePet}"),
        backgroundColor: Color(0xFF4A148C),
        foregroundColor: Colors.white,
      ),
      backgroundColor: Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerText("Inspeção Inicial", "Registre o estado físico do pet."),
            SizedBox(height: 20),

            // 1. PELAGEM (Código mantido igual)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(FontAwesomeIcons.scissors, color: Color(0xFF4A148C)),
                      SizedBox(width: 12),
                      Text(
                        "Condição de Nós/Embolo",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  SegmentedButton<NivelSeveridade>(
                    segments: const [
                      ButtonSegment(
                        value: NivelSeveridade.nenhum,
                        label: Text('Liso'),
                      ),
                      ButtonSegment(
                        value: NivelSeveridade.leve,
                        label: Text('Leve'),
                      ),
                      ButtonSegment(
                        value: NivelSeveridade.medio,
                        label: Text('Médio'),
                      ),
                      ButtonSegment(
                        value: NivelSeveridade.critico,
                        label: Text('Crítico'),
                      ),
                    ],
                    selected: {_nivelNos},
                    onSelectionChanged: (Set<NivelSeveridade> newSelection) {
                      setState(() => _nivelNos = newSelection.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: MaterialStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(MaterialState.selected)) {
                          return _nivelNos == NivelSeveridade.critico
                              ? Colors.red[100]
                              : Color(0xFFE1BEE7);
                        }
                        return Colors.grey[50];
                      }),
                    ),
                  ),
                  if (_nivelNos == NivelSeveridade.critico)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        "⚠️ Crítico: Pode exigir taxa extra.",
                        style: TextStyle(
                          color: Colors.red[800],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // 2. SAÚDE (Com Galeria de Miniaturas)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _checkItem(
                    "Pulgas ou Carrapatos",
                    FontAwesomeIcons.bug,
                    _temPulgas,
                    (v) => setState(() => _temPulgas = v),
                    isAlert: true,
                  ),
                  Divider(height: 1),

                  // --- ÁREA DAS LESÕES ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _checkItem(
                        "Lesões ou Feridas",
                        FontAwesomeIcons.bandAid,
                        _temLesoes,
                        (v) {
                          setState(() {
                            _temLesoes = v;
                            if (!v)
                              _fotosLesoes.clear(); // Limpa fotos se desmarcar
                          });
                        },
                        isAlert: true,
                      ),

                      if (_temLesoes)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // NOVA WIDGET DE GALERIA
                              _buildGaleriaFotos(),

                              if (_fotosLesoes.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "⚠️ Adicione pelo menos uma foto da lesão.",
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  Divider(height: 1),
                  _checkItem(
                    "Otite / Ouvido Sujo",
                    FontAwesomeIcons.earListen,
                    _temOtite,
                    (v) => setState(() => _temOtite = v),
                  ),
                  Divider(height: 1),
                  _checkItem(
                    "Agressivo / Medroso",
                    FontAwesomeIcons.triangleExclamation,
                    _agressivo,
                    (v) => setState(() => _agressivo = v),
                    isAlert: true,
                  ),
                ],
              ),
            ),

            SizedBox(height: 25),
            _headerText("Observações", "Detalhes adicionais."),
            SizedBox(height: 10),

            TextField(
              controller: _obsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Ex: Verruga na pata esquerda...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),

            SizedBox(height: 30),

            // BOTÃO
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? SizedBox(
                        width: 25,
                        height: 25,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                label: Text(
                  _isLoading ? "PROCESSANDO..." : "CONFIRMAR",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00C853),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                // Validação: Bloqueia se marcou lesão mas não tem fotos
                onPressed: _isLoading || (_temLesoes && _fotosLesoes.isEmpty)
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

  // --- NOVO WIDGET: GALERIA DE MINIATURAS ---
  Widget _buildGaleriaFotos() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        // 1. Lista as miniaturas existentes
        ..._fotosLesoes.asMap().entries.map((entry) {
          int idx = entry.key;
          XFile file = entry.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                  image: DecorationImage(
                    image: FileImage(File(file.path)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Botão X para remover
              Positioned(
                top: -5,
                right: -5,
                child: InkWell(
                  onTap: () => _removerFoto(idx),
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }).toList(),

        // 2. Botão de Adicionar (+ Câmera)
        InkWell(
          onTap: _tirarFoto,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red[200]!,
                style: BorderStyle.solid,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt, color: Colors.red[300]),
                Text(
                  "Adicionar",
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.red[300],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _checkItem(
    String label,
    IconData icon,
    bool valor,
    Function(bool) onChanged, {
    bool isAlert = false,
  }) {
    Color iconColor = isAlert ? Colors.red[700]! : Color(0xFF4A148C);
    return SwitchListTile(
      value: valor,
      onChanged: onChanged,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      title: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          SizedBox(width: 15),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
        ],
      ),
      activeColor: iconColor,
    );
  }

  Widget _headerText(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A148C),
          ),
        ),
        SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }
}
