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
      appBar: AppBar(
        leading: const NavigationLeading(),
        title: property.when(
          data: (p) => Text(p.title),
          loading: () => const Text('...'),
          error: (_, __) => const Text('Mülk'),
        ),
        actions: [
          const HomeToolbarAction(),
          property.maybeWhen(
            data: (p) => PopupMenuButton<String>(
              onSelected: (value) => _onMenuSelected(context, ref, p, value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Yeniden adlandır')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Mülkü sil', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: property.maybeWhen(
        data: (_) => FloatingActionButton.extended(
          onPressed: () => showAddRoomSheet(context, propertyId),
          icon: const Icon(Icons.add),
          label: const Text('Oda Ekle'),
        ),
        orElse: () => null,
      ),
      body: property.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(messageFromDioError(e), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(propertyDetailProvider(propertyId)),
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(propertyDetailProvider(propertyId));
            await ref.read(propertyDetailProvider(propertyId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              if (p.address != null)
                Text(
                  p.address!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 16),
              PropertyAiStudio(property: p),
              const SizedBox(height: 16),
              if (p.rooms.any((r) => r.media.isNotEmpty)) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            context.push('/properties/$propertyId/tour'),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('360° Sanal Tur'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
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
                const SizedBox(height: 16),
              ],
              if (p.rooms.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.meeting_room_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Henüz oda eklenmedi. Oda ekleyip fotoğraf çekmeye başlayın.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () =>
                              showAddRoomSheet(context, propertyId),
                          icon: const Icon(Icons.add),
                          label: const Text('İlk Odayı Ekle'),
                        ),
                      ],
                    ),
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
