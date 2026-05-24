// UI Flutter.
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:arash_curier/utils/app_snackbar.dart';

/// Сканирование через снимок с камеры (без live-preview — стабильнее на iOS).
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final _manualController = TextEditingController();
  final _picker = ImagePicker();
  bool _busy = false;

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _scanWithCamera() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (!mounted) return;
      if (file == null) return;

      final controller = MobileScannerController();
      try {
        final capture = await controller.analyzeImage(file.path);
        if (!mounted) return;

        final codes = capture?.barcodes ?? const <Barcode>[];
        for (final barcode in codes) {
          final value = barcode.rawValue?.trim();
          if (value != null && value.isNotEmpty) {
            Navigator.pop(context, value);
            return;
          }
        }

        showAppSnackBar(
          context,
          'Штрих-код не найден. Попробуйте ближе к коду или введите вручную.',
          isError: true,
        );
      } finally {
        await controller.dispose();
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Камера недоступна: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanFromGallery() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (file == null) return;

      final controller = MobileScannerController();
      try {
        final capture = await controller.analyzeImage(file.path);
        if (!mounted) return;

        final codes = capture?.barcodes ?? const <Barcode>[];
        for (final barcode in codes) {
          final value = barcode.rawValue?.trim();
          if (value != null && value.isNotEmpty) {
            Navigator.pop(context, value);
            return;
          }
        }

        showAppSnackBar(context, 'Штрих-код не найден на фото.', isError: true);
      } finally {
        await controller.dispose();
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Не удалось открыть галерею: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submitManual() {
    final value = _manualController.text.trim();
    if (value.isEmpty) {
      showAppSnackBar(context, 'Введите код вручную', isError: true);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать штрих-код'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.qr_code_scanner, size: 72, color: Colors.deepOrange),
                const SizedBox(height: 16),
                const Text(
                  'Наведите камеру на штрих-код и сделайте снимок. '
                  'iOS покажет запрос доступа к камере при первом использовании.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _scanWithCamera,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Сфотографировать код'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _scanFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Выбрать из галереи'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Или введите код вручную',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _manualController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Номер штрих-кода',
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitManual(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _submitManual,
                  child: const Text('Готово'),
                ),
              ],
            ),
    );
  }
}
