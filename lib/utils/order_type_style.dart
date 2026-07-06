import 'package:flutter/material.dart';

/// Визуальный стиль вида заявки (доставка/возврат/отправка) — значок и цвет,
/// показывается на карточке заказа, чтобы сразу было видно, куда идёт заказ.
class OrderTypeStyle {
  final String label;
  final IconData icon;
  final Color color;

  const OrderTypeStyle({
    required this.label,
    required this.icon,
    required this.color,
  });
}

OrderTypeStyle getOrderTypeStyle(String orderType) {
  switch (orderType) {
    case 'RETURN':
      return const OrderTypeStyle(
        label: 'Возврат',
        icon: Icons.assignment_return_rounded,
        color: Color(0xFF1976D2),
      );
    case 'SHIPMENT':
      return const OrderTypeStyle(
        label: 'Отправка',
        icon: Icons.outbox_rounded,
        color: Color(0xFFF57C00),
      );
    default:
      return const OrderTypeStyle(
        label: 'Доставка',
        icon: Icons.local_shipping_rounded,
        color: Color(0xFF2E7D32),
      );
  }
}
