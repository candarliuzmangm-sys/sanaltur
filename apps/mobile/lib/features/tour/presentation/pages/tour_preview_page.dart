import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/config/env.dart';
import '../../../../core/presentation/navigation.dart';
import '../providers/tour_provider.dart';

class TourPreviewPage extends ConsumerStatefulWidget {
  const TourPreviewPage({super.key, required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<TourPreviewPage> createState() => _TourPreviewPageState();
}

class _TourPreviewPageState extends ConsumerState<TourPreviewPage> {
  WebViewController? _controller;
  bool _injected = false;

  void _injectTour(Object tourJson) {
    final controller = _controller;
    if (controller == null || _injected) return;
    _injected = true;
    final payload = jsonEncode(tourJson);
    controller.runJavaScript('window.initTour($payload);');
  }

  @override
  Widget build(BuildContext context) {
    final tourAsync = ref.watch(propertyTourProvider(widget.propertyId));

    return Scaffold(
      backgroundColor: const Color(0xFF0C0F0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121816),
        foregroundColor: Colors.white,
        title: tourAsync.maybeWhen(
          data: (t) => Text(t.title),
          orElse: () => const Text('Sanal Tur'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Geri',
          onPressed: () => context.pop(),
        ),
        actions: [
          tourAsync.maybeWhen(
            data: (t) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (t.shareUrl != null)
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Linki paylaş',
                    onPressed: () => _shareTour(context, t.shareUrl!),
                  ),
                IconButton(
                  icon: const Icon(Icons.open_in_browser),
                  tooltip: 'Tarayıcıda aç',
                  onPressed: () => launchUrl(
                    Uri.parse(Env.publicTourUrl(t.slug)),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const HomeToolbarAction(),
        ],
      ),
      body: tourAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF2D9F6F)),
        ),
        error: (e, _) => _TourError(
          message: e.toString(),
          onRetry: () {
            setState(() {
              _injected = false;
              _controller = null;
            });
            ref.invalidate(propertyTourProvider(widget.propertyId));
          },
        ),
        data: (tour) {
          final tourJson = tour.toJson();
          _controller ??= WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(const Color(0xFF0C0F0E))
            ..setNavigationDelegate(
              NavigationDelegate(
                onPageFinished: (_) => _injectTour(tourJson),
              ),
            )
            ..loadRequest(Uri.parse(Env.tourViewerUrl));

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _injectTour(tourJson);
          });

          return WebViewWidget(
            key: ValueKey('${widget.propertyId}-${tour.rooms.length}'),
            controller: _controller!,
          );
        },
      ),
    );
  }

  Future<void> _shareTour(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tur linki kopyalandı')),
      );
    }
  }
}

class _TourError extends StatelessWidget {
  const _TourError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_in_ar_outlined,
                size: 48, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              message.contains('404') || message.contains('NotFound')
                  ? 'Tur henüz oluşturulmadı.\nAI Stüdyo → Sanal tur ile oluşturun.'
                  : message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
