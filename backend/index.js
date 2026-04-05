require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const swaggerUi = require('swagger-ui-express');
const YAML = require('yamljs');
const path = require('path');
const { supabase, supabaseAdmin, supabaseUrl } = require('./config/supabase');

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Load Swagger specification
const swaggerDocument = YAML.load(path.join(__dirname, 'swagger.yaml'));

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Swagger API Documentation
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'Colony App API Documentation'
}));

// Serve Swagger spec as JSON
app.get('/swagger.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(swaggerDocument);
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    supabase: supabaseUrl ? 'configured' : 'missing'
  });
});

// Test Supabase connection endpoint
app.get('/test-supabase', async (req, res) => {
  try {
    const { data, error } = await supabase.from('_test').select('*').limit(1);

    if (error) {
      return res.status(500).json({
        success: false,
        message: 'Supabase connection test failed',
        error: error.message
      });
    }

    res.status(200).json({
      success: true,
      message: 'Supabase connection successful',
      data: data || 'Test query executed (table may not exist)'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Supabase connection test failed',
      error: error.message
    });
  }
});

// Basic info endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Backend API is running',
    services: {
      supabase: {
        url: supabaseUrl ? 'configured' : 'not configured',
        features: ['Auth', 'PostgreSQL + PostGIS', 'Realtime', 'Storage']
      },
      redis: process.env.REDIS_URL ? 'configured' : 'not configured'
    },
    endpoints: {
      health: '/health',
      testSupabase: '/test-supabase',
      auth: {
        signup: 'POST /auth/signup',
        login: 'POST /auth/login',
        logout: 'POST /auth/logout',
        user: 'GET /auth/user',
        resetPassword: 'POST /auth/reset-password',
        updateProfile: 'PATCH /auth/profile'
      },
      profile: {
        get: 'GET /profile/:userId',
        update: 'PATCH /profile'
      },
      groups: {
        list: 'GET /groups',
        create: 'POST /groups',
        get: 'GET /groups/:groupId',
        join: 'POST /groups/:groupId/join',
        leave: 'POST /groups/:groupId/leave'
      },
      docs: '/api-docs',
      swaggerJson: '/swagger.json'
    }
  });
});

// ============== AUTH ROUTES ==============

// Sign Up
app.post('/auth/signup', async (req, res) => {
  try {
    const { email, password, displayName } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required'
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters'
      });
    }

    const { data, error } = await supabaseAdmin.auth.signUp({
      email,
      password,
      options: {
        data: displayName ? { display_name: displayName } : {}
      }
    });

    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    res.status(201).json({
      success: true,
      message: 'Account created successfully! Please check your email for verification.',
      user: {
        id: data.user?.id,
        email: data.user?.email,
        displayName: data.user?.user_metadata?.display_name
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred during signup',
      error: error.message
    });
  }
});

// Login
app.post('/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required'
      });
    }

    const { data, error } = await supabaseAdmin.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password'
      });
    }

    res.status(200).json({
      success: true,
      message: 'Login successful',
      user: {
        id: data.user?.id,
        email: data.user?.email,
        displayName: data.user?.user_metadata?.display_name,
        avatarUrl: data.user?.user_metadata?.avatar_url
      },
      session: {
        accessToken: data.session?.access_token,
        refreshToken: data.session?.refresh_token,
        expiresAt: data.session?.expires_at
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred during login',
      error: error.message
    });
  }
});

// Logout
app.post('/auth/logout', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
      return res.status(401).json({
        success: false,
        message: 'No authorization header provided'
      });
    }

    const token = authHeader.split(' ')[1];
    
    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'No token provided'
      });
    }

    const { error } = await supabaseAdmin.auth.admin.signOut(token);

    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    res.status(200).json({
      success: true,
      message: 'Logged out successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred during logout',
      error: error.message
    });
  }
});

