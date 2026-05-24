import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:arash_curier/utils/app_snackbar.dart';

/// Запрашивает доступ к камере до открытия ImagePicker / MobileScanner.
Future<bool> ensureCameraPermission(BuildContext context) async {
  var status = await Permission.camera.status;

  if (status.isGranted) {
    return true;
  }

  if (status.isDenied) {
    status = await Permission.camera.request();
    if (status.isGranted) {
      return true;
    }
  }

  if (!context.mounted) {
    return false;
  }

  if (status.isPermanentlyDenied || status.isRestricted) {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Нужен доступ к камере'),
        content: const Text(
          'Разрешите доступ к камере в настройках iPhone для фото посылок и сканирования штрих-кодов.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Настройки'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await openAppSettings();
    }
    return false;
  }

  showAppSnackBar(context, 'Доступ к камере не предоставлен', isError: true);
  return false;
}
