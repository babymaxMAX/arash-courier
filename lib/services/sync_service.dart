import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/models/sync_task.dart';

/// Очередь мутаций и отправка на Supabase при наличии сети.
class SyncService {
  SyncService(this.isar);

  final Isar isar;
  SupabaseClient get supabase => Supabase.instance.client;

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
        final update = <String, dynamic>{'status': status};
        final dateUpdated = data['date_updated']?.toString();
        if (dateUpdated != null && dateUpdated.isNotEmpty) {
          update['date_updated'] = dateUpdated;
          update['updated_at'] = dateUpdated;
        }
        await supabase.from('orders').update(update).eq('id', task.orderId);
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
        final update = <String, dynamic>{
          'status': 'delayed',
          'cancel_reason': data['reason'],
        };
        final dateUpdated = data['date_updated']?.toString();
        if (dateUpdated != null && dateUpdated.isNotEmpty) {
          update['date_updated'] = dateUpdated;
          update['updated_at'] = dateUpdated;
        }
        await supabase.from('orders').update(update).eq('id', task.orderId);
        break;

      case SyncActionType.updatePvzQr:
        await supabase.from('orders').update({
          'pvz_qr_code': data['qrCode'] ?? task.payload,
        }).eq('id', task.orderId);
        break;

      case SyncActionType.updateClientQr:
        await supabase.from('orders').update({
          'client_qr_code': data['qrCode'] ?? task.payload,
        }).eq('id', task.orderId);
        break;

      case SyncActionType.addPvzQr:
        await _appendQrToOrder(
          task.orderId,
          'pvz_qr_code',
          task.payload,
        );
        break;

      case SyncActionType.addClientQr:
        await _appendQrToOrder(
          task.orderId,
          'client_qr_code',
          task.payload,
        );
        break;

      case SyncActionType.addPhotoOffline:
        await _uploadOfflinePhoto(task.orderId, task.payload);
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
        final orderData = data['order'] ?? data;
        await supabase
            .from('orders')
            .update(Map<String, dynamic>.from(orderData as Map))
            .eq('id', task.orderId);
        break;

      case SyncActionType.addPhoto:
        final localPath = data['localPath'] as String? ?? task.payload;
        await _uploadOfflinePhoto(task.orderId, localPath);
        break;

      default:
        throw Exception('Unknown sync action: ${task.actionType}');
    }
  }

  Future<void> _appendQrToOrder(
    String orderId,
    String column,
    String code,
  ) async {
    final response = await supabase
        .from('orders')
        .select(column)
        .eq('id', orderId)
        .maybeSingle();
    final current = OrderModel.parseList(response?[column]);
    if (!current.contains(code)) current.add(code);
    await supabase.from('orders').update({
      column: OrderModel.encodeList(current),
    }).eq('id', orderId);
  }

  Future<void> _uploadOfflinePhoto(String orderId, String localPath) async {
    final file = File(localPath);
    if (!await file.exists()) return;

    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'order_${orderId}_$uniqueSuffix.jpg';

    await supabase.storage.from('packages').upload(fileName, file);
    final publicUrl = supabase.storage.from('packages').getPublicUrl(fileName);

    final response = await supabase
        .from('orders')
        .select('url_photo')
        .eq('id', orderId)
        .maybeSingle();
    final currentPhotos = OrderModel.parseList(response?['url_photo']);
    if (!currentPhotos.contains(publicUrl)) currentPhotos.add(publicUrl);

    await supabase.from('orders').update({
      'url_photo': OrderModel.encodeList(currentPhotos),
    }).eq('id', orderId);

    try {
      await file.delete();
    } catch (_) {}
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
