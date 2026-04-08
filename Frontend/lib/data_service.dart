import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'notification_service.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  final SupabaseClient _client = SupabaseService().client;

  /// Discovery radius cap (must match backend `NEARBY_5KM_AND_WAVES.sql`).
  static const double maxNearbyRadiusKm = 5.0;

  double _effectiveNearbyRadius(double radiusKm) {
    final r = radiusKm <= 0 ? maxNearbyRadiusKm : radiusKm;
    return r > maxNearbyRadiusKm ? maxNearbyRadiusKm : r;
  }

  // ============================================
  // NEARBY USERS
  // ============================================
  
  Future<List<NearbyUser>> getNearbyUsers({
    required double latitude,
    required double longitude,
    double radiusKm = maxNearbyRadiusKm,
  }) async {
    try {
      final response = await _client.rpc(
        'get_nearby_users',
        params: {
          'user_lat': latitude,
          'user_lon': longitude,
          'radius_km': _effectiveNearbyRadius(radiusKm),
        },
      );

      return (response as List)
          .map((json) => NearbyUser.fromJson(json as Map<String, dynamic>))
          .where((u) => u.distance <= maxNearbyRadiusKm + 1e-6)
          .toList();
    } catch (e) {
      print('Error fetching nearby users: $e');
      return [];
    }
  }

  // ============================================
  // NEARBY GROUPS
  // ============================================

  Future<List<NearbyGroup>> getNearbyGroups({
    required double latitude,
    required double longitude,
    double radiusKm = maxNearbyRadiusKm,
  }) async {
    try {
      final response = await _client.rpc(
        'get_nearby_groups',
        params: {
          'user_lat': latitude,
          'user_lon': longitude,
          'radius_km': _effectiveNearbyRadius(radiusKm),
        },
      );

      final raw = (response as List).cast<Map<String, dynamic>>();

      // RPC `get_nearby_groups` returns member_count + distance, but it doesn't
      // include whether the current user is a member. We compute `isMember`
      // from `group_members` so UI Join/Leave state is correct.
      final user = _client.auth.currentUser;
      final Set<String> myGroupIds = <String>{};
      if (user != null && raw.isNotEmpty) {
        final groupIds = raw.map((g) => g['id']?.toString()).whereType<String>().toList();
        if (groupIds.isNotEmpty) {
          final memberRows = await _client
              .from('group_members')
              .select('group_id')
              .inFilter('group_id', groupIds)
              .eq('user_id', user.id);

          for (final row in (memberRows as List)) {
            final gid = (row['group_id'] ?? row['groupId'])?.toString();
            if (gid != null && gid.isNotEmpty) myGroupIds.add(gid);
          }
        }
      }

      return raw
          .map((json) {
            final groupId = json['id']?.toString();
            final isMember = groupId != null && myGroupIds.contains(groupId);
            return NearbyGroup.fromJson(json, isMember: isMember);
          })
          .where((g) => g.distance <= maxNearbyRadiusKm + 1e-6)
          .toList();
    } catch (e) {
      print('Error fetching nearby groups: $e');
      return [];
    }
  }

  /// All groups the current user has joined (any distance; includes private).
  Future<List<NearbyGroup>> getMyJoinedGroups() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final memberRows = await _client
          .from('group_members')
          .select('group_id')
          .eq('user_id', user.id);

      final ids = (memberRows as List)
          .map((r) => r['group_id']?.toString())
          .whereType<String>()
          .toList();
      if (ids.isEmpty) return [];

      final groupsData = await _client
          .from('groups')
          .select(
            'id, name, description, category, cover_image_url, location_text, latitude, longitude, is_private',
          )
          .inFilter('id', ids);

      final countRows = await _client
          .from('group_members')
          .select('group_id')
          .inFilter('group_id', ids);

      final counts = <String, int>{};
      for (final r in countRows as List) {
        final gid = r['group_id']?.toString();
        if (gid == null) continue;
        counts[gid] = (counts[gid] ?? 0) + 1;
      }

      final list = (groupsData as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['id']?.toString() ?? '';
        map['member_count'] = counts[id] ?? 0;
        map['distance'] = 0.0;
        return NearbyGroup.fromJson(map, isMember: true);
      }).toList();

      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    } catch (e) {
      print('Error fetching joined groups: $e');
      return [];
    }
  }

  // ============================================
  // STORIES
  // ============================================

  Future<List<Story>> getActiveStories() async {
    try {
      final response = await _client
          .from('stories')
          .select('''
            id,
            media_url,
            media_type,
            caption,
            created_at,
            expires_at,
            user_id,
            profiles!stories_user_id_fkey (
              id,
              username,
              display_name,
              avatar_url
            )
          ''')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Story.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching stories: $e');
      return [];
    }
  }

  Future<bool> createStory({
    required String mediaUrl,
    String mediaType = 'image',
    String? caption,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      await _client.from('stories').insert({
        'user_id': user.id,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'caption': caption,
      });
      return true;
    } catch (e) {
      print('Error creating story: $e');
      return false;
    }
  }

  Future<bool> deleteStory(String storyId) async {
    try {
      await _client.from('stories').delete().eq('id', storyId);
      return true;
    } catch (e) {
      print('Error deleting story: $e');
      return false;
    }
  }

  // ============================================
  // FRIEND REQUEST SYSTEM (uses waves table)
  // ============================================

  /// Send a friend request to [receiverId]. Returns true if sent.
  Future<bool> sendFriendRequest(String receiverId) async {
    return sendWave(receiverId);
  }

  /// Remove a friend (delete the wave record in both directions).
  Future<bool> removeFriend(String friendId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      // Delete wave sent by current user to friend
      await _client
          .from('waves')
          .delete()
          .eq('sender_id', user.id)
          .eq('receiver_id', friendId);

      // Delete wave sent by friend to current user
      await _client
          .from('waves')
          .delete()
          .eq('sender_id', friendId)
          .eq('receiver_id', user.id);

      return true;
    } catch (e) {
      print('Error removing friend: \$e');
      return false;
    }
  }

  /// Get friend request status between current user and [targetUserId].
  /// Returns: 'pending' | 'accepted' | 'rejected' | 'received' | 'received_accepted' | null
  Future<String?> getFriendRequestStatus(String targetUserId) async {
    return getWaveStatus(targetUserId);
  }

  /// Count friends (accepted waves) for [userId].
  Future<int> getFriendsCount(String userId) async {
    try {
      final sentAccepted = await _client
          .from('waves')
          .select('id')
          .eq('sender_id', userId)
          .eq('status', 'accepted');

      final receivedAccepted = await _client
          .from('waves')
          .select('id')
          .eq('receiver_id', userId)
          .eq('status', 'accepted');

      final sentCount = (sentAccepted as List).length;
      final receivedCount = (receivedAccepted as List).length;
      return sentCount + receivedCount;
    } catch (e) {
      print('Error fetching friends count: \$e');
      return 0;
    }
  }

  /// Count groups that [userId] is a member of.
  Future<int> getUserGroupsCount(String userId) async {
    try {
      final rows = await _client
          .from('group_members')
          .select('group_id')
          .eq('user_id', userId);
      return (rows as List).length;
    } catch (e) {
      print('Error fetching groups count: \$e');
      return 0;
    }
  }

  /// Count active (non-expired) stories posted by [userId].
  Future<int> getUserStoriesCount(String userId) async {
    try {
      final rows = await _client
          .from('stories')
          .select('id')
          .eq('user_id', userId)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String());
      return (rows as List).length;
    } catch (e) {
      print('Error fetching stories count: \$e');
      return 0;
    }
  }

  // ============================================
  // WAVES
  // ============================================

  Future<bool> sendWave(String receiverId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      // Check if wave already exists
      final existingWave = await _client
          .from('waves')
          .select('id')
          .eq('sender_id', user.id)
          .eq('receiver_id', receiverId)
          .maybeSingle();

      if (existingWave != null) {
        // Wave already exists, return true (idempotent)
        return true;
      }

      await _client.from('waves').insert({
        'sender_id': user.id,
        'receiver_id': receiverId,
      });
  
      // Send push notification to receiver
      await NotificationService().sendWaveNotification(receiverId);
  
      return true;
    } catch (e) {
      print('Error sending wave: $e');
      return false;
    }
  }

  Future<bool> respondToWave(String waveId, String status) async {
    try {
      await _client.from('waves').update({
        'status': status,
        'responded_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', waveId);
      return true;
    } catch (e) {
      print('Error responding to wave: $e');
      return false;
    }
  }

  Future<List<Wave>> getPendingWaves() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('waves')
          .select('''
            id,
            status,
            created_at,
            sender_id,
            profiles!waves_sender_id_fkey (
              id,
              username,
              display_name,
              avatar_url,
              bio
            )
          ''')
          .eq('receiver_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Wave.fromJson(json, isReceived: true))
          .toList();
    } catch (e) {
      print('Error fetching waves: $e');
      return [];
    }
  }

  Future<bool> canChatWith(String targetUserId) async {
    try {
      final response = await _client.rpc(
        'can_chat_with',
        params: {'target_user_id': targetUserId},
      );
      return response == true;
    } catch (e) {
      print('Error checking chat permission: $e');
      return false;
    }
  }

  /// Get wave status between current user and target user
  /// Returns: 'pending' (sent, waiting), 'accepted' (they accepted), 'rejected' (they rejected),
  /// 'received' (they sent you a wave), or null (no wave)
  Future<String?> getWaveStatus(String targetUserId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      // Check if current user sent a wave to target
      final sentWave = await _client
          .from('waves')
          .select('status')
          .eq('sender_id', user.id)
          .eq('receiver_id', targetUserId)
          .maybeSingle();

      if (sentWave != null) {
        return sentWave['status'] as String?;
      }

      // Check if target sent a wave to current user
      final receivedWave = await _client
          .from('waves')
          .select('status')
          .eq('sender_id', targetUserId)
          .eq('receiver_id', user.id)
          .maybeSingle();

      if (receivedWave != null) {
        // If they sent us a wave, return 'received_' + status
        final status = receivedWave['status'] as String?;
        if (status == 'pending') {
          return 'received'; // They sent us a pending wave
        }
        return 'received_$status'; // received_accepted or received_rejected
      }

      return null;
    } catch (e) {
      print('Error getting wave status: $e');
      return null;
    }
  }

  // ============================================
  // CONVERSATIONS & MESSAGES
  // ============================================

  Future<List<Conversation>> getConversations() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('conversations')
          .select('''
            id,
            last_message_at,
            user1_id,
            user2_id,
            messages (
              id,
              content,
              created_at,
              sender_id,
              is_read
            )
          ''')
          .or('user1_id.eq.${user.id},user2_id.eq.${user.id}')
          .order('last_message_at', ascending: false);

      // Get all unique user IDs to fetch their profiles
      final userIds = <String>{};
      for (final conv in response) {
        if (conv['user1_id'] != user.id) userIds.add(conv['user1_id']);
        if (conv['user2_id'] != user.id) userIds.add(conv['user2_id']);
      }

      // Fetch user profiles
      final usersData = await _client
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .inFilter('id', userIds.toList());

      final usersMap = {for (var u in usersData) u['id']: u};

      return (response as List)
          .map((json) {
            final otherUserId = json['user1_id'] == user.id
                ? json['user2_id']
                : json['user1_id'];
            final otherUserData = usersMap[otherUserId];
            
            return Conversation.fromJson(
              json,
              currentUserId: user.id,
              otherUserData: otherUserData,
            );
          })
          .where((c) => c.otherUser != null)
          .toList();
    } catch (e) {
      print('Error fetching conversations: $e');
      return [];
    }
  }

  /// Other participant in a 1:1 conversation (for chat header / profile when only `conversationId` is known).
  Future<String?> getOtherParticipantUserId(String conversationId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final row = await _client
          .from('conversations')
          .select('user1_id, user2_id')
          .eq('id', conversationId)
          .maybeSingle();

      if (row == null) return null;
      final u1 = row['user1_id']?.toString();
      final u2 = row['user2_id']?.toString();
      if (u1 == user.id) return u2;
      if (u2 == user.id) return u1;
      return null;
    } catch (e) {
      print('Error resolving conversation peer: $e');
      return null;
    }
  }

  Future<Conversation?> getOrCreateConversation(String otherUserId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      // Check if can chat
      final canChat = await canChatWith(otherUserId);
      if (!canChat) return null;

      // Check existing conversation
      final existing = await _client
          .from('conversations')
          .select()
          .or('and(user1_id.eq.${user.id},user2_id.eq.$otherUserId),and(user1_id.eq.$otherUserId,user2_id.eq.${user.id})')
          .maybeSingle();

      if (existing != null) {
        return Conversation.fromJson(existing, currentUserId: user.id);
      }

      // Create new conversation
      final newConv = await _client
          .from('conversations')
          .insert({
            'user1_id': user.id,
            'user2_id': otherUserId,
          })
          .select()
          .single();

      return Conversation.fromJson(newConv, currentUserId: user.id);
    } catch (e) {
      print('Error getting conversation: $e');
      return null;
    }
  }

  Future<List<Message>> getMessages(String conversationId) async {
    try {
      final response = await _client
          .from('messages')
          .select('''
            id,
            content,
            media_url,
            media_type,
            is_read,
            created_at,
            sender_id,
            delivered_at,
            seen_at
          ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => Message.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  Future<Message?> sendMessage({
    required String conversationId,
    required String content,
    String? mediaUrl,
    String? mediaType,
    String? targetUserId, // For sending notification
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response = await _client
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': user.id,
            'content': content,
            'media_url': mediaUrl,
            'media_type': mediaType,
          })
          .select()
          .single();

      final message = Message.fromJson(response);

      // FCM to the other participant only (they get a push when you send;
      // you get a push when they reply — same as Telegram-style 1:1 alerts).
      if (targetUserId != null && content.isNotEmpty) {
        // Truncate message for notification preview
        final preview = content.length > 50 ? '${content.substring(0, 50)}...' : content;
        await NotificationService().sendMessageNotification(
          targetUserId: targetUserId,
          conversationId: conversationId,
          messagePreview: preview,
        );
      }

      return message;
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  // ============================================
  // GROUPS
  // ============================================

  Future<bool> joinGroup(String groupId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      await _client.from('group_members').insert({
        'group_id': groupId,
        'user_id': user.id,
      });
      return true;
    } on PostgrestException catch (e) {
      // Unique violation — already a member
      if (e.code == '23505') return true;
      print('Error joining group: $e');
      return false;
    } catch (e) {
      print('Error joining group: $e');
      return false;
    }
  }

  Future<bool> leaveGroup(String groupId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      await _client.from('group_members').delete()
      .eq('group_id', groupId)
      .eq('user_id', user.id);
      return true;
    } catch (e) {
      print('Error leaving group: $e');
      return false;
    }
  }

  Future<bool> createGroup({
    required String name,
    String? description,
    String? category,
    double? latitude,
    double? longitude,
    String? coverImageUrl,
    bool isPrivate = false,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      // Create the group
      final groupResponse = await _client
          .from('groups')
          .insert({
            'name': name,
            'description': description,
            'category': category,
            'latitude': latitude,
            'longitude': longitude,
            'cover_image_url': coverImageUrl,
            'is_private': isPrivate,
            'created_by': user.id,
          })
          .select()
          .single();

      // Add creator as admin member
      await _client.from('group_members').insert({
        'group_id': groupResponse['id'],
        'user_id': user.id,
        'role': 'admin',
      });

      return true;
    } catch (e) {
      print('Error creating group: $e');
      return false;
    }
  }

  Future<bool> updateGroupCover({
    required String groupId,
    required String coverImageUrl,
  }) async {
    try {
      await _client.from('groups').update({
        'cover_image_url': coverImageUrl,
      }).eq('id', groupId);
      return true;
    } catch (e) {
      print('Error updating group cover: $e');
      return false;
    }
  }

  Future<List<GroupMessage>> getGroupMessages(String groupId) async {
    try {
      final response = await _client
          .from('group_messages')
          .select('''
            id,
            group_id,
            sender_id,
            content,
            created_at,
            profiles (
              display_name,
              username,
              avatar_url
            )
          ''')
          .eq('group_id', groupId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((row) => GroupMessage.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching group messages: $e');
      return [];
    }
  }

  Future<GroupMessage?> sendGroupMessage({
    required String groupId,
    required String content,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final trimmed = content.trim();
      if (trimmed.isEmpty) return null;

      final response = await _client
          .from('group_messages')
          .insert({
            'group_id': groupId,
            'sender_id': user.id,
            'content': trimmed,
          })
          .select('''
            id,
            group_id,
            sender_id,
            content,
            created_at,
            profiles (
              display_name,
              username,
              avatar_url
            )
          ''')
          .single();

      return GroupMessage.fromJson(response);
    } catch (e) {
      print('Error sending group message: $e');
      return null;
    }
  }

  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    try {
      final response = await _client
          .from('group_members')
          .select('''
            id,
            role,
            joined_at,
            profiles (
              id,
              username,
              display_name,
              avatar_url
            )
          ''')
          .eq('group_id', groupId)
          .order('joined_at', ascending: true);

      return (response as List)
          .map((json) => GroupMember.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching group members: $e');
      return [];
    }
  }

  // ============================================
  // USER PROFILE
  // ============================================

  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  Future<bool> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      final updates = <String, dynamic>{};
      if (displayName != null) updates['display_name'] = displayName;
      if (bio != null) updates['bio'] = bio;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      if (updates.isEmpty) return true;

      await _client.from('profiles').update(updates).eq('id', user.id);
      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  // ============================================
  // USER KEYS (for E2E encryption)
  // ============================================

  Future<String?> getUserPublicKey(String userId) async {
    try {
      final response = await _client
          .from('user_keys')
          .select('public_key')
          .eq('user_id', userId)
          .single();

      return response['public_key'] as String?;
    } catch (e) {
      print('Error fetching user public key: $e');
      return null;
    }
  }

  Future<bool> saveUserPublicKey(String publicKey, {int keyVersion = 1}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      await _client
          .from('user_keys')
          .upsert({
            'user_id': user.id,
            'public_key': publicKey,
            'key_version': keyVersion,
          }, onConflict: 'user_id');

      return true;
    } catch (e) {
      print('Error saving user public key: $e');
      return false;
    }
  }

  // ============================================
  // ONLINE STATUS & LAST SEEN
  // ============================================

  /// Update current user's last_seen timestamp
  Future<void> updateLastSeen() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client.from('profiles').update({
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      print('Error updating last seen: $e');
    }
  }

  /// Get user's online status and last seen
  Future<UserProfile?> getUserOnlineStatus(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('id, last_seen')
          .eq('id', userId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error fetching user online status: $e');
      return null;
    }
  }

  // ============================================
  // MESSAGE DELIVERY STATUS
  // ============================================

  /// Mark messages as delivered for current user
  Future<void> markMessagesAsDelivered(String conversationId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      // Mark all undelivered messages sent to current user as delivered
      await _client
          .from('messages')
          .update({
            'delivered_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('conversation_id', conversationId)
          .neq('sender_id', user.id)
          .filter('delivered_at', 'is', null);
    } catch (e) {
      print('Error marking messages as delivered: $e');
    }
  }

  /// Mark messages as seen for current user
  Future<void> markMessagesAsSeen(String conversationId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      // Mark all unseen messages sent to current user as seen
      await _client
          .from('messages')
          .update({
            'seen_at': DateTime.now().toUtc().toIso8601String(),
            'is_read': true,
          })
          .eq('conversation_id', conversationId)
          .neq('sender_id', user.id)
          .filter('seen_at', 'is', null);
    } catch (e) {
      print('Error marking messages as seen: $e');
    }
  }
}

// ============================================
// DATA MODELS
// ============================================

class NearbyUser {
  final String id;
  final String? email;
  final String? username;
  final String? fullName;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? locationText;
  final double distance;

  NearbyUser({
    required this.id,
    this.email,
    this.username,
    this.fullName,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.locationText,
    required this.distance,
  });

  factory NearbyUser.fromJson(Map<String, dynamic> json) {
    return NearbyUser(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      fullName: json['full_name'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      locationText: json['location_text'],
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get displayDistance {
    if (distance < 1) {
      return '${(distance * 1000).round()}m';
    }
    return '${distance.round()}km';
  }
}

class NearbyGroup {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? coverImageUrl;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final bool isPrivate;
  final int memberCount;
  final double distance;
  final bool isMember;

  NearbyGroup({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.coverImageUrl,
    this.locationText,
    this.latitude,
    this.longitude,
    required this.isPrivate,
    required this.memberCount,
    required this.distance,
    this.isMember = false,
  });

  factory NearbyGroup.fromJson(Map<String, dynamic> json, {bool? isMember}) {
    final dynamic memberVal = isMember ?? json['is_member'] ?? false;
    final computedIsMember = memberVal is bool
        ? memberVal
        : (memberVal.toString().toLowerCase() == 'true');

    return NearbyGroup(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      category: json['category'],
      coverImageUrl: json['cover_image_url'],
      locationText: json['location_text'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isPrivate: json['is_private'] ?? false,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      isMember: computedIsMember,
    );
  }

  String get displayDistance {
    if (distance < 1) {
      return '${(distance * 1000).round()}m';
    }
    return '${distance.round()}km';
  }
}

class Story {
  final String id;
  final String mediaUrl;
  final String mediaType;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String userId;
  final StoryUser user;

  Story({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.userId,
    required this.user,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'],
      mediaUrl: json['media_url'],
      mediaType: json['media_type'] ?? 'image',
      caption: json['caption'],
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: DateTime.parse(json['expires_at']),
      userId: json['user_id'],
      user: StoryUser.fromJson(json['profiles']),
    );
  }
}

class StoryUser {
  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  StoryUser({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory StoryUser.fromJson(Map<String, dynamic> json) {
    return StoryUser(
      id: json['id'],
      username: json['username'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
    );
  }
}

class Wave {
  final String id;
  final String status;
  final DateTime createdAt;
  final String senderId;
  final WaveUser? sender;
  final WaveUser? receiver;

  Wave({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.senderId,
    this.sender,
    this.receiver,
  });

  factory Wave.fromJson(Map<String, dynamic> json, {bool isReceived = false}) {
    return Wave(
      id: json['id'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      senderId: json['sender_id'],
      sender: isReceived && json['profiles'] != null
          ? WaveUser.fromJson(json['profiles'])
          : null,
    );
  }
}

class WaveUser {
  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;

  WaveUser({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
  });

  factory WaveUser.fromJson(Map<String, dynamic> json) {
    return WaveUser(
      id: json['id'],
      username: json['username'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
    );
  }
}

class Conversation {
  final String id;
  final DateTime? lastMessageAt;
  final String user1Id;
  final String user2Id;
  final ConversationUser? otherUser;
  final Message? lastMessage;
  final int unreadCount;

  Conversation({
    required this.id,
    this.lastMessageAt,
    required this.user1Id,
    required this.user2Id,
    this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
    Map<String, dynamic>? otherUserData,
  }) {
    final otherUserId = json['user1_id'] == currentUserId
        ? json['user2_id']
        : json['user1_id'];

    Message? lastMsg;
    int unread = 0;
    if (json['messages'] != null && (json['messages'] as List).isNotEmpty) {
      final messages = json['messages'] as List;
      messages.sort((a, b) => b['created_at'].compareTo(a['created_at']));
      lastMsg = Message.fromJson(messages.first);
      
      // Count unread messages (not sent by current user and not read)
      unread = messages.where((m) =>
        m['sender_id'] != currentUserId && (m['is_read'] == false || m['is_read'] == null)
      ).length;
    }

    ConversationUser? otherUser;
    if (otherUserData != null) {
      otherUser = ConversationUser.fromJson(otherUserData);
    } else if (otherUserId != null) {
      otherUser = ConversationUser(id: otherUserId);
    }

    return Conversation(
      id: json['id'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : null,
      user1Id: json['user1_id'],
      user2Id: json['user2_id'],
      otherUser: otherUser,
      lastMessage: lastMsg,
      unreadCount: unread,
    );
  }
}

class ConversationUser {
  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  ConversationUser({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory ConversationUser.fromJson(Map<String, dynamic> json) {
    return ConversationUser(
      id: json['id'],
      username: json['username'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
    );
  }
}

class Message {
  final String id;
  final String content;
  final String? mediaUrl;
  final String? mediaType;
  final bool isRead;
  final DateTime createdAt;
  final String senderId;
  final DateTime? deliveredAt;
  final DateTime? seenAt;

  Message({
    required this.id,
    required this.content,
    this.mediaUrl,
    this.mediaType,
    required this.isRead,
    required this.createdAt,
    required this.senderId,
    this.deliveredAt,
    this.seenAt,
  });

  // Message status enum
  MessageStatus get status {
    if (seenAt != null) return MessageStatus.seen;
    if (deliveredAt != null) return MessageStatus.delivered;
    return MessageStatus.sent;
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'] ?? '',
      mediaUrl: json['media_url'],
      mediaType: json['media_type'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      senderId: json['sender_id'],
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
      seenAt: json['seen_at'] != null
          ? DateTime.parse(json['seen_at'])
          : null,
    );
  }
}

enum MessageStatus {
  sent,      // Single tick - message sent but not delivered
  delivered, // Double tick grey - message delivered
  seen,      // Double tick blue - message seen
}

class GroupMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? senderDisplayName;
  final String? senderUsername;
  final String? senderAvatarUrl;

  GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.senderDisplayName,
    this.senderUsername,
    this.senderAvatarUrl,
  });

  String get senderLabel {
    final d = senderDisplayName?.trim();
    if (d != null && d.isNotEmpty) return d;
    final u = senderUsername?.trim();
    if (u != null && u.isNotEmpty) return u;
    return 'Member';
  }

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    dynamic prof = json['profiles'];
    if (prof is List && prof.isNotEmpty) {
      prof = prof.first;
    }
    Map<String, dynamic>? pmap;
    if (prof is Map) {
      pmap = Map<String, dynamic>.from(prof);
    }

    return GroupMessage(
      id: json['id'].toString(),
      groupId: json['group_id'].toString(),
      senderId: json['sender_id'].toString(),
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      senderDisplayName: pmap?['display_name'] as String?,
      senderUsername: pmap?['username'] as String?,
      senderAvatarUrl: pmap?['avatar_url'] as String?,
    );
  }
}

class GroupMember {
  final String id;
  final String role;
  final DateTime joinedAt;
  final GroupMemberUser user;

  GroupMember({
    required this.id,
    required this.role,
    required this.joinedAt,
    required this.user,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'],
      role: json['role'],
      joinedAt: DateTime.parse(json['joined_at']),
      user: GroupMemberUser.fromJson(json['profiles']),
    );
  }
}

class GroupMemberUser {
  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  GroupMemberUser({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory GroupMemberUser.fromJson(Map<String, dynamic> json) {
    return GroupMemberUser(
      id: json['id'],
      username: json['username'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
    );
  }
}

class UserProfile {
  final String id;
  final String? email;
  final String? username;
  final String? fullName;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final DateTime? lastSeen;

  UserProfile({
    required this.id,
    this.email,
    this.username,
    this.fullName,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.locationText,
    this.latitude,
    this.longitude,
    this.lastSeen,
  });

  // Check if user is online (active within last 5 minutes)
  bool get isOnline {
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen!).inMinutes < 5;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      fullName: json['full_name'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      locationText: json['location_text'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'])
          : null,
    );
  }
}
