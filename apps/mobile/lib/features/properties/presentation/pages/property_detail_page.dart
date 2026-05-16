import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/presentation/navigation.dart';
import '../../data/models/publish_result.dart';
import '../../data/models/property_model.dart';
import '../providers/property_provider.dart';
import '../widgets/add_room_sheet.dart';
import '../widgets/property_ai_studio.dart';
import '../widgets/reorderable_rooms_list.dart';
import '../widgets/share_links_sheet.dart';

class PropertyDetailPage extends ConsumerWidget {
  const PropertyDetailPage({super.key, required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final property = ref.watch(propertyDetailProvider(propertyId));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E0D),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const NavigationLeading(),
        title: property.when(
          data: (p) => Text(
            p.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          loading: () => const Text('...'),
          error: (_, __) => const Text('Mülk'),
        ),
        actions: [
          const HomeToolbarAction(),
          property.maybeWhen(
            data: (p) => PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: const Color(0xFF1A2220),
              onSelected: (value) => _onMenuSelected(context, ref, p, value),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'rename',
                  child: Text('Yeniden adlandır',
                      style: TextStyle(color: Colors.white)),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Mülkü sil',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: property.maybeWhen(
        data: (_) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () => showAddRoomSheet(context, propertyId),
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.black,
            elevation: 0,
            shape: const StadiumBorder(),
            icon: const Icon(Icons.add),
            label: const Text('Oda Ekle',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        orElse: () => null,
      ),
      body: property.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF22C55E))),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(messageFromDioError(e),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.black),
                  onPressed: () =>
                      ref.invalidate(propertyDetailProvider(propertyId)),
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        ),
        data: (p) => RefreshIndicator(
          color: const Color(0xFF22C55E),
          backgroundColor: const Color(0xFF121816),
          onRefresh: () async {
            ref.invalidate(propertyDetailProvider(propertyId));
            await ref.read(propertyDetailProvider(propertyId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _PropertyMetaCard(property: p),
              const SizedBox(height: 14),
              PropertyAiStudio(property: p),
              const SizedBox(height: 14),
              if (p.rooms.any((r) => r.media.isNotEmpty)) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _publishAndShare(context, ref, p),
                        icon: Icon(p.publicSlug != null
                            ? Icons.share
                            : Icons.public),
                        label: Text(p.publicSlug != null
                            ? 'Linki Paylaş'
                            : 'Yayınla & Paylaş'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              if (p.rooms.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121816),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E)
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.meeting_room_outlined,
                          size: 30,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Henüz oda eklenmedi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Oda ekleyip fotoğraf çekmeye başlayın.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () =>
                            showAddRoomSheet(context, propertyId),
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'İlk Odayı Ekle',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ReorderableRoomsList(property: p),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onMenuSelected(
    BuildContext context,
    WidgetRef ref,
    PropertyModel p,
    String value,
  ) async {
    if (value == 'rename') {
      final newTitle = await _promptText(
        context,
        title: 'Mülkü yeniden adlandır',
        initial: p.title,
      );
      if (newTitle == null || newTitle.isEmpty || !context.mounted) return;
      try {
        await ref
            .read(propertyActionsProvider)
            .updateProperty(propertyId: p.id, title: newTitle);
      } catch (e) {
        if (context.mounted) _snack(context, 'Hata: $e');
      }
    } else if (value == 'delete') {
      final ok = await _confirm(
        context,
        title: 'Mülkü sil?',
        message: '"${p.title}" geri alınamaz şekilde silinecek.',
      );
      if (ok != true || !context.mounted) return;
      try {
        await ref.read(propertyActionsProvider).deleteProperty(p.id);
        if (context.mounted) context.pop();
      } catch (e) {
        if (context.mounted) _snack(context, 'Hata: $e');
      }
    }
  }

  Future<String?> _promptText(
    BuildContext context, {
    required String title,
    required String initial,
  }) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _publishAndShare(
    BuildContext context,
    WidgetRef ref,
    PropertyModel p,
  ) async {
    try {
      PublishResult result;
      if (p.publicSlug != null) {
        final slug = p.publicSlug!;
        result = PublishResult(
          publicSlug: slug,
          propertyUrl: Env.publicPropertyUrl(slug),
          tourUrl: (p.tourSlug ?? slug).isNotEmpty
              ? Env.publicTourUrl(p.tourSlug ?? slug)
              : null,
        );
      } else {
        result = await ref.read(propertyActionsProvider).publish(p.id);
      }

      final tourUrl = result.tourUrl;
      final propertyUrl = result.propertyUrl ?? Env.publicPropertyUrl(result.publicSlug);
      final primary = tourUrl ?? propertyUrl;

      await Clipboard.setData(ClipboardData(text: primary));
      if (!context.mounted) return;

      await ShareLinksSheet.show(
        context,
        title: p.title,
        primaryUrl: primary,
        tourUrl: tourUrl,
        propertyUrl: propertyUrl,
      );
    } catch (e) {
      if (context.mounted) _snack(context, 'Hata: $e');
    }
  }
}

class _PropertyMetaCard extends StatelessWidget {
  const _PropertyMetaCard({required this.property});

  final PropertyModel property;

  IconData get _icon {
    switch (property.category) {
      case 'VILLA':
        return Icons.villa_outlined;
      case 'OFFICE':
        return Icons.business_center_outlined;
      case 'STORE':
        return Icons.storefront_outlined;
      case 'SHOP':
        return Icons.store_outlined;
      case 'OTHER':
        return Icons.category_outlined;
      case 'APARTMENT':
      default:
        return Icons.apartment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121816),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: const Color(0xFF22C55E), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      property.categoryLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (property.floorCount != null) ...[
                      const SizedBox(width: 6),
                      _DotChip(label: '${property.floorCount} kat'),
                    ],
                    if (property.rooms.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _DotChip(label: '${property.rooms.length} oda'),
                    ],
                  ],
                ),
                if (property.address != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 12, color: Colors.white54),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.address!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DotChip extends StatelessWidget {
  const _DotChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
