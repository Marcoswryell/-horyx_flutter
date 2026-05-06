import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WhatsAppConfigPage extends StatefulWidget {
  const WhatsAppConfigPage({super.key});

  @override
  State<WhatsAppConfigPage> createState() => _WhatsAppConfigPageState();
}

class _WhatsAppConfigPageState extends State<WhatsAppConfigPage> {
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _mensagemController = TextEditingController();

  bool _loading = true;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final doc = await FirebaseFirestore.instance
        .collection('tenants')
        .doc(uid)
        .collection('config')
        .doc('empresa')
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      _numeroController.text = data['whatsappNumero'] ?? '';
      _mensagemController.text = data['whatsappMensagem'] ?? '';
    }

    setState(() => _loading = false);
  }

  Future<void> _salvar() async {
    await FirebaseFirestore.instance
        .collection('tenants')
        .doc(uid)
        .collection('config')
        .doc('empresa')
        .set({
      'whatsappNumero': _numeroController.text.trim(),
      'whatsappMensagem': _mensagemController.text.trim(),
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configurações salvas com sucesso')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Configurações de Whatsapp',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: const Color(0xFFF7F7F7),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 10),

                  // LOGO
                  Center(
                    child: Image.asset(
                      'assets/horix2.png',
                      height: 170,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // CARD PRINCIPAL
                  Container(
                    padding: const EdgeInsets.all(16),
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

                        const Text(
                          "WhatsApp da Empresa",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),

                        TextField(
                          controller: _numeroController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF1F1F1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            hintText: "Ex: 71999999999",
                            prefixIcon: const Icon(Icons.phone),
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          "Mensagem Automática",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),

                        TextField(
                          controller: _mensagemController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF1F1F1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            hintText: "Use {cliente}, {servico}, {data}, {hora}",
                          ),
                        ),

                        const SizedBox(height: 30),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _salvar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Salvar configurações",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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