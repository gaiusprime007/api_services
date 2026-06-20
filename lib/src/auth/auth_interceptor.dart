import '../auth/token_storage.dart';

/// Internal helper that manages Bearer token injection and
/// the token-refresh queue lock.
///
/// Exposed in the public API so advanced users can subclass it.
class AuthInterceptor {
  final TokenStorage storage;

  AuthInterceptor(this.storage);

  /// Returns the current `Authorization: Bearer <token>` header value,
  /// or `null` if no token is stored.
  Future<String?> authorizationHeader() async {
    final token = await storage.getAccessToken();
    return token != null ? 'Bearer $token' : null;
  }
}
