import 'package:supabase_flutter/supabase_flutter.dart';

/// Видео определяем по расширению или по префиксу `video_`, который
/// приложение само проставляет при загрузке (см. DatabaseService.addOrderMedia).
/// Такие же файлы попадают в тот же массив `url_photo`, что и обычные фото —
/// со стороны веб-панели или бота.
bool isVideoAttachment(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.m4v') ||
      lower.startsWith('video_');
}

String resolveMediaUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  if (path.startsWith('/')) return path;
  return Supabase.instance.client.storage.from('packages').getPublicUrl(path);
}
