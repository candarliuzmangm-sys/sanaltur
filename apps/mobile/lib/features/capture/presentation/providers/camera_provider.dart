import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final camerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  return availableCameras();
});

final cameraControllerProvider =
    FutureProvider.autoDispose<CameraController>((ref) async {
  final cameras = await ref.watch(camerasProvider.future);
  if (cameras.isEmpty) throw Exception('Kamera bulunamadı');

  final backCamera = cameras.firstWhere(
    (c) => c.lensDirection == CameraLensDirection.back,
    orElse: () => cameras.first,
  );

  final controller = CameraController(
    backCamera,
    ResolutionPreset.high,
    enableAudio: false,
    imageFormatGroup: ImageFormatGroup.jpeg,
  );

  await controller.initialize();

  ref.onDispose(() => controller.dispose());

  return controller;
});
