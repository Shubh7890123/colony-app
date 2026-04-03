import 'package:flutter/material.dart';
import '../data_service.dart';
import '../location_service.dart';
import 'chat_detail_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final DataService _dataService = DataService();
  final LocationService _locationService = LocationService();
  
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isWaving = false;
  bool _hasWaved = false;
  bool _canChat = false;
  String? _waveStatus;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    
    final profile = await _dataService.getUserProfile(widget.userId);
    final canChat = await _dataService.canChatWith(widget.userId);
    
    if (!mounted) return;
    setState(() {
      _userProfile = profile;
      _canChat = canChat;
      _isLoading = false;
    });
  }

  Future<void> _sendWave() async {
    setState(() => _isWaving = true);
    
    final success = await _dataService.sendWave(widget.userId);
    
    setState(() {
      _isWaving = false;
      if (success) {
        _hasWaved = true;
        _waveStatus = 'pending';
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Wave sent! Waiting for response.' : 'Failed to send wave'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F7ED),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF14471E)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF14471E)),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5A27)))
          : _userProfile == null
              ? const Center(child: Text('User not found'))
              : _buildProfile(),
    );
  }

  Widget _buildProfile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Profile Avatar
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF17F36), Color(0xFF2E6B3B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F7ED),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: CircleAvatar(
                    backgroundImage: _userProfile!.avatarUrl != null
                        ? NetworkImage(_userProfile!.avatarUrl!)
                        : const NetworkImage('https://i.pravatar.cc/200'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            _userProfile!.displayName ?? _userProfile!.username ?? 'User',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2C3E30),
            ),
          ),
          const SizedBox(height: 4),
          // Username
          if (_userProfile!.username != null)
            Text(
              '@${_userProfile!.username}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 4),
          // Location
          if (_userProfile!.locationText != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 16),
                const SizedBox(width: 4),
                Text(
                  _userProfile!.locationText!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          // Bio
          if (_userProfile!.bio != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _userProfile!.bio!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2C3E30),
                  height: 1.5,
                ),
              ),
            ),
          const SizedBox(height: 24),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _canChat
                    ? ElevatedButton.icon(
                        onPressed: () async {
                          final conv = await _dataService
                              .getOrCreateConversation(widget.userId);
                          if (!mounted) return;
                          if (conv == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Unable to open chat right now'),
                              ),
                            );
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatDetailScreen(
                                conversationId: conv.id,
                                otherUserId: widget.userId,
                                otherUserName: _userProfile!.displayName ??
                                    _userProfile!.username ??
                                    'User',
                                otherUserAvatar: _userProfile!.avatarUrl,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Message'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5A27),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _isWaving || _hasWaved ? null : _sendWave,
                        icon: _isWaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(_hasWaved ? Icons.check : Icons.waving_hand),
                        label: Text(_hasWaved 
                            ? (_waveStatus == 'accepted' ? 'Connected' : 'Wave Sent')
                            : 'Wave'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF17F36),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Add to contacts or other action
                  },
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Connect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1B5A27),
                    side: const BorderSide(color: Color(0xFF1B5A27)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Stats
          _buildStatsRow(),
          const SizedBox(height: 24),
          // Info Card
          _buildInfoCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('Groups', '0'),
        Container(height: 40, width: 1, color: Colors.grey.shade300),
        _buildStatItem('Connections', '0'),
        Container(height: 40, width: 1, color: Colors.grey.shade300),
        _buildStatItem('Waves', '0'),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E30),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E30),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.email_outlined, 'Email', _userProfile!.email ?? 'Not available'),
          if (_userProfile!.locationText != null)
            _buildInfoRow(Icons.location_on_outlined, 'Location', _userProfile!.locationText!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1B5A27), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2C3E30),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
