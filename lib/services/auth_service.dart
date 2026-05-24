// Клиент Supabase: Auth, запросы к таблицам и т.д.
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

// Класс-обёртка над Supabase Auth и таблицей profiles (роль пользователя).
class AuthService {
  // Ссылка на уже инициализированный в main() клиент Supabase.
  SupabaseClient get supabase => Supabase.instance.client;

  // Геттер: true, если currentUser не null (есть активная сессия).
  bool get isAuthenticated => supabase.auth.currentUser != null;

  // Вход по email и паролю; возвращает AuthResponse с сессией или ошибкой.
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    // signInWithPassword — стандартный метод Supabase Auth.
    return await supabase.auth.signInWithPassword(
      email: email, // Логин пользователя.
      password: password, // Пароль в открытом виде (передаётся по HTTPS).
    );
  }

  // Завершает сессию: удаляет токены локально и на сервере.
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  // Читает роль из таблицы profiles; при ошибке — 'courier'.
  Future<String> getUserRole() async {
    // Текущий авторизованный пользователь из JWT-сессии.
    final user = supabase.auth.currentUser;

    // Нет пользователя — считаем роль курьером по умолчанию.
    if (user == null) {
      return 'courier';
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle(); // Используем maybeSingle() вместо single()
          
      if (response == null) return 'courier';
      return response['role'] as String;
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return 'courier';
    }
  }
}