// Get current user
app.get('/auth/user', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
      return res.status(401).json({
        success: false,
        message: 'No authorization header provided'
      });
    }

    const token = authHeader.split(' ')[1];
    
    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'No token provided'
      });
    }

    const { data, error } = await supabaseAdmin.auth.getUser(token);

    if (error) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired token'
      });
    }

    res.status(200).json({
      success: true,
      user: {
        id: data.user?.id,
        email: data.user?.email,
        displayName: data.user?.user_metadata?.display_name,
        avatarUrl: data.user?.user_metadata?.avatar_url
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// Reset password
app.post('/auth/reset-password', async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Email is required'
      });
    }

    const { error } = await supabaseAdmin.auth.resetPasswordForEmail(email, {
      redirectTo: `${process.env.FRONTEND_URL || 'http://localhost:3000'}/reset-password`
    });

    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    res.status(200).json({
      success: true,
      message: 'Password reset email sent successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// Update user profile
app.patch('/auth/profile', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const { displayName, avatarUrl } = req.body;
    
    if (!authHeader) {
      return res.status(401).json({
        success: false,
        message: 'No authorization header provided'
      });
    }

    const token = authHeader.split(' ')[1];
    
    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'No token provided'
      });
    }

    const { data, error } = await supabaseAdmin.auth.updateUser(token, {
      data: {
        ...(displayName && { display_name: displayName }),
        ...(avatarUrl && { avatar_url: avatarUrl })
      }
    });

    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      user: {
        id: data.user?.id,
        email: data.user?.email,
        displayName: data.user?.user_metadata?.display_name,
        avatarUrl: data.user?.user_metadata?.avatar_url
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// ============== PROFILE ROUTES ==============

// Get user profile by ID
app.get('/profile/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const { data, error } = await supabaseAdmin
      .from('profiles')
      .select('id, username, display_name, avatar_url, bio, location_name, created_at')
      .eq('id', userId)
      .single();

    if (error) {
      return res.status(404).json({
        success: false,
        message: 'Profile not found',
        error: error.message
      });
    }

    res.status(200).json({
      success: true,
      profile: data
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// Update current user's profile
app.patch('/profile', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const { displayName, bio, avatarUrl, locationName } = req.body;

    if (!authHeader) {
      return res.status(401).json({
        success: false,
        message: 'No authorization header provided'
      });
    }

    const token = authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'No token provided'
      });
    }

    // Get user ID from token
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired token'
      });
    }

    const userId = userData.user.id;

    // Update profile in profiles table
    const updateData = {};
    if (displayName !== undefined) updateData.display_name = displayName;
    if (bio !== undefined) updateData.bio = bio;
    if (avatarUrl !== undefined) updateData.avatar_url = avatarUrl;
    if (locationName !== undefined) updateData.location_name = locationName;

    const { data, error } = await supabaseAdmin
      .from('profiles')
      .update(updateData)
      .eq('id', userId)
      .select()
      .single();

    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      profile: data
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// ============== GROUP ROUTES ==============

