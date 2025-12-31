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

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'southamerica-east1',
  );
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

  // Busca saldo de vouchers em tempo real
  Stream<Map<String, int>> getSaldoVouchers(String cpf) {
    return _db.collection('users').doc(cpf).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return {'banho': 0, 'tosa': 0};

      return {
        'banho': (data['vouchers_banho'] ?? 0) as int,
        'tosa': (data['vouchers_tosa'] ?? 0) as int,
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
        'cpf_user': cpf,
        'tipo_plano': tipoPlano,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception("Erro ao processar assinatura: $e");
    }
  }

  // --- HOTEL ---
  Future<Map<String, dynamic>> reservarHotel({
    required String petId,
    required String cpfUser,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    try {
      final result = await _functions.httpsCallable('reservarHotel').call({
        'pet_id': petId,
        'cpf_user': cpfUser,
        'check_in': checkIn.toIso8601String(),
        'check_out': checkOut.toIso8601String(),
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      // Isso ajuda a ver o erro real no console do Flutter
      print("Erro detalhado reservarHotel: $e");

      if (e is FirebaseFunctionsException) {
        throw Exception(e.message);
      }
      throw Exception("Erro ao reservar: $e");
    }
  }

  // --- ÁREA ADMINISTRATIVA ---

  // 1. Atualizar Preços e Configurações
  Future<void> updateConfiguracoes(Map<String, dynamic> novosDados) async {
    await _db.collection('config').doc('parametros').update(novosDados);
  }

  // 2. Cadastrar Novo Profissional
  Future<void> addProfissional(
    String nome,
    String cpf,
    List<String> habilidades,
  ) async {
    await _db.collection('profissionais').add({
      'nome': nome,
      'cpf': cpf, // Importante salvar formatado: 000.000.000-00
      'habilidades': habilidades,
      'ativo': true,
      'peso_prioridade': 5, // Valor padrão
    });
  }

  // 3. Atualizar Dados do Cliente (CRM)
  Future<void> updateDadosCliente(
    String cpf,
    Map<String, dynamic> dados,
  ) async {
    await _db.collection('users').doc(cpf).update(dados);
  }

  // 4. Buscar Configurações Atuais
  Future<Map<String, dynamic>> getConfiguracoes() async {
    final doc = await _db.collection('config').doc('parametros').get();
    return doc.data() ?? {};
  }

  // ... dentro da classe FirebaseService ...

  // Buscar dias sem vaga no hotel
  Future<List<DateTime>> buscarDiasLotadosHotel() async {
    try {
      final result = await _functions.httpsCallable('obterDiasLotados').call();
      final List<dynamic> datasStrings = result.data['dias_lotados'] ?? [];

      // Converte strings '2023-10-25' para DateTime
      return datasStrings.map((s) => DateTime.parse(s)).toList();
    } catch (e) {
      print("Erro ao buscar lotação: $e");
      return []; // Se der erro, não bloqueia nada (melhor que travar)
    }
  }
}
