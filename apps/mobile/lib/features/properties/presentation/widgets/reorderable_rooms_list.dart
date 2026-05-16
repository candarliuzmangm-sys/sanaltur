import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/property_model.dart';
import '../../data/models/room_model.dart';
import '../providers/property_provider.dart';
import 'add_room_sheet.dart';
import 'room_card.dart';

class ReorderableRoomsList extends ConsumerStatefulWidget {
  const ReorderableRoomsList({
    super.key,
    required this.property,
  });

  final PropertyModel property;

  @override
  ConsumerState<ReorderableRoomsList> createState() =>
      _ReorderableRoomsListState();
}

class _ReorderableRoomsListState extends ConsumerState<ReorderableRoomsList> {
  late List<RoomModel> _rooms;

  @override
  void initState() {
    super.initState();
    _rooms = _sorted(widget.property.rooms);
  }

  @override
  void didUpdateWidget(covariant ReorderableRoomsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.property.rooms != widget.property.rooms) {
      _rooms = _sorted(widget.property.rooms);
    }
  }

  List<RoomModel> _sorted(List<RoomModel> rooms) {
    return [...rooms]..sort((a, b) => a.order.compareTo(b.order));
  }

  @override
  Widget build(BuildContext context) {
    final propertyId = widget.property.id;
    final actions = ref.read(propertyActionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Odalar', style: Theme.of(context).textTheme.titleLarge),
            ),
            TextButton.icon(
              onPressed: () => showAddRoomSheet(context, propertyId),
              icon: const Icon(Icons.add),
              label: const Text('Oda Ekle'),
            ),
          ],
        ),
        if (_rooms.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Sıralamak için ≡ simgesinden sürükleyin',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _rooms.length,
          onReorder: (oldIndex, newIndex) async {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = _rooms.removeAt(oldIndex);
              _rooms.insert(newIndex, item);
            });
            try {
              await actions.reorderRooms(
                propertyId: propertyId,
                roomIds: _rooms.map((r) => r.id).toList(),
              );
            } catch (e) {
              if (mounted) {
                setState(() => _rooms = _sorted(widget.property.rooms));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sıralama hatası: $e')),
                );
              }
            }
          },
          itemBuilder: (context, index) {
            final room = _rooms[index];
            return ReorderableDragStartListener(
              key: ValueKey(room.id),
              index: index,
              child: RoomCard(
                room: room,
                showDragHandle: _rooms.length > 1,
                onOpen: () => context.push(
                  '/properties/$propertyId/rooms/${room.id}',
                ),
                onCapture: () => context.push(
                  '/properties/$propertyId/capture/${room.id}',
                ),
                onReview: () => context.push(
                  '/properties/$propertyId/rooms/${room.id}/review',
                ),
                onRename: (name) => actions.renameRoom(
                  propertyId: propertyId,
                  roomId: room.id,
                  name: name,
                ),
                onDelete: () => actions.deleteRoom(
                  propertyId: propertyId,
                  roomId: room.id,
                ),
                onDeleteMedia: (mediaId) => actions.deleteMedia(
                  propertyId: propertyId,
                  roomId: room.id,
                  mediaId: mediaId,
                ),
                onSetCover: room.media.isNotEmpty
                    ? (url) => actions.setCoverImage(
                          propertyId: propertyId,
                          imageUrl: url,
                        )
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }
}
