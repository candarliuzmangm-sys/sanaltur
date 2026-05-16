class TourHotspotModel {
  const TourHotspotModel({
    required this.id,
    required this.targetRoomId,
    required this.label,
    required this.yaw,
    required this.pitch,
  });

  final String id;
  final String targetRoomId;
  final String label;
  final double yaw;
  final double pitch;

  factory TourHotspotModel.fromJson(Map<String, dynamic> json) {
    return TourHotspotModel(
      id: json['id'] as String,
      targetRoomId: json['targetRoomId'] as String,
      label: json['label'] as String,
      yaw: (json['yaw'] as num).toDouble(),
      pitch: (json['pitch'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'targetRoomId': targetRoomId,
        'label': label,
        'yaw': yaw,
        'pitch': pitch,
      };
}

class TourRoomMediaModel {
  const TourRoomMediaModel({required this.url, required this.type});

  final String url;
  final String type;

  factory TourRoomMediaModel.fromJson(Map<String, dynamic> json) {
    return TourRoomMediaModel(
      url: json['url'] as String,
      type: (json['type'] as String?) ?? 'IMAGE',
    );
  }

  Map<String, dynamic> toJson() => {'url': url, 'type': type};
}

class TourRoomModel {
  const TourRoomModel({
    required this.id,
    required this.name,
    required this.type,
    required this.order,
    this.panoramaUrl,
    this.thumbnailUrl,
    this.mediaType,
    this.media = const [],
    required this.connections,
    required this.hotspots,
  });

  final String id;
  final String name;
  final String type;
  final int order;
  final String? panoramaUrl;
  final String? thumbnailUrl;
  final String? mediaType;
  final List<TourRoomMediaModel> media;
  final List<String> connections;
  final List<TourHotspotModel> hotspots;

  factory TourRoomModel.fromJson(Map<String, dynamic> json) {
    return TourRoomModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      order: json['order'] as int,
      panoramaUrl: json['panoramaUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      mediaType: json['mediaType'] as String?,
      media: (json['media'] as List<dynamic>? ?? [])
          .map((e) => TourRoomMediaModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      connections: (json['connections'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      hotspots: (json['hotspots'] as List<dynamic>? ?? [])
          .map((e) => TourHotspotModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'order': order,
        if (panoramaUrl != null) 'panoramaUrl': panoramaUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (mediaType != null) 'mediaType': mediaType,
        if (media.isNotEmpty)
          'media': media.map((m) => m.toJson()).toList(),
        'connections': connections,
        'hotspots': hotspots.map((h) => h.toJson()).toList(),
      };
}

class PropertyTourModel {
  const PropertyTourModel({
    required this.slug,
    required this.title,
    this.description,
    this.coverImageUrl,
    this.floorplanUrl,
    required this.startRoomId,
    this.shareUrl,
    required this.rooms,
  });

  final String slug;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final String? floorplanUrl;
  final String startRoomId;
  final String? shareUrl;
  final List<TourRoomModel> rooms;

  factory PropertyTourModel.fromJson(Map<String, dynamic> json) {
    return PropertyTourModel(
      slug: json['slug'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      floorplanUrl: json['floorplanUrl'] as String?,
      startRoomId: json['startRoomId'] as String? ?? '',
      shareUrl: json['shareUrl'] as String?,
      rooms: (json['rooms'] as List<dynamic>)
          .map((e) => TourRoomModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'title': title,
        if (description != null) 'description': description,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        if (floorplanUrl != null) 'floorplanUrl': floorplanUrl,
        'startRoomId': startRoomId,
        if (shareUrl != null) 'shareUrl': shareUrl,
        'rooms': rooms.map((r) => r.toJson()).toList(),
      };
}
