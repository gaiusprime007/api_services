import '../../flutter_api_services.dart' show ApiClient;
import '../api_client.dart' show ApiClient;
import 'error_type.dart';

/// Thrown by [ApiClient] whenever a request does not succeed.
///
/// Always catch this in your data layer and handle by [type]:
///
/// ```dart
/// try {
///   final res = await api.send(...);
/// } on ApiException catch (e) {
///   switch (e.type) {
///     case ApiErrorType.network:
///       showBanner('No internet connection');
///     case ApiErrorType.unauthorized:
///       navigateToLogin();
///     case ApiErrorType.rateLimited:
///       showBanner('Too many requests. Retry in ${e.retryAfter?.inSeconds}s');
///     default:
///       showBanner(e.message);
///   }
/// }
/// ```
class ApiException implements Exception {
  /// HTTP status code, if the server responded.
  /// `null` for network / timeout errors.
  final int? statusCode;

  /// Human-readable message extracted from the server response,
  /// or a generic description for network/timeout errors.
  final String message;

  /// Structured error type — use this to drive UI decisions.
  final ApiErrorType type;

  /// Full parsed response body (Map, List, or String).
  /// Useful for extracting field-level validation errors.
  ///
  /// Example — Django REST / NestJS validation payload:
  /// ```dart
  /// if (e.type == ApiErrorType.unprocessable) {
  ///   final fields = e.body as Map<String, dynamic>;
  ///   // { "email": ["Enter a valid email."] }
  /// }
  /// ```
  final dynamic body;

  /// Populated for 429 responses if the server sends a
  /// `Retry-After` header (in seconds).
  final Duration? retryAfter;

  const ApiException({
    required this.message,
    required this.type,
    this.statusCode,
    this.body,
    this.retryAfter,
  });

  // ── Convenience booleans ────────────────────────────────────────────────

  bool get isUnauthorized => type == ApiErrorType.unauthorized;
  bool get isForbidden => type == ApiErrorType.forbidden;
  bool get isNotFound => type == ApiErrorType.notFound;
  bool get isNetworkError => type == ApiErrorType.network;
  bool get isTimeout => type == ApiErrorType.timeout;
  bool get isRateLimited => type == ApiErrorType.rateLimited;
  bool get isServerError =>
      statusCode != null && statusCode! >= 500 && statusCode! < 600;
  bool get isClientError =>
      statusCode != null && statusCode! >= 400 && statusCode! < 500;

  @override
  String toString() =>
      'ApiException(type: $type, status: $statusCode, message: $message)';
}
