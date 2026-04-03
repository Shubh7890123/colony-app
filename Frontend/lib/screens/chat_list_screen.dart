import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data_service.dart';
import '../supabase_service.dart';
import 'chat_detail_screen.dart';
import 'user_profile_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final DataService _dataService = DataService();
  
  List<Conversation> _conversations = [];
  List<Wave> _pendingWaves = [];
  bool _isLoading = true;
  bool _isLoadingWaves = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadPendingWaves();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
    });

    final conversations = await _dataService.getConversations();
    
    setState(() {
      _conversations = conversations;
      _isLoading = false;
    });
  }

  Future<void> _loadPendingWaves() async {
    setState(() {
      _isLoadingWaves = true;
    });

    final waves = await _dataService.getPendingWaves();

    setState(() {
      _pendingWaves = waves;
      _isLoadingWaves = false;
    });
  }

  List<Conversation> get _filteredConversations {
    if (_searchQuery.isEmpty) return _conversations;
    return _conversations.where((conv) {
      final name = conv.otherUser?.displayName ?? 
                   conv.otherUser?.username ?? 
                   'Unknown';
      return name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      // Today - show time
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
      final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '${hour == 0 ? 12 : hour}:${dateTime.minute.toString().padLeft(2, '0')} $ampm';
    } else if (difference.inDays == 1) {
      return 'YESTERDAY';
    } else if (difference.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1].toUpperCase();
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  void _navigateToChat(Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          conversationId: conversation.id,
          otherUserName: conversation.otherUser?.displayName ?? 
                          conversation.otherUser?.username ?? 
                          'User',
          otherUserAvatar: conversation.otherUser?.avatarUrl,
          otherUserId: conversation.otherUser?.id,
        ),
      ),
    ).then((_) => _loadConversations());
  }

  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7ED),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildSearchBar(),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2E6B3B),
                      ),
                    )
                        : Column(
                            children: [
                              _buildPendingWavesSection(),
                              Expanded(child: _buildConversationsList()),
                            ],
                          ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Show new message screen to search users
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('New message feature coming soon!'),
              backgroundColor: Color(0xFF2E6B3B),
            ),
          );
        },
        backgroundColor: const Color(0xFF1E5631),
        elevation: 2,
        child: const Icon(Icons.edit_square, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildPendingWavesSection() {
    if (_isLoadingWaves) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: LinearProgressIndicator(color: Color(0xFF2E6B3B)),
      );
    }

    if (_pendingWaves.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pending waves',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E30),
              ),
            ),
            const SizedBox(height: 8),
            ..._pendingWaves.map((wave) {
              final sender = wave.sender;
              final senderName =
                  sender?.displayName ?? sender?.username ?? 'User';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: sender?.avatarUrl != null
                          ? NetworkImage(sender!.avatarUrl!)
                          : const NetworkImage('https://i.pravatar.cc/150'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        senderName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C3E30),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Accept',
                          onPressed: () async {
                            final ok =
                                await _dataService.respondToWave(wave.id, 'accepted');
                            if (!mounted) return;
                            if (ok) {
                              await _loadPendingWaves();
                              await _loadConversations();
                            }
                          },
                          icon: const Icon(Icons.check, color: Color(0xFF1B5A27)),
                        ),
                        IconButton(
                          tooltip: 'Reject',
                          onPressed: () async {
                            final ok =
                                await _dataService.respondToWave(wave.id, 'rejected');
                            if (!mounted) return;
                            if (ok) {
                              await _loadPendingWaves();
                              await _loadConversations();
                            }
                          },
                          icon: const Icon(Icons.close, color: Color(0xFFB00020)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.location_on, color: Color(0xFF14471E), size: 20),
              SizedBox(width: 8),
              Text(
                'Colony',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF14471E),
                ),
              ),
            ],
          ),
          StreamBuilder<AuthState>(
            stream: SupabaseService().client.auth.onAuthStateChange,
            builder: (context, snapshot) {
              final user = snapshot.data?.session?.user;
              final avatarUrl = user?.userMetadata?['avatar_url'];
              return GestureDetector(
                onTap: () {
                  if (user != null) {
                    _navigateToUserProfile(user.id);
                  }
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : const NetworkImage('https://i.pravatar.cc/150'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: const InputDecoration(
            hintText: 'Search conversations...',
            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsList() {
    final conversations = _filteredConversations;
    
    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty 
                  ? 'No conversations yet'
                  : 'No conversations found',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (_searchQuery.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Wave at nearby people to start chatting!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: const Color(0xFF2E6B3B),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          return _buildConversationTile(conversation);
        },
      ),
    );
  }

  Widget _buildConversationTile(Conversation conversation) {
    final otherUser = conversation.otherUser;
    final lastMessage = conversation.lastMessage;
    final displayName = otherUser?.displayName ?? 
                        otherUser?.username ?? 
                        'Unknown User';
    final avatarUrl = otherUser?.avatarUrl;
    final time = conversation.lastMessageAt != null 
        ? _formatTime(conversation.lastMessageAt!) 
        : '';

    return GestureDetector(
      onTap: () => _navigateToChat(conversation),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: conversation.unreadCount > 0 
              ? const Color(0xFFE6F3E6) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          children: [
            // Avatar
            GestureDetector(
              onTap: () {
                if (otherUser != null) {
                  _navigateToUserProfile(otherUser.id);
                }
              },
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : const NetworkImage('https://i.pravatar.cc/150'),
                  ),
                  // Online indicator (you can implement real online status later)
                  if (otherUser != null)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: conversation.unreadCount > 0 
                                ? const Color(0xFFE6F3E6) 
                                : const Color(0xFFF2F7ED),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E30),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage?.content ?? 'Start a conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E5631),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            conversation.unreadCount > 9 
                                ? '9+' 
                                : conversation.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
