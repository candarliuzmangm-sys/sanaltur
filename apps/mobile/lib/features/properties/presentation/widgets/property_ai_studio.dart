import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/property_model.dart';
import '../providers/property_provider.dart';

const _accent = Color(0xFF22C55E);
const _accentDark = Color(0xFF15803D);

/// Premium AI Stüdyo kartı — dark, modern, glassmorphism dokunuşları.
class PropertyAiStudio extends ConsumerStatefulWidget {
  const PropertyAiStudio({super.key, required this.property});

  final PropertyModel property;

  @override
  ConsumerState<PropertyAiStudio> createState() => _PropertyAiStudioState();
}

class _PropertyAiStudioState extends ConsumerState<PropertyAiStudio> {
  String? _runningKey;
  String? _runningLabel;

  bool get _busy => _runningKey != null;

  Future<void> _run(
    String key,
    String label,
    Future<void> Function() action,
  ) async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    setState(() {
      _runningKey = key;
      _runningLabel = label;
    });
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _accentDark,
            content: Text('$label tamamlandı'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('$label hatası: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _runningKey = null;
          _runningLabel = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final actions = ref.read(propertyActionsProvider);
    final hasMedia = p.rooms.any((r) => r.media.isNotEmpty);
    final hasTour = p.tourSlug != null;
    final hasPlan = p.floorplan?.hasContent == true;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF132019),
            _accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Stüdyo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Analiz · Kat planı · Tur · Açıklama',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: _accent,
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const _PulsingDot(),
                  const SizedBox(width: 8),
                  Text(
                    '$_runningLabel sürüyor…',
                    style: const TextStyle(
                      color: _accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // ============ 2x2 GRID ACTIONS ============
          Row(
            children: [
              Expanded(
                child: _StudioAction(
                  icon: Icons.psychology_outlined,
                  title: 'Analiz',
                  hint: 'Oda tiplerini AI ile tanı',
                  enabled: !_busy && hasMedia,
                  loading: _runningKey == 'analyze',
                  onTap: () => _run(
                    'analyze',
                    'Analiz',
                    () => actions.runAiJobAndWait(
                      propertyId: p.id,
                      start: () => actions.analyze(p.id),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StudioAction(
                  icon: Icons.map_outlined,
                  title: 'Kat Planı',
                  hint: 'Profesyonel 2D plan',
                  enabled: !_busy && p.rooms.isNotEmpty,
                  loading: _runningKey == 'floorplan',
                  badge: hasPlan ? '✓' : null,
                  onTap: () => _run(
                    'floorplan',
                    'Kat planı',
                    () => actions.runAiJobAndWait(
                      propertyId: p.id,
                      start: () => actions.generateFloorplan(p.id),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StudioAction(
                  icon: Icons.view_in_ar_outlined,
                  title: '360° Tur',
                  hint: 'Sanal gezinti',
                  enabled: !_busy && hasMedia,
                  loading: _runningKey == 'tour',
                  badge: hasTour ? '✓' : null,
                  highlight: true,
                  onTap: () => _run(
                    'tour',
                    'Sanal tur',
                    () => actions.runAiJobAndWait(
                      propertyId: p.id,
                      start: () => actions.generateTour(p.id),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StudioAction(
                  icon: Icons.description_outlined,
                  title: 'Açıklama',
                  hint: 'AI ilan metni',
                  enabled: !_busy && p.rooms.isNotEmpty,
                  loading: _runningKey == 'desc',
                  badge: (p.description?.isNotEmpty ?? false) ? '✓' : null,
                  onTap: () => _run(
                    'desc',
                    'Açıklama',
                    () => actions.generateDescription(p.id),
                  ),
                ),
              ),
            ],
          ),

          // ============ ÖNİZLEME LİNKLERİ ============
          if (hasTour || hasPlan) ...[
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hasTour)
                  _PreviewPill(
                    icon: Icons.play_circle_outline,
                    label: 'Sanal Turu Aç',
                    primary: true,
                    onTap: _busy
                        ? null
                        : () => context.push('/properties/${p.id}/tour'),
                  ),
                if (hasPlan)
                  _PreviewPill(
                    icon: Icons.fullscreen,
                    label: p.floorplan!.estimatedAreaSqm != null
                        ? 'Kat planı (~${p.floorplan!.estimatedAreaSqm!.toStringAsFixed(0)} m²)'
                        : 'Kat planını gör',
                    onTap: _busy
                        ? null
                        : () => context.push('/properties/${p.id}/floorplan'),
                  ),
              ],
            ),
          ],

          // ============ AÇIKLAMA ============
          if (p.description != null && p.description!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.format_quote,
                          color: _accent, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'AI tarafından üretildi',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.description!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============ STUDIO ACTION ============

class _StudioAction extends StatelessWidget {
  const _StudioAction({
    required this.icon,
    required this.title,
    required this.hint,
    required this.enabled,
    required this.onTap,
    this.loading = false,
    this.badge,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String hint;
  final bool enabled;
  final bool loading;
  final String? badge;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: highlight && enabled
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_accent, _accentDark],
                    )
                  : null,
              color: highlight && enabled
                  ? null
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: highlight && enabled
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (loading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      Icon(
                        icon,
                        size: 18,
                        color: highlight && enabled
                            ? Colors.white
                            : _accent,
                      ),
                    const Spacer(),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: highlight
                              ? Colors.white.withValues(alpha: 0.20)
                              : _accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            color: highlight && enabled
                                ? Colors.white
                                : _accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    color: highlight && enabled
                        ? Colors.white
                        : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: TextStyle(
                    color: highlight && enabled
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============ PREVIEW PILL ============

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: primary
                ? _accent
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: primary
                  ? _accent
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: primary ? Colors.black : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: primary ? Colors.black : Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ PULSING DOT ============

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Container(
          width: 7 + _c.value * 3,
          height: 7 + _c.value * 3,
          decoration: BoxDecoration(
            color: _accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.6 - _c.value * 0.4),
                blurRadius: 6 + _c.value * 6,
                spreadRadius: 1 + _c.value * 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
