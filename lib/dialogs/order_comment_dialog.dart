import 'package:flutter/material.dart';
import 'package:arash_curier/services/database_service.dart';
import 'package:arash_curier/utils/app_snackbar.dart';

class OrderCommentDialog {
  static Future<void> show(
    BuildContext context, {
    required String orderId,
    required String initialComment,
    required VoidCallback onSaved,
  }) async {
    final controller = TextEditingController(text: initialComment);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Комментарий'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Введите комментарий',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await DatabaseService()
                    .updateOrderComment(orderId, controller.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  showAppSnackBar(context, 'Комментарий сохранён');
                  onSaved();
                }
              } catch (e) {
                if (context.mounted) {
                  showAppSnackBar(context, 'Ошибка сохранения', isError: true);
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
