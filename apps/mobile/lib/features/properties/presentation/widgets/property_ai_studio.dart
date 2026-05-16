import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/property_model.dart';
import '../providers/property_provider.dart';

class PropertyAiStudio extends ConsumerStatefulWidget {
  const PropertyAiStudio({super.key, required this.property});

  final PropertyModel property;

  @override
  ConsumerState<PropertyAiStudio> createState() => _PropertyAiStudioState();
}

class _PropertyAiStudioState extends ConsumerState<PropertyAiStudio> {
  bool _busy = false;

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('$label...'),
          ],
        ),
      ),
    );
    try {
      await action();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label tamamlandı')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final actions = ref.read(propertyActionsProvider);
    final hasMedia = p.rooms.any((r) => r.media.isNotEmpty);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: scheme.primary),
                const SizedBox(width: 8),
                Text('AI Stüdyo', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Odaları analiz et, kat planı ve sanal tur oluştur.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StudioButton(
                  icon: Icons.psychology_outlined,
                  label: 'Analiz',
                  enabled: !_busy && hasMedia,
                  onTap: () => _run(
                    'Oda analizi',
                    () => actions.runAiJobAndWait(
                      propertyId: p.id,
                      start: () => actions.analyze(p.id),
                    ),
                  ),
                ),
                _StudioButton(
                  icon: Icons.map_outlined,
                  label: 'Kat planı',
                  enabled: !_busy && p.rooms.isNotEmpty,
                  onTap: () => _run(
                    'Kat planı',
                    () => actions.runAiJobAndWait(
                      propertyId: p.id,
                      start: () => actions.generateFloorplan(p.id),
                    ),
                  ),
                ),
                _StudioButton(
                  icon: Icons.view_in_ar_outlined,
                  label: 'Sanal tur',
                  enabled: !_busy && hasMedia,
                  onTap: () => _run(
                    'Sanal tur',
                    () => actions.runAiJobAndWait(
                      propertyId: p.id,
                      start: () => actions.generateTour(p.id),
                    ),
                  ),
                ),
                _StudioButton(
                  icon: Icons.description_outlined,
                  label: 'Açıklama',
                  enabled: !_busy && p.rooms.isNotEmpty,
                  onTap: () => _run(
                    'Açıklama',
                    () async {
                      await actions.generateDescription(p.id);
                    },
                  ),
                ),
              ],
            ),
            if (p.floorplan?.hasContent == true) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => context.push('/properties/${p.id}/floorplan'),
                icon: const Icon(Icons.apartment_outlined),
                label: Text(
                  p.floorplan!.estimatedAreaSqm != null
                      ? 'Kat planı (~${p.floorplan!.estimatedAreaSqm!.toStringAsFixed(0)} m²)'
                      : 'Kat planını gör',
                ),
              ),
            ],
            if (hasMedia) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => context.push('/properties/${p.id}/tour'),
                icon: const Icon(Icons.view_in_ar_outlined),
                label: const Text('360° Sanal turu önizle'),
              ),
            ],
            if (p.description != null && p.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.35 : 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  p.description!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudioButton extends StatelessWidget {
  const _StudioButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: enabled ? AppTheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled ? Colors.white : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
