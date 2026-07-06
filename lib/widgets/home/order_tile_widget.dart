import 'dart:io';

import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/services/database_service.dart';
import 'package:arash_curier/screens/qr_scanner_screen.dart';
import 'package:arash_curier/screens/add_order_screen.dart';
import 'package:arash_curier/screens/media_viewer_screen.dart';
import 'package:arash_curier/dialogs/order_bottom_sheet.dart';
import 'package:arash_curier/utils/app_snackbar.dart';
import 'package:arash_curier/utils/order_status.dart';
import 'package:arash_curier/utils/media_kind.dart';
import 'package:arash_curier/utils/order_type_style.dart';
import 'package:arash_curier/widgets/home/order_progress_bar.dart';

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

  Future<void> _run(Future<dynamic> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final customMessage = await action();
      if (!mounted) return;
      
      final msgToShow = (customMessage is String) ? customMessage : success;
      if (msgToShow != null) showAppSnackBar(context, msgToShow);
      
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
    if (path.startsWith('/')) {
      return FileImage(File(path));
    }
    final publicUrl = DatabaseService().supabase.storage.from('packages').getPublicUrl(path);
    return NetworkImage(publicUrl);
  }

  Future<void> _addPhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.rear,
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
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Камера недоступна. Разрешите доступ в Настройках → Arash Curier → Камера.',
          isError: true,
        );
      }
    }
  }

  /// Одна кнопка для менеджера: сразу открывает галерею (фото или видео),
  /// без диалогов, и прикрепляет выбранное к заказу.
  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickMedia();
      if (file == null) return;
      final isVideo = isVideoAttachment(file.path);
      await _run(
        () => DatabaseService().addOrderMedia(
          order.id,
          File(file.path),
          order.photos,
          isVideo: isVideo,
        ),
        success: isVideo ? 'Видео добавлено' : 'Фото добавлено',
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Не удалось открыть галерею', isError: true);
      }
    }
  }

  Future<void> _replaceMedia(String oldPath) async {
    final picker = ImagePicker();
    final file = await picker.pickMedia();
    if (file == null) return;
    final isVideo = isVideoAttachment(file.path);
    await _run(() async {
      await DatabaseService().addOrderMedia(order.id, File(file.path), order.photos, isVideo: isVideo);
      await DatabaseService().removeOrderPhoto(order.id, oldPath, order.photos);
      return isVideo ? 'Видео заменено' : 'Фото заменено';
    });
  }

  void _openMediaViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaViewerScreen(
          order: order,
          items: order.photos,
          initialIndex: initialIndex,
          onReplace: (path) => _replaceMedia(path),
          onDelete: (path) => DatabaseService().removeOrderPhoto(order.id, path, order.photos),
        ),
      ),
    ).then((_) => widget.onRefresh());
  }

  void _showQrOptions(String qrCode, bool isClient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Text(
                isClient ? 'Штрих-код курьера (на посылку)' : 'Штрих-код менеджера',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: qrCode,
                  height: 100.0,
                  drawText: false,
                  errorBuilder: (context, error) => Center(child: Text(error)),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  qrCode,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                title: const Text('Заменить штрих-код'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final newCode = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                  );
                  if (newCode == null || newCode.isEmpty) return;
                  
                  await _run(() async {
                    final currentList = isClient ? order.clientQrCodes : order.pvzQrCodes;
                    await DatabaseService().addQrCode(order.id, newCode, currentList, isClient);
                    
                    final listAfterAdd = isClient ? order.clientQrCodes : order.pvzQrCodes;
                    await DatabaseService().removeQrCode(order.id, qrCode, listAfterAdd, isClient);
                    return 'Штрих-код заменен';
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Удалить штрих-код', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _run(
                    () => DatabaseService().removeQrCode(
                      order.id,
                      qrCode,
                      isClient ? order.clientQrCodes : order.pvzQrCodes,
                      isClient,
                    ),
                    success: 'Штрих-код удален',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addQr() async {
    bool isClient = true;

    if (isManager) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Какой штрих-код?'),
          content: const Text('Выберите тип сканируемого кода:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Штрих-код менеджера'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Штрих-код курьера'),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      isClient = choice;
    }

    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );
    if (!mounted) return;
    if (code == null || code.isEmpty) return;
    final currentList = isClient ? order.clientQrCodes : order.pvzQrCodes;
    await _run(
      () => DatabaseService().addQrCode(order.id, code, currentList, isClient),
      success: 'Штрих-код добавлен',
    );
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _showBottomSheet() {
    if (_busy) return;
    OrderBottomSheet.show(
      context,
      order: order,
      onRefresh: widget.onRefresh,
    );
  }

  Future<void> _toggleStatus() async {
    final newStatus = OrderStatus.toggleDbStatus(order.status);
    await _run(
      () => DatabaseService().updateOrderStatus(order.id, newStatus),
      success: OrderStatus.isDone(newStatus) ? 'Заказ завершён' : 'Статус сброшен',
    );
  }

  void _editOrder() async {
    final result = await Navigator.push<OrderModel>(
      context,
      MaterialPageRoute(
        builder: (context) => AddOrderScreen(orderToEdit: order),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      await _run(
        () => DatabaseService().updateOrder(result),
        success: 'Заказ успешно обновлен!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = OrderStatus.isDone(order.status);
    final isDelayed = OrderStatus.isDelayed(order.status);
    final typeStyle = getOrderTypeStyle(order.orderType);
    final shortId = order.id.length > 8
        ? order.id.substring(0, 8).toUpperCase()
        : order.id.toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isDone
              ? const Color(0xFFF1FAEE) // Светло-зеленый
              : (isDelayed ? Colors.grey.shade100 : Colors.white), // Оранжевый для новых
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDone ? 0.02 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDone ? Colors.green.shade200 : (isDelayed ? Colors.grey.shade300 : Colors.orange.shade200),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _showBottomSheet,
            onDoubleTap: _showBottomSheet,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: typeStyle.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeStyle.icon, size: 13, color: typeStyle.color),
                          const SizedBox(width: 3),
                          Text(
                            typeStyle.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: typeStyle.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'APP - $shortId',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isDone) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.access_time,
                          size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(order.dateUpdated),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (isDelayed)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.notifications_active,
                            color: Colors.red, size: 20),
                      ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.more_horiz_rounded,
                          color: Colors.grey.shade500),
                      onPressed: _showBottomSheet,
                    ),
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
                      onTap: _busy ? null : _toggleStatus,
                      onLongPress: _busy ? null : _toggleStatus,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: isDone ? Colors.green : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDone ? Colors.green : Colors.grey.shade300,
                            width: 2,
                          ),
                          boxShadow: isDone ? [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ] : null,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isDone ? Icons.check_rounded : Icons.circle_outlined,
                            key: ValueKey(isDone),
                            color: isDone ? Colors.white : Colors.grey.shade400,
                            size: 28,
                          ),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration:
                                  isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          if (order.companyName.toLowerCase() == 'другое' && order.companyAddress.isEmpty)
                            const Text(
                              'АДРЕС НЕ УКАЗАН!',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                            )
                          else
                            Text(
                              [
                                if (order.deliveryCity.isNotEmpty) order.deliveryCity else 'Город не указан',
                                if (order.companyAddress.isNotEmpty) order.companyAddress,
                              ].join(', '),
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
                const SizedBox(height: 12),
                OrderProgressBar(order: order),
                if (order.comment != null &&
                    order.comment!.trim().isNotEmpty) ...[
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
                        itemBuilder: (ctx, i) {
                          final path = order.photos[i];
                          final isVideo = isVideoAttachment(path);
                          return GestureDetector(
                            onTap: () => _openMediaViewer(i),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: isVideo ? Colors.black87 : null,
                                borderRadius: BorderRadius.circular(8),
                                image: isVideo
                                    ? null
                                    : DecorationImage(
                                        image: _photoImage(path),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              child: isVideo
                                  ? const Icon(Icons.play_circle_fill, color: Colors.white, size: 24)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ...order.clientQrCodes.map(
                        (qr) => InputChip(
                          label: Text(
                            'КУРЬЕР: $qr',
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                          backgroundColor: Colors.blue.shade600,
                          deleteIconColor: Colors.white,
                          onPressed: () => _showQrOptions(qr, true),
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
                        (qr) => InputChip(
                          label: Text(
                            'МЕНЕДЖЕР: $qr',
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                          backgroundColor: Colors.green.shade600,
                          deleteIconColor: Colors.white,
                          onPressed: () => _showQrOptions(qr, false),
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
                    if (isManager) ...[
                      Expanded(
                        child: _WideActionButton(
                          icon: Icons.add_photo_alternate_rounded,
                          label: 'Прикрепить из галереи',
                          color: Colors.green,
                          onTap: _pickFromGallery,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      _ActionButton(
                        icon: Icons.add_a_photo,
                        color: Colors.green,
                        onTap: _addPhoto,
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        icon: Icons.qr_code_scanner,
                        color: Colors.blue,
                        onTap: _addQr,
                      ),
                      const Spacer(),
                    ],
                    if (order.receivedAt != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_shipping_rounded, size: 14, color: Colors.blue.shade700),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(order.receivedAt),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(order.dateCreated),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
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

class _WideActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _WideActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
