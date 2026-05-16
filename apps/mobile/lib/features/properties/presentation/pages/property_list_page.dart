import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/property_status.dart';
import '../../data/models/property_model.dart';
import '../providers/property_provider.dart';
import '../widgets/share_links_sheet.dart';

const _bgDark = Color(0xFF0A0E0D);
const _surfaceDark = Color(0xFF121816);
const _accentGreen = Color(0xFF22C55E);

class PropertyListPage extends ConsumerStatefulWidget {
  const PropertyListPage({super.key});

  @override
  ConsumerState<PropertyListPage> createState() => _PropertyListPageState();
}

class _PropertyListPageState extends ConsumerState<PropertyListPage> {
  String _query = '';
  String _filter = 'all'; // all, draft, ready, published

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(propertyListProvider);

    return Scaffold(
      backgroundColor: _bgDark,
      extendBody: true,
      body: properties.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _accentGreen),
        ),
        error: (e, _) => _ErrorView(
          error: e,
          onRetry: () => ref.invalidate(propertyListProvider),
        ),
        data: (list) {
          final filtered = list.where((p) {
            if (_filter == 'draft' &&
                !['DRAFT', 'CAPTURING'].contains(p.status)) {
              return false;
            }
            if (_filter == 'ready' && p.status != 'READY') return false;
            if (_filter == 'published' && p.status != 'PUBLISHED') return false;
            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              return p.title.toLowerCase().contains(q) ||
                  (p.address?.toLowerCase().contains(q) ?? false);
            }
            return true;
          }).toList();

          final published = list.where((p) => p.status == 'PUBLISHED').length;
          final totalMedia = list.fold<int>(0, (s, p) => s + p.totalMedia);

          return RefreshIndicator(
            color: _accentGreen,
            backgroundColor: _surfaceDark,
            onRefresh: () async {
              ref.invalidate(propertyListProvider);
              await ref.read(propertyListProvider.future);
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _hero(context, list.length, published, totalMedia)),
                SliverToBoxAdapter(child: _searchBar()),
                if (list.isNotEmpty)
                  SliverToBoxAdapter(child: _filterChips()),
                if (list.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else if (filtered.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          '"$_query" için sonuç yok',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _PremiumPropertyCard(property: filtered[i]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _PremiumFab(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push('/properties/new');
        },
      ),
    );
  }

  // ============ HERO ============
  Widget _hero(BuildContext context, int total, int published, int media) {
    final hour = DateTime.now().hour;
    final greeting = hour < 6
        ? 'İyi geceler'
        : hour < 12
            ? 'Günaydın'
            : hour < 18
                ? 'İyi günler'
                : 'İyi akşamlar';

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F1F18),
            Color(0xFF0A0E0D),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Mülklerin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              _CircleIconBtn(
                icon: Icons.settings_outlined,
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  value: '$total',
                  label: 'Mülk',
                  icon: Icons.home_work_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStat(
                  value: '$published',
                  label: 'Yayında',
                  icon: Icons.public,
                  accent: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStat(
                  value: '$media',
                  label: 'Foto',
                  icon: Icons.photo_library_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.white54, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Ara…',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (_query.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                onPressed: () => setState(() => _query = ''),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChips() {
    final items = [
      ('all', 'Hepsi'),
      ('draft', 'Taslak'),
      ('ready', 'Hazır'),
      ('published', 'Yayında'),
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final it = items[i];
          final selected = _filter == it.$1;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _filter = it.$1);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? _accentGreen
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: selected
                      ? _accentGreen
                      : Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Center(
                child: Text(
                  it.$2,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============ HERO STAT ============

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.value,
    required this.label,
    required this.icon,
    this.accent = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: accent
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF15803D), Color(0xFF22C55E)],
              )
            : null,
        color: accent ? null : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: accent ? Colors.white : Colors.white70, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: accent ? Colors.white70 : Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  const _CircleIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }
}

// ============ PREMIUM PROPERTY CARD ============

class _PremiumPropertyCard extends ConsumerWidget {
  const _PremiumPropertyCard({required this.property});

  final PropertyModel property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalMedia = property.totalMedia;
    final aiRooms =
        property.rooms.where((r) => r.aiDetectedType != null).length;
    final cover = property.coverImageUrl;
    final status = PropertyStatusInfo.fromApi(property.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/properties/${property.id}');
        },
        onLongPress: () => _showActions(context, ref),
        child: Container(
          decoration: BoxDecoration(
            color: _surfaceDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          clipBehavior: Clip.antiAlias,
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
                            placeholder: (_, __) => const ColoredBox(
                                color: Color(0xFF1A2220)),
                            errorWidget: (_, __, ___) => const _CoverPlaceholder(),
                          )
                        : const _CoverPlaceholder(),
                  ),
                  // bottom dark gradient for legibility
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                            stops: const [0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // top-left status badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _GlassChip(
                      icon: _statusIcon(property.status),
                      label: status.label,
                      tint: status.color,
                    ),
                  ),
                  // top-right category badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _GlassChip(
                      icon: _categoryIcon(property.category),
                      label: property.categoryLabel,
                      tint: Colors.white,
                    ),
                  ),
                  // bottom: title + address
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          property.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                offset: Offset(0, 1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        if (property.address != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined,
                                  size: 12, color: Colors.white70),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  property.address!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MiniChip(
                      icon: Icons.meeting_room_outlined,
                      label: '${property.rooms.length} oda',
                    ),
                    _MiniChip(
                      icon: Icons.photo_library_outlined,
                      label: '$totalMedia foto',
                    ),
                    if (aiRooms > 0)
                      _MiniChip(
                        icon: Icons.auto_awesome,
                        label: '$aiRooms AI',
                        accent: true,
                      ),
                    if (property.floorplan?.hasContent == true)
                      const _MiniChip(
                        icon: Icons.map_outlined,
                        label: 'Kat planı',
                      ),
                    if (property.tourSlug != null)
                      const _MiniChip(
                        icon: Icons.view_in_ar,
                        label: '360° Tur',
                        accent: true,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'PUBLISHED':
        return Icons.public;
      case 'READY':
        return Icons.check_circle;
      case 'PROCESSING':
        return Icons.sync;
      case 'CAPTURING':
        return Icons.photo_camera_outlined;
      default:
        return Icons.edit_outlined;
    }
  }

  IconData _categoryIcon(String c) {
    switch (c) {
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

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _surfaceDark,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.content_copy, color: Colors.white70),
              title: const Text('Mülkü kopyala',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Odalar kopyalanır, fotoğraflar kopyalanmaz',
                style: TextStyle(color: Colors.white54),
              ),
              onTap: () => Navigator.pop(ctx, 'duplicate'),
            ),
            if (property.publicSlug != null)
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white70),
                title: const Text('Paylaşım linki',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'share'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Mülkü sil',
                  style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 8),
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
              SnackBar(content: Text('"${copy.title}" oluşturuldu')),
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
        backgroundColor: _surfaceDark,
        title: const Text('Mülkü sil?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '"${property.title}" geri alınamaz şekilde silinecek.',
          style: const TextStyle(color: Colors.white70),
        ),
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

// ============ CHIPS / FAB / OTHER ============

class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tint, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = accent ? _accentGreen : Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent
            ? _accentGreen.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: accent
              ? _accentGreen.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumFab extends StatelessWidget {
  const _PremiumFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: _accentGreen.withValues(alpha: 0.40),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: _accentGreen,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add, size: 22),
        label: const Text(
          'Yeni Mülk',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2A24), Color(0xFF0F1F18)],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.home_outlined,
        size: 48,
        color: Colors.white24,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _accentGreen.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
              border:
                  Border.all(color: _accentGreen.withValues(alpha: 0.40)),
            ),
            child: const Icon(
              Icons.add_business_outlined,
              size: 40,
              color: _accentGreen,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'İlk mülkünü ekle',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Daire, villa, ofis ya da mağaza —\n'
            'Birkaç fotoğrafla sanal turun hazır.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
          ),
        ],
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
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              messageFromDioError(error),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
