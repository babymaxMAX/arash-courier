// File — работа с файлами на устройстве (фото перед загрузкой в Storage).
import 'dart:io';
// Клиент Supabase (PostgREST, Storage).
import 'package:supabase_flutter/supabase_flutter.dart';
// Модель заказа для типизации данных из БД.
import 'package:arash_curier/models/order_model.dart';

// Сервис CRUD-операций с таблицей orders и bucket packages в Storage.
class DatabaseService {
  // Единый клиент, созданный при Supabase.initialize в main().
  final supabase = Supabase.instance.client;

  // Загружает заказы, группирует по «компания - адрес»; role влияет на фильтр статусов.
  Future<Map<String, List<OrderModel>>> fetchAndSortOrders(String role) async {
    try {
      var query = supabase.from("orders").select();

      // Фильтруем прямо в запросе к БД
      if (role == 'courier') {
        query = query.not('status', 'in', '("Выдано", "Отменено", "Возврат", "ISSUED", "CANCELLED", "CANCELED", "RETURN", "RETURNED")');
      }

      final rawResponse = await query;
      Map<String, List<OrderModel>> sortedOrders = {};

      for (var order in rawResponse) {
        final orderModel = OrderModel.fromJson(order);
        final String folderKey = "${orderModel.companyName} - ${orderModel.companyAddress}";

        sortedOrders[folderKey] ??= [];
        sortedOrders[folderKey]!.add(orderModel);
      }

      return sortedOrders;
    } catch (e) {
      print("Error fetching orders: $e");
      throw Exception('Failed to fetch orders: $e');
    }
  }

  // UPDATE orders SET comment = text WHERE id = id.
  Future<void> updateOrderComment(String id, String text) async {
    try {
      await supabase.from('orders').update({'comment': text}).eq('id', id);

      print('Order comment updated successfully');
    } catch (e) {
      print('Error updating order comment: $e');
      rethrow;
    }
  }

  // UPDATE orders SET client_payment = amount WHERE id = id.
  Future<void> updateClientPayment(String id, double amount) async {
    try {
      await supabase.from('orders').update({'client_payment': amount}).eq('id', id);

      print('Client payment updated successfully');
    } catch (e) {
      print('Error updating client payment: $e');
      rethrow;
    }
  }

  // Ставит статус delayed и сохраняет причину в cancel_reason.
  Future<void> delayOrder(String id, String reason) async {
    try {
      await supabase.from('orders').update({
        'status': 'delayed', // Английское значение в БД (переводится при чтении).
        'cancel_reason': reason // Текст причины отложения.
      }).eq('id', id);

      print('Order delayed successfully');
    } catch (e) {
      print('Error delaying order: $e');
      rethrow;
    }
  }

  // Загружает файл в Storage bucket packages и пишет публичный URL в orders.url_photo.
  Future<String?> uploadOrderPhoto(String id, File imageFile) async {
    try {
      // Жестко привязываем имя к ID заказа (без миллисекунд)
      final fileName = 'order_$id.jpg';

      await supabase.storage.from('packages').upload(
        fileName,
        imageFile,
        fileOptions: const FileOptions(upsert: true),
      );

      final baseUrl = supabase.storage.from('packages').getPublicUrl(fileName);
      // Миллисекунды оставляем только в ссылке (URL), чтобы сбрасывать кэш картинок в приложении
      final publicUrl = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await supabase
          .from('orders')
          .update({'url_photo': publicUrl})
          .eq('id', id);

      print('Order photo uploaded successfully');
      return publicUrl;
    } catch (e) {
      print('Error uploading order photo: $e');
      rethrow;
    }
  }

  // UPDATE client_qr_code после сканирования QR на экране курьера.
  Future<void> updateOrderQr(String id, String qrCode) async {
    try {
      await supabase
          .from('orders')
          .update({'client_qr_code': qrCode})
          .eq('id', id);

      print('Order QR updated successfully');
    } catch (e) {
      print('Error updating order QR: $e');
      rethrow;
    }
  }

  // Очищает поле url_photo (пустая строка вместо null).
  Future<void> clearOrderPhoto(String id) async {
    try {
      await supabase
          .from('orders')
          .update({'url_photo': ''})
          .eq('id', id);

      print('Order photo cleared successfully');
    } catch (e) {
      print('Error clearing order photo: $e');
      rethrow;
    }
  }

  // Очищает сохранённый QR клиента.
  Future<void> clearOrderQr(String id) async {
    try {
      await supabase
          .from('orders')
          .update({'client_qr_code': ''})
          .eq('id', id);

      print('Order QR cleared successfully');
    } catch (e) {
      print('Error clearing order QR: $e');
      rethrow;
    }
  }

  // Меняет статус заказа (например READY, SHIPPING — англ. в БД).
  Future<void> updateOrderStatus(String id, String status) async {
    try {
      await supabase.from('orders').update({'status': status}).eq('id', id);
      print('Order status updated successfully');
    } catch (e) {
      print('Error updating order status: $e');
      rethrow; // <-- ПРОСТО ДОБАВЬ ЭТУ СТРОКУ ВО ВСЕ ПОДОБНЫЕ МЕТОДЫ
    }
  }

  // INSERT новой строки из JSON модели (toJson).
  Future<void> createOrder(OrderModel order) async {
    try {
      await supabase.from('orders').insert(order.toJson());
      print('Order created successfully');
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }
}
