import 'package:flutter/material.dart';

class StatusStyle {
  final Color background;
  final Color foreground;
  final IconData icon;

  const StatusStyle({
    required this.background,
    required this.foreground,
    required this.icon,
  });
}

StatusStyle statusStyleFor(String status) {
  switch (status) {
    case 'Готово':
      return StatusStyle(
        background: const Color(0xFFE8F5E9),
        foreground: const Color(0xFF2E7D32),
        icon: Icons.check_circle_rounded,
      );
    case 'В пути':
      return StatusStyle(
        background: const Color(0xFFE3F2FD),
        foreground: const Color(0xFF1565C0),
        icon: Icons.local_shipping_rounded,
      );
    case 'Отложено':
      return StatusStyle(
        background: const Color(0xFFFFF3E0),
        foreground: const Color(0xFFE65100),
        icon: Icons.schedule_rounded,
      );
    case 'Новый':
      return StatusStyle(
        background: const Color(0xFFF3E5F5),
        foreground: const Color(0xFF6A1B9A),
        icon: Icons.fiber_new_rounded,
      );
    case 'Отменено':
    case 'Возврат':
      return StatusStyle(
        background: const Color(0xFFFFEBEE),
        foreground: const Color(0xFFC62828),
        icon: Icons.cancel_rounded,
      );
    default:
      return StatusStyle(
        background: const Color(0xFFECEFF1),
        foreground: const Color(0xFF455A64),
        icon: Icons.info_outline_rounded,
      );
  }
}

Widget buildStatusChip(String status) {
  final style = statusStyleFor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: style.background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(style.icon, size: 14, color: style.foreground),
        const SizedBox(width: 4),
        Text(
          status,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: style.foreground,
          ),
        ),
      ],
    ),
  );
}
