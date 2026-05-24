import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/models/sync_task.dart';
import 'package:arash_curier/services/isar_service.dart' as isar_svc;
import 'package:arash_curier/services/sync_service.dart';

/// Умный посредник: онлайн — Supabase, офлайн — очередь SyncService + локальный Isar.
class DatabaseService {
  SupabaseClient get supabase => Supabase.instance.client;
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

        final rawResponse = await query.limit(99999);
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

  Future<void> takeFolderInWork(List<String> orderIds, String email) async {
    for (var id in orderIds) {
      await _sync.applyLocalOrderPatch(id, (o) => o.responsiblePerson = email);
    }
    
    if (await _isOnline()) {
      try {
        await supabase
            .from('orders')
            .update({'responsible_person': email})
            .inFilter('id', orderIds);
        return;
      } catch (e) {
        // Fallback for offline mode if exception
      }
    }
  }

  Future<void> releaseFolderFromWork(List<String> orderIds) async {
    for (var id in orderIds) {
      await _sync.applyLocalOrderPatch(id, (o) => o.responsiblePerson = '');
    }
    
    if (await _isOnline()) {
      try {
        await supabase
            .from('orders')
            .update({'responsible_person': ''})
            .inFilter('id', orderIds);
        return;
      } catch (e) {
        // Fallback for offline mode if exception
      }
    }
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
    await _sync.applyLocalOrderPatch(id, (o) {
      if (!o.photos.contains(localPath)) {
        o.photos = List<String>.from(o.photos)..add(localPath);
      }
    });
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
        await supabase.from('orders').update({
          'url_photo': OrderModel.encodeList(
            [...(await _fetchPhotoUrls(id)), url],
          ),
        }).eq('id', id);
        return url;
      } catch (e) {
        await _sync.addTask(SyncActionType.addPhoto, id, payload);
        return localPath;
      }
    }

    await _sync.addTask(SyncActionType.addPhoto, id, payload);
    return localPath;
  }

  Future<List<String>> _fetchPhotoUrls(String id) async {
    final row = await supabase
        .from('orders')
        .select('url_photo')
        .eq('id', id)
        .maybeSingle();
    return OrderModel.parseList(row?['url_photo']);
  }

  Future<void> updatePvzQr(String id, String qrCode) async {
    await _sync.applyLocalOrderPatch(id, (o) {
      if (!o.pvzQrCodes.contains(qrCode)) {
        o.pvzQrCodes = List<String>.from(o.pvzQrCodes)..add(qrCode);
      }
    });
    final payload = jsonEncode({'qrCode': qrCode});

    if (await _isOnline()) {
      try {
        await supabase.from('orders').update({
          'pvz_qr_code': OrderModel.encodeList(
            await _fetchPvzQrCodes(id, qrCode),
          ),
        }).eq('id', id);
        return;
      } catch (e) {
        await _sync.addTask(SyncActionType.updatePvzQr, id, payload);
        rethrow;
      }
    }

    await _sync.addTask(SyncActionType.updatePvzQr, id, payload);
  }

  Future<List<String>> _fetchPvzQrCodes(String id, String newCode) async {
    final row = await supabase
        .from('orders')
        .select('pvz_qr_code')
        .eq('id', id)
        .maybeSingle();
    final list = OrderModel.parseList(row?['pvz_qr_code']);
    if (!list.contains(newCode)) list.add(newCode);
    return list;
  }

  Future<void> updateOrderQr(String id, String qrCode) async {
    await _sync.applyLocalOrderPatch(id, (o) {
      if (!o.clientQrCodes.contains(qrCode)) {
        o.clientQrCodes = List<String>.from(o.clientQrCodes)..add(qrCode);
      }
    });
    final payload = jsonEncode({'qrCode': qrCode});

    if (await _isOnline()) {
      try {
        await supabase.from('orders').update({
          'client_qr_code': OrderModel.encodeList(
            await _fetchClientQrCodes(id, qrCode),
          ),
        }).eq('id', id);
        return;
      } catch (e) {
        await _sync.addTask(SyncActionType.updateClientQr, id, payload);
        rethrow;
      }
    }

    await _sync.addTask(SyncActionType.updateClientQr, id, payload);
  }

  Future<List<String>> _fetchClientQrCodes(String id, String newCode) async {
    final row = await supabase
        .from('orders')
        .select('client_qr_code')
        .eq('id', id)
        .maybeSingle();
    final list = OrderModel.parseList(row?['client_qr_code']);
    if (!list.contains(newCode)) list.add(newCode);
    return list;
  }

  Future<void> clearOrderPhoto(String id) async {
    await _sync.applyLocalOrderPatch(id, (o) => o.photos = []);
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
    await _sync.applyLocalOrderPatch(id, (o) => o.clientQrCodes = []);
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

  // --- РАБОТА С МНОЖЕСТВЕННЫМИ ФОТО ---

  Future<String?> addOrderPhoto(
    String id,
    File imageFile,
    List<String> currentPhotos,
  ) async {
    if (await _isOnline()) {
      try {
        final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'order_${id}_$uniqueSuffix.jpg';

        await supabase.storage.from('packages').upload(
          fileName,
          imageFile,
          fileOptions: const FileOptions(upsert: true),
        );

        final updatedPhotos = List<String>.from(currentPhotos)..add(fileName);

        await _sync.applyLocalOrderPatch(id, (o) {
          if (!o.photos.contains(fileName)) {
            o.photos = List<String>.from(o.photos)..add(fileName);
          }
        });

        await supabase.from('orders').update({
          'url_photo': OrderModel.encodeList(updatedPhotos),
        }).eq('id', id);
        return null;
      } catch (e) {
        rethrow;
      }
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final localImage = await imageFile.copy(
        '${dir.path}/offline_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await _sync.applyLocalOrderPatch(id, (o) {
        if (!o.photos.contains(localImage.path)) {
          o.photos = List<String>.from(o.photos)..add(localImage.path);
        }
      });
      await _sync.addTask(
        SyncActionType.addPhotoOffline,
        id,
        localImage.path,
      );
      return 'ОФФЛАЙН: Фото сохранено. Оно будет отправлено при появлении сети.';
    }
  }

  Future<void> removeOrderPhoto(
    String orderId,
    String photoUrl,
    List<String> currentPhotos,
  ) async {
    try {
      final updatedPhotos = List<String>.from(currentPhotos)..remove(photoUrl);

      await _sync.applyLocalOrderPatch(orderId, (o) {
        o.photos = List<String>.from(o.photos)..remove(photoUrl);
      });

      await supabase.from('orders').update({
        'url_photo': OrderModel.encodeList(updatedPhotos),
      }).eq('id', orderId);

      final fileName = photoUrl.split('/').last.split('?').first;
      await supabase.storage.from('packages').remove([fileName]);
    } catch (e) {
      rethrow;
    }
  }

  // --- РАБОТА С МНОЖЕСТВЕННЫМИ QR КОДАМИ ---

  Future<String?> addQrCode(
    String id,
    String code,
    List<String> currentQrs,
    bool isClientQr,
  ) async {
    if (currentQrs.contains(code)) return 'Этот код уже добавлен';

    if (await _isOnline()) {
      final updatedQrs = List<String>.from(currentQrs)..add(code);
      final column = isClientQr ? 'client_qr_code' : 'pvz_qr_code';

      await _sync.applyLocalOrderPatch(id, (o) {
        if (isClientQr) {
          if (!o.clientQrCodes.contains(code)) {
            o.clientQrCodes = List<String>.from(o.clientQrCodes)..add(code);
          }
        } else {
          if (!o.pvzQrCodes.contains(code)) {
            o.pvzQrCodes = List<String>.from(o.pvzQrCodes)..add(code);
          }
        }
      });

      try {
        await supabase.from('orders').update({
          column: OrderModel.encodeList(updatedQrs),
        }).eq('id', id);
        return null;
      } catch (e) {
        return 'Ошибка сохранения: слишком много кодов?';
      }
    } else {
      await _sync.applyLocalOrderPatch(id, (o) {
        if (isClientQr) {
          if (!o.clientQrCodes.contains(code)) {
            o.clientQrCodes = List<String>.from(o.clientQrCodes)..add(code);
          }
        } else {
          if (!o.pvzQrCodes.contains(code)) {
            o.pvzQrCodes = List<String>.from(o.pvzQrCodes)..add(code);
          }
        }
      });
      await _sync.addTask(
        isClientQr ? SyncActionType.addClientQr : SyncActionType.addPvzQr,
        id,
        code,
      );
      return 'ОФФЛАЙН: Штрих-код сохранен. Он будет отправлен при появлении сети.';
    }
  }

  Future<void> removeQrCode(
    String id,
    String code,
    List<String> currentQrs,
    bool isClientQr,
  ) async {
    final updatedQrs = List<String>.from(currentQrs)..remove(code);
    final column = isClientQr ? 'client_qr_code' : 'pvz_qr_code';
    
    await _sync.applyLocalOrderPatch(id, (o) {
      if (isClientQr) {
        o.clientQrCodes = List<String>.from(o.clientQrCodes)..remove(code);
      } else {
        o.pvzQrCodes = List<String>.from(o.pvzQrCodes)..remove(code);
      }
    });

    await supabase.from('orders').update({
      column: OrderModel.encodeList(updatedQrs),
    }).eq('id', id);
  }

  // Метод для сохранения отредактированного заказа
  Future<void> updateOrder(OrderModel order) async {
    await isar.writeTxn(() async {
      await isar.orderModels.put(order);
    });

    final payload = jsonEncode({'order': order.toJson()});

    if (await _isOnline()) {
      try {
        await supabase.from('orders').update(order.toJson()).eq('id', order.id);
        return;
      } catch (e) {
        await _sync.addTask(SyncActionType.updateOrder, order.id, payload);
        rethrow;
      }
    }

    await _sync.addTask(SyncActionType.updateOrder, order.id, payload);
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
