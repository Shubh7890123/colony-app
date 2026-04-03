# Backend Setup with Supabase

This backend is configured to use Supabase for the following services:
- **Auth** (Login/Signup)
- **PostgreSQL + PostGIS** (Location data)
- **Realtime** (Chat)
- **Storage** (Images)

## Configuration

### Environment Variables
Copy `.env.example` to `.env` and fill in your Supabase credentials:

```bash
cp .env.example .env
```

The `.env` file should contain:
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Your Supabase anonymous key
- `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service role key (keep secret)
- `SUPABASE_JWT_SECRET`: Your JWT secret from Supabase
- `REDIS_URL`: Redis connection URL (for caching/sessions)
- `PORT`: Server port (default: 3000)

### Supabase Setup
1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Get your project URL and keys from Settings > API
3. Enable the required services:
   - Authentication
   - Database (PostgreSQL with PostGIS extension)
   - Realtime
   - Storage

## Installation

```bash
cd backend
npm install
```

## Running the Server

Development (with auto-restart):
```bash
npm run dev
```

Production:
```bash
npm start
```

## API Endpoints

- `GET /` - API information
- `GET /health` - Health check
- `GET /test-supabase` - Test Supabase connection

## Project Structure

```
backend/
├── index.js              # Main server entry point
├── package.json          # Dependencies
├── .env                  # Environment variables (gitignored)
├── .env.example          # Example environment variables
├── README.md             # This file
└── src/                  # Source code
    ├── config/           # Configuration files
    ├── services/         # Business logic
    ├── routes/           # API routes
    └── utils/            # Utility functions
```

## Next Steps

1. **Create database schema** - After frontend screens are ready, create tables in Supabase
2. **Implement authentication routes** - Add login/signup endpoints
3. **Add realtime functionality** - Set up chat/notification channels
4. **Implement file upload** - Add storage endpoints for images
5. **Add location services** - Use PostGIS for geospatial queries

## Security Notes

- Never commit `.env` file to version control
- Use environment variables for all secrets
- The service role key should only be used server-side
- Implement proper authentication and authorization