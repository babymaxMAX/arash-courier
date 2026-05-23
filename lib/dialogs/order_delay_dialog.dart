import 'package:flutter/material.dart';
import 'package:arash_curier/services/database_service.dart';
import 'package:arash_curier/utils/app_snackbar.dart';

class OrderDelayDialog {
  static const _reasons = [
    'Клиент не отвечает',
    'Нет доступа к адресу',
    'Перенос на завтра',
    'Другое',
  ];

  static Future<void> show(
    BuildContext context, {
    required String orderId,
    required VoidCallback onSaved,
  }) async {
    String selected = _reasons.first;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Отложить заказ'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Причина'),
            items: _reasons
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) {
              if (v != null) setDialogState(() => selected = v);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await DatabaseService().delayOrder(orderId, selected);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    showAppSnackBar(context, 'Заказ отложен');
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
      ),
    );
  }
}
