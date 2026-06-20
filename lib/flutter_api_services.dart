/// flutter_api_services
///
/// A plug-and-play HTTP client for Flutter.
/// Single import, zero boilerplate.
///
/// ```dart
/// import 'package:flutter_api_services/flutter_api_services.dart';
///
/// final api = ApiClient(baseUrl: 'https://api.example.com');
///
/// final response = await api.send(ApiRequest(
///   path: '/users/me',
/// ));
/// ```
library flutter_api_services;

// Core
export 'src/api_client.dart';
export 'src/api_request.dart';
export 'src/api_response.dart';

// Auth
export 'src/auth/token_storage.dart';
export 'src/auth/token_storage_impl.dart';
export 'src/auth/auth_interceptor.dart';

// Errors
export 'src/errors/api_exception.dart';
export 'src/errors/error_type.dart';

// Multipart
export 'src/multipart/upload_file.dart';

// Config
export 'src/config/api_config.dart';

// Interceptors
export 'src/interceptors/interceptor.dart';
export 'src/interceptors/logger_interceptor.dart';
export 'src/interceptors/retry_interceptor.dart';
