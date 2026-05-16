import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/network/media_url.dart';
import '../../../../core/presentation/navigation.dart';
import '../../data/models/floorplan_model.dart';
import '../../data/models/property_model.dart';
import '../providers/property_provider.dart';

class FloorplanPage extends ConsumerWidget {
  const FloorplanPage({super.key, required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final property = ref.watch(propertyDetailProvider(propertyId));

    return Scaffold(
      appBar: AppBar(
        leading: const NavigationLeading(),
        title: const Text('Kat Planı'),
        actions: const [HomeToolbarAction()],
      ),
      body: property.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (p) {
          final fp = p.floorplan;
          if (fp == null || !fp.hasContent) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Henüz kat planı yok.\nMülk detayında AI Stüdyo → Kat planı.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (fp.estimatedAreaSqm != null)
                Text(
                  'Tahmini alan: ~${fp.estimatedAreaSqm!.toStringAsFixed(0)} m²',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              const SizedBox(height: 8),
              Text(
                'AI tahmini düzen — gerçek ölçüm değildir.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              if (fp.svgUrl != null)
                Card(
                  clipBehavior: Clip.antiAlias,
                  color: const Color(0xFFFAF9F7),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: SvgPicture.network(
                        resolveMediaUrl(fp.svgUrl!),
                        fit: BoxFit.contain,
                        placeholderBuilder: (_) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Card(
                  child: SizedBox(
                    height: 280,
                    child: _LayoutCanvas(
                      property: p,
                      layouts: fp.layoutJson,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ...fp.layoutJson.map((layout) {
                final room = p.rooms
                    .where((r) => r.id == layout.roomId)
                    .firstOrNull;
                return ListTile(
                  leading: const Icon(Icons.square_outlined),
                  title: Text(room?.name ?? layout.roomId),
                  subtitle: Text(
                    '${layout.width.toStringAsFixed(1)} × ${layout.height.toStringAsFixed(1)} m',
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _LayoutCanvas extends StatelessWidget {
  const _LayoutCanvas({
    required this.property,
    required this.layouts,
  });

  final PropertyModel property;
  final List<FloorplanRoomLayout> layouts;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FloorplanPainter(
        layouts: layouts,
        property: property,
        roomNames: {
          for (final r in property.rooms) r.id: r.name,
        },
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _FloorplanPainter extends CustomPainter {
  _FloorplanPainter({
    required this.layouts,
    required this.roomNames,
    required this.property,
  });

  final List<FloorplanRoomLayout> layouts;
  final Map<String, String> roomNames;
  final PropertyModel property;

  @override
  void paint(Canvas canvas, Size size) {
    if (layouts.isEmpty) return;

    const scale = 28.0;
    const pad = 16.0;

    const wetTypes = {'BATHROOM', 'LAUNDRY'};

    for (final l in layouts) {
      final room = property.rooms.where((r) => r.id == l.roomId).firstOrNull;
      final type = room?.aiDetectedType?.name ?? room?.type.name ?? 'OTHER';
      final isWet = wetTypes.contains(type);
      final fill = Paint()
        ..color = isWet
            ? const Color(0xFFD4E8F5)
            : type == 'LIVING_ROOM' || type == 'KITCHEN'
                ? const Color(0xFFF4F1EA)
                : const Color(0xFFEBE8F2);
      final border = Paint()
        ..color = const Color(0xFF4A4A4A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      final rect = Rect.fromLTWH(
        pad + l.x * scale,
        pad + l.y * scale,
        l.width * scale,
        l.height * scale,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, border);

      final name = roomNames[l.roomId] ?? '';
      if (name.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: name,
            style: const TextStyle(fontSize: 10, color: Color(0xFF1B4D3E)),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: rect.width - 4);
        tp.paint(canvas, rect.topLeft + const Offset(4, 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
