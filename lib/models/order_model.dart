// Immutable-модель одного заказа курьера (данные из Supabase / UI).
class OrderModel {
  final String id;
  final DateTime dateCreated;
  final DateTime dateUpdated;

  final String companyName;
  final String companyAddress;
  final String responsiblePerson;

  final String clientName;
  final String deliveryCity;

  final String pvzQrCode;
  final String clientQrCode;
  final String urlPhoto;

  final String status;
  final String? comment;
  final String? cancelReason;

  final double clientPayment;
  final double debtAmount;
  final double deliveryPrice;
  final double pointsDeduction;

  double get totalAmount =>
      (clientPayment + debtAmount + deliveryPrice) - pointsDeduction;

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

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id']?.toString() ?? 'ОШИБКА_ID',
      dateCreated: json['date_created'] != null
          ? DateTime.parse(json['date_created'])
          : DateTime.now(),
      dateUpdated: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : (json['date_updated'] != null
              ? DateTime.parse(json['date_updated'])
              : DateTime.now()),
      companyName: json['company_name'] ?? 'Неизвестная компания',
      companyAddress: json['company_address'] ?? 'Адрес не указан',
      responsiblePerson: json['responsible_person'] ?? '',
      clientName: json['client_name'] ?? 'Без имени',
      deliveryCity: json['delivery_city'] ?? '',
      pvzQrCode: json['pvz_qr_code'] ?? '',
      clientQrCode: json['client_qr_code'] ?? '',
      urlPhoto: json['url_photo'] ?? '',
      status: _translateStatus(json['status']?.toString() ?? 'New'),
      comment: json['comment'],
      cancelReason: json['cancel_reason'],
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
