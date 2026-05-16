import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/media_url.dart';
import '../../data/models/room_model.dart';

class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.room,
    required this.onCapture,
    required this.onReview,
    this.onOpen,
    this.onRename,
    this.onDelete,
    this.onDeleteMedia,
    this.onSetCover,
    this.showDragHandle = false,
  });

  final RoomModel room;
  final VoidCallback onCapture;
  final VoidCallback onReview;
  final VoidCallback? onOpen;
  final Future<void> Function(String newName)? onRename;
  final Future<void> Function()? onDelete;
  final Future<void> Function(String mediaId)? onDeleteMedia;
  final Future<void> Function(String imageUrl)? onSetCover;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final displayType = room.aiDetectedType ?? room.type;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (showDragHandle) ...[
                  Icon(
                    Icons.drag_handle,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(room.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(displayType.label),
                      if (room.aiDetectedType != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 14, color: Colors.green.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'AI: ${room.aiDetectedType!.label}'
                                '${room.aiConfidence != null ? ' (%${(room.aiConfidence! * 100).round()})' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        '${room.mediaCount} medya',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: onCapture,
                  tooltip: 'Fotoğraf çek',
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: onReview,
                  tooltip: 'Oda tipi',
                ),
                PopupMenuButton<String>(
                  tooltip: 'Daha fazla',
                  onSelected: (v) => _onMenu(context, v),
                  itemBuilder: (_) => [
                    if (onRename != null)
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Yeniden adlandır'),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Odayı sil',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (room.media.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: room.media.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final item = room.media[i];
                    return GestureDetector(
                      onLongPress: () => _photoLongPress(context, item.url, item.id),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: resolveMediaUrl(item.url),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('İlk fotoğrafı çek'),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, String value) async {
    if (value == 'rename' && onRename != null) {
      final controller = TextEditingController(text: room.name);
      final newName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Odayı yeniden adlandır'),
          content: TextField(controller: controller, autofocus: true),
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
      if (newName == null || newName.isEmpty) return;
      try {
        await onRename!(newName);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    } else if (value == 'delete' && onDelete != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Odayı sil?'),
          content: Text(
              '"${room.name}" odası ve içindeki ${room.mediaCount} medya silinecek.'),
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
        await onDelete!();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    }
  }

  Future<void> _photoLongPress(
    BuildContext context,
    String url,
    String mediaId,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onSetCover != null)
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Kapak fotoğrafı yap'),
                onTap: () => Navigator.pop(ctx, 'cover'),
              ),
            if (onDeleteMedia != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Fotoğrafı sil',
                    style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (action == 'cover' && onSetCover != null) {
      try {
        await onSetCover!(url);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kapak fotoğrafı güncellendi')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    } else if (action == 'delete') {
      await _confirmDeleteMedia(context, mediaId);
    }
  }

  Future<void> _confirmDeleteMedia(BuildContext context, String mediaId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fotoğrafı sil?'),
        content: const Text('Bu fotoğraf silinecek.'),
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
    if (ok != true || onDeleteMedia == null) return;
    try {
      await onDeleteMedia!(mediaId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }
}
