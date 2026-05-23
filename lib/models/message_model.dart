import 'package:isar/isar.dart';

part 'message_model.g.dart';

/// Сообщение чата по заказу (Isar + Supabase).
@Collection()
class MessageModel {
  Id isarId = Isar.autoIncrement;

  /// UUID из Supabase.
  @Index(unique: true, replace: true)
  late String id;

  /// Заказ, к которому привязан чат.
  @Index()
  late String orderId;

  late String senderId;
  late String text;
  late DateTime createdAt;

  MessageModel();

  factory MessageModel.create({
    required String id,
    required String orderId,
    required String senderId,
    required String text,
    required DateTime createdAt,
  }) {
    return MessageModel()
      ..id = id
      ..orderId = orderId
      ..senderId = senderId
      ..text = text
      ..createdAt = createdAt;
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel.create(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'sender_id': senderId,
        'text': text,
        'created_at': createdAt.toIso8601String(),
      };
}
