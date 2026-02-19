import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agenpet/config/app_config.dart';

class VetService {
  final _db = FirebaseFirestore.instance;

  // Busca fila de espera
  Stream<QuerySnapshot> getFilaEspera() {
    return _db
        .collection('tenants')
        .doc(AppConfig.tenantId)
        .collection('agendamentos')
        .where('servico', isEqualTo: 'veterinario')
        .orderBy('data_inicio', descending: true)
        .snapshots();
  }

  // Salva consulta direto no banco
  Future<void> salvarConsultaCompleta({
    required Map<String, dynamic> petData,
    required Map<String, dynamic> anamnese,
    required Map<String, dynamic> fisico,
    required Map<String, dynamic> diagnostico,
    required List<Map<String, dynamic>> receita,
    required List<Map<String, dynamic>> vacinas,
    required List<Map<String, dynamic>> itensCobranca,
  }) async {
    final batch = _db.batch();
    final tenantRef = _db.collection('tenants').doc(AppConfig.tenantId);

    // 1. Cria Consulta (Prontuário)
    final consultaRef = tenantRef.collection('consultas_vet').doc();
    batch.set(consultaRef, {
      'pet': petData,
      'anamnese': anamnese,
      'fisico': fisico,
      'diagnostico': diagnostico,
      'receita': receita,
      'vacinas': vacinas,
      'data': FieldValue.serverTimestamp(),
      'veterinario_uid': FirebaseAuth.instance.currentUser?.uid,
      'status': 'finalizada',
    });

    // 2. Atualiza status do agendamento se existir
    if (petData['agendamento_id'] != null) {
      final agendamentoRef = tenantRef.collection('agendamentos').doc(petData['agendamento_id']);
      batch.update(agendamentoRef, {
        'status': 'concluido',
        'enviado_pdv': itensCobranca.isNotEmpty,
      });
    }

    // 3. Cria Comanda no PDV (se tiver cobrança)
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
