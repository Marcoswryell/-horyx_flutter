import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'widgets/card_financeiro.dart';
import 'services/financeiro_service.dart';
import 'widgets/filtro_periodo.dart';
import 'widgets/profissional_filtro_button.dart';
import 'widgets/barra_grafico.dart';
import 'package:lottie/lottie.dart';



class FinanceiroPage extends StatefulWidget {
  const FinanceiroPage({super.key});

  @override
  State<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends State<FinanceiroPage> {
  final user = FirebaseAuth.instance.currentUser;
  final db = FirebaseFirestore.instance;

  double totalHoje = 0;
  double totalSemana = 0;
  double totalGeral = 0;

  DateTime hoje = DateTime.now();

  // --- Period and Professional Filter State ---
  String periodo = 'hoje'; // hoje | semana | mes
  String profissionalFiltro = 'todos';


  @override
  void initState() {
    super.initState();
    _calcularTotais();
  }
  final financeiroService = FinanceiroService();

  Future<void> _calcularTotais() async {
    if (user == null) return;

    final snapshot = await db
        .collection('tenants')
        .doc(user!.uid)
        .collection('financeiro_cache')
        .get();

    double hojeTemp = 0;
    double semanaTemp = 0;
    double mesTemp = 0;
    double geralTemp = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final valor = (data['valor'] ?? 0).toDouble();

      if (profissionalFiltro != 'todos' && data['profissionalId'] != profissionalFiltro) {
        continue;
      }

      final ts = data['data'];
      if (ts is Timestamp) {
        final d = ts.toDate();
        geralTemp += valor;

        final inicioHoje = DateTime(hoje.year, hoje.month, hoje.day);
        final fimHoje = inicioHoje.add(const Duration(days: 1));
        if (d.isAfter(inicioHoje.subtract(const Duration(seconds: 1))) && d.isBefore(fimHoje)) {
          hojeTemp += valor;
        }

        final inicioSemana = DateTime(hoje.year, hoje.month, hoje.day)
            .subtract(Duration(days: hoje.weekday - 1));
        if (d.isAfter(inicioSemana.subtract(const Duration(seconds: 1))) &&
            d.isBefore(hoje.add(const Duration(days: 1)))) {
          semanaTemp += valor;
        }

        final inicioMes = DateTime(hoje.year, hoje.month, 1);
        if (d.isAfter(inicioMes.subtract(const Duration(seconds: 1)))) {
          mesTemp += valor;
        }
      }
    }

    if (!mounted) return;

    setState(() {
      totalHoje = hojeTemp;
      totalSemana = semanaTemp;
      totalGeral = periodo == 'mes' ? mesTemp : (periodo == 'semana' ? semanaTemp : hojeTemp);
    });
  }

  

