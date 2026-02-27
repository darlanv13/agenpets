import 'package:agenpet/core/config/app_config.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

class HotelRepository {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'southamerica-east1',
  );

  String get _tenantId => AppConfig.tenantId;

  // --- HOTEL ---
  Future<Map<String, dynamic>> reservarHotel({
    required String petId,
    required String cpfUser,
    required DateTime checkIn,
    required DateTime checkOut,
    bool? taxiDog,
    String? endereco,
    String? modalidadeTaxi,
  }) async {
    try {
      final result = await _functions.httpsCallable('reservarHotel').call({
        'tenantId': _tenantId,
        'pet_id': petId,
        'cpf_user': cpfUser,
        'check_in': checkIn.toIso8601String(),
        'check_out': checkOut.toIso8601String(),
        'taxi_dog': taxiDog ?? false,
        'endereco_buscar': endereco,
        'modalidade_taxi': modalidadeTaxi,
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
}
