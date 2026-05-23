import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/models/sync_task.dart';
import 'package:arash_curier/services/isar_service.dart' show isar, syncService;
import 'package:arash_curier/services/sync_service.dart';

/// CRUD заказов: онлайн — Supabase, офлайн — очередь SyncService.
class DatabaseService {
  final supabase = Supabase.instance.client;
  SyncService get _sync => syncService;

  Future<Map<String, List<OrderModel>>> fetchAndSortOrders(String role) async {
    if (await _sync.isOnline) {
      try {
        var query = supabase.from('orders').select();

        if (role == 'courier') {
          query = query.not(
            'status',
            'in',
            '("Выдано", "Отменено", "Возврат", "ISSUED", "CANCELLED", "CANCELED", "RETURN", "RETURNED")',
          );
        }

        final rawResponse = await query;
        final sortedOrders = <String, List<OrderModel>>{};

        for (final row in rawResponse) {
          final orderModel = OrderModel.fromJson(row);
          final folderKey =
              '${orderModel.companyName} - ${orderModel.companyAddress}';
          sortedOrders.putIfAbsent(folderKey, () => []).add(orderModel);
        }

        await _sync.cacheOrders(
          sortedOrders.values.expand((list) => list),
        );
        await _sync.trySync();

        return sortedOrders;
      } catch (e) {
        final cached = await _sync.loadOrdersFromCache(role);
        if (cached.isNotEmpty) return cached;
        throw Exception('Failed to fetch orders: $e');
      }
    }

    final cached = await _sync.loadOrdersFromCache(role);
    if (cached.isEmpty) {
      throw Exception('Нет сети и локальный кэш пуст');
    }
    return cached;
  }

  /// Онлайн — сразу в Supabase; офлайн или ошибка — в очередь.
  Future<void> _syncMutation({
    required String orderId,
    required String actionType,
    required Map<String, dynamic> payload,
    required Future<void> Function() applyLocal,
  }) async {
    await applyLocal();

    final jsonPayload = jsonEncode(payload);

    if (await _sync.isOnline) {
      try {
        await _sync.executeAction(actionType, orderId, jsonPayload);
        return;
      } catch (_) {
        // Сеть есть, но запрос не прошёл — кладём в очередь
      }
    }

    await _sync.addTask(actionType, orderId, jsonPayload);
  }

  Future<void> updateOrderComment(String id, String text) async {
    await _syncMutation(
      orderId: id,
      actionType: SyncActionType.updateComment,
      payload: {'comment': text},
      applyLocal: () => _sync.applyLocalOrderPatch(id, (o) => o.comment = text),
    );
  }

  Future<void> updateClientPayment(String id, double amount) async {
    await _syncMutation(
      orderId: id,
      actionType: SyncActionType.updatePayment,
      payload: {'amount': amount},
      applyLocal: () =>
          _sync.applyLocalOrderPatch(id, (o) => o.clientPayment = amount),
    );
  }

  Future<void> delayOrder(String id, String reason) async {
    await _syncMutation(
      orderId: id,
      actionType: SyncActionType.delayOrder,
      payload: {'reason': reason},
      applyLocal: () => _sync.applyLocalOrderPatch(id, (o) {
        o.status = 'Отложено';
        o.cancelReason = reason;
      }),
    );
  }

  Future<String?> uploadOrderPhoto(String id, File imageFile) async {
    final localPath = imageFile.path;
    final payload = {'localPath': localPath};

    await _sync.applyLocalOrderPatch(id, (o) => o.urlPhoto = localPath);

    if (await _sync.isOnline) {
      try {
        await _sync.executeAction(
          SyncActionType.addPhoto,
          id,
          jsonEncode(payload),
        );
        final row = await supabase
            .from('orders')
            .select('url_photo')
            .eq('id', id)
            .maybeSingle();
        return row?['url_photo'] as String?;
      } catch (_) {
        await _sync.addTask(SyncActionType.addPhoto, id, jsonEncode(payload));
        return localPath;
      }
    }

    await _sync.addTask(SyncActionType.addPhoto, id, jsonEncode(payload));
    return localPath;
  }

  Future<void> updatePvzQr(String id, String qrCode) async {
    await _syncMutation(
      orderId: id,
      actionType: SyncActionType.updatePvzQr,
      payload: {'qrCode': qrCode},
      applyLocal: () =>
          _sync.applyLocalOrderPatch(id, (o) => o.pvzQrCode = qrCode),
    );
  }

  Future<void> updateOrderQr(String id, String qrCode) async {
    await _syncMutation(
      orderId: id,
      actionType: SyncActionType.updateClientQr,
      payload: {'qrCode': qrCode},
      applyLocal: () =>
          _sync.applyLocalOrderPatch(id, (o) => o.clientQrCode = qrCode),
    );
  }

  Future<void> clearOrderPhoto(String id) async {
    await _syncMutation(
      orderId: id,
      actionType: SyncActionType.clearPhoto,
      payload: {},
      applyLocal: () => _sync.applyLocalOrderPatch(id, (o) => o.urlPhoto = ''),
    );
  }

  Future<void> clearOrderQr(String id) async {
    await _syncMutation(
      orderId: id,
      actionType: SyncActionType.clearQr,
      payload: {},
      applyLocal: () =>
          _sync.applyLocalOrderPatch(id, (o) => o.clientQrCode = ''),
    );
  }

  Future<void> updateOrderStatus(String id, String status) async {
    await _syncMutation(
      orderId: id,
      actionType: SyncActionType.updateStatus,
      payload: {'status': status},
      applyLocal: () => _sync.applyLocalOrderPatch(id, (o) => o.status = status),
    );
  }

  Future<void> createOrder(OrderModel order) async {
    await isar.writeTxn(() async {
      await isar.orderModels.put(order);
    });

    final payload = {'order': order.toJson()};
    final jsonPayload = jsonEncode(payload);

    if (await _sync.isOnline) {
      try {
        await _sync.executeAction(
          SyncActionType.createOrder,
          order.id,
          jsonPayload,
        );
        return;
      } catch (_) {}
    }

    await _sync.addTask(SyncActionType.createOrder, order.id, jsonPayload);
  }
}
