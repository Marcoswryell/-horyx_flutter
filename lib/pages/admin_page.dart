import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:horyx_fluter/pages/whatsapp_config_page.dart';

import 'package:url_launcher/url_launcher.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  Future<void> _carregarConfiguracoes() async {
    final uid = user?.uid;
    if (uid == null) return;

    final doc = await db
        .collection('tenants')
        .doc(uid)
        .collection('config')
        .doc('funcionamento')
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;

    final inicio = data['inicio'] ?? '08:00';
    final fim = data['fim'] ?? '18:00';

    final inicioParts = inicio.split(':');
    final fimParts = fim.split(':');

    setState(() {
      inicioExpediente = TimeOfDay(
        hour: int.parse(inicioParts[0]),
        minute: int.parse(inicioParts[1]),
      );

      fimExpediente = TimeOfDay(
        hour: int.parse(fimParts[0]),
        minute: int.parse(fimParts[1]),
      );

      intervaloMinutos = data['intervalo'] ?? 15;
      duracaoPadraoMinutos = data['duracaoPadrao'] ?? 30;
    });
  }

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
  }
  final user = FirebaseAuth.instance.currentUser;
  final db = FirebaseFirestore.instance;
  DateTime dataSelecionada = DateTime.now();
  String? profissionalSelecionadoId;

  // --- Horário de funcionamento e intervalo ---
  TimeOfDay inicioExpediente = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay fimExpediente = const TimeOfDay(hour: 18, minute: 0);
  int intervaloMinutos = 15;
  int duracaoPadraoMinutos = 30;

  int _selectedIndex = 0;
  bool _isDarkMode = false;
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _abrirCadastroProfissional() {
    final nomeController = TextEditingController();
    final picker = ImagePicker();
    XFile? fotoFile;

    Future<String?> uploadFotoProfissional(XFile file, String path) async {
      try {
        final ref = FirebaseStorage.instance.ref().child(path);

        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          await ref.putData(bytes);
        } else {
          await ref.putFile(File(file.path));
        }

        return await ref.getDownloadURL();
      } catch (e) {
        print("Erro upload profissional: $e");
        return null;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Cadastrar Profissional"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: "Nome"),
                    ),
                    const SizedBox(height: 10),

                    GestureDetector(
                      onTap: () async {
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setState(() {
                            fotoFile = picked;
                          });
                        }
                      },
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: fotoFile == null
                              ? const Text("Selecionar foto")
                              : const Text("Foto selecionada"),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Divider(),
                    const SizedBox(height: 10),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Profissionais cadastrados",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      height: 200,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: db
                            .collection('tenants')
                            .doc(user!.uid)
                            .collection('profissionais')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final docs = snapshot.data!.docs;

                          if (docs.isEmpty) {
                            return const Center(child: Text("Nenhum profissional"));
                          }

                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: docs.length,
                            itemBuilder: (context, i) {
                              final data = docs[i].data() as Map<String, dynamic>;
                              final nome = data['nome'] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () async {
                                            final picked = await picker.pickImage(source: ImageSource.gallery);
                                            if (picked != null) {
                                              final url = await uploadFotoProfissional(
                                                picked,
                                                "tenants/${user!.uid}/profissionais/${docs[i].id}.jpg",
                                              );

                                              if (url != null) {
                                                await db
                                                    .collection('tenants')
                                                    .doc(user!.uid)
                                                    .collection('profissionais')
                                                    .doc(docs[i].id)
                                                    .update({'fotoUrl': url});

                                                setState(() {});
                                              }
                                            }
                                          },
                                          child: CircleAvatar(
                                            radius: 20,
                                            backgroundImage: (data['fotoUrl'] != null && data['fotoUrl'] != '')
                                                ? NetworkImage(data['fotoUrl'])
                                                : null,
                                            backgroundColor: Colors.black,
                                            child: (data['fotoUrl'] == null || data['fotoUrl'] == '')
                                                ? const Icon(Icons.person, color: Colors.white, size: 18)
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(nome),
                                      ],
                                    ),

                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () {
                                            final editController = TextEditingController(text: nome);
                                            XFile? editFotoFile;
                                            showDialog(
                                              context: context,
                                              builder: (_) {
                                                return AlertDialog(
                                                  title: const Text("Editar"),
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      GestureDetector(
                                                        onTap: () async {
                                                          final picked = await picker.pickImage(source: ImageSource.gallery);
                                                          if (picked != null) {
                                                            editFotoFile = picked;
                                                          }
                                                        },
                                                        child: Container(
                                                          height: 70,
                                                          margin: const EdgeInsets.only(bottom: 10),
                                                          decoration: BoxDecoration(
                                                            border: Border.all(color: Colors.grey),
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                          child: const Center(child: Text("Alterar foto")),
                                                        ),
                                                      ),
                                                      TextField(
                                                        controller: editController,
                                                        decoration: const InputDecoration(labelText: "Nome"),
                                                      ),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text("Cancelar"),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () async {
                                                        String? newFotoUrl;

                                                        if (editFotoFile != null) {
                                                          final url = await uploadFotoProfissional(
                                                            editFotoFile!,
                                                            "tenants/${user!.uid}/profissionais/${docs[i].id}.jpg",
                                                          );
                                                          newFotoUrl = url;
                                                        }

                                                        await db
                                                            .collection('tenants')
                                                            .doc(user!.uid)
                                                            .collection('profissionais')
                                                            .doc(docs[i].id)
                                                            .update({
                                                          'nome': editController.text,
                                                          if (newFotoUrl != null) 'fotoUrl': newFotoUrl,
                                                        });

                                                        Navigator.pop(context);
                                                      },
                                                      child: const Text("Salvar"),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () async {
                                            await db
                                                .collection('tenants')
                                                .doc(user!.uid)
                                                .collection('profissionais')
                                                .doc(docs[i].id)
                                                .delete();
                                          },
                                        ),
                                      ],
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final uid = user?.uid;
                    if (uid == null) return;

                    String fotoUrl = '';

                    if (fotoFile != null) {
                      final url = await uploadFotoProfissional(
                        fotoFile!,
                        "tenants/$uid/profissionais/${DateTime.now().millisecondsSinceEpoch}.jpg",
                      );
                      fotoUrl = url ?? '';
                    }

                    await db
                        .collection('tenants')
                        .doc(uid)
                        .collection('profissionais')
                        .add({
                      'nome': nomeController.text,
                      'fotoUrl': fotoUrl,
                      'createdAt': Timestamp.now(),
                    });

                    Navigator.pop(context);
                  },
                  child: const Text("Salvar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _abrirConfiguracaoFuncionamento() {
    final inicioController = TextEditingController(text: inicioExpediente.format(context));
    final fimController = TextEditingController(text: fimExpediente.format(context));
    final intervaloController = TextEditingController(text: intervaloMinutos.toString());
    final duracaoController = TextEditingController(text: duracaoPadraoMinutos.toString());

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Horário de funcionamento"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: inicioController,
                readOnly: true,
                decoration: const InputDecoration(labelText: "Início"),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: inicioExpediente,
                  );
                  if (picked != null) {
                    inicioExpediente = picked;
                    inicioController.text = picked.format(context);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fimController,
                readOnly: true,
                decoration: const InputDecoration(labelText: "Fim"),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: fimExpediente,
                  );
                  if (picked != null) {
                    fimExpediente = picked;
                    fimController.text = picked.format(context);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: intervaloController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Intervalo (min)"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: duracaoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Duração padrão do atendimento (min)"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                final uid = user?.uid;
                if (uid == null) return;

                setState(() {
                  intervaloMinutos = int.tryParse(intervaloController.text) ?? 15;
                  duracaoPadraoMinutos = int.tryParse(duracaoController.text) ?? 30;
                });

                await db
                    .collection('tenants')
                    .doc(uid)
                    .collection('config')
                    .doc('funcionamento')
                    .set({
                  'inicio': "${inicioExpediente.hour}:${inicioExpediente.minute}",
                  'fim': "${fimExpediente.hour}:${fimExpediente.minute}",
                  'intervalo': intervaloMinutos,
                  'duracaoPadrao': duracaoPadraoMinutos,
                  'updatedAt': Timestamp.now(),
                });

                setState(() {});
                Navigator.pop(context);
              },
              child: const Text("Salvar"),
            ),
          ],
        );
      },
    );
  }

  void _abrirInfoPage() {
    // FIX: remove função aninhada inválida
    final nomeEmpresaController = TextEditingController();
    final fotoUrlController = TextEditingController();
    final bannerUrlController = TextEditingController();

    XFile? logoFile;
    XFile? bannerFile;
    final picker = ImagePicker();

    Future<String?> uploadImagem(XFile file, String path) async {
      try {
        final ref = FirebaseStorage.instance.ref().child(path);
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          await ref.putData(bytes);
        } else {
          await ref.putFile(File(file.path));
        }
        return await ref.getDownloadURL();
      } catch (e) {
        print("Erro upload: $e");
        return null;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.store, color: Colors.black),
                          SizedBox(width: 8),
                          Text(
                            "Configuração da Barbearia",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nomeEmpresaController,
                        decoration: InputDecoration(
                          labelText: "Nome da empresa",
                          prefixIcon: const Icon(Icons.badge),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          final picked = await picker.pickImage(source: ImageSource.gallery);
                          if (picked != null) {
                            setState(() {
                              logoFile = picked;
                            });
                          }
                        },
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(child: Text("Selecionar Logo")),
                        ),
                      ),
                      if (logoFile != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Image.network(logoFile!.path, height: 80),
                        ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          final picked = await picker.pickImage(source: ImageSource.gallery);
                          if (picked != null) {
                            setState(() {
                              bannerFile = picked;
                            });
                          }
                        },
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(child: Text("Selecionar Banner")),
                        ),
                      ),
                      if (bannerFile != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Image.network(bannerFile!.path, height: 100),
                        ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancelar"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                final uid = user?.uid;
                                if (uid == null) return;

                                String? logoUrl;
                                String? bannerUrl;

                                if (logoFile != null) {
                                  logoUrl = await uploadImagem(
                                    logoFile!,
                                    "tenants/$uid/logo.jpg",
                                  );
                                }
                                if (bannerFile != null) {
                                  bannerUrl = await uploadImagem(
                                    bannerFile!,
                                    "tenants/$uid/banner.jpg",
                                  );
                                }

                                await db
                                    .collection('tenants')
                                    .doc(uid)
                                    .collection('config')
                                    .doc('empresa')
                                    .set({
                                  'nome': nomeEmpresaController.text,
                                  'fotoUrl': logoUrl ?? '',
                                  'bannerUrl': bannerUrl ?? '',
                                  'updatedAt': Timestamp.now(),
                                });

                                Navigator.pop(context);
                              },
                              child: const Text("Salvar"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : Colors.white,
      // --- MENU LATERAL (DRAWER) ---
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.black),
              currentAccountPicture: StreamBuilder<DocumentSnapshot>(
                stream: db
                    .collection('tenants')
                    .doc(user!.uid)
                    .collection('config')
                    .doc('empresa')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white),
                    );
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  final fotoUrl = data?['fotoUrl'] ?? '';

                  if (fotoUrl.isEmpty) {
                    return const CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white),
                    );
                  }

                  return CircleAvatar(
                    backgroundImage: NetworkImage(fotoUrl),
                  );
                },
              ),
              accountName: Text(
                user?.email ?? 'Usuário',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: const Text(
                "Seu negócio",
                style: TextStyle(color: Colors.white70),
              ),
            ),
            _itemMenu(Icons.calendar_today, 'Agenda', selecionado: true),
            _itemMenu(Icons.attach_money, 'Financeiro', onTapCustom: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FinanceiroPage()),
              );
            }),
            _itemMenu(Icons.people_outline, 'Clientes', onTapCustom: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientesPage()),
              );
            }),
            _itemMenu(Icons.work_outline, 'Profissionais', onTapCustom: _abrirCadastroProfissional),
            _itemMenu(Icons.content_cut, 'Serviços', onTapCustom: _abrirModalServicos),
            _itemMenu(Icons.storefront, 'Marketplace', onTapCustom: _abrirMarketplace),
            _itemMenu(Icons.language, 'Agendamento Online'),
            Divider(),
            _itemMenu(Icons.public, 'Webpage Info', onTapCustom: _abrirInfoPage),
            _itemMenu(Icons.message_outlined, 'Suporte'),
            Divider(),
            _itemMenu(Icons.settings_outlined, 'Configurações', onTapCustom: _abrirMenuConfiguracoes),
            const ListTile(
              leading: Icon(Icons.logout),
              title: Text('Sair'),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _isDarkMode ? Colors.black : Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Container(
          decoration: const BoxDecoration(),
          child: Image.asset(
            'assets/horix2.png',
            height: 80,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              setState(() {
                _isDarkMode = !_isDarkMode;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _abrirMenuConfiguracoes,
          ),
        ],
      ),
      body: _selectedIndex == 0
          ? Column(
              children: [
                _seletorData(),
                _listaProfissionais(),
                const Divider(height: 1),
                Expanded(child: _gradeHorarios()),
              ],
            )
          : _selectedIndex == 1
              ? const FinanceiroPage()
              : _perfilPage(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          elevation: 0,
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Agenda',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.attach_money),
              label: 'Financeiro',
            ),
            BottomNavigationBarItem(
              icon: StreamBuilder<DocumentSnapshot>(
                stream: db
                    .collection('tenants')
                    .doc(user!.uid)
                    .collection('config')
                    .doc('empresa')
                    .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final fotoUrl = data?['fotoUrl'] ?? '';

                  return CircleAvatar(
                    radius: 12,
                    backgroundImage:
                        fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
                    child: fotoUrl.isEmpty
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  );
                },
              ),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _perfilPage() {
    final uid = user?.uid;

    if (uid == null) {
      return const Center(child: Text("Sem usuário"));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: db
          .collection('tenants')
          .doc(uid)
          .collection('config')
          .doc('empresa')
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final fotoUrl = data?['fotoUrl'] ?? '';

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: fotoUrl.isNotEmpty
                    ? NetworkImage(fotoUrl)
                    : null,
                child: fotoUrl.isEmpty
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
              const SizedBox(height: 15),
              Text(
                user?.email ?? "Perfil",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget para os itens do Menu Lateral (simplified version)
  Widget _itemMenu(
    IconData icone,
    String titulo, {
    bool selecionado = false,
    VoidCallback? onTapCustom,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(
        icone,
        size: 26,
        color: selecionado ? Colors.black : Colors.black87,
      ),
      title: Text(
        titulo,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selecionado ? FontWeight.w600 : FontWeight.w500,
          color: selecionado ? Colors.black : Colors.black87,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: Colors.grey,
      ),
      onTap: onTapCustom ?? () {},
    );
  }

  Widget _seletorData() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                dataSelecionada = dataSelecionada.subtract(const Duration(days: 1));
              });
            },
          ),
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        child: TableCalendar(
                          firstDay: DateTime(2020),
                          lastDay: DateTime(2100),
                          focusedDay: dataSelecionada,
                          calendarFormat: CalendarFormat.month,
                          availableGestures: AvailableGestures.horizontalSwipe,
                          selectedDayPredicate: (day) =>
                              isSameDay(day, dataSelecionada),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              dataSelecionada = selectedDay;
                            });
                            Navigator.pop(context);
                          },
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),
                          calendarStyle: const CalendarStyle(
                            outsideDaysVisible: false,
                            todayDecoration: BoxDecoration(
                              color: Colors.black26,
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, size: 18),
                  const SizedBox(width: 8),
                  Text(DateFormat('EEE, dd/MM/yyyy').format(dataSelecionada)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                dataSelecionada = dataSelecionada.add(const Duration(days: 1));
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _listaProfissionais() {
    final uid = user?.uid;

    if (uid == null) {
      return const SizedBox();
    }

    return SizedBox(
      height: 90,
      child: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection('tenants')
            .doc(uid)
            .collection('profissionais')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhum profissional cadastrado"));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final nome = data['nome'] ?? 'Sem nome';

              return GestureDetector(
                onTap: () {
                  setState(() {
                    profissionalSelecionadoId = docs[i].id;
                  });
                },
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  scale: profissionalSelecionadoId == docs[i].id ? 1.08 : 1.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundImage: (data['fotoUrl'] != null && data['fotoUrl'] != '')
                                  ? NetworkImage(data['fotoUrl'])
                                  : null,
                              backgroundColor: profissionalSelecionadoId == docs[i].id
                                  ? Colors.blue
                                  : Colors.black,
                              child: (data['fotoUrl'] == null || data['fotoUrl'] == '')
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : null,
                            ),
                            if (profissionalSelecionadoId == docs[i].id)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: profissionalSelecionadoId == docs[i].id
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: profissionalSelecionadoId == docs[i].id
                                ? Colors.blue
                                : Colors.black,
                          ),
                          child: Text(nome),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _gradeHorarios() {
    final uid = user?.uid;

    if (uid == null || profissionalSelecionadoId == null) {
      return const Center(
        child: Text("Selecione um profissional"),
      );
    }

    // Adiciona cálculo do início e fim do dia antes do StreamBuilder
    // final inicioDoDia = DateTime(dataSelecionada.year, dataSelecionada.month, dataSelecionada.day);
    // final fimDoDia = inicioDoDia.add(const Duration(days: 1));

    final inicioMin = inicioExpediente.hour * 60 + inicioExpediente.minute;
    final fimMin = fimExpediente.hour * 60 + fimExpediente.minute;

    if (fimMin <= inicioMin) {
      return const Center(
        child: Text("Horário de funcionamento inválido"),
      );
    }

    // duração padrão de atendimento (ex: 30 min)
    final int duracaoPadrao = duracaoPadraoMinutos;

    // intervalo agora é um GAP entre atendimentos
    // final totalSlots = ((fimMin - inicioMin) ~/ (duracaoPadrao + intervaloMinutos));

    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('tenants')
          .doc(uid)
          .collection('profissionais')
          .doc(profissionalSelecionadoId)
          .collection('agendamentos')
          .snapshots(),
      builder: (context, snapshot) {
        final todosAgendamentos = snapshot.data?.docs ?? [];
        final agendamentos = todosAgendamentos.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // prioridade: timestamp
          final ts = data['dataTimestamp'];

          if (ts is Timestamp) {
            final d = ts.toDate();
            return d.year == dataSelecionada.year &&
                d.month == dataSelecionada.month &&
                d.day == dataSelecionada.day;
          }

          // fallback: string yyyy-MM-dd
          final dataStr = data['data'];
          if (dataStr is String && dataStr.isNotEmpty) {
            final parts = dataStr.split('-');
            if (parts.length == 3) {
              final y = int.tryParse(parts[0]);
              final m = int.tryParse(parts[1]);
              final d = int.tryParse(parts[2]);

              return y == dataSelecionada.year &&
                  m == dataSelecionada.month &&
                  d == dataSelecionada.day;
            }
          }

          // 🔥 FIX PRINCIPAL: não descarta agendamentos antigos sem data
          // (isso fazia "não reconhecer pedidos normais")
          if (data['minutos'] != null) {
            return true;
          }

          return false;
        }).toList();

        // 🔥 slots extras de encaixe
        final Set<int> slotsExtras = {};

        for (final doc in agendamentos) {
          final data = doc.data() as Map<String, dynamic>;

          if (data['encaixe'] == true && data['minutos'] != null) {
            final int? m = data['minutos'] is int ? data['minutos'] as int : int.tryParse('${data['minutos']}');
            if (m != null) {
              slotsExtras.add(m);
            }
          }
        }

        // 🔥 slots base + extras (timeline híbrida)
        final totalSlots = ((fimMin - inicioMin) ~/ (duracaoPadrao + intervaloMinutos));
        final List<int> listaMinutos = {
          for (int i = 0; i < totalSlots; i++)
            inicioMin + (i * (duracaoPadrao + intervaloMinutos)),
          ...slotsExtras,
        }.toList()
          ..sort();

        return ListView.builder(
          itemCount: listaMinutos.length,
          itemBuilder: (context, i) {
            final minutos = listaMinutos[i];
            if (minutos + duracaoPadrao > fimMin) {
              return const SizedBox.shrink();
            }
            final hora = (minutos ~/ 60).toString().padLeft(2, '0');
            final minuto = (minutos % 60).toString().padLeft(2, '0');
            final horaFormatada = "$hora:$minuto";

            // --- 🔥 STEP 1: Adiciona função normalizadora de minutos ---
            int _parseMinutos(Map<String, dynamic> data) {
              final v = data['minutos'];
              if (v is int) return v;
              return int.tryParse(v?.toString() ?? '') ?? -1;
            }

            // --- 🔥 STEP 2: Troca comparação de ocupado para usar _parseMinutos ---
            final ocupado = agendamentos.any((doc) {
              final data = doc.data() as Map<String, dynamic>;

              final m = _parseMinutos(data);
              if (m != minutos) return false;

              // garante que encaixe ou normal contam como ocupados
              return true;
            });

            // --- 🔥 STEP 3: Troca match para usar _parseMinutos ---
            final match = agendamentos.where((doc) {
              final data = doc.data() as Map<String, dynamic>;

              final m = _parseMinutos(data);
              return m == minutos;
            }).toList();

            // 🚀 FINAL SAFETY FIX (UI MUST ALWAYS RENDER SLOT): never block rendering based on match emptiness
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: GestureDetector(
                onTap: () async {
                  if (ocupado) {
                    final match = agendamentos.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['minutos'] == minutos;
                    }).toList();

                    if (match.isEmpty) return;

                    final data = match.first.data() as Map<String, dynamic>;

                    showDialog(
                      context: context,
                      builder: (context) {
                        return Dialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const SizedBox(width: 48), // espaço para compensar o botão X
                                      const Expanded(
                                        child: Center(
                                          child: Text(
                                            "Detalhes do Agendamento",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style,
                                      children: [
                                        const TextSpan(
                                          text: "Cliente: ",
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: "${data['clienteNome'] ?? data['clienteId'] ?? '---'}",
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style,
                                      children: [
                                        const TextSpan(
                                          text: "Data: ",
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: "${data['data'] ?? (data['dataTimestamp'] != null ? DateFormat('dd/MM/yyyy').format((data['dataTimestamp'] as Timestamp).toDate()) : '---')}",
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style,
                                      children: [
                                        const TextSpan(
                                          text: "Horário: ",
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: "${data['hora'] ?? (data['minutos'] != null ? '${(data['minutos'] ~/ 60).toString().padLeft(2,'0')}:${(data['minutos'] % 60).toString().padLeft(2,'0')}' : '---')}",
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style,
                                      children: [
                                        const TextSpan(
                                          text: "Valor: ",
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: "${data['valor'] != null ? 'R\$ ${data['valor']}' : 'Não informado'}",
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style,
                                      children: [
                                        const TextSpan(
                                          text: "Telefone: ",
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: "${data['telefone'] ?? data['whatsapp'] ?? 'Não informado'}",
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style,
                                      children: [
                                        const TextSpan(
                                          text: "Serviço: ",
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: "${data['servico'] ?? data['nomeServico'] ?? 'Não informado'}",
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            shape: const CircleBorder(),
                                            padding: const EdgeInsets.all(14),
                                          ),
                                          onPressed: () async {
                                            final telefone = (data['telefone'] ?? data['whatsapp'] ?? '').toString();

                                            // --- LOAD CONFIG FROM FIRESTORE (INSERTED BLOCK) ---
                                            final uid = user?.uid;
                                            String mensagemBase = "";
                                            String numeroEmpresa = "";

                                            if (uid != null) {
                                              final doc = await db
                                                  .collection('tenants')
                                                  .doc(uid)
                                                  .collection('config')
                                                  .doc('empresa')
                                                  .get();

                                              if (doc.exists) {
                                                final cfg = doc.data()!;
                                                mensagemBase = cfg['whatsappMensagem'] ?? "";
                                                numeroEmpresa = cfg['whatsappNumero'] ?? "";
                                              }
                                            }

                                            final cliente = data['clienteNome'] ?? data['clienteId'] ?? 'Cliente';
                                            final servico = data['servico'] ?? 'serviço';
                                            final horario = data['hora'] ??
                                                (data['minutos'] != null
                                                    ? '${(data['minutos'] ~/ 60).toString().padLeft(2,'0')}:${(data['minutos'] % 60).toString().padLeft(2,'0')}'
                                                    : '');
                                            final dataFormatada = data['data'] ??
                                                (data['dataTimestamp'] != null
                                                    ? DateFormat('dd/MM/yyyy').format((data['dataTimestamp'] as Timestamp).toDate())
                                                    : '');

                                            // --- REPLACE mensagem construction ---
                                            String mensagemFinal;

                                            if (mensagemBase.isNotEmpty) {
                                              mensagemFinal = mensagemBase
                                                  .replaceAll('{cliente}', cliente)
                                                  .replaceAll('{servico}', servico)
                                                  .replaceAll('{data}', dataFormatada)
                                                  .replaceAll('{hora}', horario);
                                            } else {
                                              mensagemFinal =
                                                  "Olá $cliente, seu agendamento está confirmado!\n\n"
                                                  "Serviço: $servico\n"
                                                  "Data: $dataFormatada\n"
                                                  "Horário: $horario\n\n"
                                                  "Qualquer dúvida estamos à disposição.";
                                            }

                                            final mensagem = Uri.encodeComponent(mensagemFinal);

                                            // --- REPLACE telefoneLimpo logic ---
                                            final telefoneDestino = telefone.isNotEmpty ? telefone : numeroEmpresa;
                                            final telefoneLimpo = telefoneDestino.replaceAll(RegExp(r'[^0-9]'), '');

                                            final uri = Uri.parse(
                                              "https://wa.me/55$telefoneLimpo?text=$mensagem",
                                            );

                                            try {
                                              if (kIsWeb) {
                                                html.window.open(uri.toString(), '_blank');
                                              } else {
                                                final sucesso = await launchUrl(
                                                  uri,
                                                  mode: LaunchMode.externalApplication,
                                                );

                                                if (!sucesso) {
                                                  print("Não foi possível abrir o WhatsApp");
                                                }
                                              }
                                            } catch (e) {
                                              print("Erro ao abrir WhatsApp: $e");
                                            }
                                          },
                                          child: Image.asset(
                                            'assets/whatsapp.png',
                                            height: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          onPressed: () async {
                                            // STEP 1 — ADD CONTROLLERS (inside onPressed BEFORE showDialog)
                                            final nomeController = TextEditingController(text: data['clienteNome'] ?? '');
                                            final telefoneController = TextEditingController(text: data['telefone'] ?? '');
                                            List<String> servicosSelecionados = data['servico'] is List
                                                ? List<String>.from(data['servico'])
                                                : <String>[];

                                            double valorTotal = 0.0;
                                            DateTime dataEncaixe = dataSelecionada;
                                            int novosMinutos = data['minutos'] ?? 0;

                                            await showDialog(
                                              context: context,
                                              builder: (context) {
                                                return StatefulBuilder(
                                                  builder: (context, setStateDialog) {
                                                        return AlertDialog(
                                                          title: const Text("Criar Encaixe"),
                                                          content: SingleChildScrollView(
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                const Align(
                                                                  alignment: Alignment.centerLeft,
                                                                  child: Text("Cliente"),
                                                                ),
                                                                TextField(
                                                                  controller: nomeController,
                                                                  decoration: const InputDecoration(labelText: "Nome"),
                                                                ),
                                                                TextField(
                                                                  controller: telefoneController,
                                                                  decoration: const InputDecoration(labelText: "Telefone"),
                                                                ),
                                                                ListTile(
                                                                  title: const Text("Selecionar data"),
                                                                  subtitle: Text(DateFormat('dd/MM/yyyy').format(dataEncaixe)),
                                                                  onTap: () async {
                                                                    final picked = await showDatePicker(
                                                                      context: context,
                                                                      initialDate: dataEncaixe,
                                                                      firstDate: DateTime(2020),
                                                                      lastDate: DateTime(2100),
                                                                    );
                                                                    if (picked != null) {
                                                                      setStateDialog(() {
                                                                        dataEncaixe = picked;
                                                                      });
                                                                    }
                                                                  },
                                                                ),
                                                                StreamBuilder<QuerySnapshot>(
                                                                  stream: db.collection('tenants').doc(uid).collection('servicos').snapshots(),
                                                                  builder: (context, snap) {
                                                                    if (!snap.hasData) return const SizedBox();

                                                                    final servicos = snap.data!.docs;

                                                                    return ConstrainedBox(
                                                                      constraints: const BoxConstraints(maxHeight: 260),
                                                                      child: SingleChildScrollView(
                                                                        child: Column(
                                                                          children: servicos.map((doc) {
                                                                            final s = doc.data() as Map<String, dynamic>;
                                                                            final nome = s['nome'] ?? '';
                                                                            final preco = (s['valor'] ?? 0).toDouble();

                                                                            final selecionado = servicosSelecionados.contains(nome);

                                                                            return CheckboxListTile(
                                                                              dense: true,
                                                                              controlAffinity: ListTileControlAffinity.leading,
                                                                              title: Text(nome),
                                                                              subtitle: Text("R\$ ${preco.toStringAsFixed(2)}"),
                                                                              value: selecionado,
                                                                              onChanged: (checked) {
                                                                                setStateDialog(() {
                                                                                  if (checked == true) {
                                                                                    if (!servicosSelecionados.contains(nome)) {
                                                                                      servicosSelecionados.add(nome);
                                                                                    }
                                                                                  } else {
                                                                                    servicosSelecionados.remove(nome);
                                                                                  }

                                                                                  valorTotal = servicosSelecionados.fold(0.0, (total, nomeSel) {
                                                                                    final match = servicos.where((d) {
                                                                                      final data = d.data() as Map<String, dynamic>;
                                                                                      return data['nome'] == nomeSel;
                                                                                    });

                                                                                    if (match.isEmpty) return total;

                                                                                    final m = match.first.data() as Map<String, dynamic>;
                                                                                    return total + ((m['valor'] ?? 0).toDouble());
                                                                                  });
                                                                                });
                                                                              },
                                                                            );
                                                                          }).toList(),
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                                ListTile(
                                                                  title: const Text("Selecionar horário"),
                                                                  subtitle: Text(
                                                                    '${(novosMinutos ~/ 60).toString().padLeft(2, '0')}:${(novosMinutos % 60).toString().padLeft(2, '0')}',
                                                                  ),
                                                                  onTap: () async {
                                                                    final picked = await showTimePicker(
                                                                      context: context,
                                                                      initialTime: TimeOfDay(
                                                                        hour: novosMinutos ~/ 60,
                                                                        minute: novosMinutos % 60,
                                                                      ),
                                                                    );
                                                                    if (picked != null) {
                                                                      setStateDialog(() {
                                                                        novosMinutos = picked.hour * 60 + picked.minute;
                                                                      });
                                                                    }
                                                                  },
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () => Navigator.pop(context),
                                                              child: const Text("Cancelar"),
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () async {
                                                                await db
                                                                    .collection('tenants')
                                                                    .doc(uid)
                                                                    .collection('profissionais')
                                                                    .doc(profissionalSelecionadoId)
                                                                    .collection('agendamentos')
                                                                    .add({
                                                                  'profissionalId': profissionalSelecionadoId,
                                                                  'clienteNome': nomeController.text,
                                                                  'telefone': telefoneController.text,
                                                                  'servico': servicosSelecionados.join(', '),
                                                                  'valor': valorTotal,
                                                                  'data': DateFormat('yyyy-MM-dd').format(dataEncaixe),
                                                                  'dataTimestamp': Timestamp.fromDate(dataEncaixe),
                                                                  'minutos': novosMinutos,
                                                                  'hora':
                                                                      '${(novosMinutos ~/ 60).toString().padLeft(2, '0')}:${(novosMinutos % 60).toString().padLeft(2, '0')}',
                                                                  'encaixe': true,
                                                                  'createdAt': Timestamp.now(),
                                                                });
                                                                Navigator.pop(context);
                                                                Navigator.pop(context);
                                                              },
                                                              child: const Text("Salvar encaixe"),
                                                            ),
                                                          ],
                                                        );
                                                  },
                                                );
                                              },
                                            );
                                          },
                                          child: const Text("Encaixe"),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.purple,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          onPressed: () async {
                                            final nomeController = TextEditingController(text: data['clienteNome'] ?? data['clienteId'] ?? '');
                                            final telefoneController = TextEditingController(text: data['telefone'] ?? data['whatsapp'] ?? '');

                                            DateTime novaData = (data['dataTimestamp'] is Timestamp)
                                                ? (data['dataTimestamp'] as Timestamp).toDate()
                                                : dataSelecionada;

                                            int novosMinutos = data['minutos'] ?? 0;
                                            List<String> servicosSelecionados;

                                            if (data['servico'] is List) {
                                              servicosSelecionados = List<String>.from(data['servico']);
                                            } else if (data['servico'] is String && (data['servico'] as String).isNotEmpty) {
                                              servicosSelecionados = (data['servico'] as String)
                                                  .split(',')
                                                  .map((e) => e.trim())
                                                  .where((e) => e.isNotEmpty)
                                                  .toList();
                                            } else {
                                              servicosSelecionados = [];
                                            }
                                            double valor = 0;

                                            await showDialog(
                                              context: context,
                                              builder: (context) {
                                                return StatefulBuilder(
                                                  builder: (context, setStateDialog) {
                                                    return AlertDialog(
                                                      scrollable: true,
                                                      title: const Text("Alterar Agendamento"),
                                                      content: SizedBox(
                                                        width: double.maxFinite,
                                                        height: 600,
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            TextField(controller: nomeController, decoration: const InputDecoration(labelText: "Cliente")),
                                                            const SizedBox(height: 10),
                                                            TextField(controller: telefoneController, decoration: const InputDecoration(labelText: "Telefone")),
                                                            const SizedBox(height: 10),
                                                            ListTile(
                                                              title: const Text("Selecionar data"),
                                                              subtitle: Text(DateFormat('dd/MM/yyyy').format(novaData)),
                                                              onTap: () async {
                                                                final picked = await showDatePicker(
                                                                  context: context,
                                                                  initialDate: novaData,
                                                                  firstDate: DateTime(2020),
                                                                  lastDate: DateTime(2100),
                                                                );
                                                                if (picked != null) {
                                                                  setStateDialog(() => novaData = picked);
                                                                }
                                                              },
                                                            ),
                                                            ListTile(
                                                              title: const Text("Horário"),
                                                              subtitle: Text('${(novosMinutos ~/ 60).toString().padLeft(2,'0')}:${(novosMinutos % 60).toString().padLeft(2,'0')}'),
                                                              onTap: () async {
                                                                final picked = await showTimePicker(
                                                                  context: context,
                                                                  initialTime: TimeOfDay(hour: novosMinutos ~/ 60, minute: novosMinutos % 60),
                                                                );
                                                                if (picked != null) {
                                                                  setStateDialog(() {
                                                                    novosMinutos = picked.hour * 60 + picked.minute;
                                                                  });
                                                                }
                                                              },
                                                            ),
                                                            const SizedBox(height: 10),
                                                            StreamBuilder<QuerySnapshot>(
                                                              stream: db.collection('tenants').doc(uid).collection('servicos').snapshots(),
                                                              builder: (context, snap) {
                                                                if (!snap.hasData) return const CircularProgressIndicator();

                                                                final servicos = snap.data!.docs;

                                                                return SizedBox(
                                                                  height: 260,
                                                                  child: ListView.builder(
                                                                    itemCount: servicos.length,
                                                                    itemBuilder: (context, index) {
                                                                      final doc = servicos[index];
                                                                      final s = doc.data() as Map<String, dynamic>;
                                                                      final nome = s['nome'] ?? '';
                                                                      final preco = (s['valor'] ?? 0).toDouble();

                                                                      final selecionado = servicosSelecionados.contains(nome);

                                                                      return CheckboxListTile(
                                                                        dense: true,
                                                                        controlAffinity: ListTileControlAffinity.leading,
                                                                        title: Text(nome),
                                                                        subtitle: Text("R\$ ${preco.toStringAsFixed(2)}"),
                                                                        value: selecionado,
                                                                        onChanged: (checked) {
                                                                          setStateDialog(() {
                                                                            if (checked == true) {
                                                                              if (!servicosSelecionados.contains(nome)) {
                                                                                servicosSelecionados.add(nome);
                                                                              }
                                                                            } else {
                                                                              servicosSelecionados.remove(nome);
                                                                            }

                                                                            // recalcula valor total corretamente
                                                                            valor = servicosSelecionados.fold(0.0, (total, nomeSel) {
                                                                              final matchDoc = servicos.where((d) {
                                                                                final data = d.data() as Map<String, dynamic>;
                                                                                return data['nome'] == nomeSel;
                                                                              });

                                                                              if (matchDoc.isEmpty) return total;

                                                                              final match = matchDoc.first.data() as Map<String, dynamic>;
                                                                              return total + ((match['valor'] ?? 0).toDouble());
                                                                            });
                                                                          });
                                                                        },
                                                                      );
                                                                    },
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                            const SizedBox(height: 10),
                                                            Text("Valor: R\$ ${valor.toStringAsFixed(2)}"),
                                                          ],
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                                                        ElevatedButton(
                                                          onPressed: () async {
                                                            final ref = db
                                                                .collection('tenants')
                                                                .doc(uid)
                                                                .collection('profissionais')
                                                                .doc(profissionalSelecionadoId)
                                                                .collection('agendamentos')
                                                                .doc(match.first.id);

                                                            await ref.update({
                                                              'clienteNome': nomeController.text,
                                                              'telefone': telefoneController.text,
                                                              'dataTimestamp': Timestamp.fromDate(novaData),
                                                              'data': DateFormat('yyyy-MM-dd').format(novaData),
                                                              'minutos': novosMinutos,
                                                              'hora': '${(novosMinutos ~/ 60).toString().padLeft(2,'0')}:${(novosMinutos % 60).toString().padLeft(2,'0')}',
                                                              'servico': servicosSelecionados.join(', '),
                                                              'valor': valor,
                                                            });

                                                            Navigator.pop(context);
                                                          },
                                                          child: const Text("Salvar"),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                          },
                                          child: const Text("Alterar"),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            shape: const CircleBorder(),
                                            padding: const EdgeInsets.all(14),
                                          ),
                                          onPressed: () async {
                                            final confirmar = await showDialog<bool>(
                                              context: context,
                                              builder: (context) {
                                                return AlertDialog(
                                                  title: const Text("Confirmar cancelamento"),
                                                  content: const Text("Tem certeza que deseja cancelar este agendamento?"),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: const Text("Não"),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.red,
                                                        foregroundColor: Colors.white,
                                                      ),
                                                      onPressed: () => Navigator.pop(context, true),
                                                      child: const Text("Sim, cancelar"),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );

                                            if (confirmar != true) return;

                                            try {
                                              final agendamentoRef = db
                                                  .collection('tenants')
                                                  .doc(uid)
                                                  .collection('profissionais')
                                                  .doc(profissionalSelecionadoId)
                                                  .collection('agendamentos')
                                                  .doc(match.first.id);

                                              final docSnapshot = await agendamentoRef.get();

                                              if (docSnapshot.exists) {
                                                final dados = docSnapshot.data() as Map<String, dynamic>;

                                                await db
                                                    .collection('tenants')
                                                    .doc(uid)
                                                    .collection('profissionais')
                                                    .doc(profissionalSelecionadoId)
                                                    .collection('agendamentos_excluidos')
                                                    .add({
                                                  ...dados,
                                                  'status': 'excluido',
                                                  'excluidoEm': Timestamp.now(),
                                                });

                                                await agendamentoRef.delete();
                                              }

                                              Navigator.pop(context);
                                            } catch (e) {
                                              print("Erro ao cancelar agendamento: $e");
                                            }
                                          },
                                          child: const Icon(Icons.delete),
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

                    return;
                  }

                  final nomeController = TextEditingController();
                  final telefoneController = TextEditingController();

                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text("Novo Agendamento"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Horário: $horaFormatada"),
                            const SizedBox(height: 10),
                            TextField(
                              controller: nomeController,
                              decoration: const InputDecoration(
                                labelText: "Nome do cliente",
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: telefoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: "Telefone",
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancelar"),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final nome = nomeController.text.trim();
                              if (nome.isEmpty) return;
                              final telefone = telefoneController.text.trim();

                              await db
                                  .collection('tenants')
                                  .doc(uid)
                                  .collection('profissionais')
                                  .doc(profissionalSelecionadoId)
                                  .collection('agendamentos')
                                  .add({
                                'profissionalId': profissionalSelecionadoId,
                                'hora': horaFormatada,
                                'minutos': (minutos),
                                'data': DateFormat('yyyy-MM-dd').format(dataSelecionada),
                                'dataTimestamp': Timestamp.fromDate(dataSelecionada),
                                'clienteNome': nome,
                                'telefone': telefone,
                                'createdAt': Timestamp.now(),
                              });

                              Navigator.pop(context);
                            },
                            child: const Text("Salvar"),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Container(
                  height: 65,
                  decoration: BoxDecoration(
                    color: ocupado ? Colors.grey.shade200 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (!ocupado)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                    ],
                    border: Border.all(
                      color: ocupado ? Colors.transparent : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        alignment: Alignment.center,
                        child: Text(
                          horaFormatada,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ocupado ? Colors.grey : Colors.black,
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ocupado
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: Builder(
                                        builder: (_) {
                                          if (match.isEmpty) {
                                            return const Text("Ocupado");
                                          }

                                          final data = match.first.data() as Map<String, dynamic>;

                                          final cliente = data['clienteNome'] ?? data['clienteId'] ?? 'Cliente';
                                          final servico = data['servico'] ?? data['nomeServico'] ?? '';

                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                cliente,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                servico,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Padding(
                                                padding: const EdgeInsets.only(right: 8, bottom: 2),
                                                child: Align(
                                                  alignment: Alignment.centerRight,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue,
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.check_circle, size: 12, color: Colors.white),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          "Agendado",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: const [
                                    Icon(Icons.check_circle, size: 16, color: Colors.blue),
                                    SizedBox(width: 6),
                                    Text(
                                      "Disponível",
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w500,
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
            );
          },
        );
      },
    );
  }
  
  void _abrirModalServicos() {
    final nomeController = TextEditingController();
    final valorController = TextEditingController();
    int duracaoMinutos = 30;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.6,
                maxChildSize: 0.9,
                minChildSize: 0.4,
                builder: (_, controller) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(20),
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Cadastrar Serviço",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),

                        TextField(
                          controller: nomeController,
                          decoration: InputDecoration(
                            labelText: "Nome do serviço",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        TextField(
                          controller: valorController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Valor (R\$)",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          "Duração",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 10),

                        TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Tempo em minutos (ex: 30)",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed != null) {
                              duracaoMinutos = parsed;
                            }
                          },
                        ),

                        const SizedBox(height: 30),

                        // --- Inserido bloco de serviços cadastrados ---
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),
                        const Text(
                          "Serviços cadastrados",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        StreamBuilder<QuerySnapshot>(
                          stream: db
                              .collection('tenants')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .collection('servicos')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return const Text("Nenhum serviço cadastrado");
                            }

                            final servicos = snapshot.data!.docs;

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: servicos.length,
                              itemBuilder: (context, index) {
                                final doc = servicos[index];
                                final data = doc.data() as Map<String, dynamic>;

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
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['nome'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Text("R\$ ${data['valor']}"),
                                          Text("${data['duracaoMinutos']} min"),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          await db
                                              .collection('tenants')
                                              .doc(FirebaseAuth.instance.currentUser!.uid)
                                              .collection('servicos')
                                              .doc(doc.id)
                                              .delete();
                                        },
                                      )
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        // --- Fim do bloco inserido ---

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            final user = FirebaseAuth.instance.currentUser;

                            if (user == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Usuário não autenticado")),
                              );
                              return;
                            }

                            // Força sincronização do token com o Firestore
                            await user.getIdToken(true);

                            final uid = user.uid;

                            print("USER UID: $uid");

                            final nome = nomeController.text.trim();
                            final valor = double.tryParse(valorController.text.replaceAll(',', '.'));

                            if (nome.isEmpty || valor == null || duracaoMinutos <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Preencha todos os campos corretamente")),
                              );
                              return;
                            }

                            try {
                              print("SALVANDO SERVIÇO...");
                              print("nome: $nome");
                              print("valor: $valor");
                              print("duracao: $duracaoMinutos");

                              final tenantRef = db.collection('tenants').doc(uid);
                              final ref = tenantRef.collection('servicos').doc();

                              print("CAMINHO: tenants/$uid/servicos/${ref.id}");

                              await ref.set({
                                'nome': nome,
                                'valor': valor,
                                'duracaoMinutos': duracaoMinutos,
                                'duracao': duracaoMinutos,
                                'ativo': true,
                                'ordem': Timestamp.now().millisecondsSinceEpoch,
                                'createdAt': Timestamp.now(),
                              });

                              print("SALVO NO FIREBASE COM ID: ${ref.id}");


                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Serviço salvo com sucesso")),
                              );

                              Navigator.pop(context);
                            } catch (e) {
                              print("ERRO AO SALVAR: $e");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Erro ao salvar: $e")),
                              );
                            }
                          },
                          child: const Text("Salvar serviço"),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
    print("PROJECT ID: ${FirebaseFirestore.instance.app.options.projectId}");
  }
  void _abrirMenuConfiguracoes() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                "Configurações",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text("Horários de funcionamento"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  Future.delayed(const Duration(milliseconds: 200), () {
                    _abrirConfiguracaoFuncionamento();
                  });
                },
              ),
              ListTile(
                leading: Image.asset(
                  'assets/whatsapp.png',
                  width: 24,
                  height: 24,
                ),
                title: const Text("Configurações de WhatsApp"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WhatsAppConfigPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrirMarketplace() {
    final nomeController = TextEditingController();
    final descricaoController = TextEditingController();
    final valorController = TextEditingController();

    XFile? fotoFile;
    final picker = ImagePicker();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final db = FirebaseFirestore.instance;

    Future<String?> uploadFoto(XFile file) async {
      try {
        final ref = FirebaseStorage.instance.ref().child(
          "tenants/$uid/marketplace/produtos/${DateTime.now().millisecondsSinceEpoch}.jpg",
        );

        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          await ref.putData(bytes);
        } else {
          await ref.putFile(File(file.path));
        }

        return await ref.getDownloadURL();
      } catch (e) {
        print("Erro upload marketplace: $e");
        return null;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.85,
                maxChildSize: 0.95,
                minChildSize: 0.6,
                builder: (_, controller) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Marketplace",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 15),

                        TextField(
                          controller: nomeController,
                          decoration: InputDecoration(
                            labelText: "Nome do produto",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),

                        const SizedBox(height: 10),

                        TextField(
                          controller: descricaoController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: "Descrição",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),

                        const SizedBox(height: 10),

                        TextField(
                          controller: valorController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Valor",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),

                        const SizedBox(height: 15),

                        GestureDetector(
                          onTap: () async {
                            final picked = await picker.pickImage(source: ImageSource.gallery);
                            if (picked != null) {
                              setState(() {
                                fotoFile = picked;
                              });
                            }
                          },
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: fotoFile == null
                                  ? const Text("Selecionar imagem")
                                  : const Text("Imagem selecionada"),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            if (uid == null) return;

                            final nome = nomeController.text.trim();
                            final descricao = descricaoController.text.trim();
                            final valor = double.tryParse(valorController.text.replaceAll(',', '.'));

                            if (nome.isEmpty || descricao.isEmpty || valor == null) return;

                            String fotoUrl = '';

                            if (fotoFile != null) {
                              final url = await uploadFoto(fotoFile!);
                              fotoUrl = url ?? '';
                            }

                            await db
                                .collection('tenants')
                                .doc(uid)
                                .collection('marketplace')
                                .doc('produtos')
                                .collection('items')
                                .add({
                              'nome': nome,
                              'descricao': descricao,
                              'valor': valor,
                              'fotoUrl': fotoUrl,
                              'createdAt': Timestamp.now(),
                            });

                            Navigator.pop(context);
                          },
                          child: const Text("Salvar produto"),
                        ),

                        const SizedBox(height: 20),

                        const Divider(),
                        const SizedBox(height: 10),
                        const Text(
                          "Produtos cadastrados",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),

                        if (uid != null)
                          StreamBuilder<QuerySnapshot>(
                            stream: db
                                .collection('tenants')
                                .doc(uid)
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
                                return const Text("Nenhum produto cadastrado");
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: docs.length,
                                itemBuilder: (context, i) {
                                  final data = docs[i].data() as Map<String, dynamic>;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            image: data['fotoUrl'] != ''
                                                ? DecorationImage(
                                                    image: NetworkImage(data['fotoUrl']),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                            color: Colors.grey.shade300,
                                          ),
                                          child: data['fotoUrl'] == ''
                                              ? const Icon(Icons.image)
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                data['nome'] ?? '',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                data['descricao'] ?? '',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          "R\$ ${data['valor']}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () async {
                                            await db
                                                .collection('tenants')
                                                .doc(uid)
                                                .collection('marketplace')
                                                .doc('produtos')
                                                .collection('items')
                                                .doc(docs[i].id)
                                                .delete();
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
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}


class ClientesPage extends StatelessWidget {
  const ClientesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection('tenants')
            .doc(user!.uid)
            .collection('clientes')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final clientes = snapshot.data!.docs;

          if (clientes.isEmpty) {
            return const Center(child: Text('Nenhum cliente ainda'));
          }

          return ListView.builder(
            itemCount: clientes.length,
            itemBuilder: (context, i) {
              final doc = clientes[i];
              final data = doc.data() as Map<String, dynamic>;

              return ListTile(
                title: Text(data['nome'] ?? ''),
                subtitle: Text(data['telefone'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        final nomeController = TextEditingController(text: data['nome']);
                        final telController = TextEditingController(text: data['telefone']);

                        showDialog(
                          context: context,
                          builder: (_) {
                            return AlertDialog(
                              title: const Text('Editar Cliente'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome')),
                                  TextField(controller: telController, decoration: const InputDecoration(labelText: 'Telefone')),
                                ],
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                                ElevatedButton(
                                  onPressed: () async {
                                    await db
                                        .collection('tenants')
                                        .doc(user.uid)
                                        .collection('clientes')
                                        .doc(doc.id)
                                        .update({
                                      'nome': nomeController.text,
                                      'telefone': telController.text,
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Salvar'),
                                )
                              ],
                            );
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await db
                            .collection('tenants')
                            .doc(user.uid)
                            .collection('clientes')
                            .doc(doc.id)
                            .delete();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}


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

  Widget _card(String titulo, double valor, IconData icon, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(titulo, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              "R\$ ${valor.toStringAsFixed(2)}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Financeiro'),
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _calcularTotais,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Period Filter UI ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _filtroPeriodoBtn('Hoje', 'hoje'),
                _filtroPeriodoBtn('Semana', 'semana'),
                _filtroPeriodoBtn('Mês', 'mes'),
              ],
            ),
            const SizedBox(height: 10),
            // --- Professional Filter UI ---
            StreamBuilder<QuerySnapshot>(
              stream: db
                  .collection('tenants')
                  .doc(user!.uid)
                  .collection('profissionais')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();

                final docs = snapshot.data!.docs;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _profBtn('Todos', 'todos'),
                      ...docs.map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        return _profBtn(data['nome'] ?? 'Prof', d.id);
                      }).toList()
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // --- Row of Cards ---
            Row(
              children: [
                _card("Hoje", totalHoje, Icons.today, Colors.blue),
                _card("Semana", totalSemana, Icons.calendar_view_week, Colors.orange),
                _card("Total", totalGeral, Icons.attach_money, Colors.green),
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
                  _bar(totalHoje),
                  _bar(totalSemana),
                  _bar(totalGeral),
                ],
              ),
            ),
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

  // --- Helper: Period Filter Button ---
  Widget _filtroPeriodoBtn(String label, String value) {
    final ativo = periodo == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          periodo = value;
        });
        _calcularTotais();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ativo ? Colors.black : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: ativo ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  // --- Helper: Professional Filter Button ---
  Widget _profBtn(String nome, String id) {
    final ativo = profissionalFiltro == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          profissionalFiltro = id;
        });
        _calcularTotais();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ativo ? Colors.green : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(nome, style: TextStyle(color: ativo ? Colors.white : Colors.black)),
      ),
    );
  }

  // --- Helper: Bar Widget for Graph ---
  Widget _bar(double value) {
    final maxValue = [totalHoje, totalSemana, totalGeral].reduce((a, b) => a > b ? a : b);
    final normalizedMax = maxValue == 0 ? 1 : maxValue;

    final height = (value / normalizedMax) * 100;

    return Container(
      width: 30,
      height: height.clamp(10, 100),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class MarketplacePage extends StatelessWidget {
  const MarketplacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      body: const Center(
        child: Text(
          "Marketplace em breve",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}