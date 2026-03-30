# Flutter App Integration with Backend API

## Overview

This guide explains how to integrate your Flutter mobile app with the Node.js backend system. The backend acts as a bridge between your Flutter app and the Supabase database and Cloudflare R2 storage.

## Architecture

The integration follows this architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                     FLUTTER MOBILE APP (Android)                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Admin Panel → Upload Content → Manage Categories         │  │
│  │ User Access → Download Content → View Free/Paid Content  │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTP/HTTPS API Calls
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    BACKEND API (Node.js/Express)                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ • Authentication & Authorization                         │  │
│  │ • R2 Presigned URL Generation                            │  │
│  │ • Content Management (CRUD)                              │  │
│  │ • Category Management                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└────┬────────────────────────────────────────────┬────────────────┘
     │                                            │
     ▼                                            ▼
┌──────────────────────┐              ┌──────────────────────┐
│   SUPABASE           │              │  CLOUDFLARE R2       │
│  (PostgreSQL)        │              │  (S3-Compatible)     │
│                      │              │                      │
│ • Users              │              │ • File Storage       │
│ • Categories         │              │ • Direct Uploads     │
│ • Content Metadata   │              │ • Presigned URLs     │
│ • Access Control     │              │                      │
└──────────────────────┘              └──────────────────────┘
```

## Installation

### Step 1: Add Dependencies to pubspec.yaml

Add the required packages to your Flutter project:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  file_picker: ^5.3.0
  supabase_flutter: ^1.10.0
  provider: ^6.0.0
  shared_preferences: ^2.1.0
```

Run `flutter pub get` to install the dependencies.

### Step 2: Copy Backend API Service

Copy the `backend_api_service.dart` file to your Flutter project's `lib/services/` directory:

```
lib/
  services/
    backend_api_service.dart
```

### Step 3: Update Backend URL

In `backend_api_service.dart`, update the `_baseUrl` constant to point to your deployed backend:

```dart
// For local development:
static const String _baseUrl = 'http://localhost:3000/api/trpc';

// For production:
static const String _baseUrl = 'https://your-backend-url.railway.app/api/trpc';
```

## Usage

### Initialize the Service

In your main app or auth provider, initialize the `BackendApiService`:

```dart
import 'services/backend_api_service.dart';

class AuthProvider extends ChangeNotifier {
  final _apiService = BackendApiService();
  
  BackendApiService get apiService => _apiService;
  
  // ... rest of your auth logic
}
```

### Authentication

After user logs in via Manus OAuth, set the auth token:

```dart
// After successful OAuth login
_apiService.setAuthToken(accessToken);

// Check if authenticated
if (_apiService.isAuthenticated) {
  // User is authenticated
}

// Logout
await _apiService.logout();
_apiService.clearAuthToken();
```

### Get Categories

Retrieve all available categories (public endpoint):

```dart
try {
  final categories = await _apiService.getCategories();
  for (var category in categories) {
    print('Category: ${category['name']}');
  }
} catch (e) {
  print('Error: $e');
}
```

### Get Content by Category

Retrieve all content in a specific category:

```dart
try {
  final content = await _apiService.getContentByCategory(1); // categoryId = 1
  for (var item in content) {
    print('Content: ${item['title']} (${item['contentType']})');
  }
} catch (e) {
  print('Error: $e');
}
```

### Upload File (Admin Only)

The file upload process involves three steps:

#### Step 1: Get Presigned URL

```dart
try {
  final presignedData = await _apiService.getUploadPresignedUrl(
    fileName: 'my-file.zip',
    contentType: 'application/zip',
    fileSize: 10485760, // 10 MB
  );
  
  final presignedUrl = presignedData['presignedUrl'];
  final fileKey = presignedData['fileKey'];
  print('Upload URL: $presignedUrl');
  print('File Key: $fileKey');
} catch (e) {
  print('Error: $e');
}
```

#### Step 2: Upload File to R2

```dart
try {
  final file = File('/path/to/file.zip');
  final success = await _apiService.uploadFileToR2(
    file: file,
    presignedUrl: presignedUrl,
    contentType: 'application/zip',
  );
  
  if (success) {
    print('File uploaded successfully!');
  }
} catch (e) {
  print('Error: $e');
}
```

#### Step 3: Create Content Metadata

```dart
try {
  await _apiService.createContent(
    categoryId: 1,
    title: 'My Course',
    contentType: 'folder',
    description: 'A great course',
    accessLevel: 'free',
    r2FileKey: fileKey, // From step 1
    fileSize: 10485760,
    mimeType: 'application/zip',
  );
  
  print('Content created successfully!');
} catch (e) {
  print('Error: $e');
}
```

### Download File

To download a file, first get the presigned URL, then download:

```dart
try {
  // Get presigned download URL
  final downloadData = await _apiService.getDownloadPresignedUrl(
    'uploads/1234567890-file.zip',
  );
  
  final downloadUrl = downloadData['presignedUrl'];
  
  // Download using the URL (use http package or file_picker)
  final response = await http.get(Uri.parse(downloadUrl));
  if (response.statusCode == 200) {
    // Save file to device
    final file = File('/path/to/save/file.zip');
    await file.writeAsBytes(response.bodyBytes);
    print('File downloaded successfully!');
  }
} catch (e) {
  print('Error: $e');
}
```

