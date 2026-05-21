import 'package:flutter/material.dart';

class PvzStyle {
  final Color color;
  final String initials;

  const PvzStyle({
    required this.color,
    required this.initials,
  });
}

PvzStyle getPvzStyle(String companyName) {
  final c = companyName.toLowerCase();

  if (c.contains('wildberries') || c.contains('wb') || c.contains('вб')) {
    return const PvzStyle(
      color: Color(0xFFAF08D8),
      initials: 'WB',
    );
  }
  if (c.contains('ozon') || c.contains('озон')) {
    return const PvzStyle(
      color: Color(0xFF0755C2),
      initials: 'OZ',
    );
  }
  if (c.contains('yandex') || c.contains('яндекс')) {
    return const PvzStyle(
      color: Color(0xFFFFCC00),
      initials: 'YA',
    );
  }
  if (c.contains('cdek') || c.contains('сдэк')) {
    return const PvzStyle(
      color: Color(0xFF4CAB03),
      initials: 'CD',
    );
  }

  final initials =
      companyName.isNotEmpty ? companyName.substring(0, 1).toUpperCase() : '?';
  return PvzStyle(
    color: const Color(0xFF616161),
    initials: initials,
  );
}
