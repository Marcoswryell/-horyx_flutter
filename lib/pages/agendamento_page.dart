import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/agendamento_model.dart';
import '../services/agendamento_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/painting.dart' show NetworkImage, WebHtmlElementStrategy;

class AgendamentoPage extends StatefulWidget {
  const AgendamentoPage({super.key});

  @override
  State<AgendamentoPage> createState() => _AgendamentoPageState();
}

class _AgendamentoPageState extends State<AgendamentoPage> {
  String? _horarioSelecionado;
  // final AgendamentoService _service = AgendamentoService();
  String? profissionalSelecionadoId;
  String? profissionalSelecionadoNome;
  String? profissionalSelecionadoFoto;
  final List<Map<String, dynamic>> servicosSelecionados = [];
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController whatsappController = TextEditingController();

  String get tenantId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<DocumentSnapshot>? getEmpresaStream() {
    if (tenantId.isEmpty) return null;

    return FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection('config')
        .doc('empresa')
        .snapshots();
  }

  // 1. Função para abrir o Calendário e o Relógio
  Future<void> _selecionarDataEHora(
    BuildContext context,
    String servicoNome,
  ) async {
    // Escolher a Data
    DateTime? dataSelecionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)), // Sugere amanhã
      firstDate: DateTime.now(), // Não deixa marcar no passado
      lastDate: DateTime.now().add(
        const Duration(days: 60),
      ), // Limite de 2 meses
      helpText: 'SELECIONE A DATA DO SERVIÇO',
    );

    if (dataSelecionada == null) return;

    // Escolher a Hora
    if (!mounted) return;
    TimeOfDay? horaSelecionada = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'ESCOLHA O HORÁRIO',
    );

    if (horaSelecionada == null) return;

    // Mesclar Data e Hora em um único DateTime
    final dataFinal = DateTime(
      dataSelecionada.year,
      dataSelecionada.month,
      dataSelecionada.day,
      horaSelecionada.hour,
      horaSelecionada.minute,
    );

    // Enviar para o Firebase
    _salvarAgendamento(
      servicoNome,
      dataFinal,
      nomeController.text,
      whatsappController.text,
    );
  }

  // 2. Função que grava no Firestore
  void _salvarAgendamento(
    String servicoNome,
    DateTime dataAgendada,
    String nome,
    String whatsapp,
  ) async {
    if (profissionalSelecionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um profissional antes de agendar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final novo = Agendamento(
      idCliente:
          'marcos_usuario_teste', // Depois usaremos o ID do Firebase Auth
      idServico: servicoNome,
      idProfissional: profissionalSelecionadoId!,
      dataHora: dataAgendada,
      status: 'pendente',
    );

    final int duracaoTotalMinutos = servicosSelecionados.fold<int>(
      0,
      (total, item) => total + ((item['duracao'] ?? 0) as int),
    );

    try {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('profissionais')
          .doc(profissionalSelecionadoId!)
          .collection('agendamentos')
          .add({
        'clienteId': nome,
        'whatsapp': whatsapp,
        'servico': novo.idServico,
        'valor': servicosSelecionados.isNotEmpty
            ? (servicosSelecionados.first['valor'] as num).toDouble()
            : 0.0,
        'profissionalId': novo.idProfissional,
        'dataHora': novo.dataHora,
        'status': novo.status,
        'minutos': novo.dataHora.hour * 60 + novo.dataHora.minute,
        'duracaoTotalMinutos': duracaoTotalMinutos,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🔥 Salvar/atualizar cliente (evita duplicado pelo telefone)
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('clientes')
          .doc(whatsapp)
          .set({
        'nome': nome,
        'telefone': whatsapp,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('financeiro_cache')
          .add({
        'valor': servicosSelecionados.isNotEmpty
            ? (servicosSelecionados.first['valor'] as num).toDouble()
            : 0.0,
        'clienteNome': nome,
        'servico': servicoNome,
        'data': FieldValue.serverTimestamp(),
      });
  @override
  void dispose() {
    nomeController.dispose();
    whatsappController.dispose();
    super.dispose();
  }


      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ $servicoNome agendado para o dia ${dataAgendada.day}/${dataAgendada.month} às ${dataAgendada.hour}:${dataAgendada.minute.toString().padLeft(2, '0')}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erro ao salvar agendamento.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Stream de horários disponíveis dinâmicos via Firebase
  Stream<List<String>> _getHorariosDisponiveis() {
    final db = FirebaseFirestore.instance;
    if (tenantId.isEmpty) {
      // tenantId vazio, continue
    }
    return db
        .collection('tenants')
        .doc(tenantId)
        .collection('config')
        .doc('funcionamento')
        .snapshots()
        .asyncMap((configSnap) async {
      final config = configSnap.data() as Map<String, dynamic>?;

      // ❌ Sem config = não tem base real de horários
      if (config == null) {
        final inicio = "08:00";
        final fim = "18:00";
        final intervaloMin = 15;
        final duracaoMin = 30;

        int toMin(String h) {
          final parts = h.split(':');
          return int.parse(parts[0]) * 60 + int.parse(parts[1]);
        }

        final inicioMin = toMin(inicio);
        final fimMin = toMin(fim);

        List<String> horarios = [];

        for (int m = inicioMin; m < fimMin; m += (duracaoMin + intervaloMin)) {
          if (m + duracaoMin > fimMin) break;

          final h = (m ~/ 60).toString().padLeft(2, '0');
          final min = (m % 60).toString().padLeft(2, '0');

          horarios.add("$h:$min");
        }

        return horarios;
      }

      final inicio = (config['inicio'] ?? '08:00').toString();
      final fim = (config['fim'] ?? '18:00').toString();
      final intervalo = config['intervalo'] ?? 15;

      // 🔥 Usa SEMPRE a duração padrão definida no admin
      final duracao = config['duracaoPadrao'] ?? 30;

      // 🔥 Garante que são inteiros (evita erro no loop)
      final intervaloMin = (intervalo is int) ? intervalo : (intervalo as num).toInt();
      final duracaoMin = (duracao is int) ? duracao : (duracao as num).toInt();

      int toMin(String h) {
        final parts = h.split(':');
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }

      final inicioMin = toMin(inicio);
      final fimMin = toMin(fim);

      List<String> horarios = [];

      // 🛑 Proteção contra loop inválido
      if ((duracaoMin + intervaloMin) <= 0) {
        return [];
      }

      // 🛑 Se inicio for maior que fim, corrige automaticamente
      if (inicioMin >= fimMin) {
        return [
          "08:00","09:00","10:00","11:00","12:00",
          "13:00","14:00","15:00","16:00","17:00"
        ];
      }

      for (int m = inicioMin; m < fimMin; m += (duracaoMin + intervaloMin)) {
        final fimSlot = m + duracaoMin;

        // não deixa passar do horário de funcionamento
        if (fimSlot > fimMin) break;

        final h = (m ~/ 60).toString().padLeft(2, '0');
        final min = (m % 60).toString().padLeft(2, '0');

        horarios.add("$h:$min");
      }

      // 🔥 Se por algum motivo não gerou nada, fallback
      if (horarios.isEmpty) {
        return [];
      }

      // 🔥 Agora remove horários já agendados (por dia atual por enquanto)
      if (profissionalSelecionadoId == null) return horarios;

      List<int> ocupadosMinutos = [];

      try {
        final agendamentos = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('profissionais')
            .doc(profissionalSelecionadoId!)
            .collection('agendamentos')
            .limit(50)
            .get();

        ocupadosMinutos = agendamentos.docs.map((doc) {
          final data = doc.data();
          if (data['minutos'] == null) return null;
          return data['minutos'] as int;
        }).whereType<int>().toList();

      } catch (e) {
        ocupadosMinutos = [];
      }

      // 🔥 DEBUG: se não existir nada salvo, libera todos
      if (ocupadosMinutos.isEmpty) {
        return horarios;
      }

      final filtrados = horarios.where((h) {
        final parts = h.split(':');
        final hMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        return !ocupadosMinutos.contains(hMin);
      }).toList();

      // 🔥 Se por algum motivo filtrou tudo, NÃO quebra a UI
      if (filtrados.isEmpty) {
        return horarios;
      }

      return filtrados;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Image.asset(
          'assets/horix2.png',
          height: 80,
          fit: BoxFit.contain,
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: getEmpresaStream(),
        builder: (context, snapshot) {
          if (tenantId.isEmpty) {
            return const Center(child: Text("Usuário não autenticado"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;

          final nome = data?['nome'] ?? 'Barbearia';
          final bannerUrl = data?['bannerUrl'] ?? '';
          final logoUrl = data?['fotoUrl'] ?? '';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 🔹 Header com banner dinâmico
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(25),
                        bottomRight: Radius.circular(25),
                      ),
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: bannerUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(bannerUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: bannerUrl.isEmpty ? Colors.grey[300] : null,
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: -45,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],  
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 46,
                            backgroundImage:
                                logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                            onBackgroundImageError: (_, __) {},
                            child: logoUrl.isEmpty ? const Icon(Icons.store) : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 80),

                // 🔹 Nome dinâmico
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        nome,
                        style: const TextStyle(
                          fontSize: 22,
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
                ),

                const SizedBox(height: 5),

                const Center(
                  child: Text(
                    "Estilo e precisão",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: const [
                            Icon(Icons.info, color: Colors.black),
                            SizedBox(height: 5),
                            Text("Info", style: TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) {
                            return StatefulBuilder(
                              builder: (context, setModalState) {
                                bool showInfo = false;
                                return FractionallySizedBox(
                                  heightFactor: 0.9,
                                  child: Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Center(
                                          child: Container(
                                            width: 40,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[300],
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 15),
                                        const Text(
                                          "Agenda dos profissionais",
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                setModalState(() {
                                                  showInfo = !showInfo;
                                                });
                                              },
                                              child: const Icon(Icons.info_outline, size: 20),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              "Como funciona",
                                              style: TextStyle(color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        if (showInfo)
                                          Container(
                                            margin: const EdgeInsets.only(top: 10, bottom: 10),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            child: const Text(
                                              "Selecione um profissional, depois escolha um horário disponível (verde). "
                                              "Horários em cinza já estão ocupados. Em seguida preencha seus dados e finalize o agendamento.",
                                              style: TextStyle(fontSize: 12, color: Colors.black87),
                                            ),
                                          ),
                                        const SizedBox(height: 10),
                                        // PROFISSIONAIS (somente seleção visual)
                                        SizedBox(
                                          height: 110,
                                          child: StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('tenants')
                                                .doc(tenantId)
                                                .collection('profissionais')
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              if (!snapshot.hasData) {
                                                return const Center(child: CircularProgressIndicator());
                                              }

                                              final docs = snapshot.data!.docs;

                                              return ListView.builder(
                                                scrollDirection: Axis.horizontal,
                                                itemCount: docs.length,
                                                itemBuilder: (context, index) {
                                                  final data = docs[index].data() as Map<String, dynamic>;
                                                  final nome = data['nome'] ?? '';
                                                  final foto = data['fotoUrl'] ?? '';
                                                  final id = docs[index].id;

                                                  final selected = profissionalSelecionadoId == id;

                                                  return GestureDetector(
                                                    onTap: () {
                                                      setModalState(() {
                                                        profissionalSelecionadoId = id;
                                                        profissionalSelecionadoNome = nome;
                                                        profissionalSelecionadoFoto = foto;
                                                      });
                                                    },
                                                    child: Container(
                                                      width: 95,
                                                      margin: const EdgeInsets.only(right: 12),
                                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: selected ? Colors.blue.withOpacity(0.08) : Colors.white,
                                                        borderRadius: BorderRadius.circular(16),
                                                        border: Border.all(
                                                          color: selected ? Colors.blue : Colors.grey.shade200,
                                                        ),
                                                      ),
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          CircleAvatar(
                                                            radius: 28,
                                                            backgroundImage:
                                                                foto.isNotEmpty ? NetworkImage(foto) : null,
                                                            child: foto.isEmpty ? const Icon(Icons.person) : null,
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Text(
                                                            nome,
                                                            textAlign: TextAlign.center,
                                                            style: const TextStyle(fontSize: 12),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          "Horários disponíveis",
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 10),
                                        Expanded(
                                          child: profissionalSelecionadoId == null
                                              ? const Center(child: Text("Selecione um profissional"))
                                              : StreamBuilder<List<String>>(
                                                  key: ValueKey(profissionalSelecionadoId),
                                                  stream: _getHorariosDisponiveis(),
                                                  builder: (context, snapshot) {
                                                    if (!snapshot.hasData) {
                                                      return const Center(child: CircularProgressIndicator());
                                                    }

                                                    final horarios = snapshot.data!;

                                                    return GridView.builder(
                                                      itemCount: horarios.length,
                                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                        crossAxisCount: 4,
                                                        mainAxisSpacing: 10,
                                                        crossAxisSpacing: 10,
                                                        childAspectRatio: 2.5,
                                                      ),
                                                      itemBuilder: (context, index) {
                                                        final horario = horarios[index];

                                                        return Container(
                                                          alignment: Alignment.center,
                                                          decoration: BoxDecoration(
                                                            color: Colors.grey[200],
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Text(
                                                            horario,
                                                            style: const TextStyle(fontSize: 12),
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: const [
                            Icon(Icons.calendar_month, color: Colors.black),
                            SizedBox(height: 5),
                            Text("Agenda", style: TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: const [
                            Icon(Icons.person, color: Colors.black),
                            SizedBox(height: 5),
                            Text("Profissionais", style: TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) {
                            return FractionallySizedBox(
                              heightFactor: 0.9,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                color: Colors.white,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Container(
                                        width: 40,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    Row(
                                      children: [
                                        const Text(
                                          "Marketplace",
                                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          nome,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.verified,
                                          color: Colors.blue,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('tenants')
                                            .doc(tenantId)
                                            .collection('marketplace')
                                            .doc('produtos')
                                            .collection('items')
                                            .orderBy('createdAt', descending: true)
                                            .snapshots(),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) {
                                            return const Center(child: CircularProgressIndicator());
                                          }

                                          final docs = snapshot.data!.docs;

                                          if (docs.isEmpty) {
                                            return const Center(
                                              child: Text("Nenhum produto cadastrado"),
                                            );
                                          }

                                          return ListView.builder(
                                            itemCount: docs.length,
                                            itemBuilder: (context, index) {
                                              final data = docs[index].data() as Map<String, dynamic>;

                                              final nome = data['nome'] ?? '';
                                              final descricao = data['descricao'] ?? '';
                                              final valor = data['valor'] ?? 0;
                                              final fotoUrl = data['fotoUrl'] ?? '';

                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 12),
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 60,
                                                      height: 60,
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(10),
                                                        image: fotoUrl.isNotEmpty
                                                            ? DecorationImage(
                                                                image: NetworkImage(fotoUrl),
                                                                fit: BoxFit.cover,
                                                              )
                                                            : null,
                                                        color: Colors.grey[300],
                                                      ),
                                                      child: fotoUrl.isEmpty
                                                          ? const Icon(Icons.image)
                                                          : null,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            nome,
                                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                                          ),
                                                          Text(
                                                            descricao,
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Text(
                                                      "R\$ $valor",
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.green,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: const [
                            Icon(Icons.storefront, color: Colors.black),
                            SizedBox(height: 5),
                            Text("Marketplace", style: TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Profissionais",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tenants')
                      .doc(tenantId)
                      .collection('profissionais')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['ativo'] == null || data['ativo'] == true;
                    }).toList();

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text("Nenhum profissional disponível"),
                      );
                    }

                    return SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;

                          final nome = data['nome'] ?? '';
                          final foto = data['fotoUrl'] ?? '';
                          final id = docs[index].id;
                          final selecionado = profissionalSelecionadoId == id;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                profissionalSelecionadoId = id;
                                profissionalSelecionadoNome = nome;
                                profissionalSelecionadoFoto = foto;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              width: 95,
                              margin: const EdgeInsets.only(left: 15),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selecionado ? Colors.blue.withOpacity(0.08) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: selecionado
                                        ? Colors.blue.withOpacity(0.25)
                                        : Colors.black.withOpacity(0.08),
                                    blurRadius: selecionado ? 12 : 6,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: selecionado ? Colors.blue : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      CircleAvatar(
                                        radius: selecionado ? 32 : 28,
                                        backgroundColor: Colors.grey[300],
                                        backgroundImage:
                                            foto.isNotEmpty ? NetworkImage(foto) : null,
                                        child: foto.isEmpty
                                            ? const Icon(Icons.person)
                                            : null,
                                      ),
                                      if (selecionado)
                                        Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(
                                            Icons.check,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    nome,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          selecionado ? FontWeight.bold : FontWeight.normal,
                                      color: selecionado ? Colors.blue : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 25),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Serviços",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tenants')
                      .doc(tenantId)
                      .collection('servicos')
                      .where('ativo', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;

                    // Ordena manualmente para evitar erro de index no Firestore
                    docs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;

                      final aOrdem = aData['ordem'] ?? 0;
                      final bOrdem = bData['ordem'] ?? 0;

                      return aOrdem.compareTo(bOrdem);
                    });

                    if (docs.isEmpty) {
                      return const Center(child: Text("Nenhum serviço disponível"));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;

                        final nome = data['nome'] ?? '';
                        final valor = data['valor'] ?? 0;
                        final duracao = data['duracaoMinutos'] ?? 0;

                        final isSelected = servicosSelecionados.any((s) => s['id'] == docs[index].id);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                servicosSelecionados.removeWhere((s) => s['id'] == docs[index].id);
                              } else {
                                servicosSelecionados.add({
                                  'id': docs[index].id,
                                  'nome': nome,
                                  'duracao': duracao,
                                  'valor': valor,
                                });
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.black : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.08),
                                  blurRadius: isSelected ? 12 : 6,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.grey.shade200,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? Colors.white : Colors.grey.shade200,
                                  ),
                                  child: Icon(
                                    isSelected ? Icons.check : Icons.content_cut,
                                    color: isSelected ? Colors.black : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nome,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isSelected ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${duracao} min",
                                        style: TextStyle(
                                          color: isSelected ? Colors.white70 : Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "R\$ $valor",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    AnimatedOpacity(
                                      duration: const Duration(milliseconds: 250),
                                      opacity: isSelected ? 1 : 0,
                                      child: const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.85,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: servicosSelecionados.isEmpty || profissionalSelecionadoId == null
                            ? null
                            : () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  builder: (_) {
                                    return FractionallySizedBox(
                                      heightFactor: 0.85,
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Center(
                                              child: Container(
                                                width: 40,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 15),
                                            const Text(
                                              "Escolha o horário",
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 10),

                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 18,
                                                  backgroundImage: (profissionalSelecionadoFoto != null &&
                                                          profissionalSelecionadoFoto!.isNotEmpty)
                                                      ? NetworkImage(profissionalSelecionadoFoto!)
                                                      : null,
                                                  child: (profissionalSelecionadoFoto == null ||
                                                          profissionalSelecionadoFoto!.isEmpty)
                                                      ? const Icon(Icons.person, size: 18)
                                                      : null,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  "Profissional: ${profissionalSelecionadoNome ?? ''}",
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),

                                            Text(
                                              "Serviços: ${servicosSelecionados.map((s) => s['nome']).join(', ')}",
                                              style: const TextStyle(color: Colors.grey),
                                            ),

                                            const SizedBox(height: 20),

                                            Expanded(
                                              child: StatefulBuilder(
                                                builder: (context, setModalState) {
                                                  return StreamBuilder<List<String>>(
                                                    key: ValueKey(profissionalSelecionadoId),
                                                    stream: _getHorariosDisponiveis(),
                                                    builder: (context, snapshot) {
                                                      print("StreamBuilder horários rebuild → profissional: $profissionalSelecionadoId");
                                                      if (!snapshot.hasData) {
                                                        return const Center(child: CircularProgressIndicator());
                                                      }

                                                      final horarios = snapshot.data!;

                                                      if (horarios.isEmpty) {
                                                        return const Center(child: Text("Sem horários disponíveis"));
                                                      }

                                                      return GridView.builder(
                                                        itemCount: horarios.length,
                                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                          crossAxisCount: 4,
                                                          mainAxisSpacing: 10,
                                                          crossAxisSpacing: 10,
                                                          childAspectRatio: 2.5,
                                                        ),
                                                        itemBuilder: (context, index) {
                                                          final horario = horarios[index];
                                                          final isSelected = horario == _horarioSelecionado;

                                                          return GestureDetector(
                                                            onTap: () {
                                                              setModalState(() {
                                                                _horarioSelecionado = horario;
                                                              });
                                                            },
                                                            child: AnimatedContainer(
                                                              duration: const Duration(milliseconds: 200),
                                                              alignment: Alignment.center,
                                                              decoration: BoxDecoration(
                                                                color: isSelected ? Colors.blue : Colors.grey[200],
                                                                borderRadius: BorderRadius.circular(20),
                                                              ),
                                                              child: Text(
                                                                horario,
                                                                style: TextStyle(
                                                                  color: isSelected ? Colors.white : Colors.black,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(height: 0),

                                            const Text(
                                              "Informações pessoais",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),

                                            const SizedBox(height: 4),
                                            const Divider(height: 8),

                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: Colors.grey.shade300),
                                              ),
                                              child: Column(
                                                children: [
                                                  TextField(
                                                    controller: nomeController,
                                                    decoration: InputDecoration(
                                                      labelText: "Seu nome",
                                                      prefixIcon: const Icon(Icons.person),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide.none,
                                                      ),
                                                    ),
                                                  ),

                                                  const SizedBox(height: 10),

                                                  TextField(
                                                    controller: whatsappController,
                                                    keyboardType: TextInputType.phone,
                                                    decoration: InputDecoration(
                                                      labelText: "WhatsApp",
                                                      prefixIcon: const Icon(Icons.phone),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide.none,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 25),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.black,
                                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                                ),
                                                onPressed: () {
                                                  if (_horarioSelecionado == null) return;
                                                  final partes = _horarioSelecionado!.split(':');
                                                  final now = DateTime.now();

                                                  final dataFinal = DateTime(
                                                    now.year,
                                                    now.month,
                                                    now.day,
                                                    int.parse(partes[0]),
                                                    int.parse(partes[1]),
                                                  );

                                                  _salvarAgendamento(
                                                    servicosSelecionados.map((s) => s['nome']).join(', '),
                                                    dataFinal,
                                                    nomeController.text,
                                                    whatsappController.text,
                                                  );

                                                  Navigator.pop(context);
                                                },
                                                child: const Text("Finalizar agendamento"),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                        child: const Text(
                          "Agendar",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // --- Syslogyc Footer ---
                const SizedBox(height: 30),
                Center(
                  child: Column(
                    children: [
                      Transform.translate(
                        offset: const Offset(0,40),
                        child: Image.asset(
                          'assets/SysLogyc_logo.png',
                          height: 130,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '© 2026 Syslogyc LTDA - Soluções inteligentes para transformar negócios',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Marcos Wryell - Founder & CEO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
