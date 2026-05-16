import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/platform/capture_platform.dart';
import '../../../../core/presentation/navigation.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../upload/data/repositories/upload_repository.dart';
import '../../../rooms/presentation/providers/room_provider.dart';
import '../../../upload/presentation/providers/upload_queue_provider.dart';
import '../providers/camera_provider.dart';

/// Çekim modu — kullanıcı ne yüklemek istediğini seçer.
enum CaptureMode {
  photo,
  gallery,
  panorama,
}

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
  CaptureMode? _mode;
  final List<_PendingItem> _pending = [];
  bool _isCapturing = false;
  bool _isUploading = false;
  String? _uploadError;
  String? _aiResultLabel;

  @override
  Widget build(BuildContext context) {
    if (_mode == null) {
      return _modeSelectorScaffold();
    }
    if (_mode == CaptureMode.photo) {
      return _photoCaptureScaffold();
    }
    // gallery + panorama: galeri seçimi sonrası önizleme + yükleme
    return _gallerySelectionScaffold();
  }

  // -------- MODE SELECTOR --------

  Scaffold _modeSelectorScaffold() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Çekim Modu'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Geri',
          onPressed: () => context.pop(),
        ),
        actions: const [HomeToolbarAction()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'Nasıl çekim yapmak istersin?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Her bir oda için en uygun çekim tipini seç. İstediğin kadar fotoğraf ekleyebilirsin.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _ModeCard(
                      icon: Icons.photo_camera_outlined,
                      title: 'Fotoğraf çek',
                      description:
                          'Telefon kameranla tek tek çek. Hızlı ve pratik.',
                      accent: AppTheme.primary,
                      onTap: () => setState(() => _mode = CaptureMode.photo),
                    ),
                    const SizedBox(height: 14),
                    _ModeCard(
                      icon: Icons.view_in_ar_outlined,
                      title: '360° Panorama',
                      description:
                          'Telefon kamerasındaki "Panorama" modunda çekilmiş 360°/equirectangular fotoğrafı seç. Sanal turda gerçek 360 görünüm.',
                      accent: const Color(0xFF22C55E),
                      badge: 'En iyi tur',
                      onTap: () => _pickPanoramaFromGallery(),
                    ),
                    const SizedBox(height: 14),
                    _ModeCard(
                      icon: Icons.photo_library_outlined,
                      title: 'Galeriden yükle',
                      description:
                          'Hazır fotoğraflarını çoklu seçimle hızlıca yükle.',
                      accent: const Color(0xFF6366F1),
                      onTap: () => _pickGalleryMulti(),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tips_and_updates_outlined,
                        color: Colors.amberAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'İpucu: Sanal turda en güzel sonucu telefonun Panorama modu verir. Çekim sırasında oda ortasında dön, sabit kal.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------- PHOTO MODE (live camera) --------

  Scaffold _photoCaptureScaffold() {
    if (!supportsLiveCamera) {
      return _genericScaffold(
        title: 'Fotoğraf çek',
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.photo_camera_outlined,
                    color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                Text(
                  _pending.isEmpty
                      ? 'Bu cihazda kamera yok. Galeriden seç.'
                      : '${_pending.length} fotoğraf hazır',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isUploading ? null : _pickGalleryMulti,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Galeriden seç'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final cameraAsync = ref.watch(cameraControllerProvider);
    return _genericScaffold(
      title: 'Fotoğraf çek',
      body: Stack(
        fit: StackFit.expand,
        children: [
          cameraAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Kamera açılamadı: $e',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (controller) => CameraPreview(controller),
          ),
          ..._captureOverlay(
            onShutter: () => cameraAsync.whenData(_takePhotoFromCamera),
          ),
        ],
      ),
    );
  }

  // -------- GALLERY / PANORAMA --------

  Scaffold _gallerySelectionScaffold() {
    final isPano = _mode == CaptureMode.panorama;
    return _genericScaffold(
      title: isPano ? '360° Panorama' : 'Galeriden yükle',
      body: _pending.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPano
                          ? Icons.view_in_ar_outlined
                          : Icons.photo_library_outlined,
                      color: Colors.white54,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isPano
                          ? 'Henüz panorama seçmedin'
                          : 'Henüz fotoğraf seçmedin',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isUploading
                          ? null
                          : (isPano
                              ? _pickPanoramaFromGallery
                              : _pickGalleryMulti),
                      icon: const Icon(Icons.add_photo_alternate),
                      label: Text(isPano ? 'Panorama seç' : 'Fotoğraf seç'),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _pending.length,
                      itemBuilder: (_, i) {
                        final item = _pending[i];
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(item.path),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.black26,
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.white54),
                                ),
                              ),
                            ),
                            if (item.mediaType == 'PANORAMA')
                              const Positioned(
                                top: 4,
                                left: 4,
                                child: _PanoBadge(),
                              ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      Colors.black.withValues(alpha: 0.6),
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(28, 28),
                                ),
                                iconSize: 16,
                                color: Colors.white,
                                onPressed: _isUploading
                                    ? null
                                    : () => setState(
                                        () => _pending.removeAt(i)),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isUploading
                              ? null
                              : (isPano
                                  ? _pickPanoramaFromGallery
                                  : _pickGalleryMulti),
                          icon: const Icon(Icons.add_a_photo),
                          label: Text(isPano ? 'Başka panorama' : 'Daha ekle'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _isUploading ? null : _uploadAllAndFinish,
                          icon: const Icon(Icons.cloud_upload),
                          label: Text('Yükle (${_pending.length})'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  // -------- COMMON SCAFFOLD --------

  Scaffold _genericScaffold({required String title, required Widget body}) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isUploading
              ? null
              : () => setState(() {
                    _mode = null;
                    _pending.clear();
                  }),
        ),
        actions: const [HomeToolbarAction()],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          body,
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
                      'Yükleniyor...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
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
                  child: Text(_uploadError!,
                      style: const TextStyle(color: Colors.white)),
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
        ],
      ),
    );
  }

  // -------- CAPTURE OVERLAY (camera mode) --------

  List<Widget> _captureOverlay({required VoidCallback onShutter}) {
    return [
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
              if (_pending.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton.icon(
                    onPressed: _isUploading ? null : _uploadAllAndFinish,
                    icon: const Icon(Icons.cloud_upload),
                    label: Text('Yükle (${_pending.length})'),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _isCapturing || _isUploading
                        ? null
                        : _pickGalleryMulti,
                    icon: const Icon(Icons.photo_library,
                        color: Colors.white, size: 32),
                  ),
                  GestureDetector(
                    onTap: _isCapturing || _isUploading ? null : onShutter,
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
                            color: _isCapturing ? Colors.grey : Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '${_pending.length}',
                    style:
                        const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // -------- ACTIONS --------

  Future<void> _takePhotoFromCamera(CameraController controller) async {
    if (_isCapturing || !controller.value.isInitialized) return;
    setState(() {
      _isCapturing = true;
      _uploadError = null;
    });
    try {
      final file = await controller.takePicture();
      setState(() => _pending.add(_PendingItem(file.path, 'IMAGE')));
    } catch (e) {
      setState(() => _uploadError = 'Çekim hatası: $e');
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickGalleryMulti() async {
    final images =
        await ImagePicker().pickMultiImage(imageQuality: 85);
    if (images.isEmpty || !mounted) return;
    setState(() {
      if (_mode == null) _mode = CaptureMode.gallery;
      _pending.addAll(images.map((i) => _PendingItem(i.path, 'IMAGE')));
      _uploadError = null;
    });
  }

  Future<void> _pickPanoramaFromGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (_mode == null) _mode = CaptureMode.panorama;
      _pending.add(_PendingItem(picked.path, 'PANORAMA'));
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
    if (_pending.isEmpty) return;
    setState(() {
      _isUploading = true;
      _uploadError = null;
      _aiResultLabel = null;
    });

    try {
      UploadResult? lastResult;
      for (final item in _pending) {
        lastResult =
            await ref.read(uploadQueueProvider.notifier).enqueueAndUpload(
                  propertyId: widget.propertyId,
                  roomId: widget.roomId,
                  localPath: item.path,
                  mimeType: _mimeForPath(item.path),
                  mediaType: item.mediaType,
                );
      }

      if (lastResult != null && mounted) {
        final aiType = lastResult.room.aiDetectedType;
        setState(() {
          _aiResultLabel = aiType?.label ?? 'Yüklendi';
        });
        ref.invalidate(
          roomDetailProvider((
            propertyId: widget.propertyId,
            roomId: widget.roomId,
          )),
        );
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (mounted) context.pop();
      }
    } catch (e) {
      setState(() => _uploadError = 'Yükleme hatası: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}

class _PendingItem {
  const _PendingItem(this.path, this.mediaType);
  final String path;
  final String mediaType;
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanoBadge extends StatelessWidget {
  const _PanoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '360°',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

