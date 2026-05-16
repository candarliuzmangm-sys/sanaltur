import 'package:equatable/equatable.dart';

import 'floorplan_model.dart';
import 'room_model.dart';

class PropertyModel extends Equatable {
  const PropertyModel({
    required this.id,
    required this.title,
    required this.status,
    this.address,
    this.description,
    this.coverImageUrl,
    this.publicSlug,
    this.tourSlug,
    this.floorplan,
    this.rooms = const [],
    this.createdAt,
  });

  final String id;
  final String title;
  final String status;
  final String? address;
  final String? description;
  final String? coverImageUrl;
  final String? publicSlug;
  final String? tourSlug;
  final FloorplanModel? floorplan;
  final List<RoomModel> rooms;
  final DateTime? createdAt;

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    return PropertyModel(
      id: json['id'] as String,
      title: json['title'] as String,
      status: json['status'] as String,
      address: json['address'] as String?,
      description: json['description'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      publicSlug: json['publicSlug'] as String?,
      tourSlug: json['tourSlug'] as String?,
      floorplan: json['floorplan'] != null
          ? FloorplanModel.fromJson(json['floorplan'] as Map<String, dynamic>)
          : null,
      rooms: (json['rooms'] as List<dynamic>?)
              ?.map((r) => RoomModel.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  bool get isReady => status == 'READY' || status == 'PUBLISHED';

  int get totalMedia =>
      rooms.fold<int>(0, (sum, r) => sum + r.mediaCount);

  @override
  List<Object?> get props =>
      [id, title, status, address, rooms, publicSlug, floorplan, tourSlug];
}
