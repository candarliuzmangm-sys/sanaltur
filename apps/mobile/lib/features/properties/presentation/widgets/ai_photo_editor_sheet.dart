import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/media_url.dart';
import '../providers/property_provider.dart';

const _bg = Color(0xFF0A0E0D);
const _surface = Color(0xFF121816);
const _accent = Color(0xFF22C55E);
const _accentDark = Color(0xFF15803D);

enum AiEditMode { erase, addFurniture, recolorWall, recolorFloor, replace }

class AiPhotoEditorSheet extends ConsumerStatefulWidget {
  const AiPhotoEditorSheet({
    super.key,
    required this.propertyId,
    required this.roomId,
    required this.mediaId,
    required this.imageUrl,
  });

  final String propertyId;
  final String roomId;
  final String mediaId;
  final String imageUrl;

  static Future<void> show(
    BuildContext context, {
    required String propertyId,
    required String roomId,
    required String mediaId,
    required String imageUrl,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: _bg,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AiPhotoEditorSheet(
        propertyId: propertyId,
        roomId: roomId,
        mediaId: mediaId,
        imageUrl: imageUrl,
      ),
    );
  }

  @override
  ConsumerState<AiPhotoEditorSheet> createState() =>
      _AiPhotoEditorSheetState();
}

class _AiPhotoEditorSheetState extends ConsumerState<AiPhotoEditorSheet> {
  AiEditMode _mode = AiEditMode.erase;
  final _promptController = TextEditingController();
  final _targetController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _promptController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  String get _opName {
    switch (_mode) {
      case AiEditMode.erase:
        return 'erase';
      case AiEditMode.addFurniture:
        return 'inpaint';
      case AiEditMode.recolorWall:
      case AiEditMode.recolorFloor:
        return 'recolor';
      case AiEditMode.replace:
        return 'replace';
    }
  }

  String? get _defaultTarget {
    switch (_mode) {
      case AiEditMode.recolorWall:
        return 'wall';
      case AiEditMode.recolorFloor:
        return 'floor';
      default:
        return null;
    }
  }

  String get _modeTitle {
    switch (_mode) {
      case AiEditMode.erase:
        return 'Boşalt (Eşyaları kaldır)';
      case AiEditMode.addFurniture:
        return 'Eşya ekle';
      case AiEditMode.recolorWall:
        return 'Duvar rengini değiştir';
      case AiEditMode.recolorFloor:
        return 'Zemin rengini değiştir';
      case AiEditMode.replace:
        return 'Eşyayı değiştir';
    }
  }

  String get _promptHint {
    switch (_mode) {
      case AiEditMode.erase:
        return 'Opsiyonel: ne kaldırılsın? (örn: "tüm mobilyalar")';
      case AiEditMode.addFurniture:
        return 'Ne eklensin? (örn: "modern gri kanepe ve cam sehpa")';
      case AiEditMode.recolorWall:
        return 'Hangi renk? (örn: "warm beige", "soft gray")';
      case AiEditMode.recolorFloor:
        return 'Zemin tipi/rengi? (örn: "light oak hardwood")';
      case AiEditMode.replace:
        return 'Yenisi nasıl olsun? (örn: "leather brown sofa")';
    }
  }

  String? get _targetHint {
    switch (_mode) {
      case AiEditMode.replace:
        return 'Hangi nesne değişsin? (örn: "couch", "table")';
      default:
        return null;
    }
  }

