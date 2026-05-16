import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  throw UnimplementedError('Override in main scope if needed');
});

class TokenStorage {
  TokenStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  Future<String?> getAccessToken() => Future.value(_prefs.getString(_accessKey));

  Future<String?> getRefreshToken() =>
      Future.value(_prefs.getString(_refreshKey));

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _prefs.setString(_accessKey, accessToken);
    await _prefs.setString(_refreshKey, refreshToken);
  }

  Future<void> clear() async {
    await _prefs.remove(_accessKey);
    await _prefs.remove(_refreshKey);
  }
}

Future<TokenStorage> createTokenStorage() async {
  final prefs = await SharedPreferences.getInstance();
  return TokenStorage(prefs);
}
