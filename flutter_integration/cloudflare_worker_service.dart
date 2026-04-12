import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

/// Cloudflare Worker Service
///
/// This service handles file uploads to Cloudflare R2 via the tRPC backend.
/// It generates presigned upload URLs using the `r2.getUploadUrl` tRPC mutation
/// and uploads files directly to R2 using those URLs.
class CloudflareWorkerService {
  final String backendUrl;
  final String? authToken;

  CloudflareWorkerService({
    required this.backendUrl,
    this.authToken,
  });

  /// Get a presigned upload URL from the tRPC backend.
  ///
  /// Calls the `r2.getUploadUrl` mutation and returns the full response map,
  /// which includes:
  /// - `presignedUrl`: The URL to upload to directly
  /// - `fileKey`: The R2 object key (use when creating content metadata)
  /// - `expiresIn`: Seconds until the URL expires (3600 = 1 hour)
  Future<Map<String, dynamic>> getPresignedUploadUrl({
    required String fileName,
    required String contentType,
    int? fileSize,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/trpc/r2.getUploadUrl'),
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'fileName': fileName,
          'contentType': contentType,
          if (fileSize != null) 'fileSize': fileSize,
        }),
      );

      if (response.statusCode == 200) {
        final uploadData = jsonDecode(response.body);
        // tRPC wraps the result in result.data
        return uploadData['result']['data'] as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to get upload URL (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('getPresignedUploadUrl error: $e');
    }
  }

  /// Upload a file directly to R2 using a presigned URL.
  ///
  /// Use [getPresignedUploadUrl] first to obtain the [presignedUrl].
  /// Returns `true` on success.
  Future<bool> uploadFileToR2({
    required File file,
    required String presignedUrl,
    required String contentType,
  }) async {
    try {
      final fileBytes = await file.readAsBytes();

      final request = http.StreamedRequest('PUT', Uri.parse(presignedUrl));
      request.headers['Content-Type'] = contentType;
      request.bodyBytes = fileBytes;

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        return true;
      } else {
        throw Exception(
          'R2 upload failed with status ${streamedResponse.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('uploadFileToR2 error: $e');
    }
  }

  /// Convenience method: get a presigned URL and upload a file in one call.
  ///
  /// Returns the [fileKey] that should be stored as content metadata.
  Future<String> uploadFile({
    required File file,
    required String fileName,
    required String contentType,
    int? fileSize,
  }) async {
    // Step 1: Get presigned upload URL from tRPC backend
    final uploadData = await getPresignedUploadUrl(
      fileName: fileName,
      contentType: contentType,
      fileSize: fileSize,
    );

    final presignedUrl = uploadData['presignedUrl'] as String;
    final fileKey = uploadData['fileKey'] as String;

    // Step 2: Upload directly to R2
    await uploadFileToR2(
      file: file,
      presignedUrl: presignedUrl,
      contentType: contentType,
    );

    return fileKey;
  }
}
