import 'package:isar/isar.dart';

part 'sync_task.g.dart';

/// Типы действий в очереди синхронизации.
abstract class SyncActionType {
  static const updateStatus = 'update_status';
  static const createOrder = 'create_order';
  static const updateOrder = 'update_order';
  static const addPhoto = 'add_photo';
  static const updateComment = 'update_comment';
  static const addComment = 'add_comment';
  static const updatePayment = 'update_payment';
  static const delayOrder = 'delay_order';
  static const updatePvzQr = 'update_pvz_qr';
  static const updateClientQr = 'update_client_qr';
  static const clearPhoto = 'clear_photo';
  static const clearQr = 'clear_qr';
}

/// Задача в очереди синхронизации (Offline → Supabase).
@Collection()
class SyncTask {
  Id id = Isar.autoIncrement;

  /// Например: update_status, create_order, add_photo
  late String actionType;

  /// ID заказа, к которому относится действие.
  late String orderId;

  /// Данные в формате JSON (статус, сумма, путь к фото и т.д.).
  late String payload;

  @Index()
  DateTime createdAt = DateTime.now();
}
