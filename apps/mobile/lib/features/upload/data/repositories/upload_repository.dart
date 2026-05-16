import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../../core/platform/capture_platform.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/upload_queue_storage.dart';
import '../../../properties/data/models/room_model.dart';
import '../models/upload_task_model.dart';

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  return UploadRepository(ref.watch(apiClientProvider));
});

class UploadResult {
  const UploadResult({required this.room});

  final RoomModel room;

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    final roomJson = json['room'] as Map<String, dynamic>?;
    if (roomJson == null) {
      throw const FormatException('Upload response missing room');
    }
    return UploadResult(room: RoomModel.fromJson(roomJson));
  }
}

class UploadRepository {
  UploadRepository(this._dio);

  final Dio _dio;
  final _uuid = const Uuid();

  /// 2-12 fotoyu AI panorama olarak birleştirip backend'e yükler.
  /// Sonuç: tek PANORAMA medya kaydedilir.
  Future<UploadResult> stitchPanorama({
    required String roomId,
    required List<String> photoPaths,
  }) async {
    if (photoPaths.length < 2) {
      throw ArgumentError('En az 2 foto gerekli');
    }
    final form = FormData();
    for (final path in photoPaths) {
      final base = p.basename(path);
      form.files.add(
        MapEntry(
          'files',
          await MultipartFile.fromFile(path, filename: base),
        ),
      );
    }
    final resp = await _dio.post<Map<String, dynamic>>(
      '/rooms/$roomId/media/panorama-stitch',
      data: form,
      options: Options(
        sendTimeout: const Duration(minutes: 3),
        receiveTimeout: const Duration(minutes: 3),
      ),
    );
    return UploadResult.fromJson(resp.data!);
  }

  Future<UploadTaskModel> enqueueMedia({
    required String propertyId,
    required String roomId,
    required String localPath,
    required String mimeType,
    String? fileName,
    String? mediaType,
  }) async {
    final compressed = mediaType == 'PANORAMA'
        ? localPath
        : await _compressIfImage(localPath, mimeType);
    final task = UploadTaskModel(
      id: _uuid.v4(),
      propertyId: propertyId,
      roomId: roomId,
      localPath: compressed,
      mimeType: mimeType,
      fileName: fileName ?? p.basename(compressed),
      createdAt: DateTime.now(),
      mediaType: mediaType,
    );
    await UploadQueueStorage.enqueue(task);
    return task;
  }

  /// Kuyruk olmadan doğrudan API'ye yükle (oda detay / anlık geri bildirim).
  Future<UploadResult> uploadDirect({
    required String roomId,
    required String localPath,
    required String mimeType,
    String? fileName,
    String? mediaType,
    void Function(double progress)? onProgress,
  }) async {
    final compressed = mediaType == 'PANORAMA'
        ? localPath
        : await _compressIfImage(localPath, mimeType);
    final file = File(compressed);
    if (!await file.exists()) {
      throw Exception('Dosya bulunamadı: $compressed');
    }

    final formData = FormData.fromMap({
      if (mediaType != null) 'mediaType': mediaType,
      'file': await MultipartFile.fromFile(
        compressed,
        filename: fileName ?? p.basename(compressed),
      ),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/rooms/$roomId/media/upload',
      data: formData,
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );

    return UploadResult.fromJson(response.data!);
  }

  Future<UploadResult> processTask(
    UploadTaskModel task, {
    void Function(double progress)? onProgress,
  }) async {
    var current = task.copyWith(status: UploadStatus.uploading, progress: 0);
    await UploadQueueStorage.update(current);

    try {
      final file = File(task.localPath);
      if (!await file.exists()) {
        throw Exception('Dosya bulunamadi: ${task.localPath}');
      }

      final formData = FormData.fromMap({
        if (task.mediaType != null) 'mediaType': task.mediaType,
        'file': await MultipartFile.fromFile(
          task.localPath,
          filename: task.fileName,
        ),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/rooms/${task.roomId}/media/upload',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = sent / total;
            onProgress?.call(progress);
            current = current.copyWith(progress: progress);
          }
        },
      );

      final result = UploadResult.fromJson(response.data!);

      await UploadQueueStorage.update(
        task.copyWith(
          status: UploadStatus.completed,
          progress: 1,
        ),
      );

      return result;
    } catch (e) {
      await UploadQueueStorage.update(
        task.copyWith(
          status: UploadStatus.failed,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<String> _compressIfImage(String path, String mimeType) async {
    if (!mimeType.startsWith('image/')) return path;
    if (!supportsLiveCamera) return path;

    final targetPath = '${path}_compressed.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      path,
      targetPath,
      quality: 82,
      minWidth: 1920,
      minHeight: 1080,
    );

    return result?.path ?? path;
  }
}
