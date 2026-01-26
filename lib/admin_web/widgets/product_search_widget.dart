import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ProductSearchWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onProductSelected;
  final Color corDestaque;

  const ProductSearchWidget({
    Key? key,
    required this.onProductSelected,
    this.corDestaque = const Color(0xFF4A148C),
  }) : super(key: key);

  @override
  _ProductSearchWidgetState createState() => _ProductSearchWidgetState();
}

class _ProductSearchWidgetState extends State<ProductSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _termoBusca = "";
  final _db = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _productsStream;

  @override
  void initState() {
    super.initState();
    // Carrega todos os produtos uma vez (realtime) e filtra localmente
    // Isso evita refetch a cada keystroke e garante que a busca encontre qualquer item
    _productsStream = _db.collection('produtos').orderBy('nome').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CAMPO DE BUSCA
        TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              _termoBusca = val.toLowerCase();
            });
          },
          decoration: InputDecoration(
            hintText: "Buscar produto ou código...",
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            suffixIcon: _termoBusca.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _termoBusca = "");
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 15),
          ),
        ),
        SizedBox(height: 10),

        // LISTA DE RESULTADOS
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(10),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: _productsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.corDestaque,
                    ),
                  );
                }

                var docs = snapshot.data!.docs;

                // Se não tem busca, mostra os primeiros 20 (opcional, para não ficar vazio)
                // Se tem busca, filtra
                List<QueryDocumentSnapshot> filtered;

                if (_termoBusca.isEmpty) {
                   filtered = docs.take(20).toList();
                } else {
                   filtered = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final nome = (data['nome'] ?? '').toString().toLowerCase();
                    final codigo = (data['codigo_barras'] ?? '').toString();
                    return nome.contains(_termoBusca) || codigo.contains(_termoBusca);
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FontAwesomeIcons.boxOpen,
                          size: 30,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 5),
                        Text(
                          _termoBusca.isEmpty
                              ? "Digite para buscar"
                              : "Nenhum produto encontrado.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final estoque = (data['qtd_estoque'] ?? 0);
                    final preco = (data['preco'] ?? 0).toDouble();

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.corDestaque.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          FontAwesomeIcons.box,
                          size: 16,
                          color: widget.corDestaque,
                        ),
                      ),
                      title: Text(
                        data['nome'] ?? 'Produto sem nome',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        "Estoque: $estoque | Cod: ${data['codigo_barras']}",
                        style: TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "R\$ ${preco.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(width: 10),
                          IconButton(
                            icon: Icon(
                              Icons.add_circle,
                              color: estoque > 0
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            onPressed: estoque > 0
                                ? () {
                                    // Retorna o produto com ID incluído
                                    Map<String, dynamic> prod = Map.from(
                                      data,
                                    );
                                    prod['id'] = doc.id;
                                    widget.onProductSelected(prod);
                                  }
                                : null, // Desabilita se sem estoque
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
