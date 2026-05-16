import 'package:equatable/equatable.dart';

import '../../../../core/models/room_type.dart';
import 'media_item_model.dart';

class RoomModel extends Equatable {
  const RoomModel({
    required this.id,
    required this.name,
    required this.type,
    this.order = 0,
    this.mediaCount = 0,
    this.thumbnailUrl,
    this.coverPhoto,
    this.media = const [],
    this.photos = const [],
    this.userSelectedType,
    this.aiDetectedType,
    this.aiConfidence,
    this.createdAt,
  });

  final String id;
  final String name;
  final RoomType type;
  final int order;
  final int mediaCount;
  final String? thumbnailUrl;
  final String? coverPhoto;
  final List<MediaItemModel> media;
  final List<MediaItemModel> photos;
  final RoomType? userSelectedType;
  final RoomType? aiDetectedType;
  final double? aiConfidence;
  final DateTime? createdAt;

  /// API `roomType` alanı ile uyumlu.
  RoomType get roomType => aiDetectedType ?? userSelectedType ?? type;

  List<MediaItemModel> get allPhotos =>
      photos.isNotEmpty ? photos : media;

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'] as List<dynamic>? ??
        json['media'] as List<dynamic>? ??
        [];
    final parsed = rawPhotos
        .map((m) => MediaItemModel.fromJson(m as Map<String, dynamic>))
        .toList();
    final roomTypeStr =
        json['roomType'] as String? ?? json['type'] as String? ?? 'OTHER';

    return RoomModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: RoomType.fromApi(roomTypeStr),
      order: json['order'] as int? ?? 0,
      mediaCount: json['mediaCount'] as int? ?? parsed.length,
      thumbnailUrl: json['thumbnailUrl'] as String? ??
          json['coverPhoto'] as String? ??
          json['coverPhotoUrl'] as String?,
      coverPhoto: json['coverPhoto'] as String? ??
          json['coverPhotoUrl'] as String? ??
          json['thumbnailUrl'] as String?,
      media: parsed,
      photos: parsed,
      userSelectedType: json['userSelectedType'] != null
          ? RoomType.fromApi(json['userSelectedType'] as String)
          : null,
      aiDetectedType: json['aiDetectedType'] != null
          ? RoomType.fromApi(json['aiDetectedType'] as String)
          : null,
      aiConfidence: (json['aiConfidence'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        order,
        mediaCount,
        coverPhoto,
        allPhotos.length,
        aiDetectedType,
        createdAt,
      ];
}
