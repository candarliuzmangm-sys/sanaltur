import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/room_type.dart';
import '../../data/models/property_model.dart';
import '../../data/models/publish_result.dart';
import '../../data/models/room_model.dart';
import '../../../tour/presentation/providers/tour_provider.dart';
import '../../data/repositories/property_repository.dart';
import '../../../rooms/data/repositories/room_repository.dart';

final propertyListProvider = FutureProvider<List<PropertyModel>>((ref) async {
  return ref.watch(propertyRepositoryProvider).list();
});

final propertyDetailProvider =
    FutureProvider.family<PropertyModel, String>((ref, id) async {
  return ref.watch(propertyRepositoryProvider).getById(id);
});

final propertyActionsProvider = Provider<PropertyActions>((ref) {
  return PropertyActions(ref);
});

class PropertyActions {
  PropertyActions(this._ref);

  final Ref _ref;

  PropertyRepository get _repo => _ref.read(propertyRepositoryProvider);

  Future<PropertyModel> create({
    required String title,
    String? address,
    String? description,
    String? category,
    int? floorCount,
    Map<String, int>? roomCounts,
  }) =>
      _repo.create(
        title: title,
        address: address,
        description: description,
        category: category,
        floorCount: floorCount,
        roomCounts: roomCounts,
      );

  Future<RoomModel> addRoom({
    required String propertyId,
    required String name,
    required RoomType type,
  }) =>
      _repo.addRoom(propertyId: propertyId, name: name, type: type);

  Future<void> analyze(String propertyId) => _repo.analyzeProperty(propertyId);

  Future<void> generateFloorplan(String propertyId) =>
      _repo.generateFloorplan(propertyId);

  Future<void> generateTour(String propertyId) =>
      _repo.generateTour(propertyId);

  Future<PropertyModel> generateDescription(String propertyId) async {
    final updated = await _repo.generateDescription(propertyId);
    invalidate(propertyId);
    return updated;
  }

  Future<Map<String, dynamic>?> getLatestAiJob(String propertyId) =>
      _repo.getLatestAiJob(propertyId);

  Future<void> runAiJobAndWait({
    required String propertyId,
    required Future<void> Function() start,
  }) async {
    await start();
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final job = await _repo.getLatestAiJob(propertyId);
      final status = job?['status'] as String?;
      if (status == 'COMPLETED') {
        invalidate(propertyId);
        return;
      }
      if (status == 'FAILED') {
        final err = job?['error'] as String? ?? 'AI işlemi başarısız';
        throw Exception(err);
      }
    }
    invalidate(propertyId);
    throw Exception('AI işlemi zaman aşımına uğradı');
  }

  Future<PublishResult> publish(String propertyId) async {
    final result = await _repo.publish(propertyId);
    invalidate(propertyId);
    return result;
  }

  Future<void> updateProperty({
    required String propertyId,
    String? title,
    String? address,
    String? description,
    String? coverImageUrl,
  }) async {
    await _repo.updateProperty(
      propertyId: propertyId,
      title: title,
      address: address,
      description: description,
      coverImageUrl: coverImageUrl,
    );
    invalidate(propertyId);
  }

  Future<PropertyModel> duplicate(String propertyId) async {
    final copy = await _repo.duplicate(propertyId);
    _ref.invalidate(propertyListProvider);
    return copy;
  }

  Future<void> reorderRooms({
    required String propertyId,
    required List<String> roomIds,
  }) async {
    await _ref.read(roomRepositoryProvider).reorderRooms(
          propertyId: propertyId,
          roomIds: roomIds,
        );
    invalidate(propertyId);
  }

  Future<void> setCoverImage({
    required String propertyId,
    required String imageUrl,
  }) =>
      updateProperty(propertyId: propertyId, coverImageUrl: imageUrl);

  Future<void> renameRoom({
    required String propertyId,
    required String roomId,
    required String name,
  }) async {
    await _repo.renameRoom(
      propertyId: propertyId,
      roomId: roomId,
      name: name,
    );
    invalidate(propertyId);
  }

  Future<void> deleteProperty(String propertyId) async {
    await _repo.deleteProperty(propertyId);
    _ref.invalidate(propertyListProvider);
  }

  Future<void> deleteRoom({
    required String propertyId,
    required String roomId,
  }) async {
    await _repo.deleteRoom(propertyId: propertyId, roomId: roomId);
    invalidate(propertyId);
  }

  Future<void> deleteMedia({
    required String propertyId,
    required String roomId,
    required String mediaId,
  }) async {
    await _repo.deleteMedia(roomId: roomId, mediaId: mediaId);
    invalidate(propertyId);
  }

  /// AI ile foto düzenle. [op]: erase|inpaint|replace|recolor|outpaint
  Future<Map<String, dynamic>> aiEditMedia({
    required String propertyId,
    required String roomId,
    required String mediaId,
    required String op,
    String? prompt,
    String? target,
    bool asNewMedia = true,
  }) async {
    final result = await _repo.editMedia(
      roomId: roomId,
      mediaId: mediaId,
      op: op,
      prompt: prompt,
      target: target,
      asNewMedia: asNewMedia,
    );
    if (asNewMedia) invalidate(propertyId);
    return result;
  }

  void invalidate(String propertyId) {
    _ref.invalidate(propertyListProvider);
    _ref.invalidate(propertyDetailProvider(propertyId));
    _ref.invalidate(propertyTourProvider(propertyId));
  }
}
