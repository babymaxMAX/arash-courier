// UI Flutter.
import 'package:flutter/material.dart';
// Пакет сканирования штрих-/QR-кодов через камеру.
import 'package:mobile_scanner/mobile_scanner.dart';

// Экран камеры; результат — Navigator.pop(context, строка QR).
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

// Состояние экрана сканера (контроллер камеры, флаг однократного считывания).
class _QRScannerScreenState extends State<QRScannerScreen> {
  // late — инициализируем в initState до первого использования.
  late MobileScannerController controller;

  // true после первого успешного скана — блокирует повторные pop.
  bool isScanned = false;

  @override
  void initState() {
    super.initState(); // Обязательный вызов родителя State.

    // Создаём контроллер с настройками камеры и форматов кодов.
    controller = MobileScannerController(
      formats: const [BarcodeFormat.all], // Все поддерживаемые форматы штрихкодов.
      facing: CameraFacing.back, // Задняя камера телефона.
      detectionSpeed: DetectionSpeed.normal, // Баланс скорости и нагрузки на CPU.
    );
  }

  @override
  void dispose() {
    controller.dispose(); // Освобождаем камеру и нативные ресурсы.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать штрих-код'), // Заголовок в AppBar.
        backgroundColor: Colors.deepOrange, // Фон полосы сверху.
        foregroundColor: Colors.white, // Цвет текста и иконок AppBar.
      ),
      body: MobileScanner(
        controller: controller, // Привязка нашего контроллера к виджету превью.
        onDetect: (capture) {
          // Обрабатываем только если ещё не вернули результат.
          if (!isScanned) {
            final List<Barcode> barcodes = capture.barcodes; // Список найденных кодов в кадре.
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                isScanned = true; // Блокируем повторное срабатывание.
                Navigator.pop(context, barcode.rawValue); // Возврат строки QR на HomeScreen.
                break; // Достаточно первого валидного кода.
              }
            }
          }
        },
      ),
    );
  }
}
