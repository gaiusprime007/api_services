import '../flutter_api_services.dart' show ApiClient;
import 'api_client.dart' show ApiClient;

/// The normalised, typed response from every [ApiClient.send] call.
///
/// ```dart
/// final res = await api.send(ApiRequest(path: '/users'));
///
/// // Check status
/// print(res.statusCode);   // 200
/// print(res.isSuccess);    // true
///
/// // Access data
/// final user = res.asMap;  // Map<String, dynamic>
/// final list = res.asList; // List<dynamic>
/// final raw  = res.asString;
///
/// // No-content check (204)
/// if (res.isEmpty) { ... }
/// ```
class ApiResponse<T> {
  /// HTTP status code.
  final int statusCode;

  /// Parsed response body:
  ///   - JSON object  → `Map<String, dynamic>`
  ///   - JSON array   → `List<dynamic>`
  ///   - Plain text   → `String`
  ///   - No content   → `null`
  final T? data;

  /// Raw response headers (lowercase keys).
  final Map<String, String> headers;

  /// Duration from request send to response received.
  final Duration? duration;

  const ApiResponse({
    required this.statusCode,
    required this.headers,
    this.data,
    this.duration,
  });

  // ── Status helpers ────────────────────────────────────────────────────

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isCreated => statusCode == 201;
  bool get isEmpty => statusCode == 204 || data == null;

  // ── Data accessors ────────────────────────────────────────────────────

  /// Cast [data] to `Map<String, dynamic>` (JSON object response).
  /// Throws [StateError] if [data] is not a map.
  Map<String, dynamic> get asMap {
    if (data is Map<String, dynamic>) return data as Map<String, dynamic>;
    throw StateError(
      'Response data is ${data.runtimeType}, not Map<String, dynamic>. '
      'Use asList or asString instead.',
    );
  }

  /// Cast [data] to `List<dynamic>` (JSON array response).
  List<dynamic> get asList {
    if (data is List) return data as List<dynamic>;
    throw StateError(
      'Response data is ${data.runtimeType}, not List. '
      'Use asMap or asString instead.',
    );
  }

  /// Cast [data] to [String] (plain-text response).
  String get asString => data?.toString() ?? '';

  /// Try to cast [data] as a map; returns `null` if not a map.
  Map<String, dynamic>? get asMapOrNull =>
      data is Map<String, dynamic> ? data as Map<String, dynamic> : null;

  /// Try to cast [data] as a list; returns `null` if not a list.
  List<dynamic>? get asListOrNull => data is List ? data as List<dynamic> : null;

  // ── Header helpers ────────────────────────────────────────────────────

  String? header(String name) => headers[name.toLowerCase()];

  @override
  String toString() =>
      'ApiResponse(status: $statusCode, data: ${data.runtimeType})';
}
