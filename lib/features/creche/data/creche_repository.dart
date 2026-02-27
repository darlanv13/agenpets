import 'package:agenpet/core/config/app_config.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

class CrecheRepository {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'southamerica-east1',
  );

  String get _tenantId => AppConfig.tenantId;

  // --- CRECHE ---
  Future<Map<String, dynamic>> reservarCreche({
    required String petId,
    required String cpfUser,
    required List<DateTime> dates,
    bool? taxiDog,
    String? endereco,
    String? modalidadeTaxi,
  }) async {
    try {
      final result = await _functions.httpsCallable('reservarCreche').call({
        'tenantId': _tenantId,
        'pet_id': petId,
        'cpf_user': cpfUser,
        'dates': dates.map((d) => d.toIso8601String()).toList(),
        'taxi_dog': taxiDog ?? false,
        'endereco_buscar': endereco,
        'modalidade_taxi': modalidadeTaxi,
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
