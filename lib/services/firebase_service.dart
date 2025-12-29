import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_model.dart';
import '../models/pet_model.dart';

class FirebaseService {
  // --- A CORREÇÃO ESTÁ AQUI ---
  // Antes estava: FirebaseFirestore.instance (que vai para o default)
  // Agora apontamos explicitamente para o banco 'agenpets'
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'agenpets',
  );

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // --- USUÁRIOS ---

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
    // Usamos set() para garantir que o ID do documento seja o CPF
    await _db.collection('users').doc(user.cpf).set(user.toMap());
  }

  // --- PETS ---

  Stream<List<PetModel>> getPetsStream(String cpf) {
    return _db.collection('users').doc(cpf).collection('pets').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => PetModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addPet(PetModel pet) async {
    await _db
        .collection('users')
        .doc(pet.donoCpf)
        .collection('pets')
        .add(pet.toMap());
  }

  // --- AGENDAMENTOS (Via Cloud Functions) ---
  // Nota: As funções geralmente rodam no servidor e têm acesso admin,
  // mas a chamada client-side aqui está correta.

  Future<List<String>> buscarHorariosDisponiveis(
    String data,
    String servico,
  ) async {
    try {
      final result = await _functions.httpsCallable('buscarHorarios').call({
        'dataConsulta': data,
        'servico': servico,
      });
      return List<String>.from(result.data['horarios']);
    } catch (e) {
      throw Exception("Erro ao calcular horários: $e");
    }
  }

  Future<Map<String, dynamic>> criarAgendamento({
    required String servico,
    required DateTime dataHora,
    required String cpfUser,
    required String petId,
    required String metodoPagamento,
    required double valor,
  }) async {
    try {
      final result = await _functions.httpsCallable('criarAgendamento').call({
        'servico': servico,
        'data_hora': dataHora.toIso8601String(),
        'cpf_user': cpfUser,
        'pet_id': petId,
        'metodo_pagamento': metodoPagamento,
        'valor': valor,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception("Falha ao agendar: $e");
    }
  }
}
