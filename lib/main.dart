import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arash_curier/screens/home_screen.dart';
import 'package:arash_curier/screens/login_screen.dart';
import 'package:arash_curier/services/isar_service.dart';
import 'package:arash_curier/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Локальная БД Isar (Offline-First)
  await initIsar();

  // 2. Supabase
  await Supabase.initialize(
    url: 'https://ojotaecsqcplztxgsqol.supabase.co',
    anonKey: 'sb_publishable_bNPNpzZW75p8puMRR1fNYQ_RxbXX5QQ',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'ARASH COURIER',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: session != null ? const HomeScreen() : const LoginScreen(),
    );
  }
}
