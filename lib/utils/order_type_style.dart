import 'package:flutter/material.dart';

/// Визуальный стиль вида заявки (доставка/возврат/отправка) — значок и цвет,
/// показывается на карточке заказа, чтобы сразу было видно, куда идёт заказ.
/// Значки — картинки, присланные клиентом (assets/icons/type_*.png).
class OrderTypeStyle {
  final String label;
  final String assetPath;
  final Color color;

  const OrderTypeStyle({
    required this.label,
    required this.assetPath,
    required this.color,
  });
}

OrderTypeStyle getOrderTypeStyle(String orderType) {
  switch (orderType) {
    case 'RETURN':
      return const OrderTypeStyle(
        label: 'Возврат',
        assetPath: 'assets/icons/type_return.png',
        color: Color(0xFF1976D2),
      );
    case 'SHIPMENT':
      return const OrderTypeStyle(
        label: 'Отправка',
        assetPath: 'assets/icons/type_shipment.png',
        color: Color(0xFFF57C00),
      );
    default:
      return const OrderTypeStyle(
        label: 'Доставка',
        assetPath: 'assets/icons/type_delivery.png',
        color: Color(0xFF2E7D32),
      );
  }
}
