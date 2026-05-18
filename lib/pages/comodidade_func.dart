

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ComodidadeFuncPage extends StatefulWidget {
  final String tenantId;
  const ComodidadeFuncPage({super.key, required this.tenantId});

  @override
  State<ComodidadeFuncPage> createState() => _ComodidadeFuncPageState();
}

class _ComodidadeFuncPageState extends State<ComodidadeFuncPage> {
  bool wifi = false;
  bool ar = false;
  bool estacionamento = false;
  bool tv = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection('tenants')
        .doc(widget.tenantId)
        .collection('config')
        .doc('comodidades')
        .get();
    final data = doc.data();
    if (data != null) {
      wifi = data['wifi'] ?? false;
      ar = data['arCondicionado'] ?? false;
      estacionamento = data['estacionamento'] ?? false;
      tv = data['tv'] ?? false;
    }
    setState(() {
      loading = false;
    });
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance
        .collection('tenants')
        .doc(widget.tenantId)
        .collection('config')
        .doc('comodidades')
        .set({
      'wifi': wifi,
      'arCondicionado': ar,
      'estacionamento': estacionamento,
      'tv': tv,
    }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comodidades atualizadas!')),
      );
    }
  }

  Widget _buildTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Comodidades'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Salvar',
              style: TextStyle(color: Colors.greenAccent),
            ),
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildTile(
                    title: 'Wi-Fi',
                    subtitle: 'Internet disponível para clientes',
                    icon: Icons.wifi,
                    value: wifi,
                    onChanged: (v) => setState(() => wifi = v),
                  ),
                  _buildTile(
                    title: 'Ar Condicionado',
                    subtitle: 'Ambiente climatizado',
                    icon: Icons.ac_unit,
                    value: ar,
                    onChanged: (v) => setState(() => ar = v),
                  ),
                  _buildTile(
                    title: 'Estacionamento',
                    subtitle: 'Vagas disponíveis',
                    icon: Icons.local_parking,
                    value: estacionamento,
                    onChanged: (v) => setState(() => estacionamento = v),
                  ),
                  _buildTile(
                    title: 'TV',
                    subtitle: 'Entretenimento para clientes',
                    icon: Icons.tv,
                    value: tv,
                    onChanged: (v) => setState(() => tv = v),
                  ),
                  const Divider(
                    color: Colors.white24,
                    height: 32,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _save,
                      child: const Text('Salvar alterações'),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}