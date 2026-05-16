import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';

class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = true,
    this.user,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final Map<String, dynamic>? user;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    Map<String, dynamic>? user,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
    );
  }
}

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    final repo = _ref.read(authRepositoryProvider);
    final profile = await repo.getProfile();
    state = AuthState(
      isAuthenticated: profile != null,
      isLoading: false,
      user: profile,
    );
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    final repo = _ref.read(authRepositoryProvider);
    await repo.login(email: email, password: password);
    final profile = await repo.getProfile();
    state = AuthState(isAuthenticated: true, isLoading: false, user: profile);
  }

  Future<void> register(String email, String password, String fullName) async {
    state = state.copyWith(isLoading: true);
    final repo = _ref.read(authRepositoryProvider);
    await repo.register(email: email, password: password, fullName: fullName);
    final profile = await repo.getProfile();
    state = AuthState(isAuthenticated: true, isLoading: false, user: profile);
  }

  Future<void> logout() async {
    await _ref.read(authRepositoryProvider).logout();
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }
}
