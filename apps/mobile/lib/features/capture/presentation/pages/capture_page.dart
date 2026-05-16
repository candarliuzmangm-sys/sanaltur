import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/platform/capture_platform.dart';
import '../../../../core/presentation/navigation.dart';
import '../../../upload/data/repositories/upload_repository.dart';
import '../../../rooms/presentation/providers/room_provider.dart';
import '../../../upload/presentation/providers/upload_queue_provider.dart';
import '../providers/camera_provider.dart';

class CapturePage extends ConsumerStatefulWidget {
  const CapturePage({
    super.key,
    required this.propertyId,
    required this.roomId,
  });

  final String propertyId;
  final String roomId;

  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends ConsumerState<CapturePage> {
  final List<String> _capturedPaths = [];
  bool _isCapturing = false;
  bool _isUploading = false;
  String? _uploadError;
  String? _aiResultLabel;

  @override
  Widget build(BuildContext context) {
    if (!supportsLiveCamera) {
      return _buildScaffold(body: _desktopCaptureBody());
    }

    final cameraAsync = ref.watch(cameraControllerProvider);
    return _buildScaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          cameraAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _cameraErrorBody(e),
            data: (controller) => CameraPreview(controller),
          ),
          ..._overlayChildren(
            onCapture: () => cameraAsync.whenData(_takePhoto),
          ),
        ],
      ),
    );
  }

  Widget _buildScaffold({required Widget body}) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Oda Cekimi'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Geri',
          onPressed: _isUploading ? null : () => context.pop(),
        ),
        actions: const [HomeToolbarAction()],
      ),
      body: body,
    );
  }

  Widget _desktopCaptureBody() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.photo_library_outlined, color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                Text(
                  _capturedPaths.isEmpty
                      ? 'Windows testi: Galeriden fotoğraf seçin.'
                      : '${_capturedPaths.length} fotoğraf seçildi',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isUploading ? null : _pickFromGallery,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Galeriden seç'),
                ),
              ],
            ),
          ),
        ),
        ..._overlayChildren(onCapture: _pickFromGallery),
      ],
    );
  }

  Widget _cameraErrorBody(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Kamera açılamadı: $error\nGaleriden seçim yapabilirsiniz.',
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  List<Widget> _overlayChildren({required VoidCallback onCapture}) {
    return [
      if (_isUploading)
        Container(
          color: Colors.black54,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Yükleniyor ve AI analiz ediyor...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: _CaptureControls(
          capturedCount: _capturedPaths.length,
          isCapturing: _isCapturing || _isUploading,
          onCapture: onCapture,
          onGallery: _pickFromGallery,
          showShutter: supportsLiveCamera,
          onDone: _capturedPaths.isNotEmpty && !_isUploading ? _uploadAllAndFinish : null,
        ),
      ),
      if (_uploadError != null)
        Positioned(
          top: 80,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.red.shade700,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_uploadError!, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
      if (_aiResultLabel != null)
        Positioned(
          top: 80,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.green.shade700,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'AI: $_aiResultLabel',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
    ];
  }

  Future<void> _takePhoto(CameraController controller) async {
    if (_isCapturing || !controller.value.isInitialized) return;
    setState(() {
      _isCapturing = true;
      _uploadError = null;
    });
    try {
      final file = await controller.takePicture();
      setState(() => _capturedPaths.add(file.path));
    } catch (e) {
      setState(() => _uploadError = e.toString());
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty || !mounted) return;
    setState(() {
      _capturedPaths.addAll(images.map((i) => i.path));
      _uploadError = null;
    });
  }

  String _mimeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _uploadAllAndFinish() async {
    setState(() {
      _isUploading = true;
      _uploadError = null;
      _aiResultLabel = null;
    });

    try {
      UploadResult? lastResult;
      for (final path in _capturedPaths) {
        lastResult = await ref.read(uploadQueueProvider.notifier).enqueueAndUpload(
              propertyId: widget.propertyId,
              roomId: widget.roomId,
              localPath: path,
              mimeType: _mimeForPath(path),
            );
      }

      if (lastResult != null && mounted) {
        final aiType = lastResult.room.aiDetectedType;
        setState(() {
          _aiResultLabel = aiType?.label ?? 'Siniflandirildi';
        });
        ref.invalidate(
          roomDetailProvider((
            propertyId: widget.propertyId,
            roomId: widget.roomId,
          )),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
        if (mounted) context.pop();
      }
    } catch (e) {
      setState(() => _uploadError = 'Yukleme hatasi: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}

class _CaptureControls extends StatelessWidget {
  const _CaptureControls({
    required this.capturedCount,
    required this.isCapturing,
    required this.onCapture,
    required this.onGallery,
    this.onDone,
    this.showShutter = true,
  });

  final int capturedCount;
  final bool isCapturing;
  final VoidCallback onCapture;
  final VoidCallback onGallery;
  final VoidCallback? onDone;
  final bool showShutter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onDone != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.icon(
                onPressed: onDone,
                icon: const Icon(Icons.cloud_upload),
                label: Text('Yukle ($capturedCount)'),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: isCapturing ? null : onGallery,
                icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
              ),
              if (showShutter)
                GestureDetector(
                  onTap: isCapturing ? null : onCapture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: isCapturing ? Colors.grey : Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 72),
              Text(
                '$capturedCount',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
