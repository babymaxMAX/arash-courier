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
        backgroundColor: Colors.white,
        title: const Text(
          'Комментарий',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.pink.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Введите комментарий',
              border: InputBorder.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepOrange.shade400,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
