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

    // Identificadores obrigatórios
    final String tutorId = petData['tutor_id']; // This is the userId (CPF)
    final String petId = petData['id'];

    // --- 1. REFERÊNCIAS ---
    final tenantRef = _db.collection('tenants').doc(AppConfig.tenantId);

    // Referência dentro do Pet (Prontuário Unificado)
    // users/{cpf}/pets/{petId}/prontuario/{consultaId}
    final prontuarioRef = _db
        .collection('users')
        .doc(tutorId)
        .collection('pets')
        .doc(petId)
        .collection('prontuario')
        .doc();

    final consultaData = {
      'tenantId': AppConfig.tenantId,
      'pet': petData,
      'anamnese': anamnese,
      'fisico': fisico,
      'diagnostico': diagnostico,
      'receita': receita,
      'vacinas': vacinas, // Vacinas dentro do prontuário
      'data': FieldValue.serverTimestamp(),
      'veterinario_uid': FirebaseAuth.instance.currentUser?.uid,
      'tipo': 'consulta',
    };

    batch.set(prontuarioRef, consultaData);

    // --- 2. VACINAS (Subcoleção separada para facilitar busca) ---
    // users/{cpf}/pets/{petId}/vacinas/{vacinaId}
    if (vacinas.isNotEmpty) {
      final vacinasRef = _db
          .collection('users')
          .doc(tutorId)
          .collection('pets')
          .doc(petId)
          .collection('vacinas');

      for (var vac in vacinas) {
        final docVac = vacinasRef.doc();
        batch.set(docVac, {
          'tenantId': AppConfig.tenantId,
          'nome': vac['nome'],
          'lab': vac['lab'],
          'lote': vac['lote'],
          'revac_data': vac['revac_data'],
          'aplicacao_data': FieldValue.serverTimestamp(),
          'veterinario_uid': FirebaseAuth.instance.currentUser?.uid,
          'origem_prontuario': prontuarioRef.id,
        });
      }
    }

    // --- 3. Cópia para Tenant (Opcional, mas útil para relatórios da loja) ---
    // tenants/{tenantId}/consultas_vet/{consultaId}
    // Mantemos uma cópia ou referência para o admin da loja ver histórico
    final tenantConsultaRef = tenantRef.collection('consultas_vet').doc(prontuarioRef.id);
    batch.set(tenantConsultaRef, consultaData);

    // --- 4. Atualiza Agendamento ---
    if (petData['agendamento_id'] != null) {
      final agendamentoRef = tenantRef.collection('agendamentos').doc(petData['agendamento_id']);
      batch.update(agendamentoRef, {
        'status': 'concluido',
        'enviado_pdv': itensCobranca.isNotEmpty,
      });
    }

    // --- 5. Cria Comanda no PDV ---
    if (itensCobranca.isNotEmpty) {
      double total = itensCobranca.fold(
        0,
        (sum, item) => sum + (item['preco'] as num),
      );
      final comandaRef = tenantRef.collection('comandas').doc();
      batch.set(comandaRef, {
        'cliente_nome': petData['tutor_nome'],
        'origem_tipo': 'Veterinária',
        'origem_id': prontuarioRef.id,
        'status': 'aberta',
        'created_at': FieldValue.serverTimestamp(),
        'valor_total': total,
        'itens': itensCobranca,
      });
    }

    await batch.commit();
  }
}
