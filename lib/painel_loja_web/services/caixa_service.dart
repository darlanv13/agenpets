import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenpet/services/app_database.dart';

class CaixaService {
  static Future<bool> isCaixaAberto(String tenantId) async {
    try {
      final db = AppDatabase.instance;
      final query = await db
          .collection('tenants')
          .doc(tenantId)
          .collection('caixas_diarios')
          .where('status', isEqualTo: 'ABERTO')
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print("Erro ao verificar caixa: $e");
      return false;
    }
  }
}
