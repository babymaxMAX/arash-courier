import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:arash_curier/models/order_model.dart';

/// Глобальный экземпляр Isar — используется SyncService и DatabaseService.
late Isar isar;

Future<void> initIsar() async {
  final dir = await getApplicationDocumentsDirectory();
  isar = await Isar.open(
    [OrderModelSchema],
    directory: dir.path,
  );
}
