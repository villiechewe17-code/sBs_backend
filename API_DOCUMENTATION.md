# Content Management Backend - API Documentation

## Overview

This backend system provides a complete content management and file distribution platform built with Node.js, Express, and tRPC. It integrates Supabase for authentication and database operations, and Cloudflare R2 for secure file storage with presigned URLs.

The API enforces role-based access control, distinguishing between admin users who manage content and regular users who consume it. All file uploads and downloads use presigned URLs for security and efficiency, eliminating the need for files to pass through the backend server.

## Architecture Overview

The backend operates on a three-tier architecture consisting of a web server layer (Express with tRPC), a database layer (Supabase/MySQL), and a file storage layer (Cloudflare R2). Admin users authenticate through the system and receive JWT tokens that grant access to protected procedures. Regular users can browse and download free content without authentication, while paid content access is managed through the access level field.

## Authentication & Authorization

All protected endpoints require authentication via JWT tokens passed in the Authorization header. The system uses tRPC's `protectedProcedure` wrapper to enforce authentication automatically. Admin-only endpoints are further protected by the `adminProcedure` wrapper, which verifies that the authenticated user has an admin role in the database.

### Authentication Flow

When a user logs in, they receive a JWT token that must be included in subsequent requests. The token is verified on each request, and the user's role is checked for admin-only operations. Sessions are managed through secure HTTP-only cookies set by the Manus OAuth system.

## Database Schema

### Categories Table

The categories table organizes all content into logical groups. Each category has a display order for custom sorting and an active flag to control visibility.

| Field | Type | Description |
|-------|------|-------------|
| id | int | Primary key, auto-incremented |
| name | varchar(255) | Category name (required) |
| description | text | Optional category description |
| icon | varchar(255) | Icon identifier or URL |
| displayOrder | int | Sort order for display (default: 0) |
| isActive | boolean | Whether category is visible (default: true) |
| createdAt | timestamp | Creation timestamp |
| updatedAt | timestamp | Last update timestamp |

### Content Table

The content table stores metadata for all content items. Files are stored in R2, with only references and metadata stored here. The content type field determines how the content should be handled by clients.

| Field | Type | Description |
|-------|------|-------------|
| id | int | Primary key, auto-incremented |
| categoryId | int | Foreign key to categories |
| title | varchar(255) | Content title (required) |
| description | text | Optional content description |
| contentType | enum | One of: folder, link, image, text |
| accessLevel | enum | One of: free, paid (default: free) |
| isActive | boolean | Whether content is visible (default: true) |
| r2FileKey | varchar(512) | S3 key for file in R2 |
| r2Url | varchar(512) | Public URL to file in R2 |
| fileSize | bigint | File size in bytes |
| mimeType | varchar(100) | MIME type of file |
| externalUrl | varchar(512) | External URL for link type |
| textContent | text | Text content for text type |
| uploadedBy | int | User ID who uploaded content |
| createdAt | timestamp | Creation timestamp |
| updatedAt | timestamp | Last update timestamp |

### Users Table

The users table maintains user information and role assignments. The role field determines access levels within the system.

| Field | Type | Description |
|-------|------|-------------|
| id | int | Primary key, auto-incremented |
| openId | varchar(64) | Unique Manus OAuth identifier |
| name | text | User's display name |
| email | varchar(320) | User's email address |
| loginMethod | varchar(64) | Authentication method used |
| role | enum | One of: user, admin (default: user) |
| createdAt | timestamp | Account creation timestamp |
| updatedAt | timestamp | Last profile update timestamp |
| lastSignedIn | timestamp | Last login timestamp |

## API Endpoints

### Health Check

The health check endpoint allows monitoring systems to verify that the backend is operational.

**Endpoint:** `health.check`

**Method:** Query

