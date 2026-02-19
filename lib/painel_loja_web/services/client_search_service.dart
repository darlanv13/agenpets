import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenpet/utils/validators.dart';

class ClientSearchService {
  final _db = FirebaseFirestore.instance;

  /// Busca um cliente pelo CPF. Retorna null se não encontrar.
  Future<Map<String, dynamic>?> searchClientByCpf(String cpf) async {
    final cpfLimpo = cpf.replaceAll(RegExp(r'[^0-9]'), '');

    if (!Validators.isCpfValido(cpfLimpo)) {
      throw Exception("CPF inválido");
    }

    try {
      final userDoc = await _db.collection('users').doc(cpfLimpo).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      throw Exception("Erro ao buscar cliente: $e");
    }
  }

  /// Busca os pets de um cliente pelo CPF (ID do documento do usuário).
  Future<List<Map<String, dynamic>>> getClientPets(String cpf) async {
    final cpfLimpo = cpf.replaceAll(RegExp(r'[^0-9]'), '');

    try {
      final petsSnap = await _db
          .collection('users')
          .doc(cpfLimpo)
          .collection('pets')
          .get();

      return petsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      throw Exception("Erro ao buscar pets: $e");
    }
  }
}
