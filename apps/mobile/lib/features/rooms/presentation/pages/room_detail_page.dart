import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/media_url.dart';
import '../../../../core/presentation/async_state_view.dart';
import '../../../../core/presentation/navigation.dart';
import '../../../properties/data/models/media_item_model.dart';
import '../../../properties/data/models/room_model.dart';
import '../providers/room_provider.dart';

class RoomDetailPage extends ConsumerStatefulWidget {
  const RoomDetailPage({
    super.key,
    required this.propertyId,
    required this.roomId,
  });

  final String propertyId;
  final String roomId;

  @override
  ConsumerState<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends ConsumerState<RoomDetailPage> {
  bool _uploading = false;
  double _uploadProgress = 0;
  String? _uploadError;

  RoomKey get _key =>
      (propertyId: widget.propertyId, roomId: widget.roomId);

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomDetailProvider(_key));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const NavigationLeading(),
        title: roomAsync.maybeWhen(
          data: (r) => Text(r.name),
          orElse: () => const Text('Oda'),
        ),
        actions: [
          const HomeToolbarAction(),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Fotoğraf çek',
            onPressed: roomAsync.hasValue
                ? () => context.push(
                      '/properties/${widget.propertyId}/capture/${widget.roomId}',
                    )
                : null,
          ),
        ],
      ),
      body: LoadingOverlay(
        visible: _uploading,
        message: 'Yükleniyor… ${(_uploadProgress * 100).round()}%',
        child: AsyncValueWidget(
          value: roomAsync,
          onRetry: () => ref.invalidate(roomDetailProvider(_key)),
          data: (room) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(roomDetailProvider(_key));
              await ref.read(roomDetailProvider(_key).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                  if (room.coverPhoto != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: resolveMediaUrl(room.coverPhoto!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _MetaCard(room: room),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Fotoğraflar', style: theme.textTheme.titleMedium),
                      Text(
                        '${room.allPhotos.length}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_uploadError != null) ...[
                    ErrorStateView(
                      message: _uploadError!,
                      onRetry: () => setState(() => _uploadError = null),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (room.allPhotos.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Henüz fotoğraf yok',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Kamera veya galeriden ekleyin',
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    _PhotoGrid(
                      photos: room.allPhotos,
                      coverUrl: room.coverPhoto,
                      onSetCover: (url) => ref
                          .read(roomActionsProvider)
                          .setCover(_key, url),
                      onDelete: (id) => ref
                          .read(roomActionsProvider)
                          .deletePhoto(_key, id),
                    ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : () => _showAddPhotoSheet(context),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Fotoğraf ekle'),
      ),
    );
  }

  Future<void> _showAddPhotoSheet(BuildContext context) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;

    if (source == 'camera') {
      if (!mounted) return;
      context.push(
        '/properties/${widget.propertyId}/capture/${widget.roomId}',
      );
      return;
    }

    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty || !mounted) return;

    await _uploadFiles(
      images.map((i) => (path: i.path, mime: 'image/jpeg')).toList(),
    );
  }

  Future<void> _uploadFiles(
    List<({String path, String mime})> files,
  ) async {
    setState(() {
      _uploading = true;
      _uploadError = null;
      _uploadProgress = 0;
    });
    try {
      await ref.read(roomActionsProvider).uploadPhotos(
            key: _key,
            files: files,
            onFileProgress: (index, p) {
              if (mounted) {
                setState(() {
                  _uploadProgress = (index + p) / files.length;
                });
              }
            },
          );
    } catch (e) {
      setState(() => _uploadError = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.room});

  final RoomModel room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = room.createdAt;
    final df = date != null ? DateFormat('d MMM y, HH:mm').format(date) : '—';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(room.roomType.label, style: theme.textTheme.titleSmall),
            if (room.aiDetectedType != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.auto_awesome,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'AI: ${room.aiDetectedType!.label}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text('Oluşturulma: $df', style: theme.textTheme.bodySmall),
            Text('ID: ${room.id}', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.onSetCover,
    required this.onDelete,
    this.coverUrl,
  });

  final List<MediaItemModel> photos;
  final String? coverUrl;
  final Future<void> Function(String url) onSetCover;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        final isCover = coverUrl == photo.url;
        return GestureDetector(
          onLongPress: () => _photoMenu(context, photo),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: resolveMediaUrl(photo.url),
                  fit: BoxFit.cover,
                ),
              ),
              if (isCover)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Kapak',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _photoMenu(BuildContext context, MediaItemModel photo) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Kapak fotoğrafı yap'),
              onTap: () => Navigator.pop(ctx, 'cover'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Sil', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'cover') await onSetCover(photo.url);
    if (action == 'delete') await onDelete(photo.id);
  }
}
