import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoWebPage extends StatefulWidget {
  const InfoWebPage({super.key});

  @override
  State<InfoWebPage> createState() => _InfoWebPageState();
}

class _InfoWebPageState extends State<InfoWebPage> {
  bool loading = true;

  Map<String, dynamic> horarios = {};

  String maps = '';

  String logoUrl = '';

  final dias = [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(user.uid)
          .collection('config')
          .doc('infoWebPage')
          .get();

      if (doc.exists) {
        final data = doc.data();

        if (data != null) {
          horarios = Map<String, dynamic>.from(
            data['horarios'] ?? {},
          );

          maps = data['maps'] ?? '';
          logoUrl = '';

          final empDoc = await FirebaseFirestore.instance
              .collection('tenants')
              .doc(user.uid)
              .collection('config')
              .doc('empresa')
              .get();

          if (empDoc.exists) {
            final ed = empDoc.data();
            logoUrl = ed?['fotoUrl'] ?? '';
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar infos: $e');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> abrirMapa() async {
    if (maps.isEmpty) return;

    final uri = Uri.parse(maps);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget infoHorario(
    String titulo,
    String valor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Informações'),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: logoUrl.isEmpty
                                ? const Icon(
                                    Icons.storefront,
                                    color: Colors.white54,
                                    size: 34,
                                  )
                                : Image.network(
                                    logoUrl,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Informações da Empresa',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: Colors.white.withOpacity(0.04),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Horários de Funcionamento',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...dias.map((dia) {
                          final item = horarios[dia];

                          if (item == null) {
                            return const SizedBox();
                          }

                          final bool ativo = item['ativo'] ?? false;
                          final bool fechado = item['fechado'] == true;

                          // 🔥 BLOQUEIO TOTAL QUANDO FECHADO
                          if (!ativo || fechado) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.red.withOpacity(0.08),
                                border: Border.all(color: Colors.red.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.close, color: Colors.redAccent, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      dia,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'Fechado',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: Colors.white.withOpacity(0.03),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        dia,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ativo
                                            ? Colors.green.withOpacity(0.15)
                                            : Colors.red.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Text(
                                        ativo ? 'Aberto' : 'Fechado',
                                        style: TextStyle(
                                          color: ativo
                                              ? Colors.greenAccent
                                              : Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: infoHorario(
                                        'Abertura',
                                        item['abertura'] ?? '--:--',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: infoHorario(
                                        'Fechamento',
                                        item['fechamento'] ?? '--:--',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: infoHorario(
                                        'Almoço início',
                                        item['almocoInicio'] ?? '--:--',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: infoHorario(
                                        'Almoço fim',
                                        item['almocoFim'] ?? '--:--',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: Colors.white.withOpacity(0.04),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Localização',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white.withOpacity(0.03),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Text(
                            maps.isEmpty
                                ? 'Nenhuma localização cadastrada'
                                : maps,
                            style: const TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed:
                                maps.isEmpty ? null : abrirMapa,
                            icon: const Icon(Icons.location_on),
                            label: const Text('Abrir no Google Maps'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}