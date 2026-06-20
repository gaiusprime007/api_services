import '../../flutter_api_services.dart' show ApiException;
import 'api_exception.dart' show ApiException;

/// Classifies every possible HTTP or network failure into a typed enum.
///
/// Use this in your UI to decide what message or action to show.
enum ApiErrorType {
  /// 400 — Malformed request (validation error, bad params).
  badRequest,

  /// 401 — Not authenticated. Token missing, expired, or invalid.
  unauthorized,

  /// 403 — Authenticated but not permitted.
  forbidden,

  /// 404 — Resource does not exist.
  notFound,

  /// 405 — HTTP method not allowed on this endpoint.
  methodNotAllowed,

  /// 408 / timeout exception — Server or client timed out.
  timeout,

  /// 409 — Conflict (e.g. duplicate resource).
  conflict,

  /// 410 — Resource permanently gone.
  gone,

  /// 415 — Unsupported media type.
  unsupportedMediaType,

  /// 422 — Semantically invalid (e.g. business rule violation).
  unprocessable,

  /// 429 — Too many requests. Check [ApiException.retryAfter].
  rateLimited,

  /// 500 — Internal server error.
  internalServerError,

  /// 502 — Bad gateway.
  badGateway,

  /// 503 — Service unavailable.
  serviceUnavailable,

  /// 504 — Gateway timeout.
  gatewayTimeout,

  /// No internet / socket closed / DNS failure.
  network,

  /// Request was cancelled.
  cancelled,

  /// Any other status code not explicitly mapped above.
  unknown,
}

/// Maps an HTTP status code to an [ApiErrorType].
ApiErrorType errorTypeFromStatus(int code) {
  switch (code) {
    case 400:
      return ApiErrorType.badRequest;
    case 401:
      return ApiErrorType.unauthorized;
    case 403:
      return ApiErrorType.forbidden;
    case 404:
      return ApiErrorType.notFound;
    case 405:
      return ApiErrorType.methodNotAllowed;
    case 408:
      return ApiErrorType.timeout;
    case 409:
      return ApiErrorType.conflict;
    case 410:
      return ApiErrorType.gone;
    case 415:
      return ApiErrorType.unsupportedMediaType;
    case 422:
      return ApiErrorType.unprocessable;
    case 429:
      return ApiErrorType.rateLimited;
    case 500:
      return ApiErrorType.internalServerError;
    case 502:
      return ApiErrorType.badGateway;
    case 503:
      return ApiErrorType.serviceUnavailable;
    case 504:
      return ApiErrorType.gatewayTimeout;
    default:
      if (code >= 500) return ApiErrorType.internalServerError;
      return ApiErrorType.unknown;
  }
}
