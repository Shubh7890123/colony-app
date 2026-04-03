# Colony App - Complete API Documentation

## Base URL
- **Backend API**: `http://localhost:3000` (configurable via PORT)
- **Supabase REST API**: `https://<project-ref>.supabase.co/rest/v1/`
- **Supabase Auth API**: `https://<project-ref>.supabase.co/auth/v1/`

---

# Table of Contents
1. [Authentication APIs](#1-authentication-apis)
2. [User Profile APIs](#2-user-profile-apis)
3. [Location APIs](#3-location-apis)
4. [Nearby Users APIs](#4-nearby-users-apis)
5. [Nearby Groups APIs](#5-nearby-groups-apis)
6. [Stories APIs](#6-stories-apis)
7. [Wave APIs](#7-wave-apis)
8. [Chat/Conversation APIs](#8-chatconversation-apis)
9. [Messages APIs](#9-messages-apis)
10. [Group Management APIs](#10-group-management-apis)
11. [Group Members APIs](#11-group-members-apis)
12. [Database Functions](#12-database-functions)

---

# 1. Authentication APIs

## 1.1 Sign Up
Create a new user account.

**Endpoint**: `POST /auth/signup`

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "password123",
  "displayName": "John Doe"
}
```

**Response** (201 Created):
```json
{
  "success": true,
  "message": "Account created successfully! Please check your email for verification.",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "displayName": "John Doe"
  }
}
```

**Error Response** (400 Bad Request):
```json
{
  "success": false,
  "message": "Email and password are required"
}
```

---

## 1.2 Login
Authenticate user and get session tokens.

**Endpoint**: `POST /auth/login`

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "message": "Login successful",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "displayName": "John Doe",
    "avatarUrl": "https://..."
  },
  "session": {
    "accessToken": "eyJhbGciOi...",
    "refreshToken": "v2...",
    "expiresAt": 1234567890
  }
}
```

---

## 1.3 Logout
Sign out the current user.

**Endpoint**: `POST /auth/logout`

**Headers**:
```
Authorization: Bearer <access_token>
```

**Response** (200 OK):
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

## 1.4 Get Current User
Get the authenticated user's details.

**Endpoint**: `GET /auth/user`

**Headers**:
```
Authorization: Bearer <access_token>
```

**Response** (200 OK):
```json
{
  "success": true,
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "displayName": "John Doe",
    "avatarUrl": "https://..."
  }
}
```

---

## 1.5 Reset Password
Request a password reset email.

**Endpoint**: `POST /auth/reset-password`

**Request Body**:
```json
{
  "email": "user@example.com"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "message": "Password reset email sent successfully"
}
```

---

## 1.6 Update Profile
Update user's display name and avatar.

**Endpoint**: `PATCH /auth/profile`

**Headers**:
```
Authorization: Bearer <access_token>
```

**Request Body**:
```json
{
  "displayName": "New Name",
  "avatarUrl": "https://..."
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "message": "Profile updated successfully",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "displayName": "New Name",
    "avatarUrl": "https://..."
  }
}
```

---

# 2. User Profile APIs

## 2.1 Get User Profile
Fetch a user's profile by ID.

**Method**: Direct Supabase Query

**Table**: `profiles`

**Query**:
```dart
await supabase
  .from('profiles')
  .select('*')
  .eq('id', userId)
  .single();
```

**Response Model** (`UserProfile`):
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "username": "johndoe",
  "full_name": "John Doe",
  "display_name": "John",
  "avatar_url": "https://...",
  "bio": "Hello world!",
  "location_text": "Vasant Colony, Patna",
  "latitude": 25.5941,
  "longitude": 85.1376
}
```

---

## 2.2 Update Profile
Update current user's profile.

**Method**: Direct Supabase Query

**Table**: `profiles`

**Query**:
```dart
await supabase
  .from('profiles')
  .update({
    'display_name': 'New Name',
    'bio': 'New bio',
    'avatar_url': 'https://...'
  })
  .eq('id', userId);
```

---

## 2.3 Update User Location
Update user's current location.

**Method**: Direct Supabase Query

**Table**: `profiles`

**Query**:
```dart
await supabase
  .from('profiles')
  .update({
    'latitude': 25.5941,
    'longitude': 85.1376,
    'location_text': 'Vasant Colony, Rukunpura, Patna'
  })
  .eq('id', userId);
```

---

# 3. Location APIs

## 3.1 Get Current Location (Device)
Uses device GPS to get current coordinates.

**Method**: Flutter Geolocator Package

**Service**: `LocationService.getCurrentPosition()`

**Returns**:
```dart
LocationResult {
  latitude: 25.5941,
  longitude: 85.1376,
  locationText: "Vasant Colony, Rukunpura, Patna",
  error: null
}
```

---

## 3.2 Get Address from Coordinates
Reverse geocoding to get address from lat/long.

**Method**: Flutter Geocoding Package

**Service**: `LocationService.getAddressFromCoordinates(lat, long)`

**Returns**:
```dart
UserLocation {
  address: "Vasant Colony, Rukunpura, Patna, Bihar 800001",
  latitude: 25.5941,
  longitude: 85.1376,
  locality: "Rukunpura",
  subLocality: "Vasant Colony",
  adminArea: "Bihar",
  country: "India"
}
```

---

# 4. Nearby Users APIs

## 4.1 Get Nearby Users
Get users within a specified radius (default 5km).

**Method**: Supabase RPC Function

**Function**: `get_nearby_users`

**Parameters**:
```json
{
  "user_lat": 25.5941,
  "user_lon": 85.1376,
  "radius_km": 5.0
}
```

**Query**:
```dart
await supabase.rpc('get_nearby_users', params: {
  'user_lat': latitude,
  'user_lon': longitude,
  'radius_km': radiusKm,
});
```

**Response Model** (`List<NearbyUser>`):
```json
[
  {
    "id": "uuid",
    "email": "user1@example.com",
    "username": "user1",
    "full_name": "User One",
    "display_name": "User1",
    "avatar_url": "https://...",
    "bio": "Hello!",
    "location_text": "Rukunpura, Patna",
    "distance": 1.5
  }
]
```

---

# 5. Nearby Groups APIs

## 5.1 Get Nearby Groups
Get groups within a specified radius (default 5km).

**Method**: Supabase RPC Function

**Function**: `get_nearby_groups`

**Parameters**:
```json
{
  "user_lat": 25.5941,
  "user_lon": 85.1376,
  "radius_km": 5.0
}
```

**Query**:
```dart
await supabase.rpc('get_nearby_groups', params: {
  'user_lat': latitude,
  'user_lon': longitude,
  'radius_km': radiusKm,
});
```

**Response Model** (`List<NearbyGroup>`):
```json
[
  {
    "id": "uuid",
    "name": "Patna Developers",
    "description": "Local coding community",
    "category": "technology",
    "cover_image_url": "https://...",
    "location_text": "Patna",
    "latitude": 25.5941,
    "longitude": 85.1376,
    "is_private": false,
    "member_count": 25,
    "distance": 2.3,
    "is_member": true
  }
]
```

---

# 6. Stories APIs

## 6.1 Get Active Stories
Get all active stories (not expired).

**Method**: Direct Supabase Query

**Table**: `stories`

**Query**:
```dart
await supabase
  .from('stories')
  .select('''
    id, media_url, media_type, caption, created_at, expires_at, user_id,
    profiles!stories_user_id_fkey ( id, username, display_name, avatar_url )
  ''')
  .gt('expires_at', DateTime.now().toUtc().toIso8601String())
  .order('created_at', ascending: false);
```

**Response Model** (`List<Story>`):
```json
[
  {
    "id": "uuid",
    "media_url": "https://...",
    "media_type": "image",
    "caption": "Good morning!",
    "created_at": "2024-01-01T10:00:00Z",
    "expires_at": "2024-01-02T10:00:00Z",
    "user_id": "uuid",
    "user": {
      "id": "uuid",
      "username": "john",
      "display_name": "John",
      "avatar_url": "https://..."
    }
  }
]
```

---

## 6.2 Create Story
Create a new story (expires in 24 hours).

**Method**: Direct Supabase Insert

**Table**: `stories`

**Query**:
```dart
await supabase.from('stories').insert({
  'user_id': userId,
  'media_url': 'https://...',
  'media_type': 'image', // or 'video'
  'caption': 'My story caption',
});
```

---

## 6.3 Delete Story
Delete a story.

**Method**: Direct Supabase Delete

**Table**: `stories`

**Query**:
```dart
await supabase
  .from('stories')
  .delete()
  .eq('id', storyId);
```

---

# 7. Wave APIs

## 7.1 Send Wave
Send a wave to another user (like a friend request).

**Method**: Direct Supabase Insert

**Table**: `waves`

**Query**:
```dart
await supabase.from('waves').insert({
  'sender_id': currentUserId,
  'receiver_id': targetUserId,
});
```

---

## 7.2 Respond to Wave
Accept or reject a received wave.

**Method**: Direct Supabase Update

**Table**: `waves`

**Query**:
```dart
await supabase
  .from('waves')
  .update({
    'status': 'accepted', // or 'rejected'
    'responded_at': DateTime.now().toUtc().toIso8601String(),
  })
  .eq('id', waveId);
```

---

## 7.3 Get Pending Waves
Get all pending waves received by current user.

**Method**: Direct Supabase Query

**Table**: `waves`

**Query**:
```dart
await supabase
  .from('waves')
  .select('''
    id, status, created_at, sender_id,
    profiles!waves_sender_id_fkey ( id, username, display_name, avatar_url, bio )
  ''')
  .eq('receiver_id', userId)
  .eq('status', 'pending')
  .order('created_at', ascending: false);
```

**Response Model** (`List<Wave>`):
```json
[
  {
    "id": "uuid",
    "status": "pending",
    "created_at": "2024-01-01T10:00:00Z",
    "sender_id": "uuid",
    "sender": {
      "id": "uuid",
      "username": "jane",
      "display_name": "Jane",
      "avatar_url": "https://...",
      "bio": "Hello!"
    }
  }
]
```

---

## 7.4 Check Can Chat
Check if mutual wave exists (both users accepted).

**Method**: Supabase RPC Function

**Function**: `can_chat_with`

**Parameters**:
```json
{
  "target_user_id": "uuid"
}
```

**Query**:
```dart
await supabase.rpc('can_chat_with', params: {
  'target_user_id': otherUserId,
});
```

**Response**: `true` or `false`

---

# 8. Chat/Conversation APIs

## 8.1 Get Conversations
Get all conversations for current user.

**Method**: Direct Supabase Query

**Table**: `conversations`

**Query**:
```dart
await supabase
  .from('conversations')
  .select('''
    id, last_message_at, user1_id, user2_id,
    messages ( content, created_at, sender_id, is_read )
  ''')
  .or('user1_id.eq.$userId,user2_id.eq.$userId')
  .order('last_message_at', ascending: false);
```

**Response Model** (`List<Conversation>`):
```json
[
  {
    "id": "uuid",
    "last_message_at": "2024-01-01T10:00:00Z",
    "user1_id": "uuid",
    "user2_id": "uuid",
    "otherUser": {
      "id": "uuid",
      "username": "jane",
      "display_name": "Jane",
      "avatar_url": "https://..."
    },
    "lastMessage": {
      "content": "Hello!",
      "created_at": "2024-01-01T10:00:00Z"
    },
    "unreadCount": 2
  }
]
```

---

## 8.2 Get or Create Conversation
Get existing conversation or create new one.

**Method**: Direct Supabase Query

**Logic**:
1. Check if `can_chat_with(targetUserId)` returns `true`
2. Check for existing conversation
3. If not exists, create new conversation

**Query**:
```dart
// Check existing
await supabase
  .from('conversations')
  .select()
  .or('and(user1_id.eq.$userId,user2_id.eq.$otherUserId),and(user1_id.eq.$otherUserId,user2_id.eq.$userId)')
  .maybeSingle();

// Create new
await supabase
  .from('conversations')
  .insert({
    'user1_id': userId,
    'user2_id': otherUserId,
  })
  .select()
  .single();
```

---

# 9. Messages APIs

## 9.1 Get Messages
Get all messages in a conversation.

**Method**: Direct Supabase Query

**Table**: `messages`

**Query**:
```dart
await supabase
  .from('messages')
  .select('id, content, media_url, media_type, is_read, created_at, sender_id')
  .eq('conversation_id', conversationId)
  .order('created_at', ascending: true);
```

**Response Model** (`List<Message>`):
```json
[
  {
    "id": "uuid",
    "content": "Hello!",
    "media_url": null,
    "media_type": null,
    "is_read": false,
    "created_at": "2024-01-01T10:00:00Z",
    "sender_id": "uuid"
  }
]
```

---

## 9.2 Send Message
Send a new message in a conversation.

**Method**: Direct Supabase Insert

**Table**: `messages`

**Query**:
```dart
await supabase
  .from('messages')
  .insert({
    'conversation_id': conversationId,
    'sender_id': userId,
    'content': 'Hello!',
    'media_url': 'https://...', // optional
    'media_type': 'image', // optional: 'image', 'video', 'audio'
  })
  .select()
  .single();
```

---

# 10. Group Management APIs

## 10.1 Create Group
Create a new group.

**Method**: Direct Supabase Insert

**Table**: `groups`

**Query**:
```dart
// Create group
final groupResponse = await supabase
  .from('groups')
  .insert({
    'name': 'Group Name',
    'description': 'Description',
    'category': 'technology',
    'latitude': 25.5941,
    'longitude': 85.1376,
    'cover_image_url': 'https://...',
    'is_private': false,
    'created_by': userId,
  })
  .select()
  .single();

// Add creator as admin
await supabase.from('group_members').insert({
  'group_id': groupResponse['id'],
  'user_id': userId,
  'role': 'admin',
});
```

---

## 10.2 Update Group Cover
Update group cover image.

**Method**: Direct Supabase Update

**Table**: `groups`

**Query**:
```dart
await supabase
  .from('groups')
  .update({
    'cover_image_url': 'https://...',
  })
  .eq('id', groupId);
```

---

# 11. Group Members APIs

## 11.1 Join Group
Join a group as a member.

**Method**: Direct Supabase Insert

**Table**: `group_members`

**Query**:
```dart
await supabase.from('group_members').insert({
  'group_id': groupId,
  'user_id': userId,
});
```

---

## 11.2 Leave Group
Leave a group.

**Method**: Direct Supabase Delete

**Table**: `group_members`

**Query**:
```dart
await supabase
  .from('group_members')
  .delete()
  .eq('group_id', groupId)
  .eq('user_id', userId);
```

---

## 11.3 Get Group Members
Get all members of a group.

**Method**: Direct Supabase Query

**Table**: `group_members`

**Query**:
```dart
await supabase
  .from('group_members')
  .select('''
    id, role, joined_at,
    profiles ( id, username, display_name, avatar_url )
  ''')
  .eq('group_id', groupId)
  .order('joined_at', ascending: true);
```

**Response Model** (`List<GroupMember>`):
```json
[
  {
    "id": "uuid",
    "role": "admin",
    "joined_at": "2024-01-01T10:00:00Z",
    "user": {
      "id": "uuid",
      "username": "john",
      "display_name": "John",
      "avatar_url": "https://..."
    }
  }
]
```

---

# 12. Database Functions

## 12.1 calculate_distance
Calculate distance between two coordinates using Haversine formula.

**Function**: `calculate_distance(lat1, lon1, lat2, lon2)`

**Returns**: Distance in kilometers (double)

**SQL**:
```sql
SELECT calculate_distance(25.5941, 85.1376, 25.5945, 85.1380);
-- Returns: 0.05 (km)
```

---

## 12.2 get_nearby_users
Get users within radius from given coordinates.

**Function**: `get_nearby_users(user_lat, user_lon, radius_km)`

**Returns**: Table of nearby users with distance

**SQL**:
```sql
SELECT * FROM get_nearby_users(25.5941, 85.1376, 5.0);
```

---

## 12.3 get_nearby_groups
Get groups within radius from given coordinates.

**Function**: `get_nearby_groups(user_lat, user_lon, radius_km)`

**Returns**: Table of nearby groups with member count and distance

**SQL**:
```sql
SELECT * FROM get_nearby_groups(25.5941, 85.1376, 5.0);
```

---

## 12.4 can_chat_with
Check if two users can chat (mutual accepted wave).

**Function**: `can_chat_with(target_user_id)`

**Returns**: Boolean

**SQL**:
```sql
SELECT can_chat_with('target-user-uuid');
-- Returns: true or false
```

---

# Database Schema Summary

| Table | Purpose |
|-------|---------|
| `profiles` | User profiles with location |
| `stories` | User stories (24hr expiry) |
| `story_views` | Track story views |
| `groups` | User-created groups |
| `group_members` | Group membership |
| `waves` | Mutual wave system |
| `conversations` | Chat conversations |
| `messages` | Chat messages |
| `group_messages` | Group chat messages |

---

# Authentication Flow

```
1. User signs up → Profile auto-created via trigger
2. User logs in → Receive access_token & refresh_token
3. Store tokens in Flutter secure storage
4. Include access_token in Authorization header for all requests
5. Token expires → Use refresh_token to get new access_token
```

---

# Wave & Chat Flow

```
1. User A sends wave to User B
2. User B sees pending wave in notifications
3. User B accepts wave → status = 'accepted'
4. can_chat_with() now returns true for both users
5. Either user can now create conversation and send messages
```

---

# Error Handling

All APIs return consistent error format:
```json
{
  "success": false,
  "message": "Error description",
  "error": "Detailed error message"
}
```

Common HTTP Status Codes:
- `200` - Success
- `201` - Created
- `400` - Bad Request (invalid input)
- `401` - Unauthorized (invalid/missing token)
- `403` - Forbidden (no permission)
- `404` - Not Found
- `500` - Internal Server Error