  Future<void> _run() async {
    if (_busy) return;

    String? prompt = _promptController.text.trim().isEmpty
        ? null
        : _promptController.text.trim();
    String? target = _defaultTarget;
    if (_mode == AiEditMode.replace) {
      target = _targetController.text.trim().isEmpty
          ? null
          : _targetController.text.trim();
    }

    // Validation
    if (_mode == AiEditMode.addFurniture && prompt == null) {
      _toast('Eşya tanımı boş olamaz');
      return;
    }
    if ((_mode == AiEditMode.recolorWall ||
            _mode == AiEditMode.recolorFloor) &&
        prompt == null) {
      _toast('Renk tanımı boş olamaz');
      return;
    }
    if (_mode == AiEditMode.replace && (prompt == null || target == null)) {
      _toast('Hedef nesne ve yeni nesne tanımı gerekli');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      await ref.read(propertyActionsProvider).aiEditMedia(
            propertyId: widget.propertyId,
            roomId: widget.roomId,
            mediaId: widget.mediaId,
            op: _opName,
            prompt: prompt,
            target: target,
            asNewMedia: true,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: _accentDark,
            content: Text('AI düzenlemesi tamamlandı — yeni foto eklendi'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _toast('Hata: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
            decoration: const BoxDecoration(
              color: _bg,
              border: Border(
                bottom: BorderSide(color: Color(0xFF1F2926)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_accent, _accentDark],
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child:
                      const Icon(Icons.auto_fix_high, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Foto Stüdyo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'Stability AI · ~\$0.03 / işlem',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Preview + mode selector + prompt
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: resolveMediaUrl(widget.imageUrl),
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ColoredBox(color: _surface),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image, color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Ne yapmak istiyorsun?',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 10),
                _ModeGrid(
                  selected: _mode,
                  onChanged: (m) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _mode = m;
                      _promptController.clear();
                      _targetController.clear();
                    });
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  _modeTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                if (_mode == AiEditMode.replace)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PromptField(
                      controller: _targetController,
                      hint: _targetHint!,
                      icon: Icons.search,
                    ),
                  ),
                _PromptField(
                  controller: _promptController,
                  hint: _promptHint,
                  icon: Icons.edit_outlined,
                  maxLines: _mode == AiEditMode.addFurniture ? 3 : 2,
                ),
                if (_mode == AiEditMode.recolorWall ||
                    _mode == AiEditMode.recolorFloor) ...[
                  const SizedBox(height: 10),
                  _ColorPresets(
                    onPick: (name) => _promptController.text = name,
                  ),
                ],
                const SizedBox(height: 20),
                // Run button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _busy ? null : _run,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      _busy ? 'Üretiliyor…' : 'AI ile Uygula',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sonuç yeni bir foto olarak odana eklenir. Orijinal silinmez.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============ MODE GRID ============

class _ModeGrid extends StatelessWidget {
  const _ModeGrid({required this.selected, required this.onChanged});

  final AiEditMode selected;
  final ValueChanged<AiEditMode> onChanged;

  static const _modes = [
    (AiEditMode.erase, Icons.cleaning_services_outlined, 'Boşalt', 'Eşyaları kaldır'),
    (AiEditMode.addFurniture, Icons.weekend_outlined, 'Eşya ekle', 'Boş odaya mobilya'),
    (AiEditMode.recolorWall, Icons.format_paint_outlined, 'Duvar', 'Renk değiştir'),
    (AiEditMode.recolorFloor, Icons.grid_view_outlined, 'Zemin', 'Renk/desen değiştir'),
    (AiEditMode.replace, Icons.swap_horiz, 'Değiştir', 'Eşyayı yenile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _modes.map((m) {
        final isSelected = selected == m.$1;
        return GestureDetector(
          onTap: () => onChanged(m.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: (MediaQuery.of(context).size.width - 32 - 16) / 3 - 2,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_accent, _accentDark],
                    )
                  : null,
              color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  m.$2,
                  size: 22,
                  color: isSelected ? Colors.white : _accent,
                ),
                const SizedBox(height: 6),
                Text(
                  m.$3,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  m.$4,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.white54,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ============ PROMPT FIELD ============

class _PromptField extends StatelessWidget {
  const _PromptField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 2,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: Colors.white54, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: maxLines,
              minLines: 1,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ COLOR PRESETS ============

class _ColorPresets extends StatelessWidget {
  const _ColorPresets({required this.onPick});

  final ValueChanged<String> onPick;

  static const _colors = [
    ('warm beige', Color(0xFFE6D2B5)),
    ('soft gray', Color(0xFFCFCFCF)),
    ('sage green', Color(0xFFB5C9A8)),
    ('navy blue', Color(0xFF1E3A5F)),
    ('off white', Color(0xFFF5F2EA)),
    ('terracotta', Color(0xFFC97A5E)),
    ('charcoal', Color(0xFF3A3A3A)),
    ('light oak', Color(0xFFD2B48C)),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _colors.map((c) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onPick(c.$1);
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: c.$2,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.30),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  c.$1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
