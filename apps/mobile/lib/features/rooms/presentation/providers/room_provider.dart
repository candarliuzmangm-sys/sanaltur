import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/room_type.dart';
import '../../../properties/data/models/room_model.dart';
import '../../data/repositories/room_repository.dart';

typedef RoomKey = ({String propertyId, String roomId});

final roomDetailProvider =
    FutureProvider.family<RoomModel, RoomKey>((ref, key) async {
  return ref.read(roomRepositoryProvider).getRoom(
        propertyId: key.propertyId,
        roomId: key.roomId,
      );
});

final roomListProvider =
    FutureProvider.family<List<RoomModel>, String>((ref, propertyId) async {
  return ref.read(roomRepositoryProvider).listByProperty(propertyId);
});

final roomActionsProvider = Provider<RoomActions>((ref) => RoomActions(ref));

class RoomActions {
  RoomActions(this._ref);

  final Ref _ref;

  RoomRepository get _repo => _ref.read(roomRepositoryProvider);

  void invalidateRoom(RoomKey key) {
    _ref.invalidate(roomDetailProvider(key));
    _ref.invalidate(roomListProvider(key.propertyId));
  }

  Future<RoomModel> uploadPhotos({
    required RoomKey key,
    required List<({String path, String mime})> files,
    void Function(int index, double progress)? onFileProgress,
  }) async {
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      await _repo.uploadPhoto(
        roomId: key.roomId,
        localPath: f.path,
        mimeType: f.mime,
        onProgress: (p) => onFileProgress?.call(i, p),
      );
    }
    invalidateRoom(key);
    return _repo.getRoom(propertyId: key.propertyId, roomId: key.roomId);
  }

  Future<void> setCover(RoomKey key, String photoUrl) async {
    await _repo.updateRoom(
      propertyId: key.propertyId,
      roomId: key.roomId,
      coverPhotoUrl: photoUrl,
    );
    invalidateRoom(key);
  }

  Future<void> deletePhoto(RoomKey key, String mediaId) async {
    await _repo.deletePhoto(roomId: key.roomId, mediaId: mediaId);
    invalidateRoom(key);
  }
}
