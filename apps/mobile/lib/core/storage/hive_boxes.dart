import 'package:hive_flutter/hive_flutter.dart';

import '../../features/upload/data/models/upload_task_model.dart';

abstract final class HiveBoxes {
  static const uploadQueue = 'upload_queue';
  static const draftProperties = 'draft_properties';
  static const draftRooms = 'draft_rooms';

  static Future<void> registerAdapters() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UploadStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UploadTaskModelAdapter());
    }
  }

  static Future<void> openAll() async {
    await Hive.openBox<UploadTaskModel>(uploadQueue);
    await Hive.openBox(draftProperties);
    await Hive.openBox(draftRooms);
  }
}
