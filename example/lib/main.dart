// ignore_for_file: avoid_print
import 'package:flutter_api_services/flutter_api_services.dart';

// ═══════════════════════════════════════════════════════════
//  flutter_api_services — Real-world usage examples
// ═══════════════════════════════════════════════════════════

// ── Step 1: Create the client (once, at app startup) ────────────────────────

final api = ApiClient(
  config: ApiConfig(
    baseUrl: 'https://api.example.com',

    // Token refresh — optional. Remove if your API doesn't use refresh tokens.
    refreshTokenPath: '/auth/token/refresh',

    // Called with new tokens after a successful refresh.
    onTokenRefreshed: (access, refresh) {
      print('Tokens refreshed.');
    },

    // Called when refresh fails or no tokens exist.
    // Navigate to your login screen here.
    onAuthFailed: () {
      print('Auth failed — redirect to login');
    },

    // Default headers sent with every request.
    defaultHeaders: {
      'X-App-Version': '1.0.0',
      'X-Platform': 'flutter',
    },

    defaultTimeout: const Duration(seconds: 30),
    enableLogging: true,
  ),
);

// ── Step 2: Add optional interceptors ────────────────────────────────────────
void setup() {
  api.addInterceptor(LoggerInterceptor()); // logs all requests/responses
  api.addInterceptor(RetryInterceptor(
    // auto-retry on network failures
    maxRetries: 3,
    delay: const Duration(seconds: 1),
  ));
}

// ════════════════════════════════════════════════════════════
//  AUTH
// ════════════════════════════════════════════════════════════

Future<void> login(String email, String password) async {
  final res = await api.post(
    path:'/auth/login',
    body: {'email': email, 'password': password},
    requiresAuth: false, // no token needed to log in
  );

  await api.saveTokens(
    accessToken: res.asMap['access_token'],
    refreshToken: res.asMap['refresh_token'],
  );
}


Future<void> logout() async {
  await api.post(path:'/auth/logout');
  await api.clearTokens();
}

// ════════════════════════════════════════════════════════════
//  GET
// ════════════════════════════════════════════════════════════

Future<void> getProfile() async {
  // Using the convenience method
  final res = await api.get(path:'/users/me');
  print(res.asMap); // { "id": "...", "name": "..." }
}

Future<void> getFollowers({int page = 1}) async {
  // GET with query params
  final res = await api.get(
    path:'/users/me/followers',
    queryParams: {'page': '$page', 'limit': '20'},
  );
  print(res.asList); // [{ "id": "..." }, ...]
}

// ════════════════════════════════════════════════════════════
//  POST / PUT / PATCH / DELETE
// ════════════════════════════════════════════════════════════

Future<void> createBooking() async {
  final res = await api.post(
    path:'/bookings',
    body: {
      'studio_id': 'studio_abc',
      'date': '2025-07-01',
      'hours': 3,
      'notes': 'Recording session',
    },
  );
  print('Created booking: ${res.asMap['id']}');
}

Future<void> updateProfile() async {
  await api.patch(
    path:'/users/me',
    body: {'bio': 'Musician based in Accra 🎵', 'city': 'Accra'},
  );
}

Future<void> deleteBooking(String id) async {
  final res = await api.delete(path:'/bookings/$id');
  print(res.isEmpty); // true for 204 No Content
}

// ════════════════════════════════════════════════════════════
//  FILE UPLOADS
// ════════════════════════════════════════════════════════════

Future<void> uploadAvatar(List<int> imageBytes) async {
  // From bytes (image_picker, file_picker, etc.)
  final file = UploadFile(
    fieldName: 'avatar',
    bytes: imageBytes,
    fileName: 'avatar.jpg',
    contentType: 'image/jpeg',
  );

  final res = await api.post(path:'/profile/avatar', files: [file]);
  print('New avatar URL: ${res.asMap['url']}');
}

Future<void> uploadCoverVideoWithFields(List<int> videoBytes) async {
  // Files + text fields in the same multipart request
  final video = UploadFile(
    fieldName: 'cover_video',
    bytes: videoBytes,
    fileName: 'cover.mp4',
    contentType: 'video/mp4',
  );

  await api.put(
    path:'/profile/studio',
    files: [video],
    body: {
      'studio_name': 'Zone 5 Studios',
      'location': 'Accra, Ghana',
      'hourly_rate': '150',
    },
  );
}

Future<void> uploadPortfolioImages(List<List<int>> allBytes) async {
  // Multiple files in one request
  final files = allBytes
      .asMap()
      .entries
      .map((e) => UploadFile(
            fieldName: 'images',
            bytes: e.value,
            fileName: 'image_${e.key}.jpg',
            contentType: 'image/jpeg',
          ))
      .toList();

  await api.post(path:'/portfolio/images', files: files);
}

// ─── From file path (dart:io) ────────────────────────────────────────────
Future<void> uploadFromPath(String filePath) async {
  final file = await UploadFile.fromPath(
    fieldName: 'document',
    filePath: filePath,
    // contentType inferred from extension automatically
  );
  await api.post(path:'/documents', files: [file]);
}

// ════════════════════════════════════════════════════════════
//  ERROR HANDLING
// ════════════════════════════════════════════════════════════

Future<void> robustRequest() async {
  try {
    final res = await api.get(path:'/admin/dashboard');
    print(res.data);
  } on ApiException catch (e) {
    switch (e.type) {
      case ApiErrorType.network:
        print('No internet. Show offline banner.');

      case ApiErrorType.unauthorized:
        // Client already tried to refresh. This fires only if refresh also failed.
        print('Session expired. Redirect to login.');

      case ApiErrorType.forbidden:
        print('Permission denied: ${e.message}');

      case ApiErrorType.notFound:
        print('Not found: ${e.message}');

      case ApiErrorType.unprocessable:
        // Access field-level validation errors
        final errors = e.body as Map<String, dynamic>?;
        errors?.forEach((field, messages) => print('$field: $messages'));

      case ApiErrorType.rateLimited:
        final wait = e.retryAfter?.inSeconds ?? 60;
        print('Rate limited. Retry in ${wait}s.');

      case ApiErrorType.timeout:
        print('Request timed out. Try again.');

      case ApiErrorType.internalServerError:
      case ApiErrorType.serviceUnavailable:
        print('Server error. Status: ${e.statusCode}');

      default:
        print('Error (${e.statusCode}): ${e.message}');
    }

    // e.body contains the full raw server payload for any error type
    print('Raw body: ${e.body}');
  }
}

// ════════════════════════════════════════════════════════════
//  ADVANCED: using send() directly for full control
// ════════════════════════════════════════════════════════════

Future<void> advancedUsage() async {
  // Full URL (bypasses baseUrl)
  final geo = await api.send(const ApiRequest(
    path: 'https://maps.googleapis.com/maps/api/geocode/json',
    queryParams: {'address': 'Accra Ghana', 'key': 'YOUR_KEY'},
    requiresAuth: false,
  ));
  print(geo.data);

  // Custom timeout for a slow endpoint
  final report = await api.send(const ApiRequest(
    path: '/reports/generate',
    method: HttpMethod.post,
    timeout: Duration(minutes: 2),
  ));
  print(report.data);

  // Extra headers for one request only
  await api.send(const ApiRequest(
    path: '/payments/charge',
    method: HttpMethod.post,
    headers: {'X-Idempotency-Key': 'charge_abc_001'},
    body: {'amount': 5000, 'currency': 'GHS'},
  ));

  // Check response headers
  final res = await api.get(path:'/users/me');
  print(res.header('x-request-id'));
  print(res.header('content-type'));
}
