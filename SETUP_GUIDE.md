# Content Management Backend - Setup & Deployment Guide

## Prerequisites

Before setting up the backend, ensure you have the following:

- Node.js 18+ installed
- pnpm package manager (or npm/yarn)
- A Supabase account with a project created
- A Cloudflare account with R2 enabled
- Git for version control

## Local Development Setup

### Step 1: Clone and Install Dependencies

```bash
# Clone the project repository
git clone <repository-url>
cd content-management-backend

# Install dependencies
pnpm install
```

### Step 2: Configure Environment Variables

Create a `.env` file in the project root with the following variables:

```env
# Database Configuration
DATABASE_URL=mysql://username:password@host:3306/database_name

# Cloudflare R2 Configuration
R2_ACCOUNT_ID=your-account-id
R2_ACCESS_KEY_ID=your-access-key-id
R2_SECRET_ACCESS_KEY=your-secret-access-key
R2_BUCKET_NAME=your-bucket-name

# Authentication
JWT_SECRET=your-jwt-secret-key

# Manus OAuth Configuration
VITE_APP_ID=your-app-id
OAUTH_SERVER_URL=https://api.manus.im
```

### Step 3: Initialize the Database

The database schema is already defined in `drizzle/schema.ts`. To apply the migrations:

```bash
# Generate migration files if needed
pnpm drizzle-kit generate

# Apply migrations to your database
pnpm drizzle-kit migrate
```

### Step 4: Start Development Server

```bash
# Start the development server with hot reload
pnpm dev
```

The server will start on `http://localhost:3000`. You can test the health check endpoint:

```bash
curl http://localhost:3000/api/trpc/health.check
```

## Supabase Setup

### Creating a Supabase Project

