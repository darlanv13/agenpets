class PetModel {
  final String? id; // O ID é nulo antes de salvar
  final String donoCpf;
  final String nome;
  final String raca;
  final String tipo; // 'cao', 'gato', 'outro'

  PetModel({
    this.id,
    required this.donoCpf,
    required this.nome,
    required this.raca,
    required this.tipo,
  });

  factory PetModel.fromMap(Map<String, dynamic> map, String docId) {
    return PetModel(
      id: docId,
      donoCpf: map['dono_cpf'] ?? '',
      nome: map['nome'] ?? '',
      raca: map['raca'] ?? '',
      tipo: map['tipo'] ?? 'outro',
    );
  }

  Map<String, dynamic> toMap() {
    return {'dono_cpf': donoCpf, 'nome': nome, 'raca': raca, 'tipo': tipo};
  }
}
