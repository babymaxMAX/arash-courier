import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/services/database_service.dart';
import 'package:arash_curier/screens/qr_scanner_screen.dart';
import 'package:arash_curier/screens/add_order_screen.dart';
import 'package:arash_curier/dialogs/order_bottom_sheet.dart';
import 'package:arash_curier/services/isar_service.dart';
import 'package:arash_curier/utils/app_snackbar.dart';

class OrderTileWidget extends StatefulWidget {
  final OrderModel order;
  final String userRole;
  final VoidCallback onRefresh;

  const OrderTileWidget({
    super.key,
    required this.order,
    required this.userRole,
    required this.onRefresh,
  });

  @override
  State<OrderTileWidget> createState() => _OrderTileWidgetState();
}

class _OrderTileWidgetState extends State<OrderTileWidget> {
  bool _busy = false;

  OrderModel get order => widget.order;
  bool get isManager =>
      widget.userRole == 'manager' || widget.userRole == 'admin';

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

  ImageProvider _photoImage(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (file == null) return;
    await _run(
      () => DatabaseService().addOrderPhoto(
        order.id,
        File(file.path),
        order.photos,
      ),
      success: 'Фото добавлено',
    );
  }

  Future<void> _addQr(bool isClient) async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );
    if (code == null || code.isEmpty) return;
    final currentList = isClient ? order.clientQrCodes : order.pvzQrCodes;
    await _run(
      () => DatabaseService().addQrCode(order.id, code, currentList, isClient),
      success: 'QR код добавлен',
    );
  }

  void _editOrder() async {
    final result = await Navigator.push<OrderModel>(
      context,
      MaterialPageRoute(
        builder: (context) => AddOrderScreen(orderToEdit: order),
      ),
    );

    if (result != null) {
      await _run(
        () => DatabaseService(isar).updateOrder(result),
        success: 'Заказ успешно обновлен!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = order.status == 'Готово';
    final isDelayed = order.status == 'Отложено';
    final shortId = order.id.length > 8
        ? order.id.substring(0, 8).toUpperCase()
        : order.id.toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: isDone
            ? const Color(0xFFF1F8E9)
            : (isDelayed ? Colors.grey.shade200 : Colors.white),
        borderRadius: BorderRadius.circular(16),
        elevation: isDone ? 0 : 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onDoubleTap: () => OrderBottomSheet.show(
            context,
            order: order,
            onRefresh: widget.onRefresh,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'ID: $shortId',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (isManager)
                      IconButton(
                        icon: const Icon(Icons.edit_note, color: Colors.blue),
                        onPressed: _editOrder,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _busy
                          ? null
                          : () => _run(
                                () => DatabaseService().updateOrderStatus(
                                  order.id,
                                  isDone ? 'SHIPPING' : 'READY',
                                ),
                              ),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDone ? Colors.green : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isDone ? Icons.check : Icons.circle_outlined,
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
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              decoration:
                                  isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          Text(
                            order.deliveryCity.isEmpty
                                ? 'Город не указан'
                                : order.deliveryCity,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    if (order.clientPayment > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${order.clientPayment.toStringAsFixed(0)} ₽',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
                if (order.photos.isNotEmpty ||
                    order.clientQrCodes.isNotEmpty ||
                    order.pvzQrCodes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  if (order.photos.isNotEmpty)
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: order.photos.length,
                        itemBuilder: (ctx, i) => GestureDetector(
                          onLongPress: () => _run(
                            () => DatabaseService().removeOrderPhoto(
                              order.id,
                              order.photos[i],
                              order.photos,
                            ),
                            success: 'Фото удалено',
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: _photoImage(order.photos[i]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ...order.clientQrCodes.map(
                        (qr) => Chip(
                          label: const Text(
                            'КЛИЕНТ',
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                          backgroundColor: Colors.blue.shade600,
                          onDeleted: () => _run(
                            () => DatabaseService().removeQrCode(
                              order.id,
                              qr,
                              order.clientQrCodes,
                              true,
                            ),
                          ),
                        ),
                      ),
                      ...order.pvzQrCodes.map(
                        (qr) => Chip(
                          label: const Text(
                            'ПВЗ',
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                          backgroundColor: Colors.green.shade600,
                          onDeleted: () => _run(
                            () => DatabaseService().removeQrCode(
                              order.id,
                              qr,
                              order.pvzQrCodes,
                              false,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    _ActionButton(
                      icon: Icons.add_a_photo,
                      color: Colors.green,
                      onTap: _addPhoto,
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: Icons.qr_code_scanner,
                      color: Colors.blue,
                      onTap: () => _addQr(true),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: Icons.inventory_2_outlined,
                      color: Colors.teal,
                      onTap: () => _addQr(false),
                    ),
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
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
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
