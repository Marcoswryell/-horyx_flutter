import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/agendamento_model.dart';

class AgendamentoService {
  // Referência da coleção no Firestore
  final CollectionReference _db = FirebaseFirestore.instance.collection(
    'agendamentos',
  );

  // 1. Criar novo agendamento (Usado no App do Cliente)
  Future<void> criarAgendamento(Agendamento agendamento) async {
    try {
      await _db.add(agendamento.toMap());
    } catch (e) {
      print("Erro ao agendar: $e");
      rethrow;
    }
  }

  // 2. Listar agendamentos em tempo real (Usado no Site Admin e App Cliente)
  Stream<List<Agendamento>> listarAgendamentos() {
    return _db.orderBy('dataHora', descending: false).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        return Agendamento.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }
}
