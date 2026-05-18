import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class WebInfoGeralPage extends StatefulWidget {
  const WebInfoGeralPage({super.key});

  @override
  State<WebInfoGeralPage> createState() => _WebInfoGeralPageState();
}

class _WebInfoGeralPageState extends State<WebInfoGeralPage> {
  final List<String> dias = [
    "Segunda",
    "Terça",
    "Quarta",
    "Quinta",
    "Sexta",
    "Sábado",
    "Domingo",
  ];

  final Map<String, bool> ativo = {};
  final Map<String, TimeOfDay> abertura = {};
  final Map<String, TimeOfDay> fechamento = {};
  final Map<String, TimeOfDay> almocoInicio = {};
  final Map<String, TimeOfDay> almocoFim = {};

  final TextEditingController mapsController = TextEditingController();
  bool loading = false;
  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _loadConfigs() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(user.uid)
          .collection('config')
          .doc('infoWebPage')
          .get();

      if (!doc.exists) return;

      final data = doc.data();

      if (data == null) return;

      final horarios = data['horarios'] as Map<String, dynamic>?;

      if (horarios != null) {
        for (var dia in dias) {
          final diaData = horarios[dia];

          if (diaData != null) {
            ativo[dia] = diaData['ativo'] ?? true;

            abertura[dia] = _parseTime(
              diaData['abertura'] ?? '08:00',
            );

            fechamento[dia] = _parseTime(
              diaData['fechamento'] ?? '18:00',
            );

            almocoInicio[dia] = _parseTime(
              diaData['almocoInicio'] ?? '12:00',
            );

            almocoFim[dia] = _parseTime(
              diaData['almocoFim'] ?? '13:00',
            );
          }
        }
      }

      mapsController.text = data['maps'] ?? '';

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Erro ao carregar configs: $e');
    }
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');

    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  Future<void> _saveConfigs() async {
    try {
      setState(() {
        loading = true;
      });

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final Map<String, dynamic> horarios = {};

      for (var dia in dias) {
        horarios[dia] = {
          'ativo': ativo[dia],
          'abertura': _formatTime(abertura[dia]!),
          'fechamento': _formatTime(fechamento[dia]!),
          'almocoInicio': _formatTime(almocoInicio[dia]!),
          'almocoFim': _formatTime(almocoFim[dia]!),
        };
      }

      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(user.uid)
          .collection('config')
          .doc('infoWebPage')
          .set({
        'horarios': horarios,
        'maps': mapsController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações salvas com sucesso'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao salvar configs: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar configurações'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    for (var d in dias) {
      ativo[d] = true;
      abertura[d] = const TimeOfDay(hour: 8, minute: 0);
      fechamento[d] = const TimeOfDay(hour: 18, minute: 0);
      almocoInicio[d] = const TimeOfDay(hour: 12, minute: 0);
      almocoFim[d] = const TimeOfDay(hour: 13, minute: 0);
    }
    _loadConfigs();
  }

  Future<void> _pickTime(String dia, String tipo) async {
    final atual = switch (tipo) {
      "abertura" => abertura[dia]!,
      "fechamento" => fechamento[dia]!,
      "almocoInicio" => almocoInicio[dia]!,
      _ => almocoFim[dia]!,
    };

    final picked = await showTimePicker(
      context: context,
      initialTime: atual,
    );

    if (picked != null) {
      setState(() {
        if (tipo == "abertura") abertura[dia] = picked;
        if (tipo == "fechamento") fechamento[dia] = picked;
        if (tipo == "almocoInicio") almocoInicio[dia] = picked;
        if (tipo == "almocoFim") almocoFim[dia] = picked;
      });
    }
  }

  Future<void> _openMaps() async {
    final url = mapsController.text.trim();
    if (url.isEmpty) return;

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text("Configuração Geral"),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Horários por dia",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            ...dias.map((dia) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dia,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: ativo[dia]!,
                          onChanged: (v) {
                            setState(() {
                              ativo[dia] = v;
                            });
                          },
                        ),
                      ],
                    ),

                    if (ativo[dia]!) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Abertura"),
                          TextButton(
                            onPressed: () => _pickTime(dia, "abertura"),
                            child: Text(abertura[dia]!.format(context)),
                          ),
                        ],
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Fechamento"),
                          TextButton(
                            onPressed: () => _pickTime(dia, "fechamento"),
                            child: Text(fechamento[dia]!.format(context)),
                          ),
                        ],
                      ),

                      const Divider(),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Almoço Início"),
                          TextButton(
                            onPressed: () => _pickTime(dia, "almocoInicio"),
                            child: Text(almocoInicio[dia]!.format(context)),
                          ),
                        ],
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Almoço Fim"),
                          TextButton(
                            onPressed: () => _pickTime(dia, "almocoFim"),
                            child: Text(almocoFim[dia]!.format(context)),
                          ),
                        ],
                      ),
                    ]
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Localização",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: mapsController,
                    decoration: const InputDecoration(
                      labelText: "Link do Google Maps",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text("Preview do mapa (link ativo necessário)"),
                    ),
                  ),

                  const SizedBox(height: 10),

                  ElevatedButton(
                    onPressed: _openMaps,
                    child: const Text("Abrir no Google Maps"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: loading ? null : _saveConfigs,
                child: loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Salvar Configurações"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
