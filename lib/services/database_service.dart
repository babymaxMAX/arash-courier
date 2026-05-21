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
      // SELECT * FROM orders — список Map<String, dynamic>.
      final rawResponse = await supabase.from("orders").select();

      // Результат: ключ папки → список заказов в этой «папке» ПВЗ.
      Map<String, List<OrderModel>> sortedOrders = {};

      // Перебираем каждую строку ответа Supabase.
      for (var order in rawResponse) {
        // Преобразуем JSON строки БД в объект OrderModel.
        final orderModel = OrderModel.fromJson(order);

        // Для курьера скрываем завершённые/отменённые/возвратные заказы.
        if (role == 'courier') {
          if (orderModel.status == 'Выдано' ||
              orderModel.status == 'Отменено' ||
              orderModel.status == 'Возврат') {
            continue; // Пропускаем этот заказ, не добавляем в sortedOrders.
          }
        }

        // Строка-ключ группы: «Название ПВЗ - Адрес».
        final String folderKey = "${orderModel.companyName} - ${orderModel.companyAddress}";

        // ??= создаёт пустой список, если ключа folderKey ещё нет.
        sortedOrders[folderKey] ??= [];
        // Добавляем заказ в список этой группы.
        sortedOrders[folderKey]!.add(orderModel);
      }

      // Возвращаем сгруппированную карту вызывающему коду (HomeScreen).
      return sortedOrders;
    } catch (e) {
      // Вывод ошибки в консоль разработчика.
      print("Error fetching orders: $e");
      // Пробрасываем Exception, чтобы UI показал SnackBar.
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
    }
  }

  // UPDATE orders SET client_payment = amount WHERE id = id.
  Future<void> updateClientPayment(String id, double amount) async {
    try {
      await supabase.from('orders').update({'client_payment': amount}).eq('id', id);

      print('Client payment updated successfully');
    } catch (e) {
      print('Error updating client payment: $e');
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
    }
  }

  // Загружает файл в Storage bucket packages и пишет публичный URL в orders.url_photo.
  Future<String?> uploadOrderPhoto(String id, File imageFile) async {
    try {
      final fileName = 'order_${id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('packages').upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final baseUrl =
          supabase.storage.from('packages').getPublicUrl(fileName);
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
    }
  }

  // Меняет статус заказа (например READY, SHIPPING — англ. в БД).
  Future<void> updateOrderStatus(String id, String status) async {
    try {
      await supabase
          .from('orders')
          .update({'status': status})
          .eq('id', id);

      print('Order status updated successfully');
    } catch (e) {
      print('Error updating order status: $e');
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
