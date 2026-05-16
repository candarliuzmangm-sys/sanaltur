import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/upload_task_model.dart';
import '../providers/upload_queue_provider.dart';

class UploadStatusBanner extends ConsumerWidget {
  const UploadStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(uploadQueueProvider);
    final pending = queue.where((t) => t.status != UploadStatus.completed).length;
    final failed = queue.where((t) => t.status == UploadStatus.failed).length;

    if (pending == 0) return const SizedBox.shrink();

    return MaterialBanner(
      content: Text(
        failed > 0
            ? '$pending yükleme bekliyor ($failed başarısız)'
            : '$pending medya yükleniyor...',
      ),
      leading: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      actions: [
        if (failed > 0)
          TextButton(
            onPressed: () {
              for (final t in queue.where((t) => t.status == UploadStatus.failed)) {
                ref.read(uploadQueueProvider.notifier).retry(t.id);
              }
            },
            child: const Text('Tekrar dene'),
          ),
      ],
    );
  }
}
