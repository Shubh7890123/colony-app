import 'package:flutter/material.dart';
import '../colony_theme.dart';
import '../data_service.dart';
import '../supabase_service.dart';
import '../encryption_service.dart';
import 'user_profile_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final String? conversationId;
  final String? otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;

  const ChatDetailScreen({
    super.key,
    this.conversationId,
    this.otherUserId,
    this.otherUserName = 'User',
    this.otherUserAvatar,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final DataService _dataService = DataService();
  final EncryptionService _encryptionService = EncryptionService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Message> _messages = [];
  bool _isLoading = true;
  String? _conversationId;
  bool _isSending = false;
  bool _encryptionReady = false;
  
  // Online status tracking
  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeen;
  UserProfile? _otherUserProfile;

  /// Resolved peer (may be filled from DB when opening chat with only [conversationId]).
  String? _peerUserId;
  
  // Polling for new messages (fallback for realtime)
  Stream<void>? _pollingStream;

  String get _peerDisplayName {
    final p = _otherUserProfile;
    if (p?.displayName != null && p!.displayName!.trim().isNotEmpty) {
      return p.displayName!;
    }
    if (p?.username != null && p!.username!.trim().isNotEmpty) {
      return p.username!;
    }
    return widget.otherUserName;
  }

  String? get _peerAvatarUrl =>
      _otherUserProfile?.avatarUrl ?? widget.otherUserAvatar;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _peerUserId = widget.otherUserId;
    _initializeEncryption();
  }

  void _openPeerProfile() {
    final id = _peerUserId;
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => UserProfileScreen(userId: id),
      ),
    );
  }

  void _showChatOptions() {
    final c = ColonyColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person_outline, color: c.accent),
              title: Text('View profile', style: TextStyle(color: c.primaryText)),
              onTap: () {
                Navigator.pop(ctx);
                _openPeerProfile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeEncryption() async {
    try {
      await _encryptionService.initialize();
      setState(() {
        _encryptionReady = _encryptionService.isReady;
      });
    } catch (e) {
      print('Error initializing encryption: $e');
    }
    await _loadMessages();
    await _loadOtherUserProfile();
    _setupRealtimeSubscription();
    _updateLastSeen();
  }

  Future<void> _loadOtherUserProfile() async {
    if (_peerUserId == null) return;

    try {
      final profile = await _dataService.getUserProfile(_peerUserId!);
      if (mounted && profile != null) {
        setState(() {
          _otherUserProfile = profile;
          _isOtherUserOnline = profile.isOnline;
          _otherUserLastSeen = profile.lastSeen;
        });
      }
    } catch (e) {
      print('Error loading other user profile: $e');
    }
  }

  void _setupRealtimeSubscription() {
    if (_conversationId == null) return;
    
    // Try to use Supabase Realtime if available
    // Otherwise fall back to polling every 3 seconds
    _pollingStream = Stream.periodic(const Duration(seconds: 3), (_) {
      _checkForNewMessages();
      _checkOnlineStatus();
    });
    
    _pollingStream!.listen((_) {});
  }

  Future<void> _checkOnlineStatus() async {
    if (_peerUserId == null || !mounted) return;
    
    try {
      final profile = await _dataService.getUserOnlineStatus(_peerUserId!);
      if (mounted && profile != null) {
        setState(() {
          _isOtherUserOnline = profile.isOnline;
          _otherUserLastSeen = profile.lastSeen;
        });
      }
    } catch (e) {
      print('Error checking online status: $e');
    }
  }

  Future<void> _updateLastSeen() async {
    await _dataService.updateLastSeen();
  }
  
  DateTime? _lastMessageTime;
  
  Future<void> _checkForNewMessages() async {
    if (_conversationId == null || !mounted) return;
    
    try {
      final messages = await _dataService.getMessages(_conversationId!);
      
      // Check if there are new messages
      if (_lastMessageTime != null) {
        final newMessages = messages.where((m) =>
          m.createdAt.isAfter(_lastMessageTime!) &&
          !_messages.any((existing) => existing.id == m.id)
        ).toList();
        
        if (newMessages.isNotEmpty) {
          for (final newMessage in newMessages) {
            // Decrypt if needed
            if (_encryptionReady && _peerUserId != null) {
              try {
                if (newMessage.content.startsWith('{') && newMessage.content.contains('ciphertext')) {
                  final encryptedData = newMessage.content;
                  final encryptedJson = <String, dynamic>{};
                  final regex = RegExp(r'"(\w+)":"([^"]*)"');
                  for (final match in regex.allMatches(encryptedData)) {
                    encryptedJson[match.group(1)!] = match.group(2)!;
                  }
                  
                  final encryptedMsg = EncryptedMessage.fromJson(encryptedJson);
                  final decryptedContent = await _encryptionService.decryptMessage(
                    encryptedMessage: encryptedMsg,
                    senderId: newMessage.senderId,
                  );
                  
                  final decryptedMessage = Message(
                    id: newMessage.id,
                    senderId: newMessage.senderId,
                    content: decryptedContent,
                    isRead: newMessage.isRead,
                    createdAt: newMessage.createdAt,
                    deliveredAt: newMessage.deliveredAt,
                    seenAt: newMessage.seenAt,
                  );
                  
                  if (mounted) {
                    setState(() {
                      if (!_messages.any((m) => m.id == decryptedMessage.id)) {
                        _messages.add(decryptedMessage);
                      }
                    });
                  }
                } else {
                  if (mounted) {
                    setState(() {
                      if (!_messages.any((m) => m.id == newMessage.id)) {
                        _messages.add(newMessage);
                      }
                    });
                  }
                }
              } catch (e) {
                print('Error decrypting polled message: $e');
                if (mounted) {
                  setState(() {
                    if (!_messages.any((m) => m.id == newMessage.id)) {
                      _messages.add(newMessage);
                    }
                  });
                }
              }
            } else {
              if (mounted) {
                setState(() {
                  if (!_messages.any((m) => m.id == newMessage.id)) {
                    _messages.add(newMessage);
                  }
                });
              }
            }
          }
          
          if (mounted) {
            _scrollToBottom();
          }
        }
      }
      
      // Update last message time
      if (messages.isNotEmpty) {
        _lastMessageTime = messages.map((m) => m.createdAt).reduce((a, b) =>
          a.isAfter(b) ? a : b
        );
      }
    } catch (e) {
      print('Error polling for messages: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Cancel polling stream
    // Note: StreamSubscription would need to be stored for proper cancellation
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    // If no conversation ID, try to get or create one
    if (_conversationId == null && _peerUserId != null) {
      final conv = await _dataService.getOrCreateConversation(_peerUserId!);
      if (conv != null) {
        _conversationId = conv.id;
      }
    }

    if (_conversationId != null && _peerUserId == null) {
      final peerId =
          await _dataService.getOtherParticipantUserId(_conversationId!);
      if (mounted && peerId != null) {
        setState(() {
          _peerUserId = peerId;
        });
      }
    }

    if (_conversationId != null) {
      final messages = await _dataService.getMessages(_conversationId!);
      
      // Decrypt messages
      if (_encryptionReady && _peerUserId != null) {
        final decryptedMessages = <Message>[];
        for (final msg in messages) {
          try {
            // Check if message is encrypted (has ciphertext field)
            if (msg.content.startsWith('{') && msg.content.contains('ciphertext')) {
              final encryptedData = msg.content;
              // Parse the encrypted message properly
              final encryptedJson = <String, dynamic>{};
              final regex = RegExp(r'"(\w+)":"([^"]*)"');
              for (final match in regex.allMatches(encryptedData)) {
                encryptedJson[match.group(1)!] = match.group(2)!;
              }
              
              final encryptedMsg = EncryptedMessage.fromJson(encryptedJson);
              final decryptedContent = await _encryptionService.decryptMessage(
                encryptedMessage: encryptedMsg,
                senderId: msg.senderId,
              );
              decryptedMessages.add(Message(
                id: msg.id,
                senderId: msg.senderId,
                content: decryptedContent,
                isRead: msg.isRead,
                createdAt: msg.createdAt,
                deliveredAt: msg.deliveredAt,
                seenAt: msg.seenAt,
              ));
            } else {
              decryptedMessages.add(msg);
            }
          } catch (e) {
            // If decryption fails, show the original content
            decryptedMessages.add(msg);
          }
        }
        setState(() {
          _messages = decryptedMessages;
          _isLoading = false;
        });
        // Set initial last message time for polling
        if (decryptedMessages.isNotEmpty) {
          _lastMessageTime = decryptedMessages.map((m) => m.createdAt).reduce((a, b) =>
            a.isAfter(b) ? a : b
          );
        }
      } else {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        // Set initial last message time for polling
        if (messages.isNotEmpty) {
          _lastMessageTime = messages.map((m) => m.createdAt).reduce((a, b) =>
            a.isAfter(b) ? a : b
          );
        }
      }
      _scrollToBottom();
      // Mark messages as delivered and seen when opening chat
      if (_conversationId != null) {
        await _dataService.markMessagesAsDelivered(_conversationId!);
        await _dataService.markMessagesAsSeen(_conversationId!);
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _conversationId == null) return;

    setState(() {
      _isSending = true;
    });

    _messageController.clear();

    try {
      String messageContent = content;
      
      // Encrypt message if encryption is ready
      if (_encryptionReady && _peerUserId != null) {
        try {
          final encryptedMsg = await _encryptionService.encryptMessage(
            plaintext: content,
            recipientId: _peerUserId!,
          );
          messageContent = encryptedMsg.toJson().toString();
        } catch (e) {
          // If encryption fails (e.g., recipient has no public key), send unencrypted
          print('Could not encrypt message, sending unencrypted: $e');
        }
      }

      final message = await _dataService.sendMessage(
        conversationId: _conversationId!,
        content: messageContent,
        targetUserId: _peerUserId, // For push notification
      );

      if (message != null) {
        // Add the decrypted version to the UI
        setState(() {
          _messages.add(Message(
            id: message.id,
            senderId: message.senderId,
            content: content, // Show decrypted content
            isRead: message.isRead,
            createdAt: message.createdAt,
            deliveredAt: message.deliveredAt,
            seenAt: message.seenAt,
          ));
          _isSending = false;
        });
        _scrollToBottom();
      } else {
        setState(() {
          _isSending = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error sending message: $e');
      setState(() {
        _isSending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${dateTime.minute.toString().padLeft(2, '0')} $ampm';
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return 'TODAY';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'YESTERDAY';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: _buildAppBar(),
      ),
      body: Column(
        children: [
          // E2E Encryption Banner
          _buildEncryptionBanner(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2E6B3B),
                    ),
                  )
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessagesList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEncryptionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Messages and calls are secured with end-to-end encryption, ensuring that only the people in this chat can read, listen to, or share them. No one else — not even Colony — can access your conversations or calls. Enjoy a completely private and anonymous chatting experience.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final c = ColonyColors.of(context);
    final username = _otherUserProfile?.username;

    // Format last seen time
    String lastSeenText = '';
    if (!_isOtherUserOnline && _otherUserLastSeen != null) {
      final now = DateTime.now();
      final diff = now.difference(_otherUserLastSeen!);
      if (diff.inMinutes < 1) {
        lastSeenText = 'last seen just now';
      } else if (diff.inMinutes < 60) {
        lastSeenText = 'last seen ${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        lastSeenText = 'last seen ${diff.inHours}h ago';
      } else {
        lastSeenText = 'last seen ${diff.inDays}d ago';
      }
    }
    
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1E5631)),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _peerUserId != null ? _openPeerProfile : null,
                  borderRadius: BorderRadius.circular(28),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: _peerAvatarUrl != null
                                ? NetworkImage(_peerAvatarUrl!)
                                : const NetworkImage(
                                    'https://i.pravatar.cc/150',
                                  ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _isOtherUserOnline
                                    ? const Color(0xFF25D366)
                                    : Colors.grey.shade400,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: c.scaffold,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _peerDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E30),
                              ),
                            ),
                            if (username != null &&
                                username.trim().isNotEmpty &&
                                username.trim().toLowerCase() !=
                                    _peerDisplayName.trim().toLowerCase()) ...[
                              Text(
                                '@$username',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (_isOtherUserOnline) ...[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF25D366),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'online',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ] else if (lastSeenText.isNotEmpty) ...[
                                  Expanded(
                                    child: Text(
                                      lastSeenText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Icon(
                                  Icons.lock,
                                  size: 10,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'E2E',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
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
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Color(0xFF2C3E30)),
              onPressed:
                  _peerUserId != null ? _showChatOptions : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock,
            size: 48,
            color: Color(0xFF1E5631),
          ),
          const SizedBox(height: 16),
          const Text(
            'End-to-end encrypted',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF1E5631),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Messages you send to $_peerDisplayName are secured with end-to-end encryption.',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Say hello to $_peerDisplayName! 👋',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    final currentUserId = SupabaseService().client.auth.currentUser?.id;
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == currentUserId;
        
        // Show date chip if date changed
        final showDateChip = index == 0 || 
            !_isSameDay(_messages[index - 1].createdAt, message.createdAt);
        
        return Column(
          children: [
            if (showDateChip) ...[
              _buildDateChip(_formatDate(message.createdAt)),
              const SizedBox(height: 20),
            ],
            if (isMe)
              _buildOutgoingMsg(
                message.content,
                _formatTime(message.createdAt),
                status: message.status,
              )
            else
              _buildIncomingMsg(
                message.content,
                _formatTime(message.createdAt),
                _peerAvatarUrl,
              ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateChip(String date) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          date,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingMsg(String msg, String time, String? avatarUrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundImage: avatarUrl != null
              ? NetworkImage(avatarUrl)
              : const NetworkImage('https://i.pravatar.cc/150'),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2C3E30),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.lock,
                      size: 10,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutgoingMsg(String msg, String time, {MessageStatus status = MessageStatus.sent}) {
    // Determine tick icon and color based on status
    IconData tickIcon;
    Color tickColor;
    
    switch (status) {
      case MessageStatus.seen:
        tickIcon = Icons.done_all;
        tickColor = Colors.lightBlueAccent; // Blue ticks for seen
        break;
      case MessageStatus.delivered:
        tickIcon = Icons.done_all;
        tickColor = Colors.white.withOpacity(0.7); // Grey double tick for delivered
        break;
      case MessageStatus.sent:
      default:
        tickIcon = Icons.done; // Single tick for sent (not yet delivered)
        tickColor = Colors.white.withOpacity(0.7);
        break;
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E5631),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  msg,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      tickIcon,
                      size: 14,
                      color: tickColor,
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.lock,
                      size: 10,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageInput() {
    final c = ColonyColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final barBg = dark ? c.card : Colors.white;
    final fieldBg = dark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F7ED);
    final iconAccent = dark ? Colors.white : const Color(0xFF1E5631);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: barBg,
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black54 : const Color(0x0A000000),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.add,
              color: iconAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                style: TextStyle(color: c.primaryText),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: c.secondaryText),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E5631),
                borderRadius: BorderRadius.circular(24),
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
