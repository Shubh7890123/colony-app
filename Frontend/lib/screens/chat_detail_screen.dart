import 'package:flutter/material.dart';
import '../data_service.dart';
import '../supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Message> _messages = [];
  bool _isLoading = true;
  String? _conversationId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    // If no conversation ID, try to get or create one
    if (_conversationId == null && widget.otherUserId != null) {
      final conv = await _dataService.getOrCreateConversation(widget.otherUserId!);
      if (conv != null) {
        _conversationId = conv.id;
      }
    }

    if (_conversationId != null) {
      final messages = await _dataService.getMessages(_conversationId!);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
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

    final message = await _dataService.sendMessage(
      conversationId: _conversationId!,
      content: content,
    );

    if (message != null) {
      setState(() {
        _messages.add(message);
        _isSending = false;
      });
      _scrollToBottom();
    } else {
      setState(() {
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
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
      backgroundColor: const Color(0xFFF2F7ED),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: _buildAppBar(),
      ),
      body: Column(
        children: [
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

  Widget _buildAppBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1E5631)),
              onPressed: () => Navigator.pop(context),
            ),
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: widget.otherUserAvatar != null
                      ? NetworkImage(widget.otherUserAvatar!)
                      : const NetworkImage('https://i.pravatar.cc/150'),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF2F7ED), width: 2),
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
                    widget.otherUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E30),
                    ),
                  ),
                  const Text(
                    'ONLINE NOW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Color(0xFF2C3E30)),
              onPressed: () {},
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
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Say hello to ${widget.otherUserName}!',
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
              _buildOutgoingMsg(message.content, _formatTime(message.createdAt))
            else
              _buildIncomingMsg(
                message.content,
                _formatTime(message.createdAt),
                widget.otherUserAvatar,
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
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutgoingMsg(String msg, String time) {
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
                      Icons.done_all,
                      size: 14,
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
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add,
              color: Color(0xFF1E5631),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7ED),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey),
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
