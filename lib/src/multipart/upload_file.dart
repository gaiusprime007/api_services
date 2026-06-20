import 'dart:io' show File;

import '../../flutter_api_services.dart' show ApiRequest;

import '../api_request.dart' show ApiRequest;

/// Describes a single file to be uploaded as part of a multipart request.
///
/// Create one per file and pass them in [ApiRequest.files].
///
/// ─── From bytes (image_picker / file_picker result) ──────────────────────
/// ```dart
/// final file = UploadFile(
///   fieldName: 'avatar',
///   bytes: imageBytes,
///   fileName: 'avatar.jpg',
///   contentType: 'image/jpeg',
/// );
/// ```
///
/// ─── From dart:io File ────────────────────────────────────────────────────
/// ```dart
/// final file = await UploadFile.fromFile(
///   fieldName: 'cover_video',
///   file: File('/path/to/video.mp4'),
///   contentType: 'video/mp4',
/// );
/// ```
class UploadFile {
  /// The multipart form field name — must match what the server expects.
  final String fieldName;

  /// Raw file bytes.
  final List<int> bytes;

  /// File name sent to the server (e.g. 'photo.jpg').
  final String fileName;

  /// MIME content type (e.g. 'image/jpeg', 'video/mp4', 'audio/mpeg').
  final String contentType;

  const UploadFile({
    required this.fieldName,
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  /// Create an [UploadFile] from a dart:io [File].
  static Future<UploadFile> fromFile({
    required String fieldName,
    required File file,
    String? contentType,
    String? fileName,
  }) async {
    final bytes = await file.readAsBytes();
    final name = fileName ?? file.path.split('/').last;
    final ct = contentType ?? inferContentType(name);
    return UploadFile(fieldName: fieldName, bytes: bytes, fileName: name, contentType: ct);
  }

  /// Create an [UploadFile] from a file path string.
  static Future<UploadFile> fromPath({
    required String fieldName,
    required String filePath,
    String? contentType,
    String? fileName,
  }) =>
      fromFile(fieldName: fieldName, file: File(filePath), contentType: contentType, fileName: fileName);

  /// Infer MIME type from file extension.
  /// Falls back to 'application/octet-stream'.
  static String inferContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'gif': 'image/gif', 'webp': 'image/webp', 'heic': 'image/heic',
      'heif': 'image/heif', 'bmp': 'image/bmp', 'svg': 'image/svg+xml',
      'tiff': 'image/tiff',
      'mp4': 'video/mp4', 'mov': 'video/quicktime', 'avi': 'video/x-msvideo',
      'mkv': 'video/x-matroska', 'webm': 'video/webm', '3gp': 'video/3gpp',
      'mp3': 'audio/mpeg', 'aac': 'audio/aac', 'wav': 'audio/wav',
      'ogg': 'audio/ogg', 'flac': 'audio/flac', 'm4a': 'audio/mp4',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain', 'csv': 'text/csv',
      'json': 'application/json', 'xml': 'application/xml',
      'zip': 'application/zip', 'gz': 'application/gzip',
    };
    return map[ext] ?? 'application/octet-stream';
  }
}
