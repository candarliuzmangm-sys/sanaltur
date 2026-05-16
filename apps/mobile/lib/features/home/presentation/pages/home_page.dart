import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../upload/presentation/providers/upload_queue_provider.dart';
import '../../../upload/presentation/widgets/upload_status_banner.dart';

/// Kept for /home route; main entry is /properties.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(propertyListProvider);
    final uploadQueue = ref.watch(uploadQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sanaltur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'Mülkler',
            onPressed: () => context.push('/properties'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (uploadQueue.isNotEmpty) const UploadStatusBanner(),
          Expanded(
            child: properties.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: FilledButton.icon(
                      onPressed: () => context.push('/properties/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('İlk mülkünüzü oluşturun'),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return ListTile(
                      title: Text(p.title),
                      subtitle: Text('${p.rooms.length} oda'),
                      onTap: () => context.push('/properties/${p.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/properties/new'),
        icon: const Icon(Icons.add_home_work),
        label: const Text('Yeni Mülk'),
      ),
    );
  }
}
