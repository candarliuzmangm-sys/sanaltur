import 'package:equatable/equatable.dart';

class MediaItemModel extends Equatable {
  const MediaItemModel({
    required this.id,
    required this.url,
    required this.mimeType,
    this.createdAt,
  });

  final String id;
  final String url;
  final String mimeType;
  final DateTime? createdAt;

  factory MediaItemModel.fromJson(Map<String, dynamic> json) {
    return MediaItemModel(
      id: json['id'] as String,
      url: json['url'] as String,
      mimeType: json['mimeType'] as String? ?? 'image/jpeg',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, url, createdAt];
}
