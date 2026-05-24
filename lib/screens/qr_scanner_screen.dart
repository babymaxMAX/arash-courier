// UI Flutter.
import 'package:flutter/material.dart';
// Пакет сканирования штрих-/QR-кодов через камеру.
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:arash_curier/utils/camera_permission.dart';

// Экран камеры; результат — Navigator.pop(context, строка QR).
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

// Состояние экрана сканера (контроллер камеры, флаг однократного считывания).
class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController? controller;

  // true после первого успешного скана — блокирует повторные pop.
  bool isScanned = false;

  bool _loading = true;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final granted = await ensureCameraPermission(context);
    if (!mounted) return;

    if (!granted) {
      setState(() {
        _loading = false;
        _denied = true;
      });
      return;
    }

    controller = MobileScannerController(
      formats: const [BarcodeFormat.all],
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
    );

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать штрих-код'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_denied || controller == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Нет доступа к камере',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Разрешите камеру в настройках iPhone, затем откройте сканер снова.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  await ensureCameraPermission(context);
                  if (!mounted) return;
                  setState(() {
                    _loading = true;
                    _denied = false;
                  });
                  await _initCamera();
                },
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    return MobileScanner(
      controller: controller!,
      onDetect: (capture) {
        if (!isScanned) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              isScanned = true;
              Navigator.pop(context, barcode.rawValue);
              break;
            }
          }
        }
      },
    );
  }
}
