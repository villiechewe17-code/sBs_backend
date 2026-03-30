import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Backend API Service
/// 
/// This service handles all communication between the Flutter app and the Node.js backend.
/// It replaces the Cloudflare Worker service and provides:
/// - Authentication (login/logout)
/// - Category management
/// - Content management (CRUD)
/// - R2 presigned URL generation for uploads and downloads
/// - File upload to R2 using presigned URLs
class BackendApiService {
  static const String _baseUrl = 'http://localhost:3000/api/trpc';
  // For production, change to your deployed backend URL:
  // static const String _baseUrl = 'https://your-backend.railway.app/api/trpc';

  String? _authToken;
  
  /// Get the current authentication token
  String? get authToken => _authToken;
  
  /// Set the authentication token (usually after login)
  void setAuthToken(String token) {
    _authToken = token;
  }
  
  /// Clear the authentication token (usually on logout)
  void clearAuthToken() {
    _authToken = null;
  }
  
  /// Check if user is authenticated
  bool get isAuthenticated => _authToken != null;

  // ============================================
  // AUTHENTICATION ENDPOINTS
  // ============================================

  /// Login with email and password
  /// 
  /// This endpoint is typically not used directly in the app since Manus OAuth
  /// handles authentication. However, it's available for custom authentication flows.
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth.login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _authToken = data['accessToken'];
        return data;
      } else {
        throw Exception('Login failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  /// Get current authenticated user info
  Future<Map<String, dynamic>> getCurrentUser() async {
    if (_authToken == null) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth.me'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get user: ${response.body}');
      }
    } catch (e) {
      throw Exception('Get user error: $e');
    }
  }

  /// Logout current user
  Future<void> logout() async {
    if (_authToken == null) {
      throw Exception('Not authenticated');
    }

    try {
      await http.post(
        Uri.parse('$_baseUrl/auth.logout'),
        headers: _getHeaders(),
      );
      _authToken = null;
    } catch (e) {
      throw Exception('Logout error: $e');
    }
  }

  // ============================================
  // CATEGORY ENDPOINTS
  // ============================================

  /// Get all active categories
  /// 
  /// This is a public endpoint that doesn't require authentication.
  /// Returns a list of all active categories sorted by display order.
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/categories.list'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['result']['data'] ?? []);
      } else {
        throw Exception('Failed to get categories: ${response.body}');
      }
    } catch (e) {
      throw Exception('Get categories error: $e');
    }
  }

  /// Create a new category (admin only)
  /// 
  /// Requires authentication and admin role.
  Future<Map<String, dynamic>> createCategory({
    required String name,
    String? description,
    String? icon,
    int displayOrder = 0,
  }) async {
    if (_authToken == null) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/categories.create'),
        headers: _getHeaders(),
        body: jsonEncode({
          'name': name,
          'description': description,
          'icon': icon,
          'displayOrder': displayOrder,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create category: ${response.body}');
      }
    } catch (e) {
      throw Exception('Create category error: $e');
    }
  }

  /// Update an existing category (admin only)
  Future<Map<String, dynamic>> updateCategory({
    required int id,
    String? name,
    String? description,
    String? icon,
    int? displayOrder,
  }) async {
    if (_authToken == null) {
      throw Exception('Not authenticated');
    }

    try {
      final body = {'id': id};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (icon != null) body['icon'] = icon;
      if (displayOrder != null) body['displayOrder'] = displayOrder;

      final response = await http.post(
        Uri.parse('$_baseUrl/categories.update'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update category: ${response.body}');
      }
    } catch (e) {
      throw Exception('Update category error: $e');
    }
  }

  /// Delete a category (admin only)
  Future<void> deleteCategory(int id) async {
    if (_authToken == null) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/categories.delete'),
        headers: _getHeaders(),
        body: jsonEncode({'id': id}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete category: ${response.body}');
      }
    } catch (e) {
      throw Exception('Delete category error: $e');
    }
  }

  // ============================================
  // CONTENT ENDPOINTS
  // ============================================

  /// Get all active content in a category
  /// 
  /// This is a public endpoint that returns all active content items
  /// in the specified category.
  Future<List<Map<String, dynamic>>> getContentByCategory(int categoryId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/content.byCategory?input=${jsonEncode({'categoryId': categoryId})}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['result']['data'] ?? []);
      } else {
        throw Exception('Failed to get content: ${response.body}');
      }
    } catch (e) {
      throw Exception('Get content error: $e');
    }
  }

  /// Get a single content item by ID
  Future<Map<String, dynamic>> getContentById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/content.getById?input=${jsonEncode({'id': id})}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result']['data'];
      } else {
        throw Exception('Failed to get content: ${response.body}');
      }
    } catch (e) {
      throw Exception('Get content error: $e');
    }
  }

  /// Create new content (admin only)
  /// 
  /// Creates a new content item with metadata. For file uploads, use
  /// getUploadPresignedUrl() first to get a presigned URL, upload the file
  /// directly to R2, then create the content item with the R2 file key.
  Future<Map<String, dynamic>> createContent({
    required int categoryId,
    required String title,
    required String contentType, // 'folder', 'link', 'image', 'text'
    String? description,
    String accessLevel = 'free', // 'free' or 'paid'
    String? r2FileKey,
    String? r2Url,
    int? fileSize,
    String? mimeType,
    String? externalUrl,
    String? textContent,
  }) async {
    if (_authToken == null) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/content.create'),
        headers: _getHeaders(),
        body: jsonEncode({
          'categoryId': categoryId,
          'title': title,
          'description': description,
          'contentType': contentType,
          'accessLevel': accessLevel,
          'r2FileKey': r2FileKey,
          'r2Url': r2Url,
          'fileSize': fileSize,
          'mimeType': mimeType,
          'externalUrl': externalUrl,
          'textContent': textContent,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create content: ${response.body}');
      }
    } catch (e) {
      throw Exception('Create content error: $e');
    }
  }

  /// Update existing content (admin only)
  Future<Map<String, dynamic>> updateContent({
    required int id,
    String? title,
    String? description,
    String? accessLevel,
    bool? isActive,
  }) async {
    if (_authToken == null) {
      throw Exception('Not authenticated');
    }

    try {
      final body = {'id': id};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (accessLevel != null) body['accessLevel'] = accessLevel;
      if (isActive != null) body['isActive'] = isActive;

      final response = await http.post(
        Uri.parse('$_baseUrl/content.update'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update content: ${response.body}');
      }
    } catch (e) {
      throw Exception('Update content error: $e');
    }
  }

  /// Delete content (admin only)
  Future<void> deleteContent(int id) async {
    if (_authToken == null) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/content.delete'),
        headers: _getHeaders(),
        body: jsonEncode({'id': id}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete content: ${response.body}');
      }
    } catch (e) {
      throw Exception('Delete content error: $e');
    }
  }

  // ============================================
  // R2 FILE STORAGE ENDPOINTS
  // ============================================

  /// Get presigned URL for uploading a file to R2 (admin only)
  /// 
  /// This generates a temporary presigned URL that allows direct upload to R2.
  /// The URL expires after 1 hour. Use this URL to upload the file directly
  /// to R2 without going through the backend server.
  /// 
  /// Returns a map with:
  /// - presignedUrl: The URL to upload to
  /// - fileKey: The S3 key for the file (use this when creating content)
  /// - expiresIn: Seconds until URL expires
  Future<Map<String, dynamic>> getUploadPresignedUrl({
    required String fileName,
    required String contentType,
    int? fileSize,
  }) async {
    if (_authToken == null) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/r2.getUploadUrl'),
        headers: _getHeaders(),
        body: jsonEncode({
          'fileName': fileName,
          'contentType': contentType,
          'fileSize': fileSize,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result']['data'];
      } else {
        throw Exception('Failed to get upload URL: ${response.body}');
      }
    } catch (e) {
      throw Exception('Get upload URL error: $e');
    }
  }

  /// Get presigned URL for downloading a file from R2
  /// 
  /// This generates a temporary presigned URL that allows download from R2.
  /// The URL expires after 7 days.
  /// 
  /// Returns a map with:
  /// - presignedUrl: The URL to download from
  /// - expiresIn: Seconds until URL expires
  Future<Map<String, dynamic>> getDownloadPresignedUrl(String fileKey) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/r2.getDownloadUrl'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fileKey': fileKey}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result']['data'];
      } else {
        throw Exception('Failed to get download URL: ${response.body}');
      }
    } catch (e) {
      throw Exception('Get download URL error: $e');
    }
  }

  /// Upload a file directly to R2 using a presigned URL
  /// 
  /// This method uploads the file directly to R2 without going through
  /// the backend server. Use getUploadPresignedUrl() first to get the URL.
  /// 
  /// Returns true if upload was successful.
  Future<bool> uploadFileToR2({
    required File file,
    required String presignedUrl,
    required String contentType,
    Function(int, int)? onProgress,
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
        throw Exception('Upload failed with status ${streamedResponse.statusCode}');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  // ============================================
  // HEALTH CHECK
  // ============================================

  /// Check if backend is healthy
  /// 
  /// This is useful for monitoring and debugging.
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health.check'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Health check failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Health check error: $e');
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Get headers for authenticated requests
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
  }

  /// Get MIME type from file extension
  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    final mimeTypes = {
      'pdf': 'application/pdf',
      'zip': 'application/zip',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'txt': 'text/plain',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    };
    return mimeTypes[ext] ?? 'application/octet-stream';
  }
}
