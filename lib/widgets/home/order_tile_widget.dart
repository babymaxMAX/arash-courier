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
      success: 'Фото прикреплено к заказу',
    );
  }

  Future<void> _scanQr() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );
    if (code == null || code.isEmpty) return;
    await _run(
      () => DatabaseService().updateOrderQr(order.id, code),
      success: 'QR сохранён',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDone = order.status == 'Готово';
    final hasPhoto = order.urlPhoto.isNotEmpty;
    final hasQr = order.clientQrCode.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: isDone
            ? const Color(0xFFF1F8E9)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _busy
              ? null
              : () => OrderBottomSheet.show(
                    context,
                    order: order,
                    onRefresh: widget.onRefresh,
                  ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _busy ? null : _toggleStatus,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDone
                              ? const Color(0xFF43A047)
                              : const Color(0xFFE65100),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: (isDone
                                      ? const Color(0xFF43A047)
                                      : const Color(0xFFE65100))
                                  .withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _busy
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isDone
                                    ? Icons.check_rounded
                                    : Icons.local_shipping_rounded,
                                color: Colors.white,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: const Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          buildStatusChip(order.status),
                          if (order.comment != null &&
                              order.comment!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              order.comment!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
                if (hasPhoto) ...[
                  const SizedBox(height: 12),
                  _PhotoAttachment(
                    url: order.urlPhoto,
                    onDelete: _busy
                        ? null
                        : () => _run(
                              () => DatabaseService()
                                  .clearOrderPhoto(order.id),
                              success: 'Фото удалено',
                            ),
                  ),
                ],
                if (hasQr) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_2, size: 16, color: Color(0xFF1565C0)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.clientQrCode,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1565C0),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _ActionChip(
                      icon: Icons.camera_alt_rounded,
                      label: hasPhoto ? 'Заменить' : 'Фото',
                      color: const Color(0xFF2E7D32),
                      onTap: _busy ? null : _pickPhoto,
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'QR',
                      color: const Color(0xFF1565C0),
                      onTap: _busy ? null : _scanQr,
                    ),
                    if (hasQr) ...[
                      const SizedBox(width: 8),
                      _ActionChip(
                        icon: Icons.delete_outline_rounded,
                        label: 'Удалить QR',
                        color: const Color(0xFFC62828),
                        onTap: _busy
                            ? null
                            : () => _run(
                                  () => DatabaseService()
                                      .clearOrderQr(order.id),
                                  success: 'QR удалён',
                                ),
                      ),
                    ],
                    if (order.totalAmount > 0) ...[
                      const Spacer(),
                      Text(
                        '${order.totalAmount.toStringAsFixed(0)} ₽',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ],
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

class _PhotoAttachment extends StatelessWidget {
  final String url;
  final VoidCallback? onDelete;

  const _PhotoAttachment({required this.url, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(
              children: [
                Icon(Icons.photo_library_rounded,
                    size: 16, color: Colors.green.shade700),
                const SizedBox(width: 6),
                Text(
                  'Фото заказа',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
                const Spacer(),
                if (onDelete != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onDelete,
                    tooltip: 'Удалить фото',
                  ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
            child: Image.network(
              url,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 140,
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                height: 140,
                color: Colors.grey.shade200,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image_outlined,
                        color: Colors.grey.shade500, size: 40),
                    const SizedBox(height: 4),
                    Text(
                      'Не удалось загрузить фото',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
