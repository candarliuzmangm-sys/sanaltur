import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/capture/presentation/pages/capture_page.dart';
import '../../features/capture/presentation/pages/room_review_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/properties/presentation/pages/create_property_page.dart';
import '../../features/properties/presentation/pages/property_detail_page.dart';
import '../../features/properties/presentation/pages/floorplan_page.dart';
import '../../features/properties/presentation/pages/property_list_page.dart';
import '../../features/rooms/presentation/pages/room_detail_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/tour/presentation/pages/tour_preview_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/properties';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterPage(),
      ),
      GoRoute(
        path: '/',
        redirect: (_, __) => '/properties',
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomePage(),
      ),
      GoRoute(
        path: '/properties',
        builder: (_, __) => const PropertyListPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsPage(),
      ),
      GoRoute(
        path: '/properties/new',
        builder: (_, __) => const CreatePropertyPage(),
      ),
      GoRoute(
        path: '/properties/:id',
        builder: (_, state) => PropertyDetailPage(
          propertyId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/properties/:id/rooms/:roomId',
        builder: (_, state) => RoomDetailPage(
          propertyId: state.pathParameters['id']!,
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/properties/:id/capture/:roomId',
        builder: (_, state) => CapturePage(
          propertyId: state.pathParameters['id']!,
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/properties/:id/rooms/:roomId/review',
        builder: (_, state) => RoomReviewPage(
          propertyId: state.pathParameters['id']!,
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/properties/:id/tour',
        builder: (_, state) => TourPreviewPage(
          propertyId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/properties/:id/floorplan',
        builder: (_, state) => FloorplanPage(
          propertyId: state.pathParameters['id']!,
        ),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Sayfa bulunamadı: ${state.uri}')),
    ),
  );
});