1. Go to [https://supabase.com](https://supabase.com) and sign in
2. Click "New Project" and select your organization
3. Enter a project name and database password
4. Select your region (choose one close to your users)
5. Click "Create new project" and wait for it to initialize

### Getting Your Credentials

Once your project is created:

1. Go to Project Settings → Database
2. Copy the connection string (it will look like: `postgresql://user:password@host:5432/postgres`)
3. For MySQL compatibility, you may need to use a different connection method

### Creating the Database Tables

The database schema is defined in `drizzle/schema.ts`. To apply it:

1. Run `pnpm drizzle-kit generate` to create migration files
2. Run `pnpm drizzle-kit migrate` to apply migrations to your Supabase database

### Setting Up Row-Level Security (Optional)

For production, consider enabling Row-Level Security (RLS) policies in Supabase to control data access at the database level. This adds an extra layer of security beyond application-level access control.

## Cloudflare R2 Setup

### Creating an R2 Bucket

1. Log in to your Cloudflare dashboard
2. Navigate to R2 → Buckets
3. Click "Create bucket"
4. Enter a bucket name (must be globally unique)
5. Choose your region
6. Click "Create bucket"

### Generating API Credentials

1. In the Cloudflare dashboard, go to R2 → API Tokens
2. Click "Create API token"
3. Name the token (e.g., "Content Management Backend")
4. Select "Object Read & Write" permissions
5. Choose the bucket you created
6. Set an expiration date (or leave as no expiration)
7. Click "Create API Token"
8. Copy the credentials (Account ID, Access Key ID, Secret Access Key)

### Configuring CORS (Optional)

If you need to allow direct uploads from client applications:

1. In R2, select your bucket
2. Go to Settings → CORS Rules
3. Add a CORS rule allowing your domain:

```json
{
  "AllowedOrigins": ["https://yourdomain.com"],
  "AllowedMethods": ["GET", "PUT", "POST"],
  "AllowedHeaders": ["*"]
}
```

## Testing the Setup

### Run Unit Tests

```bash
# Run all tests
pnpm test

# Run tests in watch mode
pnpm test --watch
```

### Manual API Testing

Test the health check endpoint:

```bash
curl http://localhost:3000/api/trpc/health.check
```

Test category listing (public endpoint):

```bash
curl http://localhost:3000/api/trpc/categories.list
```

To test protected endpoints, you'll need to obtain an authentication token from the Manus OAuth system and include it in the Authorization header.

## Deployment to Railway

Railway is the recommended platform for deploying this backend due to its simplicity and built-in support for Node.js applications.

### Step 1: Prepare Your Repository

Ensure your code is pushed to GitHub:

```bash
git add .
git commit -m "Initial commit"
git push origin main
```

Make sure your `.env` file is in `.gitignore` (it should be by default).

### Step 2: Create Railway Project

1. Go to [https://railway.app](https://railway.app)
2. Sign in with GitHub
3. Click "New Project"
4. Select "Deploy from GitHub repo"
5. Authorize Railway to access your GitHub account
6. Select the repository containing your backend code
7. Click "Deploy"

### Step 3: Configure Environment Variables

1. In Railway, go to your project
2. Click on the service
3. Go to Variables
4. Add all environment variables from your `.env` file:
   - DATABASE_URL
   - R2_ACCOUNT_ID
   - R2_ACCESS_KEY_ID
   - R2_SECRET_ACCESS_KEY
   - R2_BUCKET_NAME
   - JWT_SECRET
   - VITE_APP_ID
   - OAUTH_SERVER_URL

### Step 4: Configure Build & Deploy Settings

1. Go to Settings → Build
2. Ensure the build command is: `pnpm build`
3. Ensure the start command is: `pnpm start`
4. Click "Deploy"

### Step 5: Monitor Deployment

1. Go to Deployments to watch the build progress
2. Once deployed, you'll get a public URL (e.g., `https://your-app.railway.app`)
3. Test the health check: `https://your-app.railway.app/api/trpc/health.check`

## Deployment to Other Platforms

### Render

1. Go to [https://render.com](https://render.com)
2. Click "New +" and select "Web Service"
3. Connect your GitHub repository
4. Configure environment variables
5. Set build command: `pnpm build`
6. Set start command: `pnpm start`
7. Click "Create Web Service"

### Heroku

1. Install Heroku CLI
2. Run `heroku login`
3. Run `heroku create your-app-name`
4. Set environment variables: `heroku config:set VAR_NAME=value`
5. Push to Heroku: `git push heroku main`

### AWS/EC2

1. Launch an EC2 instance with Node.js pre-installed
2. Clone your repository
3. Install dependencies: `pnpm install`
4. Set environment variables
5. Start the server: `pnpm start`
6. Configure a reverse proxy (nginx) and SSL certificate

## Production Checklist

Before deploying to production, verify the following:

- [ ] All environment variables are configured
- [ ] Database migrations have been applied
- [ ] R2 bucket is created and credentials are valid
- [ ] SSL/TLS certificate is configured
- [ ] CORS settings are appropriate for your domain
- [ ] Logging is configured for monitoring
- [ ] Backup strategy is in place for the database
- [ ] Rate limiting is configured if needed
- [ ] All tests pass locally
- [ ] Code has been reviewed

## Monitoring & Maintenance

### Health Checks

Set up monitoring to periodically check the health endpoint:

```bash
curl -f https://your-domain.com/api/trpc/health.check || alert
```

### Log Monitoring

Monitor application logs for errors and warnings. Most hosting platforms provide log viewing tools.

### Database Maintenance

Regularly back up your database. Supabase provides automatic backups, but consider additional backup strategies for critical data.

### Dependency Updates

Periodically update dependencies to get security patches:

```bash
pnpm update
pnpm audit
```

## Troubleshooting

### Database Connection Issues

If you see "Database not available" errors:

1. Verify DATABASE_URL is correct
2. Check that your database is running and accessible
3. Ensure firewall rules allow connections from your server

### R2 Upload Failures

If presigned URL generation fails:

1. Verify R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, and R2_SECRET_ACCESS_KEY are correct
2. Check that R2_BUCKET_NAME exists
3. Verify API token has Object Read & Write permissions

### Authentication Errors

If you see "Unauthorized" errors:

1. Verify JWT_SECRET is configured
2. Check that authentication tokens are being passed correctly
3. Ensure VITE_APP_ID and OAUTH_SERVER_URL are correct

## Support & Resources

- [tRPC Documentation](https://trpc.io)
- [Supabase Documentation](https://supabase.com/docs)
- [Cloudflare R2 Documentation](https://developers.cloudflare.com/r2)
- [Railway Documentation](https://docs.railway.app)
- [Node.js Documentation](https://nodejs.org/docs)
