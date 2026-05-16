import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});

class AuthRepository {
  AuthRepository(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<void> login({required String email, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    await _tokenStorage.saveTokens(
      accessToken: response.data!['accessToken'] as String,
      refreshToken: response.data!['refreshToken'] as String,
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'fullName': fullName,
      },
    );

    await _tokenStorage.saveTokens(
      accessToken: response.data!['accessToken'] as String,
      refreshToken: response.data!['refreshToken'] as String,
    );
  }

  Future<void> logout() => _tokenStorage.clear();

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      return response.data;
    } catch (_) {
      return null;
    }
  }
}
