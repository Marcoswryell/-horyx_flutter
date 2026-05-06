import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class ConsultaPedPage extends StatefulWidget {
  const ConsultaPedPage({super.key});

  @override
  State<ConsultaPedPage> createState() => _ConsultaPedPageState();
}

class _ConsultaPedPageState extends State<ConsultaPedPage> {
  final TextEditingController telefoneController = TextEditingController();

  String telefoneBusca = "";
  Future<QuerySnapshot>? _futureBusca;

  DateTime? _getDate(Map<String, dynamic> data) {
    final raw = data['dataHora'] ?? data['dataTimestamp'];
    if (raw is Timestamp) return raw.toDate();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Meus Agendamentos"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFEAEAEA),
          ),
        ),
      ),
      body: Column(
        children: [
          // 🏢 HEADER (ESTABELECIMENTO)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tenants')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .collection('config')
                .doc('empresa')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data?.data() == null) {
                return const SizedBox();
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;

              final nome = data['nome'] ?? 'Estabelecimento';
              final bannerUrl = data['bannerUrl'] ?? '';
              final fotoUrl = data['fotoUrl'] ?? '';

              return Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          image: bannerUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(bannerUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                      ),

                      Positioned(
                        bottom: -35,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor: Colors.white,
                            backgroundImage: fotoUrl.isNotEmpty
                                ? NetworkImage(fotoUrl)
                                : null,
                            child: fotoUrl.isEmpty
                                ? const Icon(Icons.store)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 45),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        nome,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified,
                        color: Colors.blue,
                        size: 18,
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                ],
              );
            },
          ),
          // 🔍 Busca
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.88,
              child: TextField(
                controller: telefoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: "Digite seu WhatsApp",
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.black, width: 1.2),
                  ),
                ),
                onSubmitted: (value) {
                  setState(() {
                    telefoneBusca = value.trim();
                    _futureBusca = FirebaseFirestore.instance
                        .collectionGroup('agendamentos')
                        .where('telefone', isEqualTo: telefoneBusca)
                        .get();
                  });
                },
              ),
            ),
          ),

          // 📋 Lista
          Expanded(
            child: _futureBusca == null
                ? const Center(child: Text("Digite seu número para buscar"))
                : FutureBuilder<QuerySnapshot>(
                    future: _futureBusca,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            "Erro: ${snapshot.error}",
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text("Nenhum agendamento encontrado"),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      // ordenação segura
                      try {
                        docs.sort((a, b) {
                          final da = _getDate(a.data() as Map<String, dynamic>);
                          final db = _getDate(b.data() as Map<String, dynamic>);

                          if (da == null || db == null) return 0;

                          return db.compareTo(da);
                        });
                      } catch (e) {
                        // evita crash silencioso
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;

                          final servico = data['servico'] ?? '';
                          final profissional = data['profissionalId'] ?? '';
                          final status = data['status'] ?? 'pendente';

                          final dt = _getDate(data);
                          if (dt == null) {
                            return const SizedBox();
                          }
                          final agora = DateTime.now();

                          Color cardColor;

                          if (dt.isBefore(DateTime(agora.year, agora.month, agora.day))) {
                            cardColor = Colors.red.shade100;
                          } else if (dt.year == agora.year &&
                              dt.month == agora.month &&
                              dt.day == agora.day) {
                            cardColor = Colors.grey.shade200;
                          } else {
                            cardColor = Colors.green.shade100;
                          }

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                )
                              ],
                              border: Border.all(
                                color: Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Colors.grey.shade300,
                                      backgroundImage: data['clienteFoto'] != null && data['clienteFoto'].toString().isNotEmpty
                                          ? NetworkImage(data['clienteFoto'])
                                          : null,
                                      child: (data['clienteFoto'] == null || data['clienteFoto'].toString().isEmpty)
                                          ? const Icon(Icons.person, color: Colors.white)
                                          : null,
                                    ),

                                    const SizedBox(width: 10),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                data['clienteNome'] ?? data['nomeCliente'] ?? data['clienteId'] ?? data['telefone'] ?? 'Cliente não identificado',
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),

                                              const SizedBox(width: 6),

                                              if (data['verificado'] == true || data['verified'] == true)
                                                const Icon(
                                                  Icons.verified,
                                                  color: Colors.blue,
                                                  size: 18,
                                                ),
                                            ],
                                          ),

                                          const SizedBox(height: 2),

                                          const Text(
                                            "Agendamentos do cliente",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // 🔥 SERVIÇO
                                Text(
                                  "Serviço: $servico",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // ⏰ DATA E HORA + STATUS
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black12,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        "${dt.day}/${dt.month}/${dt.year} • ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}",
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // 💇 PROFISSIONAL
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 13, color: Colors.black),
                                    children: [
                                      const TextSpan(
                                        text: "Profissional: ",
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      TextSpan(
                                        text: "${data['profissionalNome'] ?? 'Profissional não identificado'}",
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 4),

                                // 💰 VALOR (opcional)
                                if (data['valor'] != null)
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 13, color: Colors.black),
                                      children: [
                                        const TextSpan(
                                          text: "Valor: ",
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: "R\$ ${data['valor']}",
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 10),

                                const SizedBox(height: 12),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: Image.asset(
                                      'assets/whatsapp.png',
                                      width: 18,
                                      height: 18,
                                    ),
                                    label: const Text("Falar com estabelecimento"),
                                    onPressed: () async {
                                      try {
                                        // pega tenantId do path
                                        final path = docs[index].reference.path.split('/');
                                        final tenantId = path.length > 1 ? path[1] : null;

                                        if (tenantId == null) return;

                                        final docEmpresa = await FirebaseFirestore.instance
                                            .collection('tenants')
                                            .doc(tenantId)
                                            .collection('config')
                                            .doc('empresa')
                                            .get();

                                        if (!docEmpresa.exists) return;

                                        final cfg = docEmpresa.data()!;

                                        final numero = (cfg['whatsappNumero'] ?? '').toString();

                                        if (numero.isEmpty) return;

                                        final cliente = data['clienteNome'] ??
                                            data['nomeCliente'] ??
                                            data['cliente'] ??
                                            data['clienteId'] ??
                                            data['telefone'] ??
                                            'Cliente';
                                        final servico = data['servico'] ?? '';
                                        final mensagemBase = cfg['whatsappMensagem'] ?? '';
                                        final nomeEmpresa = cfg['nome'] ?? 'Estabelecimento';

                                        String mensagemFinal;
                                        mensagemFinal =
                                            "Olá $nomeEmpresa, tudo bem?\n\n"
                                            "Gostaria de tratar sobre questões do meu agendamento.\n\n"
                                            "📋 Informações do agendamento:\n"
                                            "• Cliente: $cliente\n"
                                            "• Serviço: $servico\n"
                                            "• Data: ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}\n"
                                            "• Horário: ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}\n\n"
                                            "Fico no aguardo do seu retorno. Obrigado!";

                                        final telefoneLimpo = numero.replaceAll(RegExp(r'[^0-9]'), '');
                                        final mensagem = Uri.encodeComponent(mensagemFinal);

                                        final uri = Uri.parse("https://wa.me/55$telefoneLimpo?text=$mensagem");

                                        // abre link
                                        // ignore: deprecated_member_use
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      } catch (e) {
                                        print("Erro WhatsApp: $e");
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'concluido':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
