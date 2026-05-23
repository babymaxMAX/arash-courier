import 'package:isar/isar.dart';

part 'sync_task.g.dart';

/// Задача в очереди синхронизации (Offline → Supabase).
@Collection()
class SyncTask {
  Id id = Isar.autoIncrement;

  /// updateOrderStatus, createOrder, updateOrderComment, ...
  late String action;

  /// JSON с параметрами действия.
  late String payload;

  late DateTime createdAt;

  SyncTask();

  factory SyncTask.create({
    required String action,
    required String payload,
  }) {
    return SyncTask()
      ..action = action
      ..payload = payload
      ..createdAt = DateTime.now();
  }
}
