import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_request.dart';
import 'api_response.dart';
import 'auth/token_storage.dart';
import 'auth/token_storage_impl.dart';
import 'config/api_config.dart';
import 'errors/api_exception.dart';
import 'errors/error_type.dart';
import 'interceptors/interceptor.dart';
import 'multipart/upload_file.dart';

/// The single entry point for all HTTP calls in your app.
///
/// ─── Create once (e.g. in a top-level singleton or DI container) ─────────
///
/// ```dart
/// final api = ApiClient(
///   config: ApiConfig(
///     baseUrl: 'https://api.example.com',
///     refreshTokenPath: '/auth/token/refresh',
///     onAuthFailed: () => Navigator.pushReplacementNamed(ctx, '/login'),
///   ),
/// );
/// ```
///
/// ─── Save tokens after login ──────────────────────────────────────────────
///
/// ```dart
/// final res = await api.send(ApiRequest(
///   path: '/auth/login',
///   method: HttpMethod.post,
///   requiresAuth: false,
///   body: {'email': email, 'password': password},
/// ));
/// await api.saveTokens(
///   accessToken: res.asMap['access_token'],
///   refreshToken: res.asMap['refresh_token'],
/// );
/// ```
///
/// ─── Send requests ────────────────────────────────────────────────────────
///
/// ```dart
/// final res = await api.send(ApiRequest(path: '/users/me'));
/// print(res.asMap['name']);
/// ```
class ApiClient {
  final ApiConfig config;
  final TokenStorage _storage;
  final http.Client _http;
  final List<ApiInterceptor> _interceptors = [];

  /// Prevents multiple concurrent token-refresh calls.
  Completer<bool>? _refreshLock;

  ApiClient({
    required this.config,
    TokenStorage? tokenStorage,
    http.Client? httpClient,
  })  : _storage = tokenStorage ?? SharedPrefsTokenStorage(),
        _http = httpClient ?? http.Client();

  // ─────────────────────────────────────────────────────────────────────────
  // Interceptor management
  // ─────────────────────────────────────────────────────────────────────────

  /// Register an interceptor. They run in the order they are added.
  void addInterceptor(ApiInterceptor interceptor) =>
      _interceptors.add(interceptor);

  /// Remove a specific interceptor instance.
  void removeInterceptor(ApiInterceptor interceptor) =>
      _interceptors.remove(interceptor);

  // ─────────────────────────────────────────────────────────────────────────
  // Token management
  // ─────────────────────────────────────────────────────────────────────────

