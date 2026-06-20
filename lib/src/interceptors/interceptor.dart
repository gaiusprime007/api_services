import '../../flutter_api_services.dart' show ApiClient;
import '../api_client.dart' show ApiClient;
import '../api_request.dart';
import '../api_response.dart';
import '../errors/api_exception.dart';

/// Base class for request/response interceptors.
///
/// Implement any combination of [onRequest], [onResponse], [onError]
/// to hook into the request lifecycle.
///
/// Register interceptors via [ApiClient.addInterceptor].
abstract class ApiInterceptor {
  const ApiInterceptor();

  /// Called before the request is sent.
  /// Modify [request] here (e.g. add headers, stamp a trace ID).
  Future<ApiRequest> onRequest(ApiRequest request) async => request;

  /// Called after a successful response (2xx).
  /// Inspect or transform [response] here.
  Future<ApiResponse> onResponse(ApiResponse response) async => response;

  /// Called when an [ApiException] is thrown.
  /// Re-throw, swallow, or transform the error.
  Future<ApiException> onError(ApiException error) async => error;
}
