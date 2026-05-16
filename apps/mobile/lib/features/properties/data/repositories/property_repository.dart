import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/room_type.dart';
import '../../../../core/network/api_client.dart';
import '../models/property_model.dart';
import '../models/publish_result.dart';
import '../models/room_model.dart';

final propertyRepositoryProvider = Provider<PropertyRepository>((ref) {
  return PropertyRepository(ref.watch(apiClientProvider));
});

class PropertyRepository {
  PropertyRepository(this._dio);

  final Dio _dio;

  Future<List<PropertyModel>> list() async {
    final response = await _dio.get<List<dynamic>>('/properties');
    return response.data!
        .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PropertyModel> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/properties/$id');
    return PropertyModel.fromJson(response.data!);
  }

  Future<PropertyModel> create({
    required String title,
    String? address,
    String? description,
    String? category,
    int? floorCount,
    Map<String, int>? roomCounts,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/properties',
      data: {
        'title': title,
        if (address != null) 'address': address,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (floorCount != null) 'floorCount': floorCount,
        if (roomCounts != null && roomCounts.isNotEmpty)
          'roomCounts': roomCounts,
      },
    );
    return PropertyModel.fromJson(response.data!);
  }

  Future<RoomModel> addRoom({
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

  Future<void> updateRoomType({
    required String propertyId,
    required String roomId,
    required RoomType type,
  }) async {
    await _dio.patch(
      '/properties/$propertyId/rooms/$roomId',
      data: {'userSelectedType': type.apiValue, 'type': type.apiValue},
    );
  }

  Future<void> renameRoom({
    required String propertyId,
    required String roomId,
    required String name,
  }) async {
    await _dio.patch(
      '/properties/$propertyId/rooms/$roomId',
      data: {'name': name},
    );
  }

  Future<void> updateProperty({
    required String propertyId,
    String? title,
    String? address,
    String? description,
    String? coverImageUrl,
  }) async {
    await _dio.patch(
      '/properties/$propertyId',
      data: {
        if (title != null) 'title': title,
        if (address != null) 'address': address,
        if (description != null) 'description': description,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      },
    );
  }

  Future<PropertyModel> duplicate(String propertyId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/properties/$propertyId/duplicate',
    );
    return PropertyModel.fromJson(response.data!);
  }

  Future<void> reorderRooms({
    required String propertyId,
    required List<String> roomIds,
  }) async {
    await _dio.post(
      '/properties/$propertyId/rooms/reorder',
      data: {'roomIds': roomIds},
    );
  }

  Future<void> deleteProperty(String propertyId) async {
    await _dio.delete('/properties/$propertyId');
  }

  Future<void> deleteRoom({
    required String propertyId,
    required String roomId,
  }) async {
    await _dio.delete('/properties/$propertyId/rooms/$roomId');
  }

  Future<void> deleteMedia({
    required String roomId,
    required String mediaId,
  }) async {
    await _dio.delete('/rooms/$roomId/media/$mediaId');
  }

  /// AI ile fotoğraf düzenle (Stability AI).
  /// [op] = erase | inpaint | replace | recolor | outpaint
  Future<Map<String, dynamic>> editMedia({
    required String roomId,
    required String mediaId,
    required String op,
    String? prompt,
    String? target,
    bool asNewMedia = true,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/rooms/$roomId/media/$mediaId/edit',
      data: {
        'op': op,
        if (prompt != null) 'prompt': prompt,
        if (target != null) 'target': target,
        'asNewMedia': asNewMedia,
      },
      options: Options(receiveTimeout: const Duration(seconds: 90)),
    );
    return resp.data ?? const {};
  }

  Future<void> analyzeProperty(String propertyId) async {
    await _dio.post('/properties/$propertyId/analyze');
  }

  Future<void> generateFloorplan(String propertyId) async {
    await _dio.post('/properties/$propertyId/generate-floorplan');
  }

  Future<void> generateTour(String propertyId) async {
    await _dio.post('/properties/$propertyId/generate-tour');
  }

  Future<PropertyModel> generateDescription(String propertyId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/properties/$propertyId/generate-description',
    );
    return PropertyModel.fromJson(response.data!);
  }

  Future<Map<String, dynamic>?> getLatestAiJob(String propertyId) async {
    final response = await _dio.get<Map<String, dynamic>?>(
      '/properties/$propertyId/ai-jobs/latest',
    );
    return response.data;
  }

  Future<PublishResult> publish(String propertyId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/properties/$propertyId/publish',
    );
    return PublishResult.fromJson(response.data ?? {});
  }
}
