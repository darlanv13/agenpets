import 'package:agenpet/core/services/app_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenpet/features/auth/domain/models/user_model.dart';

class AuthRepository {
  final FirebaseFirestore _db = AppDatabase.instance;

  Future<UserModel?> getUser(String cpf) async {
    try {
      final doc = await _db.collection('users').doc(cpf).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print("Erro ao buscar usuário: $e");
      return null;
    }
  }

  Future<void> createUser(UserModel user) async {
    await _db.collection('users').doc(user.cpf).set(user.toMap());
  }

  Future<void> updateDadosCliente(String cpf, Map<String, dynamic> dados) async {
    await _db.collection('users').doc(cpf).update(dados);
  }

  Future<void> saveUserAddress(String cpf, String endereco) async {
    await _db.collection('users').doc(cpf).set({
      'endereco_padrao': endereco,
    }, SetOptions(merge: true));
  }

  Future<String?> getUserAddress(String cpf) async {
    final doc = await _db.collection('users').doc(cpf).get();
    if (doc.exists) {
      return doc.data()?['endereco_padrao'];
    }
    return null;
  }
}
