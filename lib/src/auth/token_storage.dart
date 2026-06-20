import '../../flutter_api_services.dart' show ApiClient;
import '../api_client.dart' show ApiClient;

/// Abstract interface for reading and writing auth tokens.
///
/// The default implementation uses [SharedPreferences].
/// Swap it for [flutter_secure_storage] or any other backend
/// by passing your own implementation to [ApiClient.tokenStorage].
///
/// ```dart
/// class SecureTokenStorage implements TokenStorage {
///   final _storage = FlutterSecureStorage();
///
///   @override
///   Future<String?> getAccessToken() => _storage.read(key: 'access');
///
///   @override
///   Future<String?> getRefreshToken() => _storage.read(key: 'refresh');
///
///   @override
///   Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
///     await _storage.write(key: 'access', value: accessToken);
///     if (refreshToken != null) await _storage.write(key: 'refresh', value: refreshToken);
///   }
///
///   @override
///   Future<void> clearTokens() async {
///     await _storage.delete(key: 'access');
///     await _storage.delete(key: 'refresh');
///   }
/// }
/// ```
abstract class TokenStorage {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  });
  Future<void> clearTokens();
}
