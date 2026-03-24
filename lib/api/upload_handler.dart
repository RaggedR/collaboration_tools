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

    // Read full body
    final bytes = await request.read().expand((chunk) => chunk).toList();
    if (bytes.length > _maxFileSize) {
      return _error('VALIDATION_ERROR', 'File exceeds 10MB limit');
    }

    // Parse multipart manually (Shelf doesn't include multipart parsing)
    final bodyString = String.fromCharCodes(bytes);
    final parts = bodyString.split('--$boundary');

    String? filename;
    List<int>? fileBytes;

    for (final part in parts) {
      if (part.trim() == '--' || part.trim().isEmpty) continue;

      final headerEnd = part.indexOf('\r\n\r\n');
      if (headerEnd == -1) continue;

      final headers = part.substring(0, headerEnd);
      if (!headers.contains('filename=')) continue;

      // Extract filename
      final fnMatch = RegExp(r'filename="([^"]+)"').firstMatch(headers);
      if (fnMatch == null) continue;
      filename = fnMatch.group(1)!;

      // Extract file content (as bytes from original byte array)
      // Find the position in the byte array
      final partStart = bodyString.indexOf(part);
      final contentStart = partStart + headerEnd + 4; // skip \r\n\r\n
      final contentEnd = partStart + part.length - 2; // trim trailing \r\n
      fileBytes = bytes.sublist(contentStart, contentEnd);
      break;
    }

    if (filename == null || fileBytes == null) {
      return _error('VALIDATION_ERROR', 'No file found in upload');
    }

    // Validate extension
    final ext = filename.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(ext)) {
      return _error('VALIDATION_ERROR',
          'File type not allowed. Allowed: ${_allowedExtensions.join(', ')}');
    }

    // Generate unique filename
    final uniqueName = '${_generateId()}_$filename';
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
