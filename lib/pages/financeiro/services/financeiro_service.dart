import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceiroService {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  Future<Map<String, double>> calcularTotais({
    required String uid,
    required String profissionalFiltro,
  }) async {
    final snapshot = await db
        .collection('tenants')
        .doc(uid)
        .collection('financeiro_cache')
        .get();

    double hoje = 0;
    double semana = 0;
    double mes = 0;

    final now = DateTime.now();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final valor = (data['valor'] ?? 0).toDouble();

      if (profissionalFiltro != 'todos' &&
          data['profissionalId'] != profissionalFiltro) {
        continue;
      }

      final ts = data['data'];

      if (ts is Timestamp) {
        final d = ts.toDate();

        final inicioHoje = DateTime(now.year, now.month, now.day);
        final fimHoje = inicioHoje.add(const Duration(days: 1));

        if (d.isAfter(inicioHoje.subtract(const Duration(seconds: 1))) &&
            d.isBefore(fimHoje)) {
          hoje += valor;
        }

        final inicioSemana =
            DateTime(now.year, now.month, now.day)
                .subtract(Duration(days: now.weekday - 1));

        if (d.isAfter(inicioSemana.subtract(const Duration(seconds: 1))) &&
            d.isBefore(now.add(const Duration(days: 1)))) {
          semana += valor;
        }

        final inicioMes = DateTime(now.year, now.month, 1);

        if (d.isAfter(inicioMes.subtract(const Duration(seconds: 1)))) {
          mes += valor;
        }
      }
    }

    return {
      'hoje': hoje,
      'semana': semana,
      'mes': mes,
    };
  }

  Future<void> fecharCaixa({
    required String uid,
    required double totalHoje,
    required String profissionalFiltro,
  }) async {
    await db
        .collection('tenants')
        .doc(uid)
        .collection('financeiro')
        .add({
      'data': Timestamp.now(),
      'totalHoje': totalHoje,
      'profissionalFiltro': profissionalFiltro,
      'createdAt': Timestamp.now(),
    });

    final cache = await db
        .collection('tenants')
        .doc(uid)
        .collection('financeiro_cache')
        .get();

    for (var doc in cache.docs) {
      await doc.reference.delete();
    }
  }
}