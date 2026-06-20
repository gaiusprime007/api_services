import '../../flutter_api_services.dart' show ApiClient, ApiRequest;
import '../api_client.dart' show ApiClient;
import '../api_request.dart' show ApiRequest;

/// Configuration for [ApiClient].
///
/// Pass this to [ApiClient] to control base URL, timeouts,
/// token refresh behaviour, and global headers.
class ApiConfig {
  /// The base URL prepended to every relative path.
  /// Must NOT have a trailing slash.
  ///
  /// Example: `'https://api.example.com'`
  final String baseUrl;

  /// Path or full URL of the token-refresh endpoint.
  ///
  /// When a request fails with 401, the client will POST to this
  /// endpoint with `{ "refresh_token": "<stored_refresh_token>" }`
  /// and expect `{ "access_token": "...", "refresh_token": "..." }`.
  ///
  /// Set to `null` to disable automatic refresh.
  final String? refreshTokenPath;

  /// JSON field name for the access token in the refresh response.
  /// Defaults to `'access_token'`.
  final String refreshResponseAccessKey;

  /// JSON field name for the refresh token in the refresh response.
  /// Defaults to `'refresh_token'`.
  final String refreshResponseRefreshKey;

  /// JSON field name for the refresh token in the refresh request body.
  /// Defaults to `'refresh_token'`.
  final String refreshRequestBodyKey;

  /// Called after a successful token refresh.
  final void Function(String accessToken, String? refreshToken)?
      onTokenRefreshed;

  /// Called when a 401 occurs and refresh fails (or no refresh is configured).
  /// Use this to navigate to your login screen.
  final void Function()? onAuthFailed;

  /// Headers sent with every request (e.g. API version, app ID).
  final Map<String, String> defaultHeaders;

  /// Default timeout applied to every request.
  /// Can be overridden per-request via [ApiRequest.timeout].
  final Duration defaultTimeout;

  /// Whether to log requests and responses to the console.
  /// Automatically disabled in release builds unless [forceLogging] is true.
  final bool enableLogging;

  /// Force logging even in release mode. Default: false.
  final bool forceLogging;

  ApiConfig({
    required this.baseUrl,
    this.refreshTokenPath,
    this.refreshResponseAccessKey = 'access_token',
    this.refreshResponseRefreshKey = 'refresh_token',
    this.refreshRequestBodyKey = 'refresh_token',
    this.onTokenRefreshed,
    this.onAuthFailed,
    this.defaultHeaders = const {},
    this.defaultTimeout = const Duration(seconds: 30),
    this.enableLogging = true,
    this.forceLogging = false,
  }) : assert(
          !baseUrl.endsWith('/'),
          'baseUrl must not have a trailing slash.',
        );
}
