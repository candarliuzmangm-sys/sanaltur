import 'package:equatable/equatable.dart';

class FloorplanModel extends Equatable {
  const FloorplanModel({
    this.estimatedAreaSqm,
    this.svgUrl,
    this.layoutJson = const [],
  });

  final double? estimatedAreaSqm;
  final String? svgUrl;
  final List<FloorplanRoomLayout> layoutJson;

  factory FloorplanModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FloorplanModel();
    final raw = json['layoutJson'];
    List<FloorplanRoomLayout> layouts = [];
    if (raw is List) {
      layouts = raw
          .map((e) =>
              FloorplanRoomLayout.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return FloorplanModel(
      estimatedAreaSqm: (json['estimatedAreaSqm'] as num?)?.toDouble(),
      svgUrl: json['svgUrl'] as String?,
      layoutJson: layouts,
    );
  }

  bool get hasContent => svgUrl != null || layoutJson.isNotEmpty;

  @override
  List<Object?> get props => [estimatedAreaSqm, svgUrl, layoutJson];
}

class FloorplanRoomLayout extends Equatable {
  const FloorplanRoomLayout({
    required this.roomId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String roomId;
  final double x;
  final double y;
  final double width;
  final double height;

  factory FloorplanRoomLayout.fromJson(Map<String, dynamic> json) {
    return FloorplanRoomLayout(
      roomId: json['roomId'] as String? ?? json['room_id'] as String? ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 3,
      height: (json['height'] as num?)?.toDouble() ?? 3,
    );
  }

  @override
  List<Object?> get props => [roomId, x, y, width, height];
}
