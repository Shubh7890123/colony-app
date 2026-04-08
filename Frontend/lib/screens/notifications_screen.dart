import 'package:flutter/material.dart';
import '../colony_theme.dart';
import '../data_service.dart';
import 'user_profile_screen.dart';
import 'chat_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final DataService _dataService = DataService();
  List<Wave> _waves = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWaves();
  }

  Future<void> _loadWaves() async {
    setState(() => _isLoading = true);
    final waves = await _dataService.getPendingWaves();
    if (mounted) {
      setState(() {
        _waves = waves;
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptWave(Wave wave) async {
    final success = await _dataService.respondToWave(wave.id, 'accepted');
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request accepted! You can now chat.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadWaves();
    }
  }

  Future<void> _rejectWave(Wave wave) async {
    final success = await _dataService.respondToWave(wave.id, 'rejected');
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request rejected.'),
          backgroundColor: Colors.orange,
        ),
      );
      _loadWaves();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ColonyColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 50,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: c.accent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF1B5A27),
              ),
            )
          : _waves.isEmpty
              ? _buildEmptyState(c)
              : _buildWavesList(c),
    );
  }

  Widget _buildEmptyState(ColonyColors c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 80,
            color: c.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            'No New Notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: c.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When someone sends you a friend request,\nit will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: c.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWavesList(ColonyColors c) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _waves.length,
      itemBuilder: (context, index) {
        final wave = _waves[index];
        return _buildWaveCard(wave, c);
      },
    );
  }

  Widget _buildWaveCard(Wave wave, ColonyColors c) {
    final sender = wave.sender;
    final senderName = sender?.displayName ?? sender?.username ?? 'Unknown User';
    final senderAvatar = sender?.avatarUrl;
    final timeAgo = _getTimeAgo(wave.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with sender info
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(userId: sender?.id ?? wave.senderId),
                ),
              );
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c.accent.withValues(alpha: 0.2), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundImage: senderAvatar != null
                          ? NetworkImage(senderAvatar)
                          : const NetworkImage('https://i.pravatar.cc/150'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name and time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                senderName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: c.primaryText,
                                ),
                              ),
                            ),
                            Text(
                              timeAgo,
                              style: TextStyle(
                                fontSize: 12,
                                color: c.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_add_outlined,
                              size: 16,
                              color: c.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'sent you a friend request',
                              style: TextStyle(
                                fontSize: 14,
                                color: c.secondaryText,
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
          // Bio preview if available
          if (sender?.bio != null && sender!.bio!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.pillBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sender.bio!,
                  style: TextStyle(
                    fontSize: 13,
                    color: c.primaryText,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectWave(wave),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptWave(wave),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).brightness ==
                              Brightness.dark
                          ? Colors.white
                          : const Color(0xFF1B5A27),
                      foregroundColor: Theme.of(context).brightness ==
                              Brightness.dark
                          ? Colors.black
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
