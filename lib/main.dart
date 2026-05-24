import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arash_curier/screens/home_screen.dart';
import 'package:arash_curier/screens/login_screen.dart';
import 'package:arash_curier/services/connection_wrapper.dart';
import 'package:arash_curier/services/isar_service.dart';
import 'package:arash_curier/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // 1. Локальная БД Isar (Offline-First)
  await initIsar();

  // 2. Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const ConnectionWrapper(child: MyApp()));
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
