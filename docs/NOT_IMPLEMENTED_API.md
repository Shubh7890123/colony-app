# Not Implemented API Endpoints

This document lists all API endpoints that are documented in Swagger but **NOT YET IMPLEMENTED** in the backend.

Total: **14 endpoints** remaining to implement.

---

## 1. Users API

### GET /users/nearby
**Description:** Get nearby users within a radius (5km default)

**Status:** ❌ Not Implemented

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| latitude | number | Yes | User's current latitude |
| longitude | number | Yes | User's current longitude |
| radius | number | No | Search radius in km (default: 5) |
| limit | number | No | Max results (default: 20) |

**Response (200):**
```json
{
  "success": true,
  "data": {
    "users": [
      {
        "id": "uuid",
        "username": "string",
        "full_name": "string",
        "avatar_url": "string",
        "bio": "string",
        "distance_km": 1.5
      }
    ],
    "total": 10,
    "radius_km": 5
  }
}
```

---

## 2. Groups API

### GET /groups/nearby
**Description:** Get nearby groups within a radius

**Status:** ❌ Not Implemented

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| latitude | number | Yes | User's current latitude |
| longitude | number | Yes | User's current longitude |
| radius | number | No | Search radius in km (default: 5) |
| limit | number | No | Max results (default: 20) |

**Response (200):**
```json
{
  "success": true,
  "data": {
    "groups": [
      {
        "id": "uuid",
        "name": "string",
        "description": "string",
        "created_by": "uuid",
        "created_at": "timestamp",
        "member_count": 5,
        "distance_km": 1.2
      }
    ],
    "total": 5,
    "radius_km": 5
  }
}
```

---

## 3. Location API

### PUT /location/update
**Description:** Update user's current location

**Status:** ❌ Not Implemented

**Headers:**
| Header | Type | Required | Description |
|--------|------|----------|-------------|
| Authorization | string | Yes | Bearer token |

**Request Body:**
```json
{
  "latitude": 28.6139,
  "longitude": 77.2090
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "Location updated successfully",
  "data": {
    "latitude": 28.6139,
    "longitude": 77.2090,
    "updated_at": "2024-01-15T10:30:00Z"
  }
}
```

---

## 4. Stories API

### GET /stories
**Description:** Get active stories (not expired)

**Status:** ❌ Not Implemented

**Headers:**
| Header | Type | Required | Description |
|--------|------|----------|-------------|
| Authorization | string | Yes | Bearer token |

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| latitude | number | Yes | User's current latitude |
| longitude | number | Yes | User's current longitude |

**Response (200):**
```json
{
  "success": true,
  "data": {
    "stories": [
      {
        "id": "uuid",
        "user_id": "uuid",
        "username": "string",
        "avatar_url": "string",
        "media_url": "string",
        "media_type": "image|video",
        "caption": "string",
        "created_at": "timestamp",
        "expires_at": "timestamp",
        "viewed": false
      }
    ]
  }
}
```

### POST /stories
**Description:** Create a new story

**Status:** ❌ Not Implemented

**Headers:**
| Header | Type | Required | Description |
|--------|------|----------|-------------|
| Authorization | string | Yes | Bearer token |
| Content-Type | string | Yes | multipart/form-data |

**Request Body (multipart/form-data):**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| media | file | Yes | Image or video file |
| media_type | string | Yes | "image" or "video" |
| caption | string | No | Story caption |
| latitude | number | Yes | User's latitude |
| longitude | number | Yes | User's longitude |

**Response (201):**
```json
{
  "success": true,
  "message": "Story created successfully",
  "data": {
    "id": "uuid",
    "media_url": "string",
    "expires_at": "timestamp"
  }
}
```

### DELETE /stories/:storyId
**Description:** Delete a story

**Status:** ❌ Not Implemented

**Headers:**
| Header | Type | Required | Description |
|--------|------|----------|-------------|
| Authorization | string | Yes | Bearer token |

**Path Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| storyId | string | Yes | Story UUID |

**Response (200):**
```json
{
  "success": true,
  "message": "Story deleted successfully"
}
```

---

## 5. Waves API

### GET /waves
**Description:** Get pending waves for current user

**Status:** ❌ Not Implemented

**Headers:**
| Header | Type | Required | Description |
|--------|------|----------|-------------|
| Authorization | string | Yes | Bearer token |

**Response (200):**
```json
{
  "success": true,
  "data": {
    "waves": [
      {
        "id": "uuid",
        "from_user": {
          "id": "uuid",
          "username": "string",
          "avatar_url": "string"
        },
        "status": "pending",
        "created_at": "timestamp"
      }
    ],
    "total": 3
  }
}
```

### POST /waves
**Description:** Send a wave to another user

**Status:** ❌ Not Implemented

**Headers:**
| Header | Type | Required | Description |
|--------|------|----------|-------------|
| Authorization | string | Yes | Bearer token |

**Request Body:**
```json
{
  "to_user_id": "uuid"
}
```

**Response (201):**
```json
{
  "success": true,
  "message": "Wave sent successfully",
  "data": {
    "id": "uuid",
    "status": "pending"
  }
}
```

### PATCH /waves/:waveId/respond
**Description:** Accept or reject a wave

**Status:** ❌ Not Implemented

**Headers:**
| Header | Type | Required | Description |
|--------|------|----------|-------------|
| Authorization | string | Yes | Bearer token |

**Path Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| waveId | string | Yes | Wave UUID |

