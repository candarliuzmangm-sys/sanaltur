import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/room_type.dart';
import '../providers/property_provider.dart';

void showAddRoomSheet(BuildContext context, String propertyId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AddRoomSheet(propertyId: propertyId),
  );
}

class AddRoomSheet extends ConsumerStatefulWidget {
  const AddRoomSheet({super.key, required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<AddRoomSheet> createState() => _AddRoomSheetState();
}

class _AddRoomSheetState extends ConsumerState<AddRoomSheet> {
  final _nameController = TextEditingController();
  RoomType _selectedType = RoomType.livingRoom;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final room = await ref.read(propertyActionsProvider).addRoom(
            propertyId: widget.propertyId,
            name: _nameController.text.trim(),
            type: _selectedType,
          );
      ref.read(propertyActionsProvider).invalidate(widget.propertyId);
      if (mounted) {
        Navigator.pop(context);
        context.push(
          '/properties/${widget.propertyId}/capture/${room.id}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Yeni Oda', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            cursorColor: Theme.of(context).colorScheme.primary,
            decoration: const InputDecoration(labelText: 'Oda adı'),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<RoomType>(
            value: _selectedType,
            decoration: const InputDecoration(labelText: 'Oda tipi'),
            items: RoomType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedType = v);
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('Oluştur ve Fotoğraf Çek'),
          ),
        ],
      ),
    );
  }
}
