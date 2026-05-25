import 'dart:convert';

import 'package:isar_community/isar.dart';

part 'order_model.g.dart';

/// Локальная + серверная модель заказа (Isar + Supabase).
@Collection()
class OrderModel {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  late DateTime dateCreated;
  late DateTime dateUpdated;

  late String companyName;
  late String companyAddress;
  late String responsiblePerson;

  late String clientName;
  late String deliveryCity;

  /// Список URL фото (в Supabase — JSON-массив в колонке url_photo).
  List<String> photos = [];

  /// QR-коды клиента.
  List<String> clientQrCodes = [];

  /// QR-коды ПВЗ.
  List<String> pvzQrCodes = [];

  late String status;
  String? comment;
  String? cancelReason;

  late double clientPayment;
  late double debtAmount;
  late double deliveryPrice;
  late double pointsDeduction;

  double get totalAmount =>
      (clientPayment + debtAmount + deliveryPrice) - pointsDeduction;

  OrderModel();

  /// Парсит старый формат (одна строка) и новый (JSON-массив).
  static List<String> parseList(dynamic value) {
    if (value == null) return [];
    if (value is String) {
      if (value.startsWith('[')) {
        try {
          return List<String>.from(jsonDecode(value));
        } catch (_) {}
      }
      if (value.isNotEmpty) return [value];
      return [];
    }
    if (value is List) {
      return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  static String encodeList(List<String> items) {
    final cleaned =
        items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (cleaned.isEmpty) return '';
    return jsonEncode(cleaned);
  }

  factory OrderModel.create({
    required String id,
    required DateTime dateCreated,
    required DateTime dateUpdated,
    required String companyName,
    required String companyAddress,
    required String responsiblePerson,
    required String clientName,
    required String deliveryCity,
    List<String>? photos,
    List<String>? clientQrCodes,
    List<String>? pvzQrCodes,
    required String status,
    String? comment,
    String? cancelReason,
    required double clientPayment,
    required double debtAmount,
    required double deliveryPrice,
    required double pointsDeduction,
  }) {
    return OrderModel()
      ..id = id
      ..dateCreated = dateCreated
      ..dateUpdated = dateUpdated
      ..companyName = companyName
      ..companyAddress = companyAddress
      ..responsiblePerson = responsiblePerson
      ..clientName = clientName
      ..deliveryCity = deliveryCity
      ..photos = photos ?? []
      ..clientQrCodes = clientQrCodes ?? []
      ..pvzQrCodes = pvzQrCodes ?? []
      ..status = status
      ..comment = comment
      ..cancelReason = cancelReason
      ..clientPayment = clientPayment
      ..debtAmount = debtAmount
      ..deliveryPrice = deliveryPrice
      ..pointsDeduction = pointsDeduction;
  }

  OrderModel copyWith({
    String? id,
    DateTime? dateCreated,
    DateTime? dateUpdated,
    String? companyName,
    String? companyAddress,
    String? responsiblePerson,
    String? clientName,
    String? deliveryCity,
    List<String>? photos,
    List<String>? clientQrCodes,
    List<String>? pvzQrCodes,
    String? status,
    String? comment,
    String? cancelReason,
    double? clientPayment,
    double? debtAmount,
    double? deliveryPrice,
    double? pointsDeduction,
  }) {
    return OrderModel.create(
      id: id ?? this.id,
      dateCreated: dateCreated ?? this.dateCreated,
      dateUpdated: dateUpdated ?? this.dateUpdated,
      companyName: companyName ?? this.companyName,
      companyAddress: companyAddress ?? this.companyAddress,
      responsiblePerson: responsiblePerson ?? this.responsiblePerson,
      clientName: clientName ?? this.clientName,
      deliveryCity: deliveryCity ?? this.deliveryCity,
      photos: photos ?? List<String>.from(this.photos),
      clientQrCodes: clientQrCodes ?? List<String>.from(this.clientQrCodes),
      pvzQrCodes: pvzQrCodes ?? List<String>.from(this.pvzQrCodes),
      status: status ?? this.status,
      comment: comment ?? this.comment,
      cancelReason: cancelReason ?? this.cancelReason,
      clientPayment: clientPayment ?? this.clientPayment,
      debtAmount: debtAmount ?? this.debtAmount,
      deliveryPrice: deliveryPrice ?? this.deliveryPrice,
      pointsDeduction: pointsDeduction ?? this.pointsDeduction,
    );
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel.create(
      id: json['id']?.toString() ?? 'ОШИБКА_ID',
      dateCreated: json['date_created'] != null
          ? (DateTime.tryParse(json['date_created'].toString()) ?? DateTime.now())
          : DateTime.now(),
      dateUpdated: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now())
          : (json['date_updated'] != null
              ? (DateTime.tryParse(json['date_updated'].toString()) ??
                  DateTime.now())
              : DateTime.now()),
      companyName: json['company_name'] ?? 'Неизвестная компания',
      companyAddress: json['company_address'] ?? 'Адрес не указан',
      responsiblePerson: json['responsible_person'] ?? '',
      clientName: json['client_name'] ?? 'Без имени',
      deliveryCity: json['delivery_city'] ?? '',
      photos: parseList(json['url_photo']),
      clientQrCodes: parseList(json['client_qr_code']),
      pvzQrCodes: parseList(json['pvz_qr_code']),
      status: _translateStatus(json['status']?.toString() ?? 'New'),
      comment: json['comment']?.toString(),
      cancelReason: json['cancel_reason']?.toString(),
      clientPayment: (json['client_payment'] as num?)?.toDouble() ?? 0.0,
      debtAmount: (json['debt_amount'] as num?)?.toDouble() ?? 0.0,
      deliveryPrice: (json['delivery_price'] as num?)?.toDouble() ?? 0.0,
      pointsDeduction: (json['points_deduction'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static String _translateStatus(String englishStatus) {
    switch (englishStatus.toUpperCase()) {
      case 'READY':
        return 'Готово';
      case 'WAITING':
        return 'Ожидает';
      case 'ISSUED':
        return 'Выдано';
      case 'SHIPPING':
        return 'В пути';
      case 'CANCELLED':
      case 'CANCELED':
        return 'Отменено';
      case 'RETURN':
      case 'RETURNED':
        return 'Возврат';
      case 'DEBT':
        return 'Долг';
      case 'NEW':
        return 'Новый';
      case 'IN_PROGRESS':
      case 'IN PROGRESS':
        return 'В пути';
      case 'DELIVERED':
        return 'Доставлено';
      case 'COMPLETED':
      case 'DONE':
        return 'Готово';
      case 'DELAYED':
      case 'POSTPONED':
        return 'Отложено';
      default:
        if (englishStatus == 'Готово' ||
            englishStatus == 'Отложено' ||
            englishStatus == 'Новый') {
          return englishStatus;
        }
        return englishStatus;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date_created': dateCreated.toIso8601String(),
      'date_updated': dateUpdated.toIso8601String(),
      'company_name': companyName,
      'company_address': companyAddress,
      'responsible_person': responsiblePerson,
      'client_name': clientName,
      'delivery_city': deliveryCity,
      'url_photo': encodeList(photos),
      'client_qr_code': encodeList(clientQrCodes),
      'pvz_qr_code': encodeList(pvzQrCodes),
      'status': status,
      'comment': comment,
      'cancel_reason': cancelReason,
      'client_payment': clientPayment,
      'debt_amount': debtAmount,
      'delivery_price': deliveryPrice,
      'points_deduction': pointsDeduction,
    };
  }
}
