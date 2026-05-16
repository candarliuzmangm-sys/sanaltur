import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/room_type.dart';
import '../../../../core/network/api_client.dart';
import '../../../properties/data/models/room_model.dart';
import '../../../upload/data/repositories/upload_repository.dart';

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository(ref.watch(apiClientProvider));
});

/// Oda ve fotoğraf işlemleri — tek veri kaynağı (NestJS API).
class RoomRepository {
  RoomRepository(this._dio);

  final Dio _dio;

  Future<List<RoomModel>> listByProperty(String propertyId) async {
    final response = await _dio.get<List<dynamic>>(
      '/properties/$propertyId/rooms',
    );
    return (response.data ?? [])
        .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RoomModel> getRoom({
    required String propertyId,
    required String roomId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/properties/$propertyId/rooms/$roomId',
    );
    return RoomModel.fromJson(response.data!);
  }

  Future<RoomModel> createRoom({
    required String propertyId,
    required String name,
    required RoomType type,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/properties/$propertyId/rooms',
      data: {
        'name': name,
        'type': type.apiValue,
        'userSelectedType': type.apiValue,
      },
    );
    return RoomModel.fromJson(response.data!);
  }

  Future<RoomModel> updateRoom({
    required String propertyId,
    required String roomId,
    String? name,
    RoomType? type,
    String? coverPhotoUrl,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/properties/$propertyId/rooms/$roomId',
      data: {
        if (name != null) 'name': name,
        if (type != null) 'type': type.apiValue,
        if (type != null) 'userSelectedType': type.apiValue,
        if (coverPhotoUrl != null) 'coverPhotoUrl': coverPhotoUrl,
      },
    );
    return RoomModel.fromJson(response.data!);
  }

  Future<List<RoomModel>> reorderRooms({
    required String propertyId,
    required List<String> roomIds,
  }) async {
    final response = await _dio.post<List<dynamic>>(
      '/properties/$propertyId/rooms/reorder',
      data: {'roomIds': roomIds},
    );
    return (response.data ?? [])
        .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteRoom({
    required String propertyId,
    required String roomId,
  }) async {
    await _dio.delete('/properties/$propertyId/rooms/$roomId');
  }

  Future<void> deletePhoto({
    required String roomId,
    required String mediaId,
  }) async {
    await _dio.delete('/rooms/$roomId/media/$mediaId');
  }

  /// Multipart upload — doğrudan API'ye (üretim yolu).
  Future<UploadResult> uploadPhoto({
    required String roomId,
    required String localPath,
    required String mimeType,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final repo = UploadRepository(_dio);
    return repo.uploadDirect(
      roomId: roomId,
      localPath: localPath,
      mimeType: mimeType,
      fileName: fileName,
      onProgress: onProgress,
    );
  }
}