// Create a new group
app.post('/groups', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const { name, description, isPrivate = false, latitude, longitude, locationName } = req.body;

    if (!authHeader) {
      return res.status(401).json({
        success: false,
        message: 'No authorization header provided'
      });
    }

    const token = authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'No token provided'
      });
    }

    // Get user ID from token
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired token'
      });
    }

    const userId = userData.user.id;

    if (!name) {
      return res.status(400).json({
        success: false,
        message: 'Group name is required'
      });
    }

    // Create group
    const groupData = {
      name,
      description: description || null,
      is_private: isPrivate,
      created_by: userId
    };

    // Add location if provided
    if (latitude && longitude) {
      groupData.location = `POINT(${longitude} ${latitude})`;
      groupData.location_name = locationName || null;
    }

    const { data: group, error: groupError } = await supabaseAdmin
      .from('groups')
      .insert(groupData)
      .select()
      .single();

    if (groupError) {
      return res.status(400).json({
        success: false,
        message: groupError.message
      });
    }

    // Add creator as admin member
    const { error: memberError } = await supabaseAdmin
      .from('group_members')
      .insert({
        group_id: group.id,
        user_id: userId,
        role: 'admin'
      });

    if (memberError) {
      console.error('Error adding creator as member:', memberError);
    }

    res.status(201).json({
      success: true,
      message: 'Group created successfully',
      group: group
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// Get all groups (with optional filters)
app.get('/groups', async (req, res) => {
  try {
    const { latitude, longitude, radius = 5, limit = 20, offset = 0 } = req.query;

    let query = supabaseAdmin
      .from('groups')
      .select('id, name, description, is_private, location_name, created_at, created_by')
      .eq('is_private', false)
      .order('created_at', { ascending: false })
      .range(parseInt(offset), parseInt(offset) + parseInt(limit) - 1);

    const { data, error } = await query;

    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    res.status(200).json({
      success: true,
      groups: data
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// Get group by ID
app.get('/groups/:groupId', async (req, res) => {
  try {
    const { groupId } = req.params;

    const { data, error } = await supabaseAdmin
      .from('groups')
      .select('id, name, description, is_private, location_name, created_at, created_by')
      .eq('id', groupId)
      .single();

    if (error) {
      return res.status(404).json({
        success: false,
        message: 'Group not found',
        error: error.message
      });
    }

    res.status(200).json({
      success: true,
      group: data
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// Join a group
app.post('/groups/:groupId/join', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const { groupId } = req.params;

    if (!authHeader) {
      return res.status(401).json({
        success: false,
        message: 'No authorization header provided'
      });
    }

    const token = authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'No token provided'
      });
    }

    // Get user ID from token
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired token'
      });
    }

    const userId = userData.user.id;

    // Check if already a member
    const { data: existingMember } = await supabaseAdmin
      .from('group_members')
      .select('id')
      .eq('group_id', groupId)
      .eq('user_id', userId)
      .single();

    if (existingMember) {
      return res.status(400).json({
        success: false,
        message: 'Already a member of this group'
      });
    }

    // Add member
    const { error: memberError } = await supabaseAdmin
      .from('group_members')
      .insert({
        group_id: groupId,
        user_id: userId,
        role: 'member'
      });

    if (memberError) {
      return res.status(400).json({
        success: false,
        message: memberError.message
      });
    }

    res.status(200).json({
      success: true,
      message: 'Successfully joined the group'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// Leave a group
app.post('/groups/:groupId/leave', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const { groupId } = req.params;

    if (!authHeader) {
      return res.status(401).json({
        success: false,
        message: 'No authorization header provided'
      });
    }

    const token = authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'No token provided'
      });
    }

    // Get user ID from token
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired token'
      });
    }

    const userId = userData.user.id;

    // Remove member
    const { error: memberError } = await supabaseAdmin
      .from('group_members')
      .delete()
      .eq('group_id', groupId)
      .eq('user_id', userId);

    if (memberError) {
      return res.status(400).json({
        success: false,
        message: memberError.message
      });
    }

    res.status(200).json({
      success: true,
      message: 'Successfully left the group'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// ============================================================
// CONVERSATIONS ENDPOINTS
// ============================================================

// Get all conversations for the authenticated user
app.get('/conversations', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Authorization header required'
      });
    }

    const token = authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'No token provided'
      });
    }

    // Get user ID from token
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired token'
      });
    }

    const userId = userData.user.id;

    // Get all conversations where user is participant
    const { data: conversations, error: convError } = await supabaseAdmin
      .from('conversations')
      .select(`
        id,
        created_at,
        last_message_at,
        user1_id,
        user2_id
      `)
      .or(`user1_id.eq.${userId},user2_id.eq.${userId}`)
      .order('last_message_at', { ascending: false, nullsFirst: false });

    if (convError) {
      return res.status(400).json({
        success: false,
        message: convError.message
      });
    }

    // Get other user details for each conversation
    const conversationsWithUsers = await Promise.all(
      (conversations || []).map(async (conv) => {
        const otherUserId = conv.user1_id === userId ? conv.user2_id : conv.user1_id;
        
        // Get other user's profile
        const { data: otherUser } = await supabaseAdmin
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .eq('id', otherUserId)
          .single();

        // Get last message
        const { data: lastMessage } = await supabaseAdmin
          .from('messages')
          .select('content, created_at, sender_id')
          .eq('conversation_id', conv.id)
          .order('created_at', { ascending: false })
          .limit(1)
          .single();

        return {
          id: conv.id,
          otherUser: otherUser ? {
            id: otherUser.id,
            username: otherUser.username,
            displayName: otherUser.display_name,
            avatarUrl: otherUser.avatar_url
          } : null,
          lastMessage: lastMessage ? {
            content: lastMessage.content,
            createdAt: lastMessage.created_at,
            senderId: lastMessage.sender_id
          } : null,
          createdAt: conv.created_at,
          lastMessageAt: conv.last_message_at
        };
      })
    );

    res.status(200).json({
      success: true,
      data: conversationsWithUsers
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// Get or create conversation with another user
app.post('/conversations', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Authorization header required'
      });
    }

    const token = authHeader.split(' ')[1];
    const { otherUserId } = req.body;

    if (!otherUserId) {
      return res.status(400).json({
        success: false,
        message: 'otherUserId is required'
      });
    }

    // Get user ID from token
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired token'
      });
    }

    const userId = userData.user.id;

    if (userId === otherUserId) {
      return res.status(400).json({
        success: false,
        message: 'Cannot create conversation with yourself'
      });
    }

    // Check if conversation already exists
    const { data: existingConv, error: existingError } = await supabaseAdmin
      .from('conversations')
      .select('*')
      .or(`and(user1_id.eq.${userId},user2_id.eq.${otherUserId}),and(user1_id.eq.${otherUserId},user2_id.eq.${userId})`)
      .single();

    if (existingConv) {
      return res.status(200).json({
        success: true,
        data: existingConv,
        isNew: false
      });
    }

    // Create new conversation
    const { data: newConv, error: createError } = await supabaseAdmin
      .from('conversations')
      .insert({
        user1_id: userId,
        user2_id: otherUserId
      })
      .select()
      .single();

    if (createError) {
      return res.status(400).json({
        success: false,
        message: createError.message
      });
    }

    res.status(201).json({
      success: true,
      data: newConv,
      isNew: true
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// Get messages for a conversation
app.get('/conversations/:id/messages', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const { id } = req.params;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Authorization header required'
      });
    }

    const token = authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'No token provided'
      });
    }

    // Get user ID from token
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired token'
      });
    }

    const userId = userData.user.id;

    // Verify user is part of this conversation
    const { data: conversation, error: convError } = await supabaseAdmin
      .from('conversations')
      .select('*')
      .eq('id', id)
      .single();

    if (convError || !conversation) {
      return res.status(404).json({
        success: false,
        message: 'Conversation not found'
      });
    }

    if (conversation.user1_id !== userId && conversation.user2_id !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      });
    }

    // Get messages
    const { data: messages, error: msgError } = await supabaseAdmin
      .from('messages')
      .select('id, content, sender_id, is_read, created_at, media_url, media_type')
      .eq('conversation_id', id)
      .order('created_at', { ascending: true });

    if (msgError) {
      return res.status(400).json({
        success: false,
        message: msgError.message
      });
    }

    // Mark messages as read
    await supabaseAdmin
      .from('messages')
      .update({ is_read: true })
      .eq('conversation_id', id)
      .neq('sender_id', userId)
      .eq('is_read', false);

    res.status(200).json({
      success: true,
      data: messages || []
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// Send a message
app.post('/conversations/:id/messages', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const { id } = req.params;
    const { content, mediaUrl, mediaType } = req.body;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Authorization header required'
      });
    }

    const token = authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'No token provided'
      });
    }

    if (!content && !mediaUrl) {
      return res.status(400).json({
        success: false,
        message: 'Content or media is required'
      });
    }

    // Get user ID from token
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired token'
      });
    }

    const userId = userData.user.id;

    // Verify user is part of this conversation
    const { data: conversation, error: convError } = await supabaseAdmin
      .from('conversations')
      .select('*')
      .eq('id', id)
      .single();

    if (convError || !conversation) {
      return res.status(404).json({
        success: false,
        message: 'Conversation not found'
      });
    }

    if (conversation.user1_id !== userId && conversation.user2_id !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      });
    }

    // Insert message
    const { data: message, error: msgError } = await supabaseAdmin
      .from('messages')
      .insert({
        conversation_id: id,
        sender_id: userId,
        content: content || '',
        media_url: mediaUrl,
        media_type: mediaType
      })
      .select()
      .single();

    if (msgError) {
      return res.status(400).json({
        success: false,
        message: msgError.message
      });
    }

    res.status(201).json({
      success: true,
      data: message
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// ============================================================
// USER KEYS ENDPOINTS (for E2E encryption)
// ============================================================

// Get user's public key
app.get('/user-keys/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const { data: userKey, error } = await supabaseAdmin
      .from('user_keys')
      .select('public_key, key_version, created_at')
      .eq('user_id', userId)
      .single();

    if (error) {
      return res.status(404).json({
        success: false,
        message: 'Public key not found for this user'
      });
    }

    res.status(200).json({
      success: true,
      data: userKey
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// Save user's public key
app.post('/user-keys', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Authorization header required'
      });
    }

    const token = authHeader.split(' ')[1];
    const { publicKey, keyVersion } = req.body;

    if (!publicKey) {
      return res.status(400).json({
        success: false,
        message: 'publicKey is required'
      });
    }

    // Get user ID from token
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired token'
      });
    }

    const userId = userData.user.id;

    // Upsert the public key
    const { data: userKey, error: keyError } = await supabaseAdmin
      .from('user_keys')
      .upsert({
        user_id: userId,
        public_key: publicKey,
        key_version: keyVersion || 1,
        updated_at: new Date().toISOString()
      }, { onConflict: 'user_id' })
      .select()
      .single();

    if (keyError) {
      return res.status(400).json({
        success: false,
        message: keyError.message
      });
    }

    res.status(201).json({
      success: true,
      data: userKey
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'An error occurred',
      error: error.message
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Supabase URL: ${supabaseUrl ? 'Configured' : 'Not configured'}`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
});