**Authentication:** Not required

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2026-03-20T12:00:00.000Z",
  "service": "Content Management Backend"
}
```

### Category Management

#### List Categories

Retrieve all active categories sorted by display order. This endpoint is public and does not require authentication.

**Endpoint:** `categories.list`

**Method:** Query

**Authentication:** Not required

**Response:**
```json
[
  {
    "id": 1,
    "name": "Education",
    "description": "Educational materials and courses",
    "icon": "book",
    "displayOrder": 0,
    "isActive": true,
    "createdAt": "2026-03-20T10:00:00.000Z",
    "updatedAt": "2026-03-20T10:00:00.000Z"
  }
]
```

#### Create Category

Create a new category. Admin access required.

**Endpoint:** `categories.create`

**Method:** Mutation

**Authentication:** Required (admin only)

**Input:**
```json
{
  "name": "Construction",
  "description": "Construction materials and guides",
  "icon": "hammer",
  "displayOrder": 1
}
```

**Response:**
```json
{
  "success": true,
  "id": 2
}
```

#### Update Category

Update an existing category. Admin access required.

**Endpoint:** `categories.update`

**Method:** Mutation

**Authentication:** Required (admin only)

**Input:**
```json
{
  "id": 1,
  "name": "Advanced Education",
  "displayOrder": 2
}
```

**Response:**
```json
{
  "success": true
}
```

#### Delete Category

Delete a category. Admin access required.

**Endpoint:** `categories.delete`

**Method:** Mutation

**Authentication:** Required (admin only)

**Input:**
```json
{
  "id": 1
}
```

**Response:**
```json
{
  "success": true
}
```

### Content Management

#### Get Content by Category

Retrieve all active content items in a specific category.

**Endpoint:** `content.byCategory`

**Method:** Query

**Authentication:** Not required

**Input:**
```json
{
  "categoryId": 1
}
```

**Response:**
```json
[
  {
    "id": 1,
    "categoryId": 1,
    "title": "Introduction to Python",
    "description": "Beginner-friendly Python course",
    "contentType": "folder",
    "accessLevel": "free",
    "isActive": true,
    "r2FileKey": "uploads/1234567890-course.zip",
    "r2Url": "https://r2-bucket.example.com/uploads/1234567890-course.zip",
    "fileSize": 5242880,
    "mimeType": "application/zip",
    "uploadedBy": 1,
    "createdAt": "2026-03-20T10:00:00.000Z",
    "updatedAt": "2026-03-20T10:00:00.000Z"
  }
]
```

#### Get Single Content Item

Retrieve details for a specific content item.

**Endpoint:** `content.getById`

**Method:** Query

**Authentication:** Not required

**Input:**
```json
{
  "id": 1
}
```

**Response:**
```json
{
  "id": 1,
  "categoryId": 1,
  "title": "Introduction to Python",
  "description": "Beginner-friendly Python course",
  "contentType": "folder",
  "accessLevel": "free",
  "isActive": true,
  "r2FileKey": "uploads/1234567890-course.zip",
  "r2Url": "https://r2-bucket.example.com/uploads/1234567890-course.zip",
  "fileSize": 5242880,
  "mimeType": "application/zip",
  "uploadedBy": 1,
  "createdAt": "2026-03-20T10:00:00.000Z",
  "updatedAt": "2026-03-20T10:00:00.000Z"
}
```

#### Create Content

Create a new content item. Admin access required.

**Endpoint:** `content.create`

**Method:** Mutation

**Authentication:** Required (admin only)

**Input:**
```json
{
  "categoryId": 1,
  "title": "Advanced Python",
  "description": "Advanced Python programming concepts",
  "contentType": "folder",
  "accessLevel": "paid",
  "r2FileKey": "uploads/1234567890-advanced.zip",
  "r2Url": "https://r2-bucket.example.com/uploads/1234567890-advanced.zip",
  "fileSize": 10485760,
  "mimeType": "application/zip"
}
```

**Response:**
```json
{
  "success": true,
  "id": 2
}
```

#### Update Content

Update an existing content item. Admin access required.

**Endpoint:** `content.update`

**Method:** Mutation

**Authentication:** Required (admin only)

**Input:**
```json
{
  "id": 1,
  "title": "Updated Title",
  "accessLevel": "paid",
  "isActive": false
}
```

**Response:**
```json
{
  "success": true
}
```

#### Delete Content

Delete a content item. Admin access required.

**Endpoint:** `content.delete`

**Method:** Mutation

**Authentication:** Required (admin only)

**Input:**
```json
{
  "id": 1
}
```

**Response:**
```json
{
  "success": true
}
```

### File Storage (Cloudflare R2)

#### Generate Upload Presigned URL

Generate a temporary presigned URL for uploading files to R2. Admin access required. The URL expires after 1 hour.

**Endpoint:** `r2.getUploadUrl`

**Method:** Mutation

**Authentication:** Required (admin only)

**Input:**
```json
{
  "fileName": "course-materials.zip",
  "contentType": "application/zip",
  "fileSize": 10485760
}
```

**Response:**
```json
{
  "presignedUrl": "https://r2-bucket.example.com/uploads/1234567890-course-materials.zip?X-Amz-Algorithm=...",
  "fileKey": "uploads/1234567890-course-materials.zip",
  "expiresIn": 3600
}
```

#### Generate Download Presigned URL

Generate a temporary presigned URL for downloading files from R2. The URL expires after 7 days.

**Endpoint:** `r2.getDownloadUrl`

**Method:** Mutation

**Authentication:** Not required

**Input:**
```json
{
  "fileKey": "uploads/1234567890-course-materials.zip"
}
```

**Response:**
```json
{
  "presignedUrl": "https://r2-bucket.example.com/uploads/1234567890-course-materials.zip?X-Amz-Algorithm=...",
  "expiresIn": 604800
}
```

## Error Handling

The API returns standardized error responses for all error conditions. Errors include a code indicating the type of error and a message describing what went wrong.

### Common Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| UNAUTHORIZED | 401 | Authentication required or token invalid |
| FORBIDDEN | 403 | User lacks required permissions (e.g., not admin) |
| NOT_FOUND | 404 | Requested resource not found |
| BAD_REQUEST | 400 | Invalid input parameters |
| INTERNAL_SERVER_ERROR | 500 | Server error occurred |

### Error Response Format

```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "Admin access required"
  }
}
```

## Content Types

The system supports four content types, each designed for different use cases:

**Folder:** Zip files containing multiple files and directories. Ideal for distributing complete projects, course materials, or collections of related files.

**Link:** External URLs pointing to content hosted elsewhere. Useful for referencing third-party resources or websites without storing files.

**Image:** Image files (JPEG, PNG, WebP, etc.). Suitable for photos, diagrams, illustrations, and visual content.

**Text:** Text-based content stored directly in the database. Perfect for articles, announcements, news, and written content that doesn't require file uploads.

## Access Levels

Content can be marked as either free or paid to control who can access it:

**Free:** Publicly accessible to all users without any restrictions or authentication requirements.

**Paid:** Restricted content that requires user verification or payment before access is granted. The payment processing system should be implemented separately and should update the user's access permissions accordingly.

## File Upload Workflow

The file upload process uses presigned URLs to enable direct uploads to R2 without passing files through the backend server. This approach improves performance and reduces server bandwidth usage.

The workflow proceeds as follows: First, the admin calls `r2.getUploadUrl` with the file name, content type, and size. The backend validates the file size and generates a unique key with a timestamp prefix. A presigned URL is generated that allows uploading to that specific key for one hour. The admin then uploads the file directly to R2 using the presigned URL. After successful upload, the admin creates a content item with the R2 file key and URL, storing the metadata in the database.

## File Download Workflow

Downloads follow a similar presigned URL approach for security and efficiency:

The user requests a download URL by calling `r2.getDownloadUrl` with the file key. The backend generates a presigned URL that allows downloading that specific file for seven days. The user receives the presigned URL and can download the file directly from R2 without going through the backend server.

## Environment Variables

The backend requires the following environment variables to be configured:

| Variable | Description | Example |
|----------|-------------|---------|
| DATABASE_URL | MySQL connection string | mysql://user:pass@host:3306/db |
| R2_ACCOUNT_ID | Cloudflare R2 account ID | 1234567890abcdef |
| R2_ACCESS_KEY_ID | R2 API access key | AKIAIOSFODNN7EXAMPLE |
| R2_SECRET_ACCESS_KEY | R2 API secret key | wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY |
| R2_BUCKET_NAME | Name of R2 bucket | my-content-bucket |
| JWT_SECRET | Secret for JWT signing | your-secret-key-here |
| VITE_APP_ID | Manus OAuth app ID | app_123456 |
| OAUTH_SERVER_URL | Manus OAuth server URL | https://api.manus.im |

## Testing

The backend includes comprehensive unit tests covering authentication, health checks, and R2 configuration validation. Run tests with:

```bash
pnpm test
```

Tests verify that the health check endpoint returns the correct status, that R2 environment variables are properly configured, and that authentication procedures work correctly.

## Deployment

The backend is ready for deployment to any Node.js hosting platform. Recommended platforms include Railway, Render, Heroku, or AWS. The application uses environment variables for all configuration, making it easy to deploy across different environments.

Before deploying, ensure all environment variables are properly configured in your hosting platform's settings. The backend will automatically connect to the database and R2 on startup.

## Rate Limiting & Security

The backend includes built-in CORS configuration to prevent unauthorized cross-origin requests. All admin operations require authentication and role verification. File uploads are limited to 500MB to prevent abuse. Presigned URLs expire automatically to limit the window of access.

## Logging

The backend includes comprehensive logging for debugging and monitoring. All operations log their status and any errors that occur. Logs include timestamps and operation context to aid in troubleshooting.

## Future Enhancements

Potential improvements for future versions include implementing payment processing integration for paid content, adding user purchase history tracking, implementing content search and filtering, adding bulk upload capabilities, and implementing content versioning and rollback functionality.
