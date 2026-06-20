import '../flutter_api_services.dart' show ApiClient, ApiConfig;
import 'api_client.dart' show ApiClient;
import 'config/api_config.dart' show ApiConfig;
import 'multipart/upload_file.dart';

/// Describes a single HTTP request.
///
/// Pass this to [ApiClient.send]. That's the only method you need.
///
/// ```dart
/// // Simplest possible request
/// final res = await api.send(ApiRequest(path: '/users'));
///
/// // Full example
/// final res = await api.send(ApiRequest(
///   path: '/profile/studio',
///   method: HttpMethod.put,
///   body: {'name': 'Zone 5 Studios'},
///   files: [avatarFile],
///   timeout: Duration(seconds: 60),
/// ));
/// ```
class ApiRequest {
  /// Relative path or full URL.
  ///
  /// Relative paths are joined with [ApiConfig.baseUrl]:
  ///   `'/api/v1/users'` → `'https://api.example.com/api/v1/users'`
  ///
  /// Full URLs bypass [baseUrl] entirely:
  ///   `'https://other-service.com/endpoint'`
  final String path;

  /// HTTP method. Defaults to [HttpMethod.get].
  final HttpMethod method;

  /// JSON-serialisable request body.
  ///
  /// For multipart requests, scalar values here are sent as text fields
  /// alongside the files. For regular requests, this is encoded as JSON.
  ///
  /// Ignored for GET and DELETE (use [queryParams] instead).
  final Map<String, dynamic>? body;

  /// URL query parameters appended to the path.
  ///
  /// ```dart
  /// queryParams: {'page': '1', 'limit': '20', 'q': 'accra'}
  /// // → /api/v1/search?page=1&limit=20&q=accra
  /// ```
  final Map<String, String>? queryParams;

  /// Per-request headers merged on top of [ApiConfig.defaultHeaders].
  /// These override defaults if keys conflict.
  final Map<String, String>? headers;

  /// Files to upload. Providing one or more files automatically switches
  /// the request encoding to `multipart/form-data`.
  ///
  /// Mix with [body] to send both text fields and files in the same request.
  final List<UploadFile>? files;

  /// When `true`, the `Authorization: Bearer <token>` header is NOT attached.
  ///
  /// Set to `false` for public endpoints: login, register, password reset, etc.
  /// Defaults to `true`.
  final bool requiresAuth;

  /// Overrides [ApiConfig.defaultTimeout] for this specific request.
  final Duration? timeout;

  /// Optional tag for debugging — appears in log output.
  final String? tag;

  const ApiRequest({
    required this.path,
    this.method = HttpMethod.get,
    this.body,
    this.queryParams,
    this.headers,
    this.files,
    this.requiresAuth = true,
    this.timeout,
    this.tag,
  });

  /// Whether this request will be sent as multipart/form-data.
  bool get isMultipart => files != null && files!.isNotEmpty;

  /// The resolved URL (used internally for logging).
  String get url => path;

  ApiRequest copyWith({
    String? path,
    HttpMethod? method,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    List<UploadFile>? files,
    bool? requiresAuth,
    Duration? timeout,
    String? tag,
  }) {
    return ApiRequest(
      path: path ?? this.path,
      method: method ?? this.method,
      body: body ?? this.body,
      queryParams: queryParams ?? this.queryParams,
      headers: headers ?? this.headers,
      files: files ?? this.files,
      requiresAuth: requiresAuth ?? this.requiresAuth,
      timeout: timeout ?? this.timeout,
      tag: tag ?? this.tag,
    );
  }
}

/// HTTP method for an [ApiRequest].
enum HttpMethod {
  get,
  post,
  put,
  patch,
  delete,
  head,
}

extension HttpMethodExtension on HttpMethod {
  String get value {
    switch (this) {
      case HttpMethod.get:
        return 'GET';
      case HttpMethod.post:
        return 'POST';
      case HttpMethod.put:
        return 'PUT';
      case HttpMethod.patch:
        return 'PATCH';
      case HttpMethod.delete:
        return 'DELETE';
      case HttpMethod.head:
        return 'HEAD';
    }
  }
}
