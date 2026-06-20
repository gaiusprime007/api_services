## 1.0.0

- Initial release.
- `ApiClient` with GET, POST, PUT, PATCH, DELETE, HEAD.
- Convenience shorthand methods (`api.get(...)`, `api.post(...)`, etc.).
- Automatic Bearer token injection from `TokenStorage`.
- Token refresh on 401 with a queue lock (no duplicate refresh calls).
- Multipart file uploads — auto-detected from `ApiRequest.files`.
- `UploadFile.inferContentType` — 40+ MIME types inferred from extension.
- Full status code coverage — every 4xx/5xx mapped to `ApiErrorType`.
- Retry-After header parsed on 429 responses.
- Error message extraction for Django REST, NestJS, Laravel, Rails shapes.
- `LoggerInterceptor` — clean request/response console logs.
- `RetryInterceptor` — configurable automatic retries with backoff.
- `SharedPrefsTokenStorage` as default; swappable via `TokenStorage` interface.
- `ApiConfig` for centralised client configuration.
