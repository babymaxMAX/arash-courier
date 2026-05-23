import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/models/sync_task.dart';
import 'package:arash_curier/services/sync_service.dart';

/// Глобальный экземпляр Isar и SyncService.
late Isar isar;
late SyncService syncService;

Future<void> initIsar() async {
  final dir = await getApplicationDocumentsDirectory();
  isar = await Isar.open(
    [OrderModelSchema, SyncTaskSchema],
    directory: dir.path,
  );
  syncService = SyncService(isar);
  syncService.startConnectivityListener();
}
