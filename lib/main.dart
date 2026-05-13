import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// ⚠️ IN IMPORTS KO DHAYAN SE DEKHO
import 'login_screen.dart';
import 'main_app_shell.dart'; // Humne abhi ye nayi file banayi hai

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. .env file ko load karo
  await dotenv.load(fileName: ".env");

  try {
    await Supabase.initialize(
      // 2. dotenv.env se values uthao
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
  } catch (e) {
    debugPrint("Supabase Init Error: $e");
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamCare Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5E9)),
        fontFamily: 'Roboto',
      ),
      home: const AuthCheck(),
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() {
    super.initState();
    // Ye line ensure karti hai ki auth state change hote hi app react kare
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() {}); 
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    
    // Agar session hai toh seedha shell, warna login
    return session != null ? const MainAppShell() : const LoginScreen();
  }
}