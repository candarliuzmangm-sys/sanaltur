import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/upload_queue_storage.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../data/models/upload_task_model.dart';
import '../../data/repositories/upload_repository.dart';

final uploadQueueProvider =
    StateNotifierProvider<UploadQueueNotifier, List<UploadTaskModel>>((ref) {
  return UploadQueueNotifier(ref);
});

final uploadQueueProcessorProvider = Provider<void>((ref) {
  final notifier = ref.read(uploadQueueProvider.notifier);
  final sub = Connectivity().onConnectivityChanged.listen((results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online) notifier.processPending();
  });
  ref.onDispose(sub.cancel);
  Future.microtask(notifier.processPending);
});

class UploadQueueNotifier extends StateNotifier<List<UploadTaskModel>> {
  UploadQueueNotifier(this._ref) : super(UploadQueueStorage.getAll()) {
    _refresh();
  }

  final Ref _ref;
  bool _processing = false;

  void _refresh() {
    state = UploadQueueStorage.getAll();
  }

  Future<UploadResult?> enqueueAndUpload({
    required String propertyId,
    required String roomId,
    required String localPath,
    required String mimeType,
    String? fileName,
  }) async {
    final repo = _ref.read(uploadRepositoryProvider);
    final task = await repo.enqueueMedia(
      propertyId: propertyId,
      roomId: roomId,
      localPath: localPath,
      mimeType: mimeType,
      fileName: fileName,
    );
    _refresh();
    return processTask(task.id);
  }

  Future<UploadResult?> processTask(String taskId) async {
    final task = state.firstWhere((t) => t.id == taskId);
    final repo = _ref.read(uploadRepositoryProvider);

    try {
      final result = await repo.processTask(
        task,
        onProgress: (p) {
          UploadQueueStorage.update(task.copyWith(progress: p));
          _refresh();
        },
      );
      _refresh();
      _ref.read(propertyActionsProvider).invalidate(task.propertyId);
      return result;
    } catch (_) {
      _refresh();
      rethrow;
    }
  }

  Future<void> processPending() async {
    if (_processing) return;
    _processing = true;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return;

      final repo = _ref.read(uploadRepositoryProvider);
      final pending = UploadQueueStorage.pendingTasks();

      for (final task in pending) {
        try {
          await repo.processTask(
            task,
            onProgress: (p) {
              UploadQueueStorage.update(task.copyWith(progress: p));
              _refresh();
            },
          );
          _ref.read(propertyActionsProvider).invalidate(task.propertyId);
        } catch (_) {
          // keep failed state in queue for retry
        }
        _refresh();
      }
    } finally {
      _processing = false;
    }
  }

  Future<UploadResult?> retry(String taskId) async {
    final task = state.firstWhere((t) => t.id == taskId);
    await UploadQueueStorage.update(
      task.copyWith(status: UploadStatus.pending, errorMessage: null, progress: 0),
    );
    _refresh();
    return processTask(taskId);
  }
}
