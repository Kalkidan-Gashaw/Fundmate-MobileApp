import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Uploads chat attachments to Firebase Storage.
///
/// **Windows / desktop:** uses the Firebase Storage REST API (the native
/// [Reference.putData] plugin is buggy on Windows and often throws
/// `object-not-found` even when nothing was uploaded).
///
/// **Mobile / web:** uses [Reference.putData] and awaits the task snapshot.
class StorageUploadService {
  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static Future<String> uploadBytes({
    required String objectPath,
    required Uint8List data,
    required String fileName,
  }) async {
    final contentType = _contentTypeFor(fileName);
    final ref = FirebaseStorage.instance.ref(objectPath);
    final metadata = SettableMetadata(contentType: contentType);

    if (_isDesktop) {
      final urlFromRest = await _uploadViaRestApi(
        objectPath: objectPath,
        data: data,
        contentType: contentType,
      );
      if (urlFromRest != null) return urlFromRest;
      return _getDownloadUrlWithRetry(ref);
    }

    final task = ref.putData(data, metadata);
    final snapshot = await task;
    if (snapshot.state != TaskState.success) {
      throw Exception('Upload did not complete (${snapshot.state})');
    }
    return snapshot.ref.getDownloadURL();
  }

  /// Uploads via REST and returns a download URL when the response includes
  /// tokens; otherwise returns null so the caller can resolve via the SDK.
  static Future<String?> _uploadViaRestApi({
    required String objectPath,
    required Uint8List data,
    required String contentType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to upload files');
    }

    final token = await user.getIdToken(true);
    final bucket = FirebaseStorage.instance.bucket;
    if (bucket.isEmpty) {
      throw Exception('Firebase Storage bucket is not configured');
    }

    final uri = Uri.https(
      'firebasestorage.googleapis.com',
      '/v0/b/$bucket/o',
      {
        'uploadType': 'media',
        'name': objectPath,
      },
    );

    debugPrint('Storage REST upload: $objectPath (${data.length} bytes)');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': contentType,
        'Content-Length': '${data.length}',
      },
      body: data,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _parseErrorBody(response.body);
      throw Exception(
        'Storage upload failed (${response.statusCode})${detail.isEmpty ? '' : ': $detail'}',
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('Storage upload returned an unexpected response');
    }

    final url = _downloadUrlFromUploadBody(body, bucket);
    if (url != null) {
      debugPrint('Storage REST upload OK — URL from response');
      return url;
    }

    debugPrint(
      'Storage REST upload OK — no token in response, resolving via SDK',
    );
    return null;
  }

  static String? _downloadUrlFromUploadBody(
    Map<String, dynamic> body,
    String bucket,
  ) {
    final name = body['name']?.toString();
    if (name == null || name.isEmpty) return null;

    final tokensRaw = body['downloadTokens'];
    String? downloadToken;
    if (tokensRaw is String && tokensRaw.isNotEmpty) {
      downloadToken = tokensRaw.split(',').first.trim();
    } else if (tokensRaw is List && tokensRaw.isNotEmpty) {
      downloadToken = tokensRaw.first.toString().trim();
    }

    if (downloadToken == null || downloadToken.isEmpty) return null;

    return Uri.https(
      'firebasestorage.googleapis.com',
      '/v0/b/$bucket/o/${Uri.encodeComponent(name)}',
      {'alt': 'media', 'token': downloadToken},
    ).toString();
  }

  /// Firebase may need a moment after REST upload before [getDownloadURL] works.
  static Future<String> _getDownloadUrlWithRetry(
    Reference ref, {
    int attempts = 8,
  }) async {
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      try {
        return await ref.getDownloadURL();
      } catch (e) {
        lastError = e;
        debugPrint('getDownloadURL attempt ${i + 1}/$attempts failed: $e');
        if (i < attempts - 1) {
          await Future<void>.delayed(Duration(milliseconds: 400 * (i + 1)));
        }
      }
    }
    throw Exception(
      'File uploaded but download link could not be created: $lastError',
    );
  }

  static String _parseErrorBody(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json['error'] is Map) {
        final err = json['error'] as Map;
        return err['message']?.toString() ?? body;
      }
    } catch (_) {}
    return body.length > 200 ? '${body.substring(0, 200)}...' : body;
  }

  static String sanitizeFileName(String name) {
    final base = name.split(RegExp(r'[/\\]')).last;
    final sanitized = base.replaceAll(RegExp(r'[^\w.\-]'), '_');
    return sanitized.isEmpty ? 'file' : sanitized;
  }

  static String _contentTypeFor(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'zip' => 'application/zip',
      'rar' => 'application/vnd.rar',
      'mp4' => 'video/mp4',
      'mp3' => 'audio/mpeg',
      _ => 'application/octet-stream',
    };
  }
}
