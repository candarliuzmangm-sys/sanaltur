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
    this.category = 'APARTMENT',
    this.floorCount,
    this.roomCounts = const {},
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
  final String category;
  final int? floorCount;
  final Map<String, int> roomCounts;

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    Map<String, int> counts = const {};
    final rc = json['roomCounts'];
    if (rc is Map) {
      counts = {
        for (final e in rc.entries)
          e.key.toString(): (e.value is num ? (e.value as num).toInt() : 0),
      };
    }

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
      category: (json['category'] as String?) ?? 'APARTMENT',
      floorCount: (json['floorCount'] as num?)?.toInt(),
      roomCounts: counts,
    );
  }

  bool get isReady => status == 'READY' || status == 'PUBLISHED';

  int get totalMedia =>
      rooms.fold<int>(0, (sum, r) => sum + r.mediaCount);

  String get categoryLabel {
    switch (category) {
      case 'VILLA':
        return 'Villa';
      case 'OFFICE':
        return 'Ofis';
      case 'STORE':
        return 'Mağaza';
      case 'SHOP':
        return 'Dükkan';
      case 'OTHER':
        return 'Diğer';
      case 'APARTMENT':
      default:
        return 'Daire';
    }
  }

  @override
  List<Object?> get props => [
        id,
        title,
        status,
        address,
        rooms,
        publicSlug,
        floorplan,
        tourSlug,
        category,
        floorCount,
        roomCounts,
      ];
}
