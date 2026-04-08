# Backend Status Documentation

## Overview

The Colony app currently uses **Direct Supabase Integration** for all backend operations. The Express.js backend at `backend/index.js` is **NOT USED** by the Flutter frontend.

---

## Current Architecture

### Frontend → Supabase (Direct)

The Flutter frontend communicates directly with Supabase using the `supabase_flutter` package:

| Feature | Implementation |
|---------|---------------|
| Authentication | `supabase.auth.signUp()`, `supabase.auth.signInWithPassword()` |
| User Profiles | `supabase.from('profiles').select()` |
| Nearby Users | `supabase.rpc('get_nearby_users')` |
| Nearby Groups | `supabase.rpc('get_nearby_groups')` |
| Stories | `supabase.from('stories').select()` |
| Waves | `supabase.from('waves').insert()` |
| Conversations | `supabase.from('conversations').select()` |
| Messages | `supabase.from('messages').insert()` |
| Group Chat | `supabase.from('group_messages').select()` |
| Real-time Updates | `supabase.channel().onPostgresChanges()` |

### Backend (Express.js) - UNUSED

The backend at `backend/index.js` implements the following endpoints but they are **NOT CALLED** by the frontend:

| Category | Endpoints | Status |
|----------|-----------|--------|
| Authentication | `/auth/signup`, `/auth/login`, `/auth/logout`, `/auth/user` | ❌ Unused |
| Profile | `/profile/:userId`, `PATCH /profile` | ❌ Unused |
| Groups | `POST /groups`, `GET /groups`, `POST /groups/:groupId/join` | ❌ Unused |
| Conversations | `GET /conversations`, `POST /conversations` | ❌ Unused |
| Messages | `GET /conversations/:id/messages`, `POST /conversations/:id/messages` | ❌ Unused |
| User Keys | `GET /user-keys/:userId`, `POST /user-keys` | ❌ Unused |

---

## Why This Architecture?

### Advantages of Direct Supabase Integration

1. **Simpler Architecture**: No need to maintain a separate backend server
2. **Real-time Features**: Built-in real-time subscriptions via Supabase channels
3. **Row Level Security (RLS)**: Database-level security policies
4. **Reduced Latency**: Direct database access without API layer overhead
5. **Lower Infrastructure Costs**: No need to host and maintain a backend server

### When the Backend Might Be Useful

1. **Web Client**: If you build a web version that can't use Supabase SDK directly
2. **Complex Business Logic**: Server-side operations that shouldn't be exposed to clients
3. **Third-party Integrations**: Webhooks, payment processing, etc.
4. **Admin Panel**: Separate admin interface with different permissions
5. **API for Partners**: Public API for third-party developers

---

## Recommendations

### Option 1: Remove the Backend (Recommended for Current Use Case)

If you only plan to use the Flutter app:

1. **Delete the backend directory**:
   ```bash
   rm -rf backend/
   ```

2. **Remove backend documentation**:
   - `docs/API_DOCUMENTATION.md` (or update to reflect Supabase usage)
   - `docs/NOT_IMPLEMENTED_API.md`

3. **Update README** to reflect the direct Supabase architecture

### Option 2: Keep the Backend for Future Use

If you might need the backend later:

1. **Keep the backend code** but add a disclaimer in `backend/README.md`:
   ```markdown
   # Backend (Currently Unused)

   This Express.js backend is currently not used by the Flutter frontend.
   The frontend communicates directly with Supabase using the Supabase Flutter SDK.

   This backend is kept for potential future use cases:
   - Web client implementation
   - Complex server-side business logic
   - Third-party integrations
   - Admin panel
   - Public API for partners
   ```

2. **Document the endpoints** as "Available but not currently used"

### Option 3: Integrate the Backend

If you want to use the backend:

1. **Update the frontend** to call backend endpoints instead of direct Supabase queries
2. **Implement all missing endpoints** listed in `docs/NOT_IMPLEMENTED_API.md`
3. **Add authentication middleware** to validate Supabase JWT tokens
4. **Update the architecture documentation**

---

## Migration Path (If Choosing Option 3)

### Step 1: Backend Authentication

Add middleware to validate Supabase JWT tokens:

```javascript
const { verifyJwt } = require('./middleware/auth');

app.use('/api/*', verifyJwt);
```

### Step 2: Frontend HTTP Client

Create an HTTP client service:

```dart
class ApiService {
  static final _client = http.Client();
  static const _baseUrl = 'http://localhost:3000/api';

  static Future<List<NearbyUser>> getNearbyUsers(double lat, double lon) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/users/nearby?latitude=$lat&longitude=$lon'),
      headers: {'Authorization': 'Bearer ${SupabaseService().client.auth.currentSession?.accessToken}'},
    );
    // ... parse response
  }
}
```

### Step 3: Gradual Migration

1. Start with one feature (e.g., nearby users)
2. Test thoroughly
3. Migrate other features one by one
4. Remove direct Supabase calls after successful migration

---

## Current Database Schema

The database schema is defined in Supabase migrations:

| Migration File | Description |
|----------------|-------------|
| `backend/supabase/migrations/COMPLETE_MIGRATION.sql` | Main schema with 13 tables |
| `backend/supabase/migrations/FCM_TOKENS.sql` | FCM token management |
| `backend/supabase/migrations/MESSAGE_STATUS.sql` | Message delivery/read status |
| `backend/supabase/migrations/NEARBY_5KM_AND_WAVES.sql` | Nearby users and wave system |
| `backend/supabase/migrations/GROUP_MESSAGES_REALTIME.sql` | Group chat real-time |

### Key Tables

| Table | Purpose |
|-------|---------|
| `profiles` | User profiles with location |
| `stories` | User stories (24hr expiry) |
| `story_views` | Track story views |
| `groups` | User-created groups |
| `group_members` | Group membership |
| `waves` | Mutual wave system for chat enablement |
| `conversations` | Chat conversations |
| `messages` | Chat messages |
| `group_messages` | Group chat messages |
| `user_keys` | E2E encryption public keys |
| `user_fcm_tokens` | Push notification tokens |

---

## Security Considerations

### Current (Direct Supabase)

- ✅ Row Level Security (RLS) policies protect data
- ✅ Supabase Auth handles user authentication
- ✅ Anon key has limited permissions via RLS
- ⚠️ Service role key is only in backend (not exposed to frontend)

### With Backend

- ✅ Additional layer of security
- ✅ Can implement complex business logic server-side
- ✅ Can rate limit requests
- ✅ Can audit all API calls
- ❌ Additional infrastructure to maintain
- ❌ Potential for security vulnerabilities in backend code

---

## Conclusion

**Current Status**: The backend is unused and can be safely removed if you only plan to use the Flutter app.

**Recommendation**: Keep the backend code for now but document it as "unused but available for future use". This gives you flexibility if you later decide to:
- Build a web client
- Add server-side business logic
- Create an admin panel
- Provide a public API for partners

---

*Last updated: April 2025*
