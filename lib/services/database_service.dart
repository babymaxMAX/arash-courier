import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/models/sync_task.dart';
import 'package:arash_curier/services/isar_service.dart' as isar_svc;
import 'package:arash_curier/services/sync_service.dart';

/// Умный посредник: онлайн — Supabase, офлайн — очередь SyncService + локальный Isar.
class DatabaseService {
  final SupabaseClient supabase = Supabase.instance.client;
  final Isar isar;
  final SyncService _sync;

  /// Без аргумента использует глобальный [isar] (после [initIsar]).
  DatabaseService([Isar? isarInstance, SyncService? sync])
      : isar = isarInstance ?? isar_svc.isar,
        _sync = sync ?? isar_svc.syncService;

  Future<bool> _isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.any((r) => r != ConnectivityResult.none);
  }

  Future<Map<String, List<OrderModel>>> fetchAndSortOrders(String role) async {
    if (await _isOnline()) {
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

  Future<void> updateOrderStatus(String id, String status) async {
    await _sync.applyLocalOrderPatch(id, (o) => o.status = status);
    final payload = jsonEncode({'status': status});

    if (await _isOnline()) {
      try {
        await supabase.from('orders').update({'status': status}).eq('id', id);
        return;
      } catch (e) {
        await _sync.addTask(SyncActionType.updateStatus, id, payload);
        rethrow;
      }
    }

    await _sync.addTask(SyncActionType.updateStatus, id, payload);
  }

  Future<void> updateOrderComment(String id, String text) async {
    await _sync.applyLocalOrderPatch(id, (o) => o.comment = text);
    final payload = jsonEncode({'comment': text});

    if (await _isOnline()) {
      try {
        await supabase.from('orders').update({'comment': text}).eq('id', id);
        return;
      } catch (e) {
        await _sync.addTask(SyncActionType.updateComment, id, payload);
        rethrow;
      }
    }

    await _sync.addTask(SyncActionType.updateComment, id, payload);
  }

  Future<void> updateClientPayment(String id, double amount) async {
    await _sync.applyLocalOrderPatch(id, (o) => o.clientPayment = amount);
    final payload = jsonEncode({'amount': amount});

    if (await _isOnline()) {
      try {
        await supabase
            .from('orders')
            .update({'client_payment': amount})
            .eq('id', id);
        return;
      } catch (e) {
        await _sync.addTask(SyncActionType.updatePayment, id, payload);
        rethrow;
      }
    }

    await _sync.addTask(SyncActionType.updatePayment, id, payload);
  }

  Future<void> delayOrder(String id, String reason) async {
    await _sync.applyLocalOrderPatch(id, (o) {
      o.status = 'Отложено';
      o.cancelReason = reason;
    });
    final payload = jsonEncode({'reason': reason});

    if (await _isOnline()) {
      try {
        await supabase.from('orders').update({
          'status': 'delayed',
          'cancel_reason': reason,
        }).eq('id', id);
        return;
      } catch (e) {
        await _sync.addTask(SyncActionType.delayOrder, id, payload);
        rethrow;
      }
    }

    await _sync.addTask(SyncActionType.delayOrder, id, payload);
  }

  Future<String?> uploadOrderPhoto(String id, File imageFile) async {
    final localPath = imageFile.path;
    await _sync.applyLocalOrderPatch(id, (o) => o.urlPhoto = localPath);
    final payload = jsonEncode({'localPath': localPath});

    if (await _isOnline()) {
      try {
        final fileName = 'order_$id.jpg';
        await supabase.storage.from('packages').upload(
              fileName,
              imageFile,
              fileOptions: const FileOptions(upsert: true),
            );
        final baseUrl =
            supabase.storage.from('packages').getPublicUrl(fileName);
        final url = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
        await supabase.from('orders').update({'url_photo': url}).eq('id', id);
        return url;
      } catch (e) {
        await _sync.addTask(SyncActionType.addPhoto, id, payload);
        return localPath;
      }
    }

    await _sync.addTask(SyncActionType.addPhoto, id, payload);
    return localPath;
  }

  Future<void> updatePvzQr(String id, String qrCode) async {
    await _sync.applyLocalOrderPatch(id, (o) => o.pvzQrCode = qrCode);
    final payload = jsonEncode({'qrCode': qrCode});

    if (await _isOnline()) {
      try {
        await supabase
            .from('orders')
            .update({'pvz_qr_code': qrCode})
            .eq('id', id);
        return;
      } catch (e) {
        await _sync.addTask(SyncActionType.updatePvzQr, id, payload);
        rethrow;
      }
    }

    await _sync.addTask(SyncActionType.updatePvzQr, id, payload);
  }

  Future<void> updateOrderQr(String id, String qrCode) async {
    await _sync.applyLocalOrderPatch(id, (o) => o.clientQrCode = qrCode);
    final payload = jsonEncode({'qrCode': qrCode});

    if (await _isOnline()) {
      try {
        await supabase
            .from('orders')
            .update({'client_qr_code': qrCode})
            .eq('id', id);
        return;
      } catch (e) {
        await _sync.addTask(SyncActionType.updateClientQr, id, payload);
        rethrow;
      }
    }

    await _sync.addTask(SyncActionType.updateClientQr, id, payload);
  }

  Future<void> clearOrderPhoto(String id) async {
    await _sync.applyLocalOrderPatch(id, (o) => o.urlPhoto = '');
    const payload = '{}';

    if (await _isOnline()) {
      try {
        await supabase.from('orders').update({'url_photo': ''}).eq('id', id);
        return;
      } catch (e) {
        await _sync.addTask(SyncActionType.clearPhoto, id, payload);
        rethrow;
      }
    }

    await _sync.addTask(SyncActionType.clearPhoto, id, payload);
  }

  Future<void> clearOrderQr(String id) async {
    await _sync.applyLocalOrderPatch(id, (o) => o.clientQrCode = '');
    const payload = '{}';

    if (await _isOnline()) {
      try {
        await supabase
            .from('orders')
            .update({'client_qr_code': ''})
            .eq('id', id);
        return;
      } catch (e) {
        await _sync.addTask(SyncActionType.clearQr, id, payload);
        rethrow;
      }
    }

    await _sync.addTask(SyncActionType.clearQr, id, payload);
  }

  Future<void> createOrder(OrderModel order) async {
    await isar.writeTxn(() async {
      await isar.orderModels.put(order);
    });

    final payload = jsonEncode({'order': order.toJson()});

    if (await _isOnline()) {
      try {
        await supabase.from('orders').insert(order.toJson());
        return;
      } catch (e) {
        await _sync.addTask(SyncActionType.createOrder, order.id, payload);
        rethrow;
      }
    }

    await _sync.addTask(SyncActionType.createOrder, order.id, payload);
  }
}
