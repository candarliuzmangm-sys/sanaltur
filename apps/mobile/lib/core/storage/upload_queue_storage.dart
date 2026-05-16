import 'package:hive_flutter/hive_flutter.dart';

import '../../features/upload/data/models/upload_task_model.dart';
import 'hive_boxes.dart';

class UploadQueueStorage {
  UploadQueueStorage._();

  static late Box<UploadTaskModel> _box;

  static Future<void> init() async {
    _box = Hive.box<UploadTaskModel>(HiveBoxes.uploadQueue);
  }

  static List<UploadTaskModel> getAll() => _box.values.toList();

  static Future<void> enqueue(UploadTaskModel task) async {
    await _box.put(task.id, task);
  }

  static Future<void> update(UploadTaskModel task) async {
    await _box.put(task.id, task);
  }

  static Future<void> remove(String id) async {
    await _box.delete(id);
  }

  static List<UploadTaskModel> pendingTasks() =>
      _box.values.where((t) => t.status == UploadStatus.pending).toList();
}
