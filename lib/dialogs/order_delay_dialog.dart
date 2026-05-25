import 'package:flutter/material.dart';
import 'package:arash_curier/services/database_service.dart';
import 'package:arash_curier/utils/app_snackbar.dart';

class OrderDelayDialog {
  static const _reasons = [
    'Не дозвонился',
    'Повреждена упаковка',
    'Оставил на складе',
    'Другое',
  ];

  static Future<void> show(
    BuildContext context, {
    required String orderId,
    required VoidCallback onSaved,
  }) async {
    String? selectedReason;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Отложить заказ'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Укажите причину:'),
              const SizedBox(height: 12),
              ..._reasons.map(
                (reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (val) => setState(() => selectedReason = val),
                  contentPadding: EdgeInsets.zero,
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
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (selectedReason == null) {
                  showAppSnackBar(context, 'Выберите причину', isError: true);
                  return;
                }
                try {
                  await DatabaseService().delayOrder(orderId, selectedReason!);
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  showAppSnackBar(context, 'Заказ отложен');
                  onSaved();
                } catch (e) {
                  if (context.mounted) {
                    showAppSnackBar(context, 'Ошибка: $e', isError: true);
                  }
                }
              },
              child: const Text('Отложить'),
            ),
          ],
        ),
      ),
    );
  }
}
