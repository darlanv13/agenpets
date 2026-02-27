import 'package:agenpet/core/config/app_config.dart';
import 'package:agenpet/core/services/app_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreRepository {
  final FirebaseFirestore _db = AppDatabase.instance;

  String get _tenantId => AppConfig.tenantId;

  // --- ÁREA ADMINISTRATIVA (Configurações da Loja) ---

  Future<void> updateConfiguracoes(Map<String, dynamic> novosDados) async {
    // Antes: _db.collection('config')...
    // Agora: tenants/{loja}/config/parametros
    await _db
        .collection('tenants')
        .doc(_tenantId)
        .collection('config')
        .doc('parametros')
        .set(
          novosDados,
          SetOptions(merge: true),
        ); // Usei set com merge para garantir que crie se não existir
  }

  Future<Map<String, dynamic>> getConfiguracoes() async {
    final doc = await _db
        .collection('tenants')
        .doc(_tenantId)
        .collection('config')
        .doc('parametros')
        .get();
    return doc.data() ?? {};
  }

  // --- PROFISSIONAIS (Funcionários da Loja) ---

  Future<void> addProfissional(
    String nome,
    String cpf,
    List<String> habilidades,
  ) async {
    // Antes: _db.collection('profissionais')...
    // Agora: tenants/{loja}/profissionais/...
    await _db
        .collection('tenants')
        .doc(_tenantId)
        .collection('profissionais')
        .add({
          'nome': nome,
          'cpf': cpf,
          'habilidades': habilidades,
          'ativo': true,
          'peso_prioridade': 5,
        });
  }
}
