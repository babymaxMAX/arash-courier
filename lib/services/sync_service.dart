import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/models/sync_task.dart';

/// Очередь мутаций и отправка на Supabase при наличии сети.
class SyncService {
  SyncService(this.isar);

  final Isar isar;
  final SupabaseClient supabase = Supabase.instance.client;

  static const _courierExcludedStatuses = [
    'Выдано',
    'Отменено',
    'Возврат',
    'ISSUED',
    'CANCELLED',
    'CANCELED',
    'RETURN',
    'RETURNED',
  ];

  Future<bool> get isOnline async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Добавить задачу в очередь и попытаться отправить сразу.
  Future<void> addTask(
    String actionType,
    String orderId,
    String jsonPayload,
  ) async {
    final task = SyncTask()
      ..actionType = actionType
      ..orderId = orderId
      ..payload = jsonPayload
      ..createdAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.syncTasks.put(task);
    });

    await trySync();
  }

  /// Выполнить одно действие на сервере (без записи в очередь).
  Future<void> executeAction(
    String actionType,
    String orderId,
    String jsonPayload,
  ) async {
    final task = SyncTask()
      ..actionType = actionType
      ..orderId = orderId
      ..payload = jsonPayload;
    await _processTask(task);
  }

  /// Обработать все задачи из очереди (если есть интернет).
  Future<void> trySync() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (!connectivity.any((r) => r != ConnectivityResult.none)) return;

    final tasks = await isar.syncTasks.where().sortByCreatedAt().findAll();

    for (final task in tasks) {
      try {
        await _processTask(task);
        await isar.writeTxn(() async {
          await isar.syncTasks.delete(task.id);
        });
      } catch (e) {
        debugPrint('Ошибка синхронизации задачи ${task.id}: $e');
      }
    }
  }

  /// Разбор payload: JSON-объект или простая строка (legacy).
  Map<String, dynamic> _payloadMap(SyncTask task) {
    try {
      final decoded = jsonDecode(task.payload);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }

  double _payloadAmount(SyncTask task) {
    final map = _payloadMap(task);
    if (map.containsKey('amount')) {
      final value = map['amount'];
      if (value is num) return value.toDouble();
      return double.parse(value.toString());
    }
    return double.parse(task.payload);
  }

  Future<void> _processTask(SyncTask task) async {
    final data = _payloadMap(task);

    switch (task.actionType) {
      case SyncActionType.updateStatus:
        final status = data['status']?.toString() ?? task.payload;
        await supabase
            .from('orders')
            .update({'status': status})
            .eq('id', task.orderId);
        break;

      case SyncActionType.updateComment:
      case SyncActionType.addComment:
        final comment = data['comment']?.toString() ?? task.payload;
        await supabase
            .from('orders')
            .update({'comment': comment})
            .eq('id', task.orderId);
        break;

      case SyncActionType.updatePayment:
        final amount = _payloadAmount(task);
        await supabase
            .from('orders')
            .update({'client_payment': amount})
            .eq('id', task.orderId);
        break;

      case SyncActionType.delayOrder:
        await supabase.from('orders').update({
          'status': 'delayed',
          'cancel_reason': data['reason'],
        }).eq('id', task.orderId);
        break;

      case SyncActionType.updatePvzQr:
        await supabase
            .from('orders')
            .update({'pvz_qr_code': data['qrCode']})
            .eq('id', task.orderId);
        break;

      case SyncActionType.updateClientQr:
        await supabase
            .from('orders')
            .update({'client_qr_code': data['qrCode']})
            .eq('id', task.orderId);
        break;

      case SyncActionType.clearPhoto:
        await supabase
            .from('orders')
            .update({'url_photo': ''})
            .eq('id', task.orderId);
        break;

      case SyncActionType.clearQr:
        await supabase
            .from('orders')
            .update({'client_qr_code': ''})
            .eq('id', task.orderId);
        break;

      case SyncActionType.createOrder:
        await supabase.from('orders').insert(data['order']);
        break;

      case SyncActionType.updateOrder:
        await supabase
            .from('orders')
            .update(data['order'])
            .eq('id', task.orderId);
        break;

      case SyncActionType.addPhoto:
        final localPath = data['localPath'] as String;
        final file = File(localPath);
        if (!await file.exists()) {
          throw Exception('Photo file not found: $localPath');
        }
        final fileName = 'order_${task.orderId}.jpg';
        await supabase.storage.from('packages').upload(
              fileName,
              file,
              fileOptions: const FileOptions(upsert: true),
            );
        final baseUrl =
            supabase.storage.from('packages').getPublicUrl(fileName);
        final publicUrl =
            '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
        await supabase
            .from('orders')
            .update({'url_photo': publicUrl})
            .eq('id', task.orderId);
        break;

      default:
        throw Exception('Unknown sync action: ${task.actionType}');
    }
  }

  /// Кэш заказов в Isar после успешной загрузки с сервера.
  Future<void> cacheOrders(Iterable<OrderModel> orders) async {
    await isar.writeTxn(() async {
      await isar.orderModels.putAll(orders.toList());
    });
  }

  /// Чтение из локального кэша (офлайн).
  Future<Map<String, List<OrderModel>>> loadOrdersFromCache(String role) async {
    var orders = await isar.orderModels.where().findAll();
    if (role == 'courier') {
      orders = orders
          .where((o) => !_courierExcludedStatuses.contains(o.status))
          .toList();
    }
    return _groupByFolder(orders);
  }

  Map<String, List<OrderModel>> _groupByFolder(List<OrderModel> orders) {
    final Map<String, List<OrderModel>> sorted = {};
    for (final order in orders) {
      final key = '${order.companyName} - ${order.companyAddress}';
      sorted.putIfAbsent(key, () => []).add(order);
    }
    return sorted;
  }

  Future<void> applyLocalOrderPatch(
    String orderId,
    void Function(OrderModel order) patch,
  ) async {
    final existing =
        await isar.orderModels.filter().idEqualTo(orderId).findFirst();
    if (existing == null) return;
    patch(existing);
    existing.dateUpdated = DateTime.now();
    await isar.writeTxn(() async {
      await isar.orderModels.put(existing);
    });
  }
}
