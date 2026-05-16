import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/utils/property_status.dart';
import '../../data/models/property_model.dart';
import '../providers/property_provider.dart';
import '../widgets/share_links_sheet.dart';

class PropertyListPage extends ConsumerStatefulWidget {
  const PropertyListPage({super.key});

  @override
  ConsumerState<PropertyListPage> createState() => _PropertyListPageState();
}

class _PropertyListPageState extends ConsumerState<PropertyListPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(propertyListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mülklerim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: 'Ayarlar',
          ),
        ],
      ),
      body: properties.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          error: e,
          onRetry: () => ref.invalidate(propertyListProvider),
        ),
        data: (list) {
          final filtered = list.where((p) {
            if (_query.isEmpty) return true;
            final q = _query.toLowerCase();
            return p.title.toLowerCase().contains(q) ||
                (p.address?.toLowerCase().contains(q) ?? false);
          }).toList();

          if (list.isEmpty) return const _EmptyState();

          final published = list.where((p) => p.status == 'PUBLISHED').length;
          final totalMedia =
              list.fold<int>(0, (s, p) => s + p.totalMedia);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(propertyListProvider);
              await ref.read(propertyListProvider.future);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Mülk veya adres ara...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _query.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () =>
                                        setState(() => _query = ''),
                                  )
                                : null,
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                        const SizedBox(height: 12),
                        _StatsRow(
                          total: list.length,
                          published: published,
                          media: totalMedia,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(
                        '“$_query” için sonuç yok',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _PropertyCard(property: filtered[i]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/properties/new'),
        icon: const Icon(Icons.add),
        label: const Text('Yeni Mülk'),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.total,
    required this.published,
    required this.media,
  });

  final int total;
  final int published;
  final int media;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            icon: Icons.home_work_outlined,
            value: '$total',
            label: 'Mülk',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatBox(
            icon: Icons.public,
            value: '$published',
            label: 'Yayında',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatBox(
            icon: Icons.photo_library_outlined,
            value: '$media',
            label: 'Fotoğraf',
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: scheme.onSurface,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PropertyCard extends ConsumerWidget {
  const _PropertyCard({required this.property});

  final PropertyModel property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalMedia = property.totalMedia;
    final aiRooms =
        property.rooms.where((r) => r.aiDetectedType != null).length;
    final cover = property.coverImageUrl;
    final status = PropertyStatusInfo.fromApi(property.status);
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/properties/${property.id}'),
        onLongPress: () => _showActions(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: cover != null
                      ? CachedNetworkImage(
                          imageUrl: resolveMediaUrl(cover),
                          fit: BoxFit.cover,
                          placeholder: (_, __) => ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (_, __, ___) => const _CoverPlaceholder(),
                        )
                      : const _CoverPlaceholder(),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: status.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: status.color,
                      ),
                    ),
                  ),
                ),
                if (property.publicSlug != null)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(Icons.public, color: Colors.white, size: 22),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(property.title, style: theme.textTheme.titleMedium),
                  if (property.address != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      property.address!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _StatChip(
                        icon: Icons.meeting_room_outlined,
                        label: '${property.rooms.length} oda',
                      ),
                      _StatChip(
                        icon: Icons.photo_library_outlined,
                        label: '$totalMedia medya',
                      ),
                      if (aiRooms > 0)
                        _StatChip(
                          icon: Icons.auto_awesome,
                          label: '$aiRooms AI',
                          highlight: true,
                        ),
                      if (property.floorplan?.hasContent == true)
                        const _StatChip(
                          icon: Icons.map_outlined,
                          label: 'Kat planı',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Mülkü kopyala'),
              subtitle: const Text('Odalar kopyalanır, fotoğraflar kopyalanmaz'),
              onTap: () => Navigator.pop(ctx, 'duplicate'),
            ),
            if (property.publicSlug != null)
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Paylaşım linki'),
                onTap: () => Navigator.pop(ctx, 'share'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Mülkü sil',
                  style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;

    switch (action) {
      case 'duplicate':
        try {
          final copy =
              await ref.read(propertyActionsProvider).duplicate(property.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('“${copy.title}” oluşturuldu')),
            );
            context.push('/properties/${copy.id}');
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Hata: $e')));
          }
        }
      case 'share':
        final slug = property.publicSlug!;
        final tourUrl = Env.publicTourUrl(property.tourSlug ?? slug);
        final propertyUrl = Env.publicPropertyUrl(slug);
        await ShareLinksSheet.show(
          context,
          title: property.title,
          primaryUrl: tourUrl,
          tourUrl: tourUrl,
          propertyUrl: propertyUrl,
        );
      case 'delete':
        await _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mülkü sil?'),
        content: Text('"${property.title}" geri alınamaz şekilde silinecek.'),
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
    if (ok != true) return;
    try {
      await ref.read(propertyActionsProvider).deleteProperty(property.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Silme hatası: $e')));
      }
    }
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.home_outlined,
        size: 48,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = highlight ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: c)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.home_work_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz mülk eklemediniz',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Sağ alttaki + butonuyla ilk mülkünüzü oluşturun.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(
              messageFromDioError(error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}
