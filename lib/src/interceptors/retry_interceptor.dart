import '../../flutter_api_services.dart' show ApiClient;
import '../api_client.dart' show ApiClient;
import '../api_request.dart';
import '../api_response.dart';
import '../errors/api_exception.dart';
import '../errors/error_type.dart';
import 'interceptor.dart';

/// Automatically retries failed requests on network errors or 5xx responses.
///
/// ```dart
/// api.addInterceptor(RetryInterceptor(
///   maxRetries: 3,
///   retryOn: {ApiErrorType.network, ApiErrorType.serviceUnavailable},
///   delay: Duration(seconds: 1),
/// ));
/// ```
class RetryInterceptor extends ApiInterceptor {
  /// Maximum number of retry attempts. Default: 3.
  final int maxRetries;

  /// Error types that trigger a retry. Default: network + 5xx errors.
  final Set<ApiErrorType> retryOn;

  /// Delay between retries. Default: 1 second.
  final Duration delay;

  /// Whether to use exponential backoff (delay doubles on each retry).
  final bool exponentialBackoff;

  int _attempts = 0;

  RetryInterceptor({
    this.maxRetries = 3,
    this.retryOn = const {
      ApiErrorType.network,
      ApiErrorType.internalServerError,
      ApiErrorType.badGateway,
      ApiErrorType.serviceUnavailable,
      ApiErrorType.gatewayTimeout,
    },
    this.delay = const Duration(seconds: 1),
    this.exponentialBackoff = true,
  });

  @override
  Future<ApiRequest> onRequest(ApiRequest request) async {
    _attempts = 0;
    return request;
  }

  @override
  Future<ApiResponse> onResponse(ApiResponse response) async {
    _attempts = 0;
    return response;
  }

  @override
  Future<ApiException> onError(ApiException error) async {
    if (_attempts < maxRetries && retryOn.contains(error.type)) {
      _attempts++;
      final wait = exponentialBackoff
          ? delay * (1 << (_attempts - 1)) // 1s, 2s, 4s…
          : delay;
      await Future.delayed(wait);
      // Signal the client to retry by re-throwing — the client
      // catches this in its retry loop.
      throw _RetrySignal(_attempts);
    }
    return error;
  }
}

/// Internal signal used by [ApiClient] to detect a retry request.
class _RetrySignal {
  final int attempt;
  _RetrySignal(this.attempt);
}
