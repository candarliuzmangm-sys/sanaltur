import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/room_type.dart';
import '../../../../core/presentation/navigation.dart';
import '../../../properties/data/models/room_model.dart';
import '../../../properties/data/repositories/property_repository.dart';
import '../../../properties/presentation/providers/property_provider.dart';

class RoomReviewPage extends ConsumerWidget {
  const RoomReviewPage({
    super.key,
    required this.propertyId,
    required this.roomId,
  });

  final String propertyId;
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final property = ref.watch(propertyDetailProvider(propertyId));

    return Scaffold(
      appBar: AppBar(
        leading: const NavigationLeading(),
        title: const Text('Oda Düzenle'),
        actions: const [HomeToolbarAction()],
      ),
      body: property.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (p) {
          final room = p.rooms.firstWhere((r) => r.id == roomId);
          return _RoomReviewForm(
            propertyId: propertyId,
            room: room,
          );
        },
      ),
    );
  }
}

class _RoomReviewForm extends ConsumerStatefulWidget {
  const _RoomReviewForm({required this.propertyId, required this.room});

  final String propertyId;
  final RoomModel room;

  @override
  ConsumerState<_RoomReviewForm> createState() => _RoomReviewFormState();
}

class _RoomReviewFormState extends ConsumerState<_RoomReviewForm> {
  late RoomType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.room.userSelectedType ?? widget.room.type;
  }

  Future<void> _save() async {
    try {
      await ref.read(propertyRepositoryProvider).updateRoomType(
            propertyId: widget.propertyId,
            roomId: widget.room.id,
            type: _selectedType,
          );
      ref.read(propertyActionsProvider).invalidate(widget.propertyId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.room.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          if (widget.room.aiDetectedType != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text('AI tahmini: ${widget.room.aiDetectedType!.label}'),
                subtitle: widget.room.aiConfidence != null
                    ? Text(
                        'Güven: %${(widget.room.aiConfidence! * 100).round()}',
                      )
                    : null,
              ),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<RoomType>(
            value: _selectedType,
            decoration: const InputDecoration(labelText: 'Oda tipi (sizin seçiminiz)'),
            items: RoomType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedType = v);
            },
          ),
          const Spacer(),
          FilledButton(onPressed: _save, child: const Text('Kaydet')),
        ],
      ),
    );
  }
}