**Request Body:**
```json
{
  "status": "accepted"
}
```
*Note: status can be "accepted" or "rejected"*

**Response (200):**
```json
{
  "success": true,
  "message": "Wave accepted",
  "data": {
    "id": "uuid",
    "status": "accepted",
    "can_chat": true
  }
}
```

### GET /waves/can-chat/:userId
**Description:** Check if mutual wave exists with another user

**Status:** ❌ Not Implemented

**Headers:**
| Header | Type | Required | Description |
|--------|------|----------|-------------|
| Authorization | string | Yes | Bearer token |

**Path Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| userId | string | Yes | Other user's UUID |

**Response (200):**
```json
{
  "success": true,
  "data": {
    "can_chat": true,
    "wave_status": "accepted"
  }
}
```

---

## 6. Conversations API (Chat)

### GET /conversations
**Description:** Get all conversations for current user

**Status:** ❌ Not Implemented

**Headers:**
| Header | Type | Required | Description |
|--------|------|----------|-------------|
| Authorization | string | Yes | Bearer token |

**Response (200):**
```json
{
  "success": true,
  "data": {
    "conversations": [
      {
        "id": "uuid",
        "other_user": {
          "id": "uuid",
          "username": "string",
          "avatar_url": "string"
        },
        "last_message": {
          "content": "string",
          "created_at": "timestamp",
          "sender_id": "uuid"
        },
        "unread_count": 2
      }
    ]
  }
}
```

### POST /conversations
**Description:** Create a new conversation

**Status:** ❌ Not Implemented

**Headers:**
| Header | Type | Required | Description |
|--------|------|----------|-------------|
| Authorization | string | Yes | Bearer token |

**Request Body:**
```json
{
  "other_user_id": "uuid"
}
```

**Response (201):**
```json
{
  "success": true,
  "message": "Conversation created",
  "data": {
    "id": "uuid",
    "other_user": {
      "id": "uuid",
      "username": "string"
    }
  }
}
```

### GET /conversations/:id/messages
**Description:** Get messages for a conversation

**Status:** ❌ Not Implemented

**Headers:**
| Header | Type | Required | Description |
|--------|------|----------|-------------|
| Authorization | string | Yes | Bearer token |

**Path Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Conversation UUID |

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| limit | number | No | Max messages (default: 50) |
| before | string | No | Message ID for pagination |

**Response (200):**
```json
{
  "success": true,
  "data": {
    "messages": [
      {
        "id": "uuid",
        "conversation_id": "uuid",
        "sender_id": "uuid",
        "content": "string",
        "created_at": "timestamp",
        "read_at": "timestamp|null"
      }
    ],
    "has_more": false
  }
}
```

### POST /conversations/:id/messages
**Description:** Send a message in a conversation

**Status:** ❌ Not Implemented

**Headers:**
| Header | Type | Required | Description |
|--------|------|----------|-------------|
| Authorization | string | Yes | Bearer token |

**Path Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Conversation UUID |

**Request Body:**
```json
{
  "content": "Hello, how are you?"
}
```

**Response (201):**
```json
{
  "success": true,
  "message": "Message sent",
  "data": {
    "id": "uuid",
    "content": "string",
    "created_at": "timestamp"
  }
}
```

---

## Summary Table

| # | Endpoint | Method | Description | Priority |
|---|----------|--------|-------------|----------|
| 1 | /users/nearby | GET | Get nearby users | High |
| 2 | /groups/nearby | GET | Get nearby groups | High |
| 3 | /location/update | PUT | Update user location | High |
| 4 | /stories | GET | Get active stories | Medium |
| 5 | /stories | POST | Create story | Medium |
| 6 | /stories/:storyId | DELETE | Delete story | Medium |
| 7 | /waves | GET | Get pending waves | High |
| 8 | /waves | POST | Send wave | High |
| 9 | /waves/:waveId/respond | PATCH | Accept/reject wave | High |
| 10 | /waves/can-chat/:userId | GET | Check mutual wave | High |
| 11 | /conversations | GET | Get conversations | High |
| 12 | /conversations | POST | Create conversation | High |
| 13 | /conversations/:id/messages | GET | Get messages | High |
| 14 | /conversations/:id/messages | POST | Send message | High |

---

## Implementation Order (Recommended)

1. **Location Update** - Foundation for nearby features
2. **Nearby Users & Groups** - Core feature
3. **Waves API** - Connection feature
4. **Conversations API** - Chat feature
5. **Stories API** - Content feature

---

## Database Tables Required

The following tables need to be created in Supabase:

```sql
-- User locations (for nearby features)
CREATE TABLE user_locations (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Stories
CREATE TABLE stories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  media_url TEXT NOT NULL,
  media_type VARCHAR(10) NOT NULL,
  caption TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '24 hours'
);

-- Waves
CREATE TABLE waves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID REFERENCES auth.users(id) NOT NULL,
  to_user_id UUID REFERENCES auth.users(id) NOT NULL,
  status VARCHAR(20) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(from_user_id, to_user_id)
);

-- Conversations
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user1_id UUID REFERENCES auth.users(id) NOT NULL,
  user2_id UUID REFERENCES auth.users(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user1_id, user2_id)
);

-- Messages
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES conversations(id) NOT NULL,
  sender_id UUID REFERENCES auth.users(id) NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  read_at TIMESTAMPTZ
);
```

---

*Last updated: January 2024*
