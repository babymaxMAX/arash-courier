// Immutable-модель одного заказа курьера (данные из Supabase / UI).
class OrderModel {
  final String id; // UUID или строковый id строки в таблице orders.
  final DateTime dateCreated; // Когда заказ создан (сортировка «новые сверху»).
  final DateTime dateUpdated; // Последнее изменение (конфликты синхронизации).

  final String companyName; // Название ПВЗ / компании-отправителя.
  final String companyAddress; // Адрес точки выдачи / сбора.
  final String responsiblePerson; // Курьер или менеджер, закреплённый за адресом.

  final String clientName; // ФИО или имя получателя.
  final String deliveryCity; // Город доставки (группировка на HomeScreen).

  final String pvzQrCode; // QR со склада / ПВЗ (текст или URL).
  final String clientQrCode; // QR, отсканированный у клиента.
  final String urlPhoto; // Публичная ссылка на фото посылки в Storage.

  final String status; // Статус на русском после _translateStatus.
  final String? comment; // Заметка курьера (может быть null).
  final String? cancelReason; // Причина отмены/отложения (может быть null).

  final double clientPayment; // Сумма оплаты за товар.
  final double debtAmount; // Долг клиента.
  final double deliveryPrice; // Стоимость доставки.
  final double pointsDeduction; // Списание бонусных баллов.

  // Итог к оплате: товар + долг + доставка − баллы.
  double get totalAmount => (clientPayment + debtAmount + deliveryPrice) - pointsDeduction;

  // Именованный конструктор: все обязательные поля через required.
  OrderModel({
    required this.id,
    required this.dateCreated,
    required this.dateUpdated,
    required this.companyName,
    required this.companyAddress,
    required this.responsiblePerson,
    required this.clientName,
    required this.deliveryCity,
    required this.pvzQrCode,
    required this.clientQrCode,
    required this.urlPhoto,
    required this.status,
    this.comment,
    this.cancelReason,
    required this.clientPayment,
    required this.debtAmount,
    required this.deliveryPrice,
    required this.pointsDeduction,
  });

  // Копия объекта с подстановкой только переданных полей (остальные из this).
  OrderModel copyWith({
    String? id,
    DateTime? dateCreated,
    DateTime? dateUpdated,
    String? companyName,
    String? companyAddress,
    String? responsiblePerson,
    String? clientName,
    String? deliveryCity,
    String? pvzQrCode,
    String? clientQrCode,
    String? urlPhoto,
    String? status,
    String? comment,
    String? cancelReason,
    double? clientPayment,
    double? debtAmount,
    double? deliveryPrice,
    double? pointsDeduction,
  }) {
    return OrderModel(
      id: id ?? this.id,
      dateCreated: dateCreated ?? this.dateCreated,
      dateUpdated: dateUpdated ?? this.dateUpdated,
      companyName: companyName ?? this.companyName,
      companyAddress: companyAddress ?? this.companyAddress,
      responsiblePerson: responsiblePerson ?? this.responsiblePerson,
      clientName: clientName ?? this.clientName,
      deliveryCity: deliveryCity ?? this.deliveryCity,
      pvzQrCode: pvzQrCode ?? this.pvzQrCode,
      clientQrCode: clientQrCode ?? this.clientQrCode,
      urlPhoto: urlPhoto ?? this.urlPhoto,
      status: status ?? this.status,
      comment: comment ?? this.comment,
      cancelReason: cancelReason ?? this.cancelReason,
      clientPayment: clientPayment ?? this.clientPayment,
      debtAmount: debtAmount ?? this.debtAmount,
      deliveryPrice: deliveryPrice ?? this.deliveryPrice,
      pointsDeduction: pointsDeduction ?? this.pointsDeduction,
    );
  }

  // Фабрика: создаёт OrderModel из Map (строка JSON из PostgREST).
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? 'ОШИБКА_ID',
      dateCreated: json['date_created'] != null
          ? DateTime.parse(json['date_created'])
          : DateTime.now(),
      dateUpdated: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      companyName: json['company_name'] ?? 'Неизвестная компания',
      companyAddress: json['company_address'] ?? 'Адрес не указан',
      responsiblePerson: json['responsible_person'] ?? '',
      clientName: json['client_name'] ?? 'Без имени',
      deliveryCity: json['delivery_city'] ?? '',
      pvzQrCode: json['pvz_qr_code'] ?? '',
      clientQrCode: json['client_qr_code'] ?? '',
      urlPhoto: json['url_photo'] ?? '',
      status: _translateStatus(json['status'] ?? 'New'),
      comment: json['comment'],
      cancelReason: json['cancel_reason'],
      clientPayment: (json['client_payment'] as num?)?.toDouble() ?? 0.0,
      debtAmount: (json['debt_amount'] as num?)?.toDouble() ?? 0.0,
      deliveryPrice: (json['delivery_price'] as num?)?.toDouble() ?? 0.0,
      pointsDeduction: (json['points_deduction'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Переводит английские коды статуса из БД в русские подписи для UI.
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
        if (englishStatus == 'Готово' || englishStatus == 'Отложено' || englishStatus == 'Новый') {
          return englishStatus;
        }
        return englishStatus;
    }
  }

  // Обратное преобразование модели в Map для insert/update в Supabase.
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
      'pvz_qr_code': pvzQrCode,
      'client_qr_code': clientQrCode,
      'url_photo': urlPhoto,
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