### Create Category (Admin Only)

```dart
try {
  final result = await _apiService.createCategory(
    name: 'Advanced Topics',
    description: 'Advanced learning materials',
    icon: 'book',
    displayOrder: 2,
  );
  
  print('Category created with ID: ${result['id']}');
} catch (e) {
  print('Error: $e');
}
```

### Update Content (Admin Only)

```dart
try {
  await _apiService.updateContent(
    id: 1,
    title: 'Updated Title',
    accessLevel: 'paid',
    isActive: false,
  );
  
  print('Content updated successfully!');
} catch (e) {
  print('Error: $e');
}
```

### Delete Content (Admin Only)

```dart
try {
  await _apiService.deleteContent(1);
  print('Content deleted successfully!');
} catch (e) {
  print('Error: $e');
}
```

## Updated Admin Panel

An updated admin panel component (`updated_admin_panel.dart`) is provided that demonstrates how to use the backend API service. Key features include:

- **File Selection and Upload**: Users can select files and upload them directly to R2 using presigned URLs
- **Content Management**: Create, update, and delete content items
- **Link Management**: Add external links without file uploads
- **Text Content**: Create text-based content directly in the database
- **Access Control**: Set content as free or paid

### Using the Updated Admin Panel

```dart
import 'flutter_integration/updated_admin_panel.dart';

// In your navigation
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => UpdatedAdminPanel(
      categoryId: '1',
      categoryName: 'Education',
      apiService: apiService,
    ),
  ),
);
```

## Error Handling

All API methods throw exceptions on error. Handle them appropriately:

```dart
try {
  final categories = await _apiService.getCategories();
} on SocketException {
  print('Network error - check your connection');
} on TimeoutException {
  print('Request timeout - server not responding');
} catch (e) {
  print('Unexpected error: $e');
}
```

## Best Practices

### 1. Store Auth Token Securely

Use `flutter_secure_storage` to store the auth token securely:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const storage = FlutterSecureStorage();

// Save token
await storage.write(key: 'auth_token', value: token);

// Retrieve token
final token = await storage.read(key: 'auth_token');

// Delete token
await storage.delete(key: 'auth_token');
```

### 2. Show Loading States

Always show loading indicators during API calls:

```dart
setState(() => _isLoading = true);
try {
  final data = await _apiService.getCategories();
} finally {
  setState(() => _isLoading = false);
}
```

### 3. Handle Network Errors

Implement proper error handling and user feedback:

```dart
try {
  await _apiService.createContent(...);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Content created successfully!')),
  );
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

### 4. Implement Retry Logic

For critical operations, implement retry logic:

```dart
Future<T> _retryOperation<T>(
  Future<T> Function() operation, {
  int maxRetries = 3,
}) async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      return await operation();
    } catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(Duration(seconds: 2 * (i + 1)));
    }
  }
  throw Exception('Operation failed after $maxRetries retries');
}
```

### 5. Cache API Responses

Cache frequently accessed data to reduce API calls:

```dart
Map<int, List<Map<String, dynamic>>> _contentCache = {};

Future<List<Map<String, dynamic>>> getContentByCategory(int categoryId) async {
  if (_contentCache.containsKey(categoryId)) {
    return _contentCache[categoryId]!;
  }
  
  final content = await _apiService.getContentByCategory(categoryId);
  _contentCache[categoryId] = content;
  return content;
}
```

## Environment Configuration

For different environments, create separate configuration files:

```dart
// lib/config/api_config.dart
class ApiConfig {
  static const String developmentUrl = 'http://localhost:3000/api/trpc';
  static const String productionUrl = 'https://your-backend.railway.app/api/trpc';
  
  static String get baseUrl {
    const String flavor = String.fromEnvironment('FLAVOR', defaultValue: 'development');
    return flavor == 'production' ? productionUrl : developmentUrl;
  }
}
```

## Troubleshooting

### Connection Refused

If you get "Connection refused" errors, ensure:
- Backend server is running
- Backend URL is correct
- Firewall allows connections to the backend port

### Unauthorized Errors

If you get "Unauthorized" errors:
- Verify auth token is set correctly
- Check token hasn't expired
- Ensure user has required permissions (admin for protected endpoints)

### File Upload Fails

If file uploads fail:
- Check file size is under 500MB limit
- Verify R2 credentials are correct
- Ensure file MIME type is correct
- Check presigned URL hasn't expired

### CORS Errors

If you get CORS errors:
- Verify backend has CORS enabled
- Check that your app's origin is in CORS allowed list
- For development, backend should allow `http://localhost:*`

## Next Steps

1. Implement user authentication with Manus OAuth
2. Add payment processing for paid content
3. Implement content search and filtering
4. Add user purchase history tracking
5. Implement content versioning
6. Add analytics and usage tracking

## Support

For issues or questions:
1. Check the API documentation in `API_DOCUMENTATION.md`
2. Review the backend setup guide in `SETUP_GUIDE.md`
3. Check the troubleshooting section in `SETUP_GUIDE.md`
4. Review the example code in `updated_admin_panel.dart`
