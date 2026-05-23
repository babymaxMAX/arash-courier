import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/services/database_service.dart';
import 'package:arash_curier/screens/qr_scanner_screen.dart';
import 'package:arash_curier/dialogs/order_bottom_sheet.dart';
import 'package:arash_curier/utils/status_style.dart';
import 'package:arash_curier/utils/app_snackbar.dart';

class OrderTileWidget extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onRefresh;

  const OrderTileWidget({
    super.key,
    required this.order,
    required this.onRefresh,
  });

  @override
  State<OrderTileWidget> createState() => _OrderTileWidgetState();
}

class _OrderTileWidgetState extends State<OrderTileWidget> {
  bool _busy = false;

  OrderModel get order => widget.order;

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (success != null) showAppSnackBar(context, success);
      widget.onRefresh();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Ошибка: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleStatus() async {
    final newStatus = order.status == 'Готово' ? 'SHIPPING' : 'READY';
    await _run(
      () => DatabaseService().updateOrderStatus(order.id, newStatus),
      success: 'Статус обновлён',
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file == null) return;
    await _run(
      () => DatabaseService().uploadOrderPhoto(order.id, File(file.path)),
      success: 'Фото прикреплено',
    );
  }

  Future<void> _scanClientQr() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );
    if (code == null || code.isEmpty) return;
    await _run(
      () => DatabaseService().updateOrderQr(order.id, code),
      success: 'Штрих-код клиента сохранён',
    );
  }
  
  Future<void> _scanPvzQr() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );
    if (code == null || code.isEmpty) return;
    await _run(
      () => DatabaseService().updatePvzQr(order.id, code),
      success: 'Штрих-код ПВЗ сохранён',
    );
  }

  void _showBottomSheet() {
    if (_busy) return;
    OrderBottomSheet.show(
      context,
      order: order,
      onRefresh: widget.onRefresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDone = order.status == 'Готово';
    final isDelayed = order.status == 'Отложено';
    final hasPhoto = order.urlPhoto.isNotEmpty;
    final hasClientQr = order.clientQrCode.isNotEmpty;
    final hasPvzQr = order.pvzQrCode.isNotEmpty;

    // Генерируем короткий ID для визуала (APP - ###)
    final shortId = order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: isDone ? const Color(0xFFF1F8E9) : (isDelayed ? Colors.grey.shade100 : Colors.white),
        borderRadius: BorderRadius.circular(16),
        elevation: isDone ? 0 : 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onDoubleTap: _showBottomSheet, // Вызов меню по двойному тапу (по ТЗ)
          onTap: _showBottomSheet,       // Оставил и одинарный тап для удобства курьера
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Шапка карточки: Иконка источника + ID + Колокольчик
                Row(
                  children: [
                    Icon(Icons.smart_toy_outlined, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      'APP - $shortId',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (isDelayed)
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.notifications_active, color: Colors.red, size: 20),
                      ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.more_horiz_rounded, color: Colors.grey.shade500),
                      onPressed: _showBottomSheet,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Основное тело карточки: Статус, ФИО, Город, Оплата
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _busy ? null : _toggleStatus,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDone ? const Color(0xFF43A047) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          border: isDone ? null : Border.all(color: Colors.grey.shade300),
                        ),
                        child: _busy
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(
                                isDone ? Icons.check_rounded : Icons.check_box_outline_blank,
                                color: isDone ? Colors.white : Colors.grey.shade500,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.clientName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: const Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.deliveryCity.isNotEmpty ? order.deliveryCity : 'Город не указан',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    // Желтый бейдж оплаты из ТЗ
                    if (order.clientPayment > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Text(
                          '${order.clientPayment.toStringAsFixed(0)} ₽',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
                
                // Плашка комментария (Желтая, если есть текст)
                if (order.comment != null && order.comment!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(
                      order.comment!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                
                // Нижняя панель действий
                Row(
                  children: [
                    // Фото посылки
                    _MediaButton(
                      icon: hasPhoto ? Icons.image : Icons.add_a_photo,
                      color: hasPhoto ? Colors.green.shade700 : Colors.green.shade500,
                      isFilled: hasPhoto,
                      onTap: _pickPhoto,
                    ),
                    const SizedBox(width: 8),
                    // QR Клиента (синяя пленка)
                    _MediaButton(
                      icon: Icons.qr_code_scanner,
                      color: hasClientQr ? Colors.blue.shade700 : Colors.blue.shade500,
                      isFilled: hasClientQr,
                      onTap: _scanClientQr,
                    ),
                    const SizedBox(width: 8),
                    // QR ПВЗ / Адлер (зеленая пленка)
                    _MediaButton(
                      icon: Icons.inventory_2_outlined,
                      color: hasPvzQr ? Colors.green.shade700 : Colors.green.shade500,
                      isFilled: hasPvzQr,
                      onTap: _scanPvzQr,
                    ),
                    const Spacer(),
                    buildStatusChip(order.status),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Вспомогательный класс для отрисовки квадратных кнопок внизу
class _MediaButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isFilled;
  final VoidCallback onTap;

  const _MediaButton({
    required this.icon,
    required this.color,
    required this.isFilled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isFilled ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: isFilled ? null : Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(
          icon,
          color: isFilled ? Colors.white : color,
          size: 20,
        ),
      ),
    );
  }
}