import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/config/env.dart';
import '../../../../core/presentation/navigation.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const NavigationLeading(),
        title: const Text('Ayarlar'),
        actions: const [HomeToolbarAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.person, color: theme.colorScheme.primary),
              ),
              title: Text(user?['fullName'] as String? ?? 'Kullanıcı'),
              subtitle: Text(user?['email'] as String? ?? ''),
            ),
          ),
          const SizedBox(height: 16),
          Text('Bağlantı', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.api_outlined),
                  title: const Text('API'),
                  subtitle: Text(
                    Env.apiBaseUrl,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.public_outlined),
                  title: const Text('Paylaşım web'),
                  subtitle: Text(
                    Env.publicWebUrl,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Uygulama', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Sanaltur'),
                  subtitle: const Text('Sürüm 0.1.0 · MVP'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text(
                    'Çıkış yap',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () async {
                    await ref.read(authStateProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
