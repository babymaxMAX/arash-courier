import 'package:flutter/material.dart';
import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/screens/chat_screen.dart';
import 'package:arash_curier/dialogs/order_comment_dialog.dart';
import 'package:arash_curier/dialogs/order_delay_dialog.dart';
import 'package:arash_curier/dialogs/order_payment_dialog.dart';

class OrderBottomSheet {
  static Future<void> show(
    BuildContext context, {
    required OrderModel order,
    required VoidCallback onRefresh,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  order.clientName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _SheetTile(
                icon: Icons.chat_bubble_outline,
                color: const Color(0xFF00897B),
                title: 'Чат',
                subtitle: 'Переписка по заказу',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatScreen(),
                    ),
                  );
                },
              ),
              _SheetTile(
                icon: Icons.comment_rounded,
                color: const Color(0xFF5C6BC0),
                title: 'Комментарий',
                subtitle: order.comment?.isNotEmpty == true
                    ? order.comment
                    : 'Добавить заметку',
                onTap: () {
                  Navigator.pop(ctx);
                  OrderCommentDialog.show(
                    context,
                    orderId: order.id,
                    initialComment: order.comment ?? '',
                    onSaved: onRefresh,
                  );
                },
              ),
              _SheetTile(
                icon: Icons.schedule_rounded,
                color: const Color(0xFFE65100),
                title: 'Отложить',
                subtitle: 'Указать причину',
                onTap: () {
                  Navigator.pop(ctx);
                  OrderDelayDialog.show(
                    context,
                    orderId: order.id,
                    onSaved: onRefresh,
                  );
                },
              ),
              _SheetTile(
                icon: Icons.payments_rounded,
                color: const Color(0xFF2E7D32),
                title: 'Оплата',
                subtitle: '${order.clientPayment.toStringAsFixed(0)} ₽',
                onTap: () {
                  Navigator.pop(ctx);
                  OrderPaymentDialog.show(
                    context,
                    orderId: order.id,
                    initialAmount: order.clientPayment,
                    onSaved: onRefresh,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}
