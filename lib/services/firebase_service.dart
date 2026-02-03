import 'package:agenpet/config/app_config.dart';
import 'package:agenpet/services/app_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_model.dart';
import '../models/pet_model.dart';

class FirebaseService {
  // --- A CORREÇÃO ESTÁ AQUI ---
  // Antes estava: FirebaseFirestore.instance (que vai para o default)
  // Agora apontamos explicitamente para o banco 'agenpets'
  final FirebaseFirestore _db = AppDatabase.instance;

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'southamerica-east1',
  );

  String get _tenantId => AppConfig.tenantId;
  // --- USUÁRIOS ---

  // ===========================================================================
  // PARTE 1: DADOS UNIVERSAIS (Global para todos os Apps)
  // O usuário e o pet são os mesmos, não importa qual loja ele frequente.
  // ===========================================================================

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
    // Adicionamos o usuário na coleção GLOBAL 'users'
    await _db.collection('users').doc(user.cpf).set(user.toMap());
  }

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

  // ===========================================================================
  // PARTE 2: DADOS DO TENANT (Específicos da Loja Atual)
  // Aqui usamos o _tenantId para isolar os dados.
  // ===========================================================================

  // --- ÁREA ADMINISTRATIVA (Configurações da Loja) ---

  Future<void> updateConfiguracoes(Map<String, dynamic> novosDados) async {
    // Antes: _db.collection('config')...
    // Agora: tenants/{loja}/config/parametros
    await _db
        .collection('tenants')
        .doc(_tenantId)
        .collection('config')
        .doc('parametros')
        .set(
          novosDados,
          SetOptions(merge: true),
        ); // Usei set com merge para garantir que crie se não existir
  }

  Future<Map<String, dynamic>> getConfiguracoes() async {
    final doc = await _db
        .collection('tenants')
        .doc(_tenantId)
        .collection('config')
        .doc('parametros')
        .get();
    return doc.data() ?? {};
  }

  // --- PROFISSIONAIS (Funcionários da Loja) ---

  Future<void> addProfissional(
    String nome,
    String cpf,
    List<String> habilidades,
  ) async {
    // Antes: _db.collection('profissionais')...
    // Agora: tenants/{loja}/profissionais/...
    await _db
        .collection('tenants')
        .doc(_tenantId)
        .collection('profissionais')
        .add({
          'nome': nome,
          'cpf': cpf,
          'habilidades': habilidades,
          'ativo': true,
          'peso_prioridade': 5,
        });
  }

  // Atualizar Dados do Cliente (CRM)
  Future<void> updateDadosCliente(
    String cpf,
    Map<String, dynamic> dados,
  ) async {
    await _db.collection('users').doc(cpf).update(dados);
  }
  // --- AGENDAMENTOS (Via Cloud Functions) ---

  Future<List<String>> buscarHorariosDisponiveis(
    String data,
    String servico,
  ) async {
    try {
      final result = await _functions.httpsCallable('buscarHorarios').call({
        'tenantId': _tenantId,
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
        'tenantId': _tenantId,
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
            'banho': (data['vouchers_banho'] as num?)?.toInt() ?? 0,
            'tosa': (data['vouchers_tosa'] as num?)?.toInt() ?? 0,
            'creche': (data['vouchers_creche'] as num?)?.toInt() ?? 0,
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

  // --- HOTEL ---
  Future<Map<String, dynamic>> reservarHotel({
    required String petId,
    required String cpfUser,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    try {
      final result = await _functions.httpsCallable('reservarHotel').call({
        'tenantId': _tenantId,
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

  // Buscar dias sem vaga no hotel
  Future<List<DateTime>> buscarDiasLotadosHotel() async {
    try {
      final result = await _functions.httpsCallable('obterDiasLotados').call({
        'tenantId': _tenantId,
      });
      final List<dynamic> datasStrings = result.data['dias_lotados'] ?? [];

      // Converte strings '2023-10-25' para DateTime
      return datasStrings.map((s) => DateTime.parse(s)).toList();
    } catch (e) {
      print("Erro ao buscar lotação: $e");
      return []; // Se der erro, não bloqueia nada (melhor que travar)
    }
  }

  // --- CRECHE ---
  Future<Map<String, dynamic>> reservarCreche({
    required String petId,
    required String cpfUser,
    required List<DateTime> dates,
  }) async {
    try {
      final result = await _functions.httpsCallable('reservarCreche').call({
        'tenantId': _tenantId,
        'pet_id': petId,
        'cpf_user': cpfUser,
        'dates': dates.map((d) => d.toIso8601String()).toList(),
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print("Erro detalhado reservarCreche: $e");
      if (e is FirebaseFunctionsException) {
        throw Exception(e.message);
      }
      throw Exception("Erro ao reservar creche: $e");
    }
  }

  Future<List<DateTime>> buscarDiasLotadosCreche() async {
    try {
      final result = await _functions
          .httpsCallable('obterDiasLotadosCreche')
          .call({'tenantId': _tenantId});
      final List<dynamic> datasStrings = result.data['dias_lotados'] ?? [];
      return datasStrings.map((s) => DateTime.parse(s)).toList();
    } catch (e) {
      print("Erro ao buscar lotação creche: $e");
      return [];
    }
  }

  Future<double> getPrecoCreche() async {
    try {
      final result = await _functions.httpsCallable('obterPrecoCreche').call({
        'tenantId': _tenantId,
      });
      return (result.data['preco'] ?? 0).toDouble();
    } catch (e) {
      print("Erro ao buscar preço creche: $e");
      return 0.0;
    }
  }
}
