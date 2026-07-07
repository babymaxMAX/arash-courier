import 'package:flutter/material.dart';

class PvzStyle {
  final Color color;
  final String initials;

  /// Путь к логотипу компании (assets/icons/pvz_*), если он есть — тогда
  /// показываем реальный логотип вместо цветного кружка с инициалами.
  final String? assetPath;

  const PvzStyle({
    required this.color,
    required this.initials,
    this.assetPath,
  });
}

PvzStyle getPvzStyle(String companyName) {
  final c = companyName.toLowerCase();

  if (c.contains('wildberries') || c.contains('wb') || c.contains('вб')) {
    return const PvzStyle(
      color: Color(0xFFAF08D8),
      initials: 'ВБ',
      assetPath: 'assets/icons/pvz_wb.png',
    );
  }
  if (c.contains('ozon') || c.contains('озон')) {
    return const PvzStyle(
      color: Color(0xFF0755C2),
      initials: 'ОЗОН',
      assetPath: 'assets/icons/pvz_ozon.jpg',
    );
  }
  if (c.contains('yandex') || c.contains('яндекс')) {
    return const PvzStyle(
      color: Color(0xFFFFCC00),
      initials: 'ЯМ',
      assetPath: 'assets/icons/pvz_yandex_market.png',
    );
  }
  if (c.contains('cdek') || c.contains('сдэк')) {
    return const PvzStyle(
      color: Color(0xFF4CAB03),
      initials: 'СДЭК',
      assetPath: 'assets/icons/pvz_sdek.png',
    );
  }
  if (c.contains('5post') || c.contains('5 post')) {
    return const PvzStyle(
      color: Color(0xFF4CAF50),
      initials: '5',
      assetPath: 'assets/icons/pvz_5post.jpeg',
    );
  }
  if (c.contains('lamoda') || c.contains('ламода')) {
    return const PvzStyle(
      color: Color(0xFF000000),
      initials: 'Л',
      assetPath: 'assets/icons/pvz_lamoda.jpeg',
    );
  }
  if (c.contains('cainiao') || c.contains('цайняо')) {
    return const PvzStyle(
      color: Color(0xFF1565C0),
      initials: 'ЦН',
      assetPath: 'assets/icons/pvz_cainiao.jpeg',
    );
  }
  if (c.contains('почта')) {
    return const PvzStyle(
      color: Color(0xFF1E4EA6),
      initials: 'ПР',
      assetPath: 'assets/icons/pvz_pochta.png',
    );
  }
  if (c.contains('деловые')) {
    return const PvzStyle(
      color: Color(0xFFF9A825),
      initials: 'ДЛ',
      assetPath: 'assets/icons/pvz_delovye_linii.jpeg',
    );
  }
  if (c.contains('пэк')) {
    return const PvzStyle(
      color: Color(0xFFD32F2F),
      initials: 'ПЭК',
      assetPath: 'assets/icons/pvz_pek.jpeg',
    );
  }
  if (c.contains('склад')) {
    return const PvzStyle(
      color: Color(0xFF424242),
      initials: 'С',
      assetPath: 'assets/icons/pvz_sklad.jpeg',
    );
  }
  if (c.contains('emex') || c.contains('емекс')) {
    return const PvzStyle(
      color: Color(0xFFF57C00),
      initials: 'E',
      assetPath: 'assets/icons/pvz_emex.jpeg',
    );
  }
  if (c.contains('автодок') || c.contains('autodoc')) {
    return const PvzStyle(
      color: Color(0xFFD32F2F),
      initials: 'АД',
      assetPath: 'assets/icons/pvz_avtodok.jpeg',
    );
  }
  if (c.contains('бумер') || c.contains('boomer')) {
    return const PvzStyle(
      color: Color(0xFFD32F2F),
      initials: 'Б',
      assetPath: 'assets/icons/pvz_boomer.jpeg',
    );
  }
  if (c.contains('аптек')) {
    return const PvzStyle(
      color: Color(0xFF2E7D32),
      initials: 'А',
      assetPath: 'assets/icons/pvz_apteka.jpeg',
    );
  }

  final initials =
      companyName.isNotEmpty ? companyName.substring(0, 1).toUpperCase() : '?';
  return PvzStyle(
    color: const Color(0xFF616161),
    initials: initials,
  );
}

String getUserAvatar(String email) {
  if (email.isEmpty) return '👤';
  const emojis = ['🦅', '🐿️', '🦁', '🐻', '🐼', '🐨', '🐯', '🦒', '🦊', '🐰', '🐺', '🦉', '🦝', '🐴', '🦌', '🐧', '🦩', '🦚', '🦜', '🦢', '🕊️', '🐇', '🦫', '🦡', '🦦'];
  final index = email.hashCode.abs() % emojis.length;
  return emojis[index];
}
