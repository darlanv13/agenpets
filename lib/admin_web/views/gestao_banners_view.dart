import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class GestaoBannersView extends StatefulWidget {
  @override
  _GestaoBannersViewState createState() => _GestaoBannersViewState();
}

class _GestaoBannersViewState extends State<GestaoBannersView> {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  // Cores do Tema
  final Color _corAcai = Color(0xFF4A148C);
  final Color _corFundo = Color(0xFFF5F7FA);

  // Mapas para salvar/ler ícones e cores do Banco
  final Map<String, IconData> _mapaIcones = {
    'shower': FontAwesomeIcons.shower,
    'crown': FontAwesomeIcons.crown,
    'hotel': FontAwesomeIcons.hotel,
    'scissors': FontAwesomeIcons.scissors,
    'percentage': FontAwesomeIcons.percent,
    'syringe': FontAwesomeIcons.syringe,
    'heart': FontAwesomeIcons.heart,
    'star': FontAwesomeIcons.star,
  };

  final Map<String, Color> _mapaCores = {
    'acai': Color(0xFF4A148C),
    'laranja': Colors.orange,
    'azul': Colors.blue,
    'verde': Colors.green,
    'roxo': Colors.purple,
    'rosa': Colors.pink,
    'vermelho': Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      body: Container(
        padding: EdgeInsets.all(30),
        child: Column(
          children: [
            // Cabeçalho
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Gestão de Banners",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _corAcai,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Controle os destaques e promoções da Home",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.add_photo_alternate, size: 20),
                  label: Text("NOVO BANNER"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _corAcai,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    padding: EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () => _abrirEditor(context),
                ),
              ],
            ),
            SizedBox(height: 30),

            // Lista de Banners
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db.collection('banners').snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return Center(
                      child: CircularProgressIndicator(color: _corAcai),
                    );
                  }

                  final docs = snap.data!.docs;

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.web_asset_off,
                            size: 60,
                            color: Colors.grey[300],
                          ),
                          SizedBox(height: 15),
                          Text(
                            "Nenhum banner ativo.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 500, // Cards largos
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (ctx, i) => _buildBannerCard(docs[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Recupera cor e ícone ou usa padrão
    Color corBg = _mapaCores[data['cor_id']] ?? _corAcai;
    IconData icone = _mapaIcones[data['icone_id']] ?? FontAwesomeIcons.star;
    bool ativo = data['ativo'] ?? true;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          // Preview do Banner (Topo do Card)
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [corBg, corBg.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Icon(
                      icone,
                      size: 60,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ativo ? "VISÍVEL NO APP" : "OCULTO",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                data['titulo'] ?? '',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                data['subtitulo'] ?? '',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
          ),

          // Controles (Base do Card)
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Switch(
                        value: ativo,
                        activeColor: Colors.green,
                        onChanged: (val) =>
                            doc.reference.update({'ativo': val}),
                      ),
                      Text(
                        ativo ? "Ativo" : "Inativo",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: _corAcai),
                        onPressed: () =>
                            _abrirEditor(context, docId: doc.id, data: data),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red[300],
                        ),
                        onPressed: () => _confirmarExclusao(doc),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- EDITOR DE BANNER ---
  void _abrirEditor(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? data,
  }) {
    final _tituloCtrl = TextEditingController(text: data?['titulo']);
    final _subtituloCtrl = TextEditingController(text: data?['subtitulo']);
    String _corSelecionada = data?['cor_id'] ?? 'acai';
    String _iconeSelecionado = data?['icone_id'] ?? 'percentage';
    bool _ativo = data?['ativo'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // Helper para construir o preview dentro do dialog
          Color corPreview = _mapaCores[_corSelecionada]!;
          IconData iconPreview = _mapaIcones[_iconeSelecionado]!;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: EdgeInsets.zero,
            content: Container(
              width: 500,
              padding: EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    docId == null ? "Novo Banner" : "Editar Banner",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _corAcai,
                    ),
                  ),
                  SizedBox(height: 20),

                  // PREVIEW LIVE
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [corPreview, corPreview.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -10,
                          bottom: -10,
                          child: Icon(
                            iconPreview,
                            size: 70,
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _tituloCtrl.text.isEmpty
                                    ? "Título do Banner"
                                    : _tituloCtrl.text,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _subtituloCtrl.text.isEmpty
                                    ? "Subtítulo da promoção"
                                    : _subtituloCtrl.text,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 25),

                  // CAMPOS
                  TextField(
                    controller: _tituloCtrl,
                    decoration: InputDecoration(
                      labelText: "Título Principal",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) => setStateDialog(() {}), // Atualiza preview
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: _subtituloCtrl,
                    decoration: InputDecoration(
                      labelText: "Subtítulo / Chamada",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) => setStateDialog(() {}),
                  ),
                  SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Cor de Fundo",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 5),
                            Wrap(
                              spacing: 8,
                              children: _mapaCores.entries.map((e) {
                                bool isSelected = _corSelecionada == e.key;
                                return GestureDetector(
                                  onTap: () => setStateDialog(
                                    () => _corSelecionada = e.key,
                                  ),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: e.value,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(
                                              color: Colors.black,
                                              width: 2,
                                            )
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Ícone Decorativo",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 5),
                            DropdownButtonFormField<String>(
                              value: _iconeSelecionado,
                              isExpanded: true,
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              items: _mapaIcones.entries
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Row(
                                        children: [
                                          Icon(
                                            e.value,
                                            size: 16,
                                            color: Colors.grey[700],
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            e.key.toUpperCase(),
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setStateDialog(() => _iconeSelecionado = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),
                  CheckboxListTile(
                    title: Text("Banner Ativo?"),
                    value: _ativo,
                    activeColor: _corAcai,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setStateDialog(() => _ativo = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corAcai,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                onPressed: () async {
                  final bannerData = {
                    'titulo': _tituloCtrl.text,
                    'subtitulo': _subtituloCtrl.text,
                    'cor_id': _corSelecionada,
                    'icone_id': _iconeSelecionado,
                    'ativo': _ativo,
                    'updated_at': FieldValue.serverTimestamp(),
                  };

                  if (docId == null) {
                    await _db.collection('banners').add(bannerData);
                  } else {
                    await _db
                        .collection('banners')
                        .doc(docId)
                        .update(bannerData);
                  }
                  Navigator.pop(ctx);
                },
                child: Text(
                  "SALVAR",
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

  void _confirmarExclusao(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Excluir Banner?"),
        content: Text("Esta ação não pode ser desfeita."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(ctx);
            },
            child: Text("Excluir", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
