import 'package:hive/hive.dart';

part 'upload_task_model.g.dart';

@HiveType(typeId: 0)
enum UploadStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  uploading,
  @HiveField(2)
  completed,
  @HiveField(3)
  failed,
}

@HiveType(typeId: 1)
class UploadTaskModel extends HiveObject {
  UploadTaskModel({
    required this.id,
    required this.propertyId,
    required this.roomId,
    required this.localPath,
    required this.mimeType,
    required this.fileName,
    this.status = UploadStatus.pending,
    this.progress = 0,
    this.remoteKey,
    this.errorMessage,
    this.createdAt,
    this.mediaType,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String propertyId;

  @HiveField(2)
  final String roomId;

  @HiveField(3)
  final String localPath;

  @HiveField(4)
  final String mimeType;

  @HiveField(5)
  final String fileName;

  @HiveField(6)
  UploadStatus status;

  @HiveField(7)
  double progress;

  @HiveField(8)
  String? remoteKey;

  @HiveField(9)
  String? errorMessage;

  @HiveField(10)
  DateTime? createdAt;

  @HiveField(11)
  String? mediaType;

  UploadTaskModel copyWith({
    UploadStatus? status,
    double? progress,
    String? remoteKey,
    String? errorMessage,
    String? mediaType,
  }) {
    return UploadTaskModel(
      id: id,
      propertyId: propertyId,
      roomId: roomId,
      localPath: localPath,
      mimeType: mimeType,
      fileName: fileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      remoteKey: remoteKey ?? this.remoteKey,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      mediaType: mediaType ?? this.mediaType,
    );
  }
}
