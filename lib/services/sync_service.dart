import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/models/sync_task.dart';

/// Очередь мутаций и отправка на Supabase при наличии сети.
class SyncService {
  SyncService({required this.isar, SupabaseClient? client})
      : supabase = client ?? Supabase.instance.client;

  final Isar isar;
  final SupabaseClient supabase;

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

  /// Добавить задачу в очередь и сразу попытаться отправить.
  Future<void> enqueue(String action, Map<String, dynamic> payload) async {
    final task = SyncTask.create(
      action: action,
      payload: jsonEncode(payload),
    );
    await isar.writeTxn(() async {
      await isar.syncTasks.put(task);
    });
    await trySync();
  }

  /// Обработать все задачи из очереди (если есть интернет).
  Future<void> trySync() async {
    if (!await isOnline) return;

    final tasks = await isar.syncTasks.where().sortByCreatedAt().findAll();
    for (final task in tasks) {
      try {
        await _execute(task);
        await isar.writeTxn(() async {
          await isar.syncTasks.delete(task.id);
        });
      } catch (e) {
        // Оставляем в очереди — повторим при следующем trySync
        break;
      }
    }
  }

  Future<void> _execute(SyncTask task) async {
    final data = jsonDecode(task.payload) as Map<String, dynamic>;

    switch (task.action) {
      case 'updateOrderComment':
        await supabase
            .from('orders')
            .update({'comment': data['comment']})
            .eq('id', data['orderId']);
        break;

      case 'updateClientPayment':
        await supabase
            .from('orders')
            .update({'client_payment': data['amount']})
            .eq('id', data['orderId']);
        break;

      case 'delayOrder':
        await supabase.from('orders').update({
          'status': 'delayed',
          'cancel_reason': data['reason'],
        }).eq('id', data['orderId']);
        break;

      case 'updateOrderStatus':
        await supabase
            .from('orders')
            .update({'status': data['status']})
            .eq('id', data['orderId']);
        break;

      case 'updatePvzQr':
        await supabase
            .from('orders')
            .update({'pvz_qr_code': data['qrCode']})
            .eq('id', data['orderId']);
        break;

      case 'updateOrderQr':
        await supabase
            .from('orders')
            .update({'client_qr_code': data['qrCode']})
            .eq('id', data['orderId']);
        break;

      case 'clearOrderPhoto':
        await supabase
            .from('orders')
            .update({'url_photo': ''})
            .eq('id', data['orderId']);
        break;

      case 'clearOrderQr':
        await supabase
            .from('orders')
            .update({'client_qr_code': ''})
            .eq('id', data['orderId']);
        break;

      case 'createOrder':
        await supabase.from('orders').insert(data['order']);
        break;

      case 'uploadOrderPhoto':
        final orderId = data['orderId'] as String;
        final localPath = data['localPath'] as String;
        final file = File(localPath);
        if (!await file.exists()) {
          throw Exception('Photo file not found: $localPath');
        }
        final fileName = 'order_$orderId.jpg';
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
            .eq('id', orderId);
        break;

      default:
        throw Exception('Unknown sync action: ${task.action}');
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
    final existing = await isar.orderModels.filter().idEqualTo(orderId).findFirst();
    if (existing == null) return;
    patch(existing);
    existing.dateUpdated = DateTime.now();
    await isar.writeTxn(() async {
      await isar.orderModels.put(existing);
    });
  }
}
