import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:arash_curier/models/message_model.dart';

/// Отправка и Realtime-подписка на сообщения чата.
class ChatService {
  SupabaseClient get supabase => Supabase.instance.client;

  /// Отправка сообщения в таблицу messages.
  Future<void> sendMessage(String orderId, String text) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Не авторизован');

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await supabase.from('messages').insert({
      'order_id': orderId,
      'sender_id': user.id,
      'text': trimmed,
    });
  }

  /// Realtime-поток сообщений для конкретного заказа.
  Stream<List<MessageModel>> getMessagesStream(String orderId) {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .order('created_at', ascending: true)
        .map(
          (maps) => maps.map((json) => MessageModel.fromJson(json)).toList(),
        );
  }
}
