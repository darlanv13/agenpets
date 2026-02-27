import 'package:agenpet/core/config/app_config.dart';
import 'package:agenpet/core/services/app_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

class SubscriptionRepository {
  final FirebaseFirestore _db = AppDatabase.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'southamerica-east1',
  );

  String get _tenantId => AppConfig.tenantId;

  // Busca saldo de vouchers em tempo real
  Stream<Map<String, int>> getSaldoVouchers(String cpf) {
    return _db
        .collection('users')
        .doc(cpf)
        .collection('vouchers') // Nova subcoleção
        .doc(_tenantId) // <--- O ID da loja atual (ex: pet_shop_bairro)
        .snapshots()
        .map((doc) {
          final data = doc.data();
          // Se não tiver documento para esta loja, o saldo é zero
          if (data == null) return {'banho': 0, 'tosa': 0, 'creche': 0};

          return {
            // Note que removi o prefixo "vouchers_" dos nomes dos campos para ficar mais limpo
            // mas você pode manter se preferir, desde que alinhe com o servidor.
            'banho':
                (data['vouchers_banho'] as num?)?.toInt() ??
                (data['banho'] as num?)?.toInt() ??
                0,
            'tosa':
                (data['vouchers_tosa'] as num?)?.toInt() ??
                (data['tosa'] as num?)?.toInt() ??
                0,
            'creche':
                (data['vouchers_creche'] as num?)?.toInt() ??
                (data['creche'] as num?)?.toInt() ??
                0,
          };
        });
  }

  // Comprar Assinatura
  Future<Map<String, dynamic>> comprarAssinatura(
    String cpf,
    String tipoPlano,
  ) async {
    try {
      final result = await _functions.httpsCallable('comprarAssinatura').call({
        'tenantId': _tenantId,
        'cpf_user': cpf,
        'pacoteId': tipoPlano,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception("Erro ao processar assinatura: $e");
    }
  }
}
