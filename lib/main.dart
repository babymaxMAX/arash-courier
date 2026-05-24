import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  String supabaseUrl = dotenv.env['SUPABASE_URL']!;
  String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

  // Пытаемся получить удаленную конфигурацию
  try {
    final response = await http.get(
      Uri.parse('https://raw.githubusercontent.com/babymaxMAX/arash-courier/main/remote_config.json'),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final config = jsonDecode(response.body);
      if (config['SUPABASE_URL'] != null && config['SUPABASE_ANON_KEY'] != null) {
        supabaseUrl = config['SUPABASE_URL'];
        supabaseAnonKey = config['SUPABASE_ANON_KEY'];
        debugPrint('Загружена удаленная конфигурация: $supabaseUrl');
      }
    }
  } catch (e) {
    debugPrint('Не удалось загрузить удаленную конфигурацию, используем локальную. Ошибка: $e');
  }

  // 1. Supabase — до Isar/SyncService, иначе Supabase.instance ещё не готов
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // 2. Локальная БД Isar (SyncService может обращаться к Supabase)
  await initIsar();

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

