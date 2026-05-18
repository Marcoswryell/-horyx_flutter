import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:horyx_fluter/models/agendamento_model.dart';
import 'package:horyx_fluter/pages/admin_page.dart';
import 'firebase_options.dart'; // Este é o arquivo gerado pelo FlutterFire CLI
import 'pages/agendamento_page.dart'; // Import da tela que criamos
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horyx Salão',
      debugShowCheckedModeBanner: false, // Remove a faixa de "debug"
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        useMaterial3: true, // Usa o design mais moderno do Google
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // carregando
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // usuário logado
          if (snapshot.hasData) {
            return const AgendamentoPage();
          }

          // não logado
          return const LoginPage();
        },
      ),
    );
  }
}
