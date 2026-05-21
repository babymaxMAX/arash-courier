import 'package:flutter/material.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isError ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
      duration: const Duration(seconds: 3),
    ),
  );
}
