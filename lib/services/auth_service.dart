// Клиент Supabase: Auth, запросы к таблицам и т.д.
import 'package:supabase_flutter/supabase_flutter.dart';

// Класс-обёртка над Supabase Auth и таблицей profiles (роль пользователя).
class AuthService {
  // Ссылка на уже инициализированный в main() клиент Supabase.
  final supabase = Supabase.instance.client;

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
      // SELECT role FROM profiles WHERE id = user.id; ожидаем ровно одну строку.
      final response = await supabase
          .from('profiles') // Имя таблицы в Postgres.
          .select('role') // Только колонка role.
          .eq('id', user.id) // Фильтр по UUID пользователя из Auth.
          .single(); // Ошибка, если 0 или больше 1 строки.

      // Приводим значение из JSON к String (например 'courier' или 'admin').
      return response['role'] as String;
    } catch (e) {
      // Логируем в консоль для отладки.
      print('Error getting user role: $e');
      // Не ломаем UI — отдаём безопасное значение по умолчанию.
      return 'courier';
    }
  }
}
