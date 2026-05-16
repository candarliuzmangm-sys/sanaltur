import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Ana ekran: mülk listesi.
const String kHomeRoute = '/properties';

void goToHome(BuildContext context) => context.go(kHomeRoute);

/// AppBar sol: bir önceki sayfa veya mülk listesi.
class NavigationLeading extends StatelessWidget {
  const NavigationLeading({super.key, this.homeRoute = kHomeRoute});

  final String homeRoute;

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();
    return IconButton(
      icon: Icon(canPop ? Icons.arrow_back : Icons.home_outlined),
      tooltip: canPop ? 'Geri' : 'Mülklerim',
      onPressed: () {
        if (canPop) {
          context.pop();
        } else {
          context.go(homeRoute);
        }
      },
    );
  }
}

/// AppBar sağ: her zaman mülk listesine döner.
class HomeToolbarAction extends StatelessWidget {
  const HomeToolbarAction({super.key, this.homeRoute = kHomeRoute});

  final String homeRoute;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.home_outlined),
      tooltip: 'Mülklerim',
      onPressed: () => context.go(homeRoute),
    );
  }
}
