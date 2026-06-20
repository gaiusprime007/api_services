import 'package:shared_preferences/shared_preferences.dart';
import 'token_storage.dart';

/// Default [TokenStorage] backed by [SharedPreferences].
///
/// Tokens are stored in plaintext. For production apps that need
/// extra security, replace this with a [flutter_secure_storage] implementation.
class SharedPrefsTokenStorage implements TokenStorage {
  static const _accessKey = 'fas_access_token';
  static const _refreshKey = 'fas_refresh_token';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<String?> getAccessToken() async =>
      (await _store).getString(_accessKey);

  @override
  Future<String?> getRefreshToken() async =>
      (await _store).getString(_refreshKey);

  @override
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    final s = await _store;
    await s.setString(_accessKey, accessToken);
    if (refreshToken != null) {
      await s.setString(_refreshKey, refreshToken);
    }
  }

  @override
  Future<void> clearTokens() async {
    final s = await _store;
    await Future.wait([
      s.remove(_accessKey),
      s.remove(_refreshKey),
    ]);
  }
}
