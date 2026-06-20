# api_services

A plug-and-play HTTP client for Flutter. One import, zero boilerplate.

Plug in your URL, method, and body — it handles everything else: auth tokens, refresh, multipart uploads, retries, logging, and every HTTP status code.

---

## Features

| | |
|---|---|
| ✅ All HTTP methods | GET, POST, PUT, PATCH, DELETE, HEAD |
| ✅ Auto auth | Bearer token injected on every authenticated request |
| ✅ Token refresh | Refreshes on 401 with a queue lock — no duplicate calls |
| ✅ Multipart uploads | Images, video, audio, documents — just pass `files:` |
| ✅ Content type inference | 40+ MIME types inferred from file extension |
| ✅ Typed errors | Every status code mapped to `ApiErrorType` |
| ✅ Error message extraction | Works with Django REST, NestJS, Laravel, Rails |
| ✅ Retry-After | Parsed automatically on 429 responses |
| ✅ Interceptors | Logger, Retry, or write your own |
| ✅ Swappable storage | Swap `SharedPreferences` for `FlutterSecureStorage` |
| ✅ Convenience methods | `api.get()`, `api.post()` for common cases |
| ✅ Full URL support | Use absolute URLs alongside relative paths |

---

## Installation

```yaml
# pubspec.yaml
dependencies:
  api_services:
    git:
      url: https://github.com/yourusername/flutter_api_services.git
```

Or once published to pub.dev:

```yaml
dependencies:
  flutter_api_services: ^1.0.0
```

---

## Quick start

```dart
import 'package:flutter_api_services/flutter_api_services.dart';

// 1. Create the client once (global, singleton, or DI)
final api = ApiClient(
  config: ApiConfig(
    baseUrl: 'https://api.example.com',
    refreshTokenPath: '/auth/token/refresh',
    onAuthFailed: () => navigateToLogin(),
  ),
);

// 2. Add interceptors (optional)
api.addInterceptor(LoggerInterceptor());
api.addInterceptor(RetryInterceptor(maxRetries: 3));

// 3. Send requests
final res = await api.get('/users/me');
print(res.asMap['name']);
```

---

## Auth flow

### Login and save tokens

```dart
final res = await api.post(
  '/auth/login',
  body: {'email': email, 'password': password},
  requiresAuth: false,
);

await api.saveTokens(
  accessToken: res.asMap['access_token'],
  refreshToken: res.asMap['refresh_token'],
);
```

### Logout

```dart
await api.post('/auth/logout');
await api.clearTokens();
```

### Automatic token refresh

When any request returns 401, the client automatically:
1. POSTs `{ "refresh_token": "..." }` to your `refreshTokenPath`
2. Stores the new tokens
3. Retries the original request with the new access token
4. Calls `onAuthFailed` if the refresh itself fails

Multiple simultaneous 401s are handled by a queue lock — the refresh happens once, and all waiting requests share the result.

---

## HTTP methods

### Convenience methods

```dart
// GET
final res = await api.get('/users', queryParams: {'page': '1'});

// POST
final res = await api.post('/bookings', body: {'hours': 3});

// PUT
await api.put('/users/me', body: {'name': 'Gaius'});

// PATCH
await api.patch('/users/me', body: {'bio': 'Musician'});

// DELETE
await api.delete('/bookings/123');
```

### Full control with `send()`

```dart
final res = await api.send(ApiRequest(
  path: '/reports/generate',
  method: HttpMethod.post,
  body: {'from': '2025-01-01', 'to': '2025-06-01'},
  headers: {'X-Idempotency-Key': 'report_abc'},
  timeout: Duration(minutes: 2),
  tag: 'generate-report',
));
```

---

## File uploads

### From bytes (image_picker, file_picker)

```dart
final file = UploadFile(
  fieldName: 'avatar',
  bytes: imageBytes,
  fileName: 'avatar.jpg',
  contentType: 'image/jpeg',
);

final res = await api.post('/profile/avatar', files: [file]);
```

### From a file path

```dart
final file = await UploadFile.fromPath(
  fieldName: 'document',
  filePath: '/storage/file.pdf',
  // contentType inferred from .pdf extension automatically
);
```

### Files + text fields together

```dart
final video = UploadFile(
  fieldName: 'cover_video',
  bytes: videoBytes,
  fileName: 'cover.mp4',
  contentType: 'video/mp4',
);

await api.put(
  '/profile/studio',
  files: [video],
  body: {
    'studio_name': 'Zone 5 Studios',
    'location': 'Accra, Ghana',
    'hourly_rate': '150',
  },
);
```

### Multiple files

```dart
await api.post('/portfolio', files: [photo1, photo2, photo3]);
```

### Content type inference

```dart
UploadFile.inferContentType('photo.jpg')  // 'image/jpeg'
UploadFile.inferContentType('video.mp4') // 'video/mp4'
UploadFile.inferContentType('doc.pdf')   // 'application/pdf'
```

40+ extensions supported: images, video, audio, documents, archives.

---

## Error handling

