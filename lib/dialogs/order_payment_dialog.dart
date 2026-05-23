import 'package:flutter/material.dart';
import 'package:arash_curier/services/database_service.dart';
import 'package:arash_curier/utils/app_snackbar.dart';

class OrderPaymentDialog {
  static Future<void> show(
    BuildContext context, {
    required String orderId,
    required double initialAmount, // Текущая сумма оплаты
    required VoidCallback onSaved,
  }) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить оплату'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (initialAmount > 0)
              Text('Уже оплачено: ${initialAmount.toStringAsFixed(0)} ₽', 
                   style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Новая сумма (₽)',
                prefixIcon: const Icon(Icons.payments_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700, 
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newAmount = double.tryParse(controller.text.replaceAll(',', '.'));
              if (newAmount == null || newAmount <= 0) {
                showAppSnackBar(context, 'Введите корректную сумму', isError: true);
                return;
              }
              // Суммируем старую и новую оплату строго по ТЗ
              final totalAmount = initialAmount + newAmount;

              try {
                await DatabaseService().updateClientPayment(orderId, totalAmount);
                if (!context.mounted) return;
                Navigator.pop(ctx);
                onSaved();
              } catch (e) {
                showAppSnackBar(context, 'Ошибка: $e', isError: true);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}