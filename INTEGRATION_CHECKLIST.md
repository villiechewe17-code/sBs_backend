# Flutter App & Backend Integration Checklist

## Backend Setup

### Environment Configuration
- [ ] Set `DATABASE_URL` with your Supabase connection string
- [ ] Set `R2_ACCOUNT_ID` with your Cloudflare account ID
- [ ] Set `R2_ACCESS_KEY_ID` with your R2 API key
- [ ] Set `R2_SECRET_ACCESS_KEY` with your R2 secret
- [ ] Set `R2_BUCKET_NAME` with your R2 bucket name
- [ ] Set `JWT_SECRET` for session signing
- [ ] Set `VITE_APP_ID` with your Manus OAuth app ID
- [ ] Set `OAUTH_SERVER_URL` to `https://api.manus.im`

### Database Setup
- [ ] Run `pnpm drizzle-kit generate` to create migrations
- [ ] Run `pnpm drizzle-kit migrate` to apply migrations
- [ ] Verify tables created: `users`, `categories`, `content`
- [ ] Create initial admin user in database

### Backend Testing
- [ ] Run `pnpm test` to verify all tests pass
- [ ] Test health check endpoint: `curl http://localhost:3000/api/trpc/health.check`
- [ ] Test category listing: `curl http://localhost:3000/api/trpc/categories.list`
- [ ] Test R2 presigned URL generation (with auth token)

### Backend Deployment
- [ ] Create GitHub repository and push code
- [ ] Deploy to Railway/Render/your hosting platform
- [ ] Verify all environment variables are set in production
- [ ] Test health check on production URL
- [ ] Update Flutter app backend URL to production endpoint

## Flutter App Setup

### Dependencies
- [ ] Add `http: ^1.1.0` to pubspec.yaml
- [ ] Add `file_picker: ^5.3.0` to pubspec.yaml
- [ ] Add `flutter_secure_storage: ^9.0.0` to pubspec.yaml (optional, for secure token storage)
- [ ] Run `flutter pub get`

### Integration Files
- [ ] Copy `backend_api_service.dart` to `lib/services/`
- [ ] Copy `updated_admin_panel.dart` to `lib/screens/admin/` (or appropriate location)
- [ ] Update backend URL in `backend_api_service.dart` to match your deployment

### Authentication Integration
- [ ] Initialize `BackendApiService` in your auth provider
- [ ] After OAuth login, call `apiService.setAuthToken(token)`
- [ ] On logout, call `apiService.clearAuthToken()`
- [ ] Store auth token securely using `flutter_secure_storage`
- [ ] Restore auth token on app startup

### User Interface Updates
- [ ] Update category screen to use `apiService.getCategories()`
- [ ] Update content screen to use `apiService.getContentByCategory(categoryId)`
- [ ] Replace admin panel with `UpdatedAdminPanel` component
- [ ] Add loading indicators for all API calls
- [ ] Add error handling with user-friendly messages

### Admin Panel Features
- [ ] File upload with presigned URL generation
- [ ] Direct upload to R2 (no backend server overhead)
- [ ] Create content metadata in Supabase
- [ ] Edit content properties (title, description, access level)
- [ ] Delete content items
- [ ] Add external links without file uploads
- [ ] Create text-based content

### User Features
- [ ] View free content without authentication
- [ ] Download files using presigned URLs
- [ ] View paid content (with access control)
- [ ] Display content metadata (title, description, type)

## Testing

### Backend Testing
- [ ] Unit tests for authentication
- [ ] Unit tests for category endpoints
- [ ] Unit tests for content endpoints
- [ ] Unit tests for R2 integration
- [ ] Integration tests for complete workflows

### Flutter Testing
- [ ] Test category loading
- [ ] Test content loading by category
- [ ] Test file upload workflow
- [ ] Test file download workflow
- [ ] Test error handling (network errors, auth errors)
- [ ] Test loading states and UI feedback

### End-to-End Testing
- [ ] Admin uploads file → file appears in R2 → metadata in Supabase
- [ ] User views content → downloads file → file is accessible
- [ ] Admin creates category → category appears in app
- [ ] Admin updates content → changes appear in app
- [ ] Admin deletes content → content removed from app

## Security

### Backend Security
- [ ] Verify admin-only endpoints require authentication
- [ ] Verify role-based access control (RBAC) is enforced
- [ ] Verify presigned URLs expire after correct time
- [ ] Verify R2 credentials are not exposed in logs
- [ ] Enable HTTPS for all production endpoints
- [ ] Set up rate limiting if needed

### Flutter Security
- [ ] Store auth tokens securely using `flutter_secure_storage`
- [ ] Never hardcode API keys or secrets
- [ ] Use HTTPS for all API calls
- [ ] Validate SSL certificates
- [ ] Clear sensitive data on logout
- [ ] Implement certificate pinning for production

### Database Security
- [ ] Enable Supabase Row-Level Security (RLS) policies
- [ ] Verify only admins can modify categories and content
- [ ] Verify users can only access their own data
- [ ] Enable database backups
- [ ] Test data recovery procedures

## Monitoring & Maintenance

### Logging
- [ ] Backend logs all API calls
- [ ] Backend logs all errors with context
- [ ] Flutter app logs API errors for debugging
- [ ] Set up log aggregation (e.g., Sentry, LogRocket)

### Monitoring
- [ ] Set up health check monitoring
- [ ] Monitor API response times
- [ ] Monitor R2 storage usage
- [ ] Monitor database query performance
- [ ] Set up alerts for critical errors

### Maintenance
- [ ] Regular database backups
- [ ] Regular dependency updates
- [ ] Security patch reviews
- [ ] Performance optimization reviews
- [ ] User feedback collection and analysis

## Documentation

### For Developers
- [ ] API documentation (API_DOCUMENTATION.md)
- [ ] Setup guide (SETUP_GUIDE.md)
- [ ] Flutter integration guide (FLUTTER_INTEGRATION_GUIDE.md)
- [ ] Code examples and samples
- [ ] Architecture diagrams

### For Users
- [ ] User guide for uploading content
- [ ] User guide for downloading content
- [ ] FAQ and troubleshooting
- [ ] Video tutorials (optional)

## Performance Optimization

### Backend Optimization
- [ ] Enable database query caching
- [ ] Implement API response caching
- [ ] Optimize database indexes
- [ ] Use connection pooling
- [ ] Monitor and optimize slow queries

### Flutter Optimization
- [ ] Implement content caching
- [ ] Lazy load content lists
- [ ] Optimize image loading
- [ ] Implement pagination for large lists
- [ ] Profile app performance

### R2 Optimization
- [ ] Enable R2 caching headers
- [ ] Use CDN for file distribution
- [ ] Optimize file compression
- [ ] Monitor R2 performance metrics

## Future Enhancements

### Phase 2
- [ ] Payment processing integration
- [ ] User purchase history
- [ ] Content search and filtering
- [ ] Content recommendations
- [ ] User analytics

### Phase 3
- [ ] Bulk upload capabilities
- [ ] Content versioning
- [ ] Collaborative editing
- [ ] Advanced access control
- [ ] API rate limiting

### Phase 4
- [ ] Mobile app optimization
- [ ] Offline content access
- [ ] Push notifications
- [ ] User reviews and ratings
- [ ] Content marketplace

## Sign-Off

- [ ] Backend development complete
- [ ] Flutter integration complete
- [ ] All tests passing
- [ ] Documentation complete
- [ ] Security review passed
- [ ] Performance testing passed
- [ ] Ready for production deployment

**Completed by:** ________________  
**Date:** ________________  
**Notes:** ________________________________________________
