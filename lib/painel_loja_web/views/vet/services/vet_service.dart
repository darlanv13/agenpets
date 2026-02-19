import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenpet/config/app_config.dart';

class VetService {
  final _db = FirebaseFirestore.instance;

  // Busca fila de espera (ex: agendamentos do dia marcados como "Check-in")
  Stream<QuerySnapshot> getFilaEspera() {
    return _db
        .collection('tenants')
        .doc(AppConfig.tenantId)
        .collection('agendamentos')
        .where('servico_tipo', isEqualTo: 'consulta')
        .where('status', isEqualTo: 'aguardando')
        .where(
          'data',
          isEqualTo: DateTime.now().toIso8601String().split('T')[0],
        ) // Simplificado
        .snapshots();
  }

  // Salva consulta direto no banco (ou chama sua Cloud Function se preferir)
  Future<void> salvarConsultaCompleta({
    required Map<String, dynamic> petData,
    required Map<String, dynamic> anamnese,
    required Map<String, dynamic> fisico,
    required Map<String, dynamic> receita,
    required List<Map<String, dynamic>> itensCobranca,
  }) async {
    final batch = _db.batch();
    final tenantRef = _db.collection('tenants').doc(AppConfig.tenantId);

    // 1. Cria Consulta
    final consultaRef = tenantRef.collection('consultas').doc();
    batch.set(consultaRef, {
      'pet': petData,
      'anamnese': anamnese,
      'fisico': fisico,
      'receita': receita,
      'data': FieldValue.serverTimestamp(),
      'veterinario_nome': 'Dr. Logado', // Pagar do Auth
    });

    // 2. Cria Comanda no PDV (se tiver cobrança)
    if (itensCobranca.isNotEmpty) {
      double total = itensCobranca.fold(
        0,
        (sum, item) => sum + (item['preco'] as num),
      );
      final comandaRef = tenantRef.collection('comandas').doc();
      batch.set(comandaRef, {
        'cliente_nome': petData['tutor_nome'],
        'origem_tipo': 'Veterinária',
        'origem_id': consultaRef.id,
        'status': 'aberta',
        'created_at': FieldValue.serverTimestamp(),
        'valor_total': total,
        'itens': itensCobranca,
      });
    }

    await batch.commit();
  }
}
