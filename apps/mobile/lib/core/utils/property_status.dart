import 'package:flutter/material.dart';

class PropertyStatusInfo {
  const PropertyStatusInfo({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  static PropertyStatusInfo fromApi(String status) {
    switch (status) {
      case 'PUBLISHED':
        return PropertyStatusInfo(
          label: 'Yayında',
          color: const Color(0xFF1B6B4A),
          background: const Color(0xFFD4F0E4),
        );
      case 'READY':
        return PropertyStatusInfo(
          label: 'Hazır',
          color: const Color(0xFF2E5A8A),
          background: const Color(0xFFD6E8F8),
        );
      case 'PROCESSING':
        return PropertyStatusInfo(
          label: 'İşleniyor',
          color: const Color(0xFF8A6A1A),
          background: const Color(0xFFF5E8C4),
        );
      case 'CAPTURING':
        return PropertyStatusInfo(
          label: 'Çekimde',
          color: const Color(0xFF6A4A8A),
          background: const Color(0xFFE8D8F4),
        );
      case 'ARCHIVED':
        return PropertyStatusInfo(
          label: 'Arşiv',
          color: const Color(0xFF666666),
          background: const Color(0xFFE8E8E8),
        );
      default:
        return PropertyStatusInfo(
          label: 'Taslak',
          color: const Color(0xFF4A4A4A),
          background: const Color(0xFFECECEC),
        );
    }
  }
}