  void _fecharCaixa() async {
    if (user == null) return;

    await db
        .collection('tenants')
        .doc(user!.uid)
        .collection('financeiro')
        .add({
      'data': Timestamp.now(),
      'totalHoje': totalHoje,
      'profissionalFiltro': profissionalFiltro,
      'createdAt': Timestamp.now(),
    });

    final cache = await db
        .collection('tenants')
        .doc(user!.uid)
        .collection('financeiro_cache')
        .get();

    for (var doc in cache.docs) {
      await doc.reference.delete();
    }

    await _calcularTotais();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Caixa fechado")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Sem usuário")));
      
    }
    final maxGrafico = [
      totalHoje,
      totalSemana,
      totalGeral,
    ].reduce((a, b) => a > b ? a : b);
        

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _calcularTotais,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SafeArea(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 10, bottom: 20, left: 16, right: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [

                    // Lottie (left side)
                    Lottie.asset(
                      'assets/lottie/dashboard.json',
                      height: 120,
                      repeat: true,
                    ),

                    const SizedBox(width: 12),

                    // Info Card (right side)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Como usar o Financeiro",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "• Selecione o período para análise\n• Filtre por profissional\n• Acompanhe os gráficos em tempo real\n• Use o histórico para reabrir caixas",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // --- Period Filter UI ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                FiltroPeriodoButton(
                  label: 'Hoje',
                  value: 'hoje',
                  periodoAtual: periodo,
                  onTap: () {
                    setState(() {
                      periodo = 'hoje';
                    });
                    _calcularTotais();
                  },
                ),

                FiltroPeriodoButton(
                  label: 'Semana',
                  value: 'semana',
                  periodoAtual: periodo,
                  onTap: () {
                    setState(() {
                      periodo = 'semana';
                    });
                    _calcularTotais();
                  },
                ),

                FiltroPeriodoButton(
                  label: 'Mês',
                  value: 'mes',
                  periodoAtual: periodo,
                  onTap: () {
                    setState(() {
                      periodo = 'mes';
                    });
                    _calcularTotais();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 20),
            // --- Row of Cards ---
            Row(
              children: [
                
                FinanceiroCard(
                  titulo: "Hoje",
                  valor: totalHoje,
                  icon: Icons.today,
                  iconColor: Colors.blue,
                ),
                FinanceiroCard(
                    titulo: "Semana",
                    valor: totalSemana,
                    icon: Icons.calendar_view_week,
                    iconColor: const Color.fromARGB(255, 255, 0, 0),
                  ),
                  FinanceiroCard(
                    titulo: "Total",
                    valor: totalGeral,
                    icon: Icons.attach_money,
                    iconColor: Colors.green,
                  ),
              ],
            ),
            // --- Graph Bar ---
            Container(
              height: 120,
              margin: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GraficoBar(
                    value: totalHoje,
                    maxValue: maxGrafico,
                  ),
                  GraficoBar(
                    value: totalSemana,
                    maxValue: maxGrafico,
                  ),
                  GraficoBar(
                    value: totalGeral,
                    maxValue: maxGrafico,
                  ),
                ],
              ),
            ),
            // --- Professional Filter UI (centered) ---
            StreamBuilder<QuerySnapshot>(
              stream: db
                  .collection('tenants')
                  .doc(user!.uid)
                  .collection('profissionais')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();

                final docs = snapshot.data!.docs;

                return Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ProfissionalFiltroButton(
                          nome: 'Todos',
                          id: 'todos',
                          profissionalAtual: profissionalFiltro,
                          onTap: () {
                            setState(() {
                              profissionalFiltro = 'todos';
                            });
                            _calcularTotais();
                          },
                        ),
                        ...docs.map((d) {
                          final data = d.data() as Map<String, dynamic>;

                          return ProfissionalFiltroButton(
                            nome: data['nome'] ?? 'Prof',
                            id: d.id,
                            profissionalAtual: profissionalFiltro,
                            onTap: () {
                              setState(() {
                                profissionalFiltro = d.id;
                              });
                              _calcularTotais();
                            },
                          );
                        }).toList()
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              "Faturamento",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: db
                  .collection('tenants')
                  .doc(user!.uid)
                  .collection('financeiro_cache')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Text("Nenhum faturamento ainda");
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;

                    final nome = data['clienteNome'] ?? 'Cliente';
                    final valor = (data['valor'] ?? 0).toDouble();
                    final servico = data['servico'] ?? 'Serviço';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nome,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  servico,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "R\$ ${valor.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fecharCaixa,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text("Fechar Caixa"),
            ),
            const SizedBox(height: 20),
            const Text(
              "Histórico de Caixa",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: db
                  .collection('tenants')
                  .doc(user!.uid)
                  .collection('financeiro')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox();
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;

                    return ListTile(
                      title: Text("R\$ ${data['totalHoje']}"),
                      subtitle: Text(data['data'].toDate().toString()),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.green),
                            onPressed: () async {
                              final dataMap = doc.data() as Map<String, dynamic>;
                              final valor = (dataMap['totalHoje'] ?? 0).toDouble();

                              await db
                                  .collection('tenants')
                                  .doc(user!.uid)
                                  .collection('financeiro_cache')
                                  .add({
                                'valor': valor,
                                'clienteNome': 'Reabertura',
                                'servico': 'Caixa reaberto',
                                'data': Timestamp.now(),
                              });

                              await doc.reference.delete();
                              _calcularTotais();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await doc.reference.delete();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}