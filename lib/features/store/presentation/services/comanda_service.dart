import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenpet/services/app_database.dart';

class ComandaService {
  static Future<bool> cancelarEnvio({
    required String tenantId,
    required String origemCollection,
    required String origemId,
  }) async {
    try {
      final db = AppDatabase.instance;

      // 1. Encontrar a comanda aberta
      final comandaQuery = await db
          .collection('tenants')
          .doc(tenantId)
          .collection('comandas')
          .where('origem_id', isEqualTo: origemId)
          .where('status', isEqualTo: 'aberta')
          .limit(1)
          .get();

      if (comandaQuery.docs.isEmpty) {
        // Pode já ter sido paga ou não existir
        return false;
      }

      final comandaDoc = comandaQuery.docs.first;

      // 2. Deletar a comanda
      await comandaDoc.reference.delete();

      // 3. Resetar o documento de origem
      await db
          .collection('tenants')
          .doc(tenantId)
          .collection(origemCollection)
          .doc(origemId)
          .update({
            'enviado_pdv': false,
            // Opcional: Se quiser limpar o status_pagamento visual, mas 'enviado_pdv' é a chave
          });

      return true;
    } catch (e) {
      print("Erro ao cancelar comanda: $e");
      return false;
    }
  }
}
