import 'package:flutter/material.dart';
import 'package:arash_curier/services/database_service.dart';
import 'package:arash_curier/utils/app_snackbar.dart';

class OrderPaymentDialog {
  static Future<void> show(
    BuildContext context, {
    required String orderId,
    required double initialAmount,
    required VoidCallback onSaved,
  }) async {
    final controller =
        TextEditingController(text: initialAmount.toString());

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Оплата клиента'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Сумма (₽)',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text.trim());
              if (amount == null) {
                showAppSnackBar(context, 'Введите число', isError: true);
                return;
              }
              try {
                await DatabaseService()
                    .updateClientPayment(orderId, amount);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  showAppSnackBar(context, 'Оплата обновлена');
                  onSaved();
                }
              } catch (e) {
                if (context.mounted) {
                  showAppSnackBar(context, 'Ошибка', isError: true);
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
