class UserModel {
  final String cpf; // Usaremos o CPF como ID do documento
  final String nome;
  final String telefone;

  UserModel({required this.cpf, required this.nome, required this.telefone});

  // Converte dados do Firebase para Objeto Dart
  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      cpf: docId,
      nome: map['nome'] ?? '',
      telefone: map['telefone'] ?? '',
    );
  }

  // Converte Objeto Dart para salvar no Firebase
  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'telefone': telefone,
      'cpf': cpf, // Redundante, mas útil em buscas
      'created_at': DateTime.now(),
    };
  }
}
