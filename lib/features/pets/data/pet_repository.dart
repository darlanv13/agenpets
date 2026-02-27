import 'package:agenpet/core/services/app_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenpet/features/pets/domain/models/pet_model.dart';

class PetRepository {
  final FirebaseFirestore _db = AppDatabase.instance;

  Stream<List<PetModel>> getPetsStream(String cpf) {
    // Pets também são globais (pertencem ao dono)
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
}
