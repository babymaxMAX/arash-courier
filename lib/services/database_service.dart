import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/services/isar_service.dart' show isar, syncService;
import 'package:arash_curier/services/sync_service.dart';

/// CRUD заказов: мутации через SyncService, чтение — Supabase с офлайн-кэшем.
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

  Future<void> updateOrderComment(String id, String text) async {
    await _sync.applyLocalOrderPatch(id, (o) => o.comment = text);
    await _sync.enqueue('updateOrderComment', {
      'orderId': id,
      'comment': text,
    });
  }

  Future<void> updateClientPayment(String id, double amount) async {
    await _sync.applyLocalOrderPatch(id, (o) => o.clientPayment = amount);
    await _sync.enqueue('updateClientPayment', {
      'orderId': id,
      'amount': amount,
    });
  }

  Future<void> delayOrder(String id, String reason) async {
    await _sync.applyLocalOrderPatch(id, (o) {
      o.status = 'Отложено';
      o.cancelReason = reason;
    });
    await _sync.enqueue('delayOrder', {
      'orderId': id,
      'reason': reason,
    });
  }

  Future<String?> uploadOrderPhoto(String id, File imageFile) async {
    final localPath = imageFile.path;
    await _sync.applyLocalOrderPatch(id, (o) {
      o.urlPhoto = localPath;
    });

    if (await _sync.isOnline) {
      try {
        await _sync.enqueue('uploadOrderPhoto', {
          'orderId': id,
          'localPath': localPath,
        });
        final row = await supabase
            .from('orders')
            .select('url_photo')
            .eq('id', id)
            .maybeSingle();
        return row?['url_photo'] as String?;
      } catch (e) {
        await _sync.enqueue('uploadOrderPhoto', {
          'orderId': id,
          'localPath': localPath,
        });
        return localPath;
      }
    }

    await _sync.enqueue('uploadOrderPhoto', {
      'orderId': id,
      'localPath': localPath,
    });
    return localPath;
  }

  Future<void> updatePvzQr(String id, String qrCode) async {
    await _sync.applyLocalOrderPatch(id, (o) => o.pvzQrCode = qrCode);
    await _sync.enqueue('updatePvzQr', {
      'orderId': id,
      'qrCode': qrCode,
    });
  }

  Future<void> updateOrderQr(String id, String qrCode) async {
    await _sync.applyLocalOrderPatch(id, (o) => o.clientQrCode = qrCode);
    await _sync.enqueue('updateOrderQr', {
      'orderId': id,
      'qrCode': qrCode,
    });
  }

  Future<void> clearOrderPhoto(String id) async {
    await _sync.applyLocalOrderPatch(id, (o) => o.urlPhoto = '');
    await _sync.enqueue('clearOrderPhoto', {'orderId': id});
  }

  Future<void> clearOrderQr(String id) async {
    await _sync.applyLocalOrderPatch(id, (o) => o.clientQrCode = '');
    await _sync.enqueue('clearOrderQr', {'orderId': id});
  }

  Future<void> updateOrderStatus(String id, String status) async {
    await _sync.applyLocalOrderPatch(id, (o) => o.status = status);
    await _sync.enqueue('updateOrderStatus', {
      'orderId': id,
      'status': status,
    });
  }

  Future<void> createOrder(OrderModel order) async {
    await isar.writeTxn(() async {
      await isar.orderModels.put(order);
    });
    await _sync.enqueue('createOrder', {
      'order': order.toJson(),
    });
  }
}
