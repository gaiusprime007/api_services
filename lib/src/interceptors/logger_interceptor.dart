import 'package:flutter/foundation.dart';
import '../api_request.dart';
import '../api_response.dart';
import '../errors/api_exception.dart';
import 'interceptor.dart';

/// Logs every request and response to the Flutter debug console.
///
/// Automatically suppressed in release builds unless [forceLog] is true.
///
/// Output example:
/// ```
/// ┌──────────────────────────────────────────
/// │ → POST https://api.example.com/auth/login
/// │   Headers: { Authorization: Bearer ey... }
/// │   Body: { "email": "user@example.com" }
/// └──────────────────────────────────────────
/// ┌──────────────────────────────────────────
/// │ ← 200 OK  [142ms]
/// │   Body: { "access_token": "ey..." }
/// └──────────────────────────────────────────
/// ```
class LoggerInterceptor extends ApiInterceptor {
  final bool forceLog;

  const LoggerInterceptor({this.forceLog = false});

  bool get _shouldLog => kDebugMode || forceLog;

  @override
  Future<ApiRequest> onRequest(ApiRequest request) async {
    if (!_shouldLog) return request;

    final method = request.method.name.toUpperCase();
    _log('→ $method ${request.url}');
    if (request.headers != null && request.headers!.isNotEmpty) {
      _log('  Headers: ${_sanitizeHeaders(request.headers!)}');
    }
    if (request.body != null) {
      _log('  Body: ${request.body}');
    }
    if (request.queryParams != null && request.queryParams!.isNotEmpty) {
      _log('  Query: ${request.queryParams}');
    }
    if (request.files != null && request.files!.isNotEmpty) {
      final names = request.files!.map((f) => f.fileName).join(', ');
      _log('  Files: [$names]');
    }
    _log('─' * 50);
    return request;
  }

  @override
  Future<ApiResponse> onResponse(ApiResponse response) async {
    if (!_shouldLog) return response;
    _log('← ${response.statusCode}');
    if (response.data != null) {
      final preview = response.data.toString();
      _log('  Body: ${preview.length > 500 ? '${preview.substring(0, 500)}…' : preview}');
    }
    _log('─' * 50);
    return response;
  }

  @override
  Future<ApiException> onError(ApiException error) async {
    if (!_shouldLog) return error;
    _log('✕ ${error.type.name.toUpperCase()} (${error.statusCode ?? 'no status'})');
    _log('  ${error.message}');
    if (error.body != null) {
      _log('  Body: ${error.body}');
    }
    _log('─' * 50);
    return error;
  }

  void _log(String msg) => debugPrint('[ApiClient] $msg');

  Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    return {
      for (final e in headers.entries)
        e.key: e.key.toLowerCase() == 'authorization'
            ? '${e.value.substring(0, e.value.length.clamp(0, 20))}…'
            : e.value,
    };
  }
}
