import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/upload/presentation/providers/upload_queue_provider.dart';

class SanalturApp extends ConsumerWidget {
  const SanalturApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(uploadQueueProcessorProvider);

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Sanaltur',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Sistem karanlık modunda eski tema metinleri görünmezdi; her iki tema da düzeltildi.
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