```dart
try {
  final res = await api.get('/admin/dashboard');
} on ApiException catch (e) {
  switch (e.type) {
    case ApiErrorType.network:
      showBanner('No internet connection');

    case ApiErrorType.unauthorized:
      // Fires only after auto-refresh also failed
      navigateToLogin();

    case ApiErrorType.forbidden:
      showBanner('You don\'t have permission to do that');

    case ApiErrorType.notFound:
      showBanner('Not found: ${e.message}');

    case ApiErrorType.unprocessable:
      // Field-level validation errors (Django REST / NestJS)
      final errors = e.body as Map<String, dynamic>;
      errors.forEach((field, msgs) => markFieldError(field, msgs));

    case ApiErrorType.rateLimited:
      final wait = e.retryAfter?.inSeconds ?? 60;
      showBanner('Too many requests. Try again in ${wait}s.');

    case ApiErrorType.timeout:
      showBanner('Request timed out. Check your connection.');

    case ApiErrorType.internalServerError:
    case ApiErrorType.serviceUnavailable:
      showBanner('Server error. Please try again later.');

    default:
      showBanner(e.message);
  }
}
```

### `ApiException` properties

| Property | Type | Description |
|---|---|---|
| `type` | `ApiErrorType` | Typed error category |
| `statusCode` | `int?` | HTTP status (null for network errors) |
| `message` | `String` | Human-readable message from the server |
| `body` | `dynamic` | Full raw server payload |
| `retryAfter` | `Duration?` | Retry-After from 429 response |
| `isUnauthorized` | `bool` | `statusCode == 401` |
| `isServerError` | `bool` | `5xx` |
| `isNetworkError` | `bool` | Socket / connectivity failure |

### `ApiErrorType` values

`badRequest` · `unauthorized` · `forbidden` · `notFound` · `methodNotAllowed` · `timeout` · `conflict` · `gone` · `unsupportedMediaType` · `unprocessable` · `rateLimited` · `internalServerError` · `badGateway` · `serviceUnavailable` · `gatewayTimeout` · `network` · `cancelled` · `unknown`

---

## ApiResponse helpers

```dart
final res = await api.get('/users/me');

res.statusCode    // 200
res.isSuccess     // true
res.isCreated     // true if 201
res.isEmpty       // true if 204 or no body

res.asMap         // Map<String, dynamic>  — JSON object
res.asList        // List<dynamic>         — JSON array
res.asString      // String               — plain text
res.asMapOrNull   // null if not a map (safe)
res.asListOrNull  // null if not a list (safe)

res.header('x-request-id')  // response header by name
```

---

## Interceptors

### Logger

```dart
api.addInterceptor(LoggerInterceptor());
// Automatically suppressed in release builds.
// Authorization header is truncated in logs.
```

### Retry

```dart
api.addInterceptor(RetryInterceptor(
  maxRetries: 3,
  delay: Duration(seconds: 1),
  exponentialBackoff: true,  // 1s, 2s, 4s...
  retryOn: {
    ApiErrorType.network,
    ApiErrorType.serviceUnavailable,
  },
));
```

### Custom interceptor

```dart
class TimingInterceptor extends ApiInterceptor {
  DateTime? _start;

  @override
  Future<ApiRequest> onRequest(ApiRequest request) async {
    _start = DateTime.now();
    return request;
  }

  @override
  Future<ApiResponse> onResponse(ApiResponse response) async {
    final ms = DateTime.now().difference(_start!).inMilliseconds;
    print('${response.statusCode} in ${ms}ms');
    return response;
  }
}
```

---

## Custom token storage

Swap `SharedPreferences` for `FlutterSecureStorage` or anything else:

```dart
class SecureTokenStorage implements TokenStorage {
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> getAccessToken() => _storage.read(key: 'access');

  @override
  Future<String?> getRefreshToken() => _storage.read(key: 'refresh');

  @override
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: 'access', value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: 'refresh', value: refreshToken);
    }
  }

  @override
  Future<void> clearTokens() async {
    await _storage.deleteAll();
  }
}

// Pass it to the client
final api = ApiClient(
  config: ApiConfig(baseUrl: 'https://api.example.com'),
  tokenStorage: SecureTokenStorage(),
);
```

---

## ApiConfig options

| Option | Type | Default | Description |
|---|---|---|---|
| `baseUrl` | `String` | required | Base URL (no trailing slash) |
| `refreshTokenPath` | `String?` | null | Token refresh endpoint |
| `refreshResponseAccessKey` | `String` | `'access_token'` | Key in refresh response |
| `refreshResponseRefreshKey` | `String` | `'refresh_token'` | Key in refresh response |
| `refreshRequestBodyKey` | `String` | `'refresh_token'` | Key sent to refresh endpoint |
| `onTokenRefreshed` | `Function?` | null | Called after successful refresh |
| `onAuthFailed` | `Function?` | null | Called when auth fails entirely |
| `defaultHeaders` | `Map` | `{}` | Headers sent with every request |
| `defaultTimeout` | `Duration` | 30s | Global request timeout |
| `enableLogging` | `bool` | `true` | Enable `LoggerInterceptor` output |

---

## ApiRequest fields

| Field | Type | Default | Description |
|---|---|---|---|
| `path` | `String` | required | Relative path or full URL |
| `method` | `HttpMethod` | `get` | HTTP verb |
| `body` | `Map?` | null | JSON body (or multipart text fields) |
| `queryParams` | `Map<String,String>?` | null | URL query parameters |
| `headers` | `Map<String,String>?` | null | Extra headers for this request |
| `files` | `List<UploadFile>?` | null | Files (triggers multipart) |
| `requiresAuth` | `bool` | `true` | Attach Authorization header? |
| `timeout` | `Duration?` | null | Per-request timeout override |
| `tag` | `String?` | null | Debug label shown in logs |

---

## Running tests

```sh
flutter test
```

---

## License

MIT
