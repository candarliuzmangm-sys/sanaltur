import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/storage/hive_boxes.dart';
import 'core/storage/token_storage.dart';
import 'core/storage/upload_queue_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Hive.initFlutter();
  await HiveBoxes.registerAdapters();
  await HiveBoxes.openAll();
  await UploadQueueStorage.init();

  Env.load();

  final tokenStorage = await createTokenStorage();

  runApp(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokenStorage),
      ],
      child: const SanalturApp(),
    ),
  );
}
