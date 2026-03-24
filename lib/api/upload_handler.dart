import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';

/// Handles file uploads and serves static files from the uploads directory.
class UploadHandler {
  static const _maxFileSize = 10 * 1024 * 1024; // 10MB
  static const _allowedExtensions = {
    'pdf', 'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg',
  };

  final String uploadsDir;

  UploadHandler({this.uploadsDir = 'uploads'});

  /// POST /api/upload — accepts multipart file upload.
  Future<Response> upload(Request request) async {
    final contentType = request.headers['content-type'] ?? '';
    if (!contentType.startsWith('multipart/form-data')) {
      return _error('VALIDATION_ERROR', 'Expected multipart/form-data');
    }

    // Parse boundary from content-type header
    final boundaryMatch =
        RegExp(r'boundary=(.+)$').firstMatch(contentType);
    if (boundaryMatch == null) {
      return _error('VALIDATION_ERROR', 'Missing multipart boundary');
    }
    final boundary = boundaryMatch.group(1)!;
    final boundaryBytes = utf8.encode('--$boundary');

    // Read full body as bytes
    final bytes = await request.read().expand((chunk) => chunk).toList();
    if (bytes.length > _maxFileSize) {
      return _error('VALIDATION_ERROR', 'File exceeds 10MB limit');
    }

    // Find multipart parts by scanning for boundary bytes
    String? filename;
    List<int>? fileBytes;

    final partStarts = <int>[];
    for (var i = 0; i <= bytes.length - boundaryBytes.length; i++) {
      if (_bytesMatch(bytes, i, boundaryBytes)) {
        partStarts.add(i + boundaryBytes.length);
      }
    }

    for (var p = 0; p < partStarts.length; p++) {
      final partStart = partStarts[p];
      final partEnd = p + 1 < partStarts.length
          ? partStarts[p + 1] - boundaryBytes.length
          : bytes.length;

      // Skip leading \r\n after boundary
      var headerStart = partStart;
      if (headerStart < bytes.length - 1 &&
          bytes[headerStart] == 0x0D &&
          bytes[headerStart + 1] == 0x0A) {
        headerStart += 2;
      }

      // Find header/body separator: \r\n\r\n
      final separatorIndex = _findDoubleCRLF(bytes, headerStart, partEnd);
      if (separatorIndex == -1) continue;

      final headerBytes = bytes.sublist(headerStart, separatorIndex);
      final headerStr = utf8.decode(headerBytes, allowMalformed: true);

      if (!headerStr.contains('filename=')) continue;

      // Extract filename from Content-Disposition header
      final fnMatch = RegExp(r'filename="([^"]+)"').firstMatch(headerStr);
      if (fnMatch == null) continue;
      filename = fnMatch.group(1)!;

      // File content starts after \r\n\r\n, ends before trailing \r\n
      final contentStart = separatorIndex + 4;
      var contentEnd = partEnd;
      // Strip trailing \r\n before next boundary
      if (contentEnd >= 2 &&
          bytes[contentEnd - 2] == 0x0D &&
          bytes[contentEnd - 1] == 0x0A) {
        contentEnd -= 2;
      }
      fileBytes = bytes.sublist(contentStart, contentEnd);
      break;
    }

    if (filename == null || fileBytes == null) {
      return _error('VALIDATION_ERROR', 'No file found in upload');
    }

    // Sanitize filename: keep only alphanumeric, dots, hyphens, underscores
    final sanitized = filename
        .replaceAll(RegExp(r'[^\w.\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    // Validate extension
    final ext = sanitized.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(ext)) {
      return _error('VALIDATION_ERROR',
          'File type not allowed. Allowed: ${_allowedExtensions.join(', ')}');
    }

    // Generate unique filename
    final uniqueName = '${_generateId()}_$sanitized';
    final dir = Directory(uploadsDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final file = File('$uploadsDir/$uniqueName');
    await file.writeAsBytes(fileBytes);

    return Response(201,
        body: jsonEncode({'url': '/uploads/$uniqueName'}),
        headers: {'Content-Type': 'application/json'});
  }

  /// Serve a file from the uploads directory.
  Future<Response> serve(Request request, String filename) async {
    // Prevent directory traversal
    if (filename.contains('..') || filename.contains('/')) {
      return Response.notFound('Not found');
    }

    final file = File('$uploadsDir/$filename');
    if (!file.existsSync()) {
      return Response.notFound('Not found');
    }

    final ext = filename.split('.').last.toLowerCase();
    final contentType = _mimeType(ext);
    final bytes = await file.readAsBytes();

    return Response.ok(bytes, headers: {'Content-Type': contentType});
  }

  /// Check if bytes at [offset] match [pattern].
  static bool _bytesMatch(List<int> data, int offset, List<int> pattern) {
    if (offset + pattern.length > data.length) return false;
    for (var i = 0; i < pattern.length; i++) {
      if (data[offset + i] != pattern[i]) return false;
    }
    return true;
  }

  /// Find \r\n\r\n in byte array between [start] and [end].
  static int _findDoubleCRLF(List<int> data, int start, int end) {
    for (var i = start; i < end - 3; i++) {
      if (data[i] == 0x0D &&
          data[i + 1] == 0x0A &&
          data[i + 2] == 0x0D &&
          data[i + 3] == 0x0A) {
        return i;
      }
    }
    return -1;
  }

  String _mimeType(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'svg':
        return 'image/svg+xml';
      default:
        return 'application/octet-stream';
    }
  }

  static String _generateId() {
    final random = Random.secure();
    final bytes = List.generate(8, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Response _error(String code, String message, {int status = 400}) {
    return Response(status,
        body: jsonEncode({
          'error': {'code': code, 'message': message}
        }),
        headers: {'Content-Type': 'application/json'});
  }
}
