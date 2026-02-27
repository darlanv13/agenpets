import 'package:agenpet/core/config/app_config.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

class SchedulingRepository {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'southamerica-east1',
  );

  String get _tenantId => AppConfig.tenantId;

  // --- AGENDAMENTOS (Via Cloud Functions) ---

  Future<List<Map<String, dynamic>>> buscarHorariosDisponiveis(
    String data,
    String servico,
  ) async {
    try {
      final result = await _functions.httpsCallable('buscarHorarios').call({
        'tenantId': _tenantId,
        'dataConsulta': data,
        'servico': servico,
      });
      final List<dynamic> grade = result.data['grade'] ?? [];
      return grade.map((e) => Map<String, dynamic>.from(e)).toList();
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
    bool? taxiDog,
    String? endereco,
    String? modalidadeTaxi,
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
        'taxi_dog': taxiDog ?? false,
        'endereco_buscar': endereco,
        'modalidade_taxi': modalidadeTaxi,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception("Falha ao agendar: $e");
    }
  }
}
