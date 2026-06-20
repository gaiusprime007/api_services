import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_api_services/flutter_api_services.dart';

// ── Fake TokenStorage for tests ──────────────────────────────────────────────

class FakeTokenStorage implements TokenStorage {
  String? _access;
  String? _refresh;

  @override Future<String?> getAccessToken() async => _access;
  @override Future<String?> getRefreshToken() async => _refresh;

  @override
  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    _access = accessToken;
    _refresh = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    _access = null;
    _refresh = null;
  }
}

// ── Test helpers ─────────────────────────────────────────────────────────────

ApiClient makeClient(MockClient mockHttp, {FakeTokenStorage? storage}) {
  return ApiClient(
    config:  ApiConfig(baseUrl: 'https://api.test.com'),
    tokenStorage: storage ?? FakeTokenStorage(),
    httpClient: mockHttp,
  );
}

http.Response jsonResponse(dynamic body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

// ════════════════════════════════════════════════════════════
//  Tests
// ════════════════════════════════════════════════════════════

void main() {
  group('ApiClient — GET', () {
    test('returns ApiResponse with parsed JSON map', () async {
      final client = makeClient(MockClient((_) async =>
          jsonResponse({'id': '1', 'name': 'Gaius'})));

      final res = await client.get(path:'/users/me');

      expect(res.statusCode, 200);
      expect(res.isSuccess, isTrue);
      expect(res.asMap['name'], 'Gaius');
    });

    test('attaches Authorization header when requiresAuth is true', () async {
      final storage = FakeTokenStorage();
      await storage.saveTokens(accessToken: 'test_token');

      String? capturedAuth;
      final client = makeClient(
        MockClient((req) async {
          capturedAuth = req.headers['authorization'];
          return jsonResponse({'ok': true});
        }),
        storage: storage,
      );

      await client.get(path:'/protected');
      expect(capturedAuth, 'Bearer test_token');
    });

    test('does NOT attach Authorization when requiresAuth is false', () async {
      String? capturedAuth;
      final client = makeClient(
        MockClient((req) async {
          capturedAuth = req.headers['authorization'];
          return jsonResponse({'ok': true});
        }),
      );

      await client.get(path:'/public', requiresAuth: false);
      expect(capturedAuth, isNull);
    });

    test('appends query parameters to URI', () async {
      Uri? capturedUri;
      final client = makeClient(
        MockClient((req) async {
          capturedUri = req.url;
          return jsonResponse([]);
        }),
      );

      await client.get(path: '/users', queryParams: {'page': '2', 'limit': '10'});
      expect(capturedUri?.queryParameters['page'], '2');
      expect(capturedUri?.queryParameters['limit'], '10');
    });
  });

  group('ApiClient — POST', () {
    test('sends JSON body', () async {
      String? capturedBody;
      final client = makeClient(
        MockClient((req) async {
          capturedBody = req.body;
          return jsonResponse({'id': 'new_booking'}, status: 201);
        }),
      );

      final res = await client.post(path: '/bookings', body: {'hours': 3});

      expect(res.statusCode, 201);
      expect(res.isCreated, isTrue);
      final body = jsonDecode(capturedBody!);
      expect(body['hours'], 3);
    });
  });

  group('ApiClient — Error handling', () {
    test('throws ApiException with correct type on 404', () async {
      final client = makeClient(
        MockClient((_) async => jsonResponse({'message': 'Not found'}, status: 404)),
      );

      expect(
        () => client.get(path: '/missing'),
        throwsA(predicate<ApiException>(
            (e) => e.type == ApiErrorType.notFound && e.statusCode == 404)),
      );
    });

    test('throws ApiException with correct type on 422', () async {
      final client = makeClient(
        MockClient((_) async =>
            jsonResponse({'email': ['Enter a valid email.']}, status: 422)),
      );

      expect(
        () => client.post(path: '/register', body: {'email': 'bad'}),
        throwsA(predicate<ApiException>(
            (e) => e.type == ApiErrorType.unprocessable)),
      );
    });

    test('extracts retryAfter from 429 Retry-After header', () async {
      final client = makeClient(
        MockClient((_) async => http.Response(
          jsonEncode({'message': 'Too many requests'}),
          429,
          headers: {
            'content-type': 'application/json',
            'retry-after': '60',
          },
        )),
      );

      try {
        await client.get(path: '/feed');
        fail('Should have thrown');
      } on ApiException catch (e) {
        expect(e.type, ApiErrorType.rateLimited);
        expect(e.retryAfter, const Duration(seconds: 60));
      }
    });

    test('returns empty response on 204', () async {
      final client = makeClient(
        MockClient((_) async => http.Response('', 204, headers: {})),
      );

      final res = await client.delete(path: '/bookings/123');
      expect(res.statusCode, 204);
      expect(res.isEmpty, isTrue);
    });

    test('maps 5xx to server error type', () async {
      final client = makeClient(
        MockClient((_) async =>
            jsonResponse({'message': 'Internal error'}, status: 500)),
      );

      expect(
        () => client.get(path: '/crash'),
        throwsA(predicate<ApiException>((e) => e.isServerError)),
      );
    });
  });

  group('ApiResponse helpers', () {
    test('asList parses JSON array', () async {
      final client = makeClient(
        MockClient((_) async => jsonResponse([1, 2, 3])),
      );

      final res = await client.get(path: '/items');
      expect(res.asList, [1, 2, 3]);
    });

    test('asMapOrNull returns null for list response', () async {
      final client = makeClient(
        MockClient((_) async => jsonResponse([1, 2, 3])),
      );

      final res = await client.get(path: '/items');
      expect(res.asMapOrNull, isNull);
    });
  });

  group('UploadFile', () {
    test('inferContentType maps extensions correctly', () {
      expect(UploadFile.inferContentType('photo.jpg'), 'image/jpeg');
      expect(UploadFile.inferContentType('video.mp4'), 'video/mp4');
      expect(UploadFile.inferContentType('doc.pdf'), 'application/pdf');
      expect(UploadFile.inferContentType('archive.zip'), 'application/zip');
      expect(UploadFile.inferContentType('unknown.xyz'), 'application/octet-stream');
    });
  });
}
