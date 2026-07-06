import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/utils/media_kind.dart';

/// Полноэкранный просмотр вложений заказа (фото и видео вперемешку) —
/// перелистывание между всеми файлами, с шапкой (номер/ФИО/город/комментарий)
/// и явной кнопкой закрытия (раньше видео открывалось без возможности выйти).
class MediaViewerScreen extends StatefulWidget {
  final OrderModel order;
  final List<String> items;
  final int initialIndex;
  final Future<void> Function(String item)? onReplace;
  final Future<void> Function(String item)? onDelete;

  const MediaViewerScreen({
    super.key,
    required this.order,
    required this.items,
    required this.initialIndex,
    this.onReplace,
    this.onDelete,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String get _shortOrderId {
    final id = widget.order.id;
    return id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final items = widget.items;
    final currentItem = items.isEmpty ? null : items[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          items.length > 1 ? '${_currentIndex + 1} / ${items.length}' : 'Вложение',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          if (currentItem != null && (widget.onReplace != null || widget.onDelete != null))
            PopupMenuButton<String>(
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (v) async {
                final navigator = Navigator.of(context);
                setState(() => _busy = true);
                try {
                  if (v == 'replace' && widget.onReplace != null) {
                    await widget.onReplace!(currentItem);
                  } else if (v == 'delete' && widget.onDelete != null) {
                    await widget.onDelete!(currentItem);
                  }
                  if (mounted) navigator.pop();
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
              itemBuilder: (ctx) => [
                if (widget.onReplace != null)
                  const PopupMenuItem(value: 'replace', child: Text('Заменить')),
                if (widget.onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Удалить', style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.grey.shade900,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Заказ APP - $_shortOrderId',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  order.clientName,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                Text(
                  order.deliveryCity.isNotEmpty ? order.deliveryCity : 'Город не указан',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                if (order.comment != null && order.comment!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    order.comment!,
                    style: TextStyle(color: Colors.amber.shade200, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Нет вложений', style: TextStyle(color: Colors.white70)))
                : PageView.builder(
                    controller: _pageController,
                    itemCount: items.length,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    itemBuilder: (context, i) => _MediaPage(path: items[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MediaPage extends StatefulWidget {
  final String path;
  const _MediaPage({required this.path});

  @override
  State<_MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<_MediaPage> {
  VideoPlayerController? _videoController;
  bool _videoInitError = false;

  bool get _isVideo => isVideoAttachment(widget.path);
  bool get _isLocalFile => widget.path.startsWith('/');

  @override
  void initState() {
    super.initState();
    if (_isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final controller = _isLocalFile
          ? VideoPlayerController.file(File(widget.path))
          : VideoPlayerController.networkUrl(Uri.parse(resolveMediaUrl(widget.path)));
      await controller.initialize();
      await controller.setLooping(true);
      if (mounted) setState(() => _videoController = controller);
    } catch (e) {
      if (mounted) setState(() => _videoInitError = true);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo) {
      if (_videoInitError) {
        return const Center(
          child: Text('Не удалось загрузить видео', style: TextStyle(color: Colors.white70)),
        );
      }
      final controller = _videoController;
      if (controller == null || !controller.value.isInitialized) {
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      }
      return GestureDetector(
        onTap: () => setState(() {
          controller.value.isPlaying ? controller.pause() : controller.play();
        }),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
              AnimatedOpacity(
                opacity: controller.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
                  padding: const EdgeInsets.all(16),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final ImageProvider image =
        _isLocalFile ? FileImage(File(widget.path)) : NetworkImage(resolveMediaUrl(widget.path));

    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: Image(
          image: image,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          },
          errorBuilder: (context, error, stack) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
          ),
        ),
      ),
    );
  }
}
