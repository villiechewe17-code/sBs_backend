# Content Management Backend - Quick Start Guide

## 5-Minute Setup

### 1. Install Dependencies
```bash
pnpm install
```

### 2. Configure Environment
Create `.env` file with your credentials:
```env
DATABASE_URL=mysql://user:pass@host:3306/db
R2_ACCOUNT_ID=your-account-id
R2_ACCESS_KEY_ID=your-access-key
R2_SECRET_ACCESS_KEY=your-secret-key
R2_BUCKET_NAME=your-bucket
JWT_SECRET=your-secret
VITE_APP_ID=your-app-id
OAUTH_SERVER_URL=https://api.manus.im
```

### 3. Apply Database Migrations
```bash
pnpm drizzle-kit generate
pnpm drizzle-kit migrate
```

### 4. Start Development Server
```bash
pnpm dev
```

Server runs on `http://localhost:3000`

## API Quick Reference

### Public Endpoints (No Auth Required)

**List Categories**
```bash
curl http://localhost:3000/api/trpc/categories.list
```

**Get Content by Category**
```bash
curl http://localhost:3000/api/trpc/content.byCategory?input=%7B%22categoryId%22:1%7D
```

**Get Single Content**
```bash
curl http://localhost:3000/api/trpc/content.getById?input=%7B%22id%22:1%7D
```

**Health Check**
```bash
curl http://localhost:3000/api/trpc/health.check
```

### Admin Endpoints (Auth + Admin Role Required)

**Create Category**
```bash
curl -X POST http://localhost:3000/api/trpc/categories.create \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Education","icon":"book"}'
```

**Create Content**
```bash
curl -X POST http://localhost:3000/api/trpc/content.create \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "categoryId":1,
    "title":"Course",
    "contentType":"folder",
    "r2FileKey":"uploads/course.zip"
  }'
```

**Get Upload URL**
```bash
curl -X POST http://localhost:3000/api/trpc/r2.getUploadUrl \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "fileName":"course.zip",
    "contentType":"application/zip",
    "fileSize":10485760
  }'
```

### File Download

**Get Download URL**
```bash
curl -X POST http://localhost:3000/api/trpc/r2.getDownloadUrl \
  -H "Content-Type: application/json" \
  -d '{"fileKey":"uploads/course.zip"}'
```

## Project Structure

```
server/
  routers.ts          ← All API endpoints (tRPC procedures)
  db.ts               ← Database query helpers
  auth.logout.test.ts ← Authentication tests
  health.test.ts      ← Health check tests
  _core/              ← Framework internals (don't edit)

drizzle/
  schema.ts           ← Database schema definitions
  migrations/         ← Generated SQL migrations

client/
  src/                ← Frontend code (React)

package.json          ← Dependencies and scripts
```

## Common Tasks

### Add New Endpoint

1. Add procedure to `server/routers.ts`:
```typescript
newFeature: router({
  getData: publicProcedure.query(async () => {
    // Your logic here
    return data;
  }),
})
```

2. Call from client:
```typescript
const { data } = trpc.newFeature.getData.useQuery();
```

### Add Database Table

1. Add to `drizzle/schema.ts`:
```typescript
export const myTable = mysqlTable("my_table", {
  id: int("id").autoincrement().primaryKey(),
  name: varchar("name", { length: 255 }).notNull(),
});
```

2. Generate and apply migration:
```bash
pnpm drizzle-kit generate
pnpm drizzle-kit migrate
```

### Add Query Helper

1. Add function to `server/db.ts`:
```typescript
export async function getMyData() {
  const db = await getDb();
  return db.select().from(myTable);
}
```

2. Use in routers:
```typescript
const data = await getMyData();
```

### Run Tests

```bash
pnpm test              # Run all tests
pnpm test --watch      # Watch mode
```

## Environment Variables Reference

| Variable | Purpose | Example |
|----------|---------|---------|
| DATABASE_URL | MySQL connection | mysql://user:pass@host/db |
| R2_ACCOUNT_ID | Cloudflare account | abc123def456 |
| R2_ACCESS_KEY_ID | R2 API key | AKIAIOSFODNN7EXAMPLE |
| R2_SECRET_ACCESS_KEY | R2 API secret | wJalrXUtnFEMI/K7MDENG/bPx... |
| R2_BUCKET_NAME | R2 bucket name | my-content-bucket |
| JWT_SECRET | Session signing key | your-secret-key |
| VITE_APP_ID | OAuth app ID | app_123456 |
| OAUTH_SERVER_URL | OAuth server | https://api.manus.im |

## Deployment

### Railway (Recommended)
1. Push code to GitHub
2. Connect repository to Railway
3. Set environment variables
4. Deploy

### Render
1. Connect GitHub repository
2. Set build: `pnpm build`
3. Set start: `pnpm start`
4. Add environment variables
5. Deploy

### Local VPS
```bash
git clone <repo>
cd content-management-backend
pnpm install
pnpm build
NODE_ENV=production pnpm start
```

## Debugging

### View Logs
```bash
# Development
pnpm dev

# Production (Railway/Render)
# Check platform's log viewer
```

### Test Database Connection
```bash
# Check if database is accessible
mysql -u user -p -h host -D database
```

### Test R2 Connection
```bash
# Verify credentials by attempting upload
curl -X PUT "https://account-id.r2.cloudflarestorage.com/test-file" \
  -H "Authorization: Bearer token"
```

## Common Errors & Solutions

| Error | Solution |
|-------|----------|
| Database not available | Check DATABASE_URL and database is running |
| R2 presigned URL fails | Verify R2 credentials and bucket exists |
| Unauthorized error | Check JWT token is valid and passed correctly |
| CORS error | Verify CORS is configured for your domain |
| File upload fails | Check file size < 500MB and R2 has space |

## Next Steps

1. **Read Full Documentation**: See `API_DOCUMENTATION.md` for complete endpoint reference
2. **Setup Guide**: See `SETUP_GUIDE.md` for detailed setup instructions
3. **Add Authentication**: Integrate with Manus OAuth for user login
4. **Add Payment**: Integrate payment gateway for paid content
5. **Add Search**: Implement content search and filtering
6. **Add Analytics**: Track user engagement and downloads

## Support

For issues or questions:
1. Check the troubleshooting section in `SETUP_GUIDE.md`
2. Review test files for usage examples
3. Check tRPC documentation at https://trpc.io
4. Review Supabase docs at https://supabase.com/docs
5. Check Cloudflare R2 docs at https://developers.cloudflare.com/r2