  /// Persist tokens after a successful login or registration.
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) =>
      _storage.saveTokens(
          accessToken: accessToken, refreshToken: refreshToken);

  /// Remove all stored tokens (call on logout).
  Future<void> clearTokens() => _storage.clearTokens();

  /// Read the current stored access token.
  Future<String?> get accessToken => _storage.getAccessToken();

  /// Read the current stored refresh token.
  Future<String?> get refreshToken => _storage.getRefreshToken();

  // ─────────────────────────────────────────────────────────────────────────
  // Public send method — the ONLY method you call from outside
  // ─────────────────────────────────────────────────────────────────────────

  /// Send an HTTP request and return a typed [ApiResponse].
  ///
  /// Throws [ApiException] on any failure.
  ///
  /// Automatically:
  ///   - Attaches `Authorization: Bearer <token>` (if [ApiRequest.requiresAuth])
  ///   - Detects multipart vs JSON based on [ApiRequest.files]
  ///   - Refreshes the token on 401 and retries once
  ///   - Runs all registered [ApiInterceptor]s
  ///   - Maps every status code to a typed [ApiErrorType]
  Future<ApiResponse> send(ApiRequest request) async {
    // Run onRequest interceptors
    var interceptedRequest = request;
    for (final i in _interceptors) {
      interceptedRequest = await i.onRequest(interceptedRequest);
    }

    try {
      final response = await _execute(interceptedRequest);

      // Run onResponse interceptors
      var interceptedResponse = response;
      for (final i in _interceptors) {
        interceptedResponse = await i.onResponse(interceptedResponse);
      }
      return interceptedResponse;
    } on ApiException catch (e) {
      // 401 → attempt token refresh → retry once
      if (e.isUnauthorized && request.requiresAuth) {
        final refreshed = await _refreshToken();
        if (refreshed) {
          // Re-attach interceptors on retry
          var retryRequest = request;
          for (final i in _interceptors) {
            retryRequest = await i.onRequest(retryRequest);
          }
          return await _execute(retryRequest);
        } else {
          config.onAuthFailed?.call();
        }
      }

      // Run onError interceptors
      var interceptedError = e;
      for (final i in _interceptors) {
        interceptedError = await i.onError(interceptedError);
      }
      throw interceptedError;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Convenience methods
  // ─────────────────────────────────────────────────────────────────────────

  Future<ApiResponse> get(
     {
      required String path,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration? timeout,
  }) =>
      send(ApiRequest(
        path: path,
        method: HttpMethod.get,
        queryParams: queryParams,
        headers: headers,
        requiresAuth: requiresAuth,
        timeout: timeout,
      ));

  Future<ApiResponse> post(
     {
       required String path,
    Map<String, dynamic>? body,
    List<UploadFile>? files,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration? timeout,
  }) =>
      send(ApiRequest(
        path: path,
        method: HttpMethod.post,
        body: body,
        files: files,
        queryParams: queryParams,
        headers: headers,
        requiresAuth: requiresAuth,
        timeout: timeout,
      ));

  Future<ApiResponse> put(
   {
       required String path,
    Map<String, dynamic>? body,
    List<UploadFile>? files,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration? timeout,
  }) =>
      send(ApiRequest(
        path: path,
        method: HttpMethod.put,
        body: body,
        files: files,
        headers: headers,
        requiresAuth: requiresAuth,
        timeout: timeout,
      ));

  Future<ApiResponse> patch(
    {
       required String path,
    Map<String, dynamic>? body,
    List<UploadFile>? files,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration? timeout,
  }) =>
      send(ApiRequest(
        path: path,
        method: HttpMethod.patch,
        body: body,
        files: files,
        headers: headers,
        requiresAuth: requiresAuth,
        timeout: timeout,
      ));

  Future<ApiResponse> delete(
   {
       required String path,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration? timeout,
  }) =>
      send(ApiRequest(
        path: path,
        method: HttpMethod.delete,
        body: body,
        headers: headers,
        requiresAuth: requiresAuth,
        timeout: timeout,
      ));

  // ─────────────────────────────────────────────────────────────────────────
  // Internal execution
  // ─────────────────────────────────────────────────────────────────────────

  Future<ApiResponse> _execute(ApiRequest request) async {
    final uri = _buildUri(request);
    final headers = await _buildHeaders(request);
    final timeout = request.timeout ?? config.defaultTimeout;

    http.Response raw;

    try {
      raw = request.isMultipart
          ? await _executeMultipart(request, uri, headers, timeout)
          : await _executeRegular(request, uri, headers, timeout);
    } on SocketException catch (e) {
      throw ApiException(
        message: 'No internet connection. (${e.message})',
        type: ApiErrorType.network,
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Request timed out after ${timeout.inSeconds}s.',
        type: ApiErrorType.timeout,
        statusCode: 408,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        message: 'Network error: ${e.message}',
        type: ApiErrorType.network,
      );
    } on HandshakeException catch (e) {
      throw ApiException(
        message: 'SSL/TLS error: ${e.message}',
        type: ApiErrorType.network,
      );
    }

    return _parseResponse(raw);
  }

  // ── JSON / form ────────────────────────────────────────────────────────

  Future<http.Response> _executeRegular(
    ApiRequest request,
    Uri uri,
    Map<String, String> headers,
    Duration timeout,
  ) async {
    final encodedBody =
        request.body != null ? jsonEncode(request.body) : null;

    switch (request.method) {
      case HttpMethod.get:
        return _http.get(uri, headers: headers).timeout(timeout);
      case HttpMethod.post:
        return _http
            .post(uri, headers: headers, body: encodedBody)
            .timeout(timeout);
      case HttpMethod.put:
        return _http
            .put(uri, headers: headers, body: encodedBody)
            .timeout(timeout);
      case HttpMethod.patch:
        return _http
            .patch(uri, headers: headers, body: encodedBody)
            .timeout(timeout);
      case HttpMethod.delete:
        return _http
            .delete(uri, headers: headers, body: encodedBody)
            .timeout(timeout);
      case HttpMethod.head:
        return _http.head(uri, headers: headers).timeout(timeout);
    }
  }

  // ── Multipart ──────────────────────────────────────────────────────────

  Future<http.Response> _executeMultipart(
    ApiRequest request,
    Uri uri,
    Map<String, String> headers,
    Duration timeout,
  ) async {
    final multiRequest = http.MultipartRequest(request.method.value, uri);

    // Headers — strip Content-Type; http sets it with boundary automatically
    headers.forEach((k, v) {
      if (k.toLowerCase() != 'content-type') {
        multiRequest.headers[k] = v;
      }
    });

    // Scalar body values → multipart text fields
    request.body?.forEach((key, value) {
      if (value != null) multiRequest.fields[key] = value.toString();
    });

    // Files
    for (final f in request.files!) {
      multiRequest.files.add(
        http.MultipartFile.fromBytes(
          f.fieldName,
          f.bytes,
          filename: f.fileName,
        ),
      );
    }

    final streamed = await _http.send(multiRequest).timeout(timeout);
    return http.Response.fromStream(streamed);
  }

  // ── Response parser ────────────────────────────────────────────────────

  ApiResponse _parseResponse(http.Response raw) {
    final status = raw.statusCode;
    final headers = raw.headers;

    // 204 No Content
    if (status == 204 || raw.body.isEmpty) {
      if (status >= 200 && status < 300) {
        return ApiResponse(statusCode: status, headers: headers, data: null);
      }
    }

    // Parse body
    dynamic body;
    final ct = headers['content-type'] ?? '';
    if (ct.contains('application/json')) {
      try {
        body = jsonDecode(utf8.decode(raw.bodyBytes));
      } catch (_) {
        body = raw.body;
      }
    } else {
      body = raw.body.isEmpty ? null : raw.body;
    }

    // Success
    if (status >= 200 && status < 300) {
      return ApiResponse(statusCode: status, headers: headers, data: body);
    }

    // ── Error handling ───────────────────────────────────────────────────

    // Rate limit — parse Retry-After header
    Duration? retryAfter;
    if (status == 429) {
      final ra = headers['retry-after'];
      if (ra != null) {
        final seconds = int.tryParse(ra);
        if (seconds != null) retryAfter = Duration(seconds: seconds);
      }
    }

    throw ApiException(
      statusCode: status,
      message: _extractMessage(body, status),
      type: errorTypeFromStatus(status),
      body: body,
      retryAfter: retryAfter,
    );
  }

  /// Extracts a human-readable message from common server error shapes.
  ///
  /// Supports: Django REST, NestJS, Laravel, Rails, custom JSON APIs.
  String _extractMessage(dynamic body, int status) {
    if (body is Map) {
      // Try common key names in order of preference
      final candidates = [
        'message', 'error', 'detail', 'msg',
        'description', 'error_description', 'reason',
      ];
      for (final key in candidates) {
        final val = body[key];
        if (val != null && val.toString().isNotEmpty) {
          // NestJS sometimes nests: { "message": ["field is required"] }
          if (val is List && val.isNotEmpty) return val.first.toString();
          return val.toString();
        }
      }
      // Django REST validation: { "email": ["Enter a valid email."] }
      if (body.isNotEmpty) {
        final first = body.entries.first;
        final value = first.value;
        if (value is List && value.isNotEmpty) {
          return '${first.key}: ${value.first}';
        }
        return '${first.key}: $value';
      }
    }
    if (body is String && body.isNotEmpty) return body;
    return _defaultMessage(status);
  }

  String _defaultMessage(int status) {
    const messages = {
      400: 'Bad request',
      401: 'Authentication required',
      403: 'Access denied',
      404: 'Resource not found',
      405: 'Method not allowed',
      408: 'Request timed out',
      409: 'Conflict — resource already exists',
      410: 'Resource no longer available',
      422: 'Validation failed',
      429: 'Too many requests — slow down',
      500: 'Internal server error',
      502: 'Bad gateway',
      503: 'Service unavailable',
      504: 'Gateway timed out',
    };
    return messages[status] ?? 'Request failed with status $status';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Token refresh — queue lock prevents duplicate refresh calls
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _refreshToken() async {
    // Already refreshing — wait for the result
    if (_refreshLock != null) return _refreshLock!.future;

    if (config.refreshTokenPath == null) return false;

    _refreshLock = Completer<bool>();

    try {
      final storedRefresh = await _storage.getRefreshToken();
      if (storedRefresh == null) {
        _complete(false);
        return false;
      }

      final response = await send(ApiRequest(
        path: config.refreshTokenPath!,
        method: HttpMethod.post,
        body: {config.refreshRequestBodyKey: storedRefresh},
        requiresAuth: false,
      ));

      final data = response.asMap;
      final newAccess = data[config.refreshResponseAccessKey] as String?;
      final newRefresh = data[config.refreshResponseRefreshKey] as String?;

      if (newAccess == null) {
        await _storage.clearTokens();
        _complete(false);
        return false;
      }

      await _storage.saveTokens(
          accessToken: newAccess, refreshToken: newRefresh);
      config.onTokenRefreshed?.call(newAccess, newRefresh);
      _complete(true);
      return true;
    } catch (_) {
      await _storage.clearTokens();
      _complete(false);
      return false;
    }
  }

  void _complete(bool success) {
    _refreshLock?.complete(success);
    _refreshLock = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // URI + header builders
  // ─────────────────────────────────────────────────────────────────────────

  Uri _buildUri(ApiRequest request) {
    final path = request.path.trim();
    final isAbsolute = path.startsWith('http://') || path.startsWith('https://');
    final base = isAbsolute ? path : '${config.baseUrl}$path';
    final uri = Uri.parse(base);

    if (request.queryParams == null || request.queryParams!.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...request.queryParams!,
    });
  }

  Future<Map<String, String>> _buildHeaders(ApiRequest request) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...config.defaultHeaders,
      ...?request.headers,
    };

    if (request.requiresAuth) {
      final token = await _storage.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  /// Dispose the underlying HTTP client.
  /// Call this when your app or service is torn down.
  void dispose() => _http.close();
}
