import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../location_service.dart';
import '../data_service.dart';
import '../supabase_service.dart';
import 'user_profile_screen.dart';
import 'chat_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DataService _dataService = DataService();
  final LocationService _locationService = LocationService();
  
  UserLocation? _userLocation;
  List<NearbyUser> _nearbyUsers = [];
  List<NearbyGroup> _nearbyGroups = [];
  List<Story> _stories = [];
  
  bool _isLoadingLocation = true;
  bool _isLoadingUsers = false;
  bool _isLoadingGroups = false;
  bool _isLoadingStories = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchLocation();
    if (_userLocation != null) {
      _fetchNearbyData();
    }
    _fetchStories();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
    });

    try {
      // Try to get existing location first
      final existingLocation = await _locationService.getUserLocation();
      
      if (existingLocation != null) {
        setState(() {
          _userLocation = existingLocation;
          _isLoadingLocation = false;
        });
      } else {
        // Fetch new location
        final result = await _locationService.fetchAndUpdateLocation();
        if (result.success) {
          setState(() {
            _userLocation = UserLocation(
              latitude: result.latitude!,
              longitude: result.longitude!,
              locationText: result.locationText!,
            );
          });
        } else {
          setState(() {
            _errorMessage = result.errorMessage;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not fetch location: $e';
      });
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _fetchNearbyData() async {
    if (_userLocation == null) return;

    setState(() {
      _isLoadingUsers = true;
      _isLoadingGroups = true;
    });

    final users = await _dataService.getNearbyUsers(
      latitude: _userLocation!.latitude,
      longitude: _userLocation!.longitude,
      radiusKm: 5.0,
    );

    final groups = await _dataService.getNearbyGroups(
      latitude: _userLocation!.latitude,
      longitude: _userLocation!.longitude,
      radiusKm: 5.0,
    );

    setState(() {
      _nearbyUsers = users;
      _nearbyGroups = groups;
      _isLoadingUsers = false;
      _isLoadingGroups = false;
    });
  }

  Future<void> _fetchStories() async {
    setState(() {
      _isLoadingStories = true;
    });

    final stories = await _dataService.getActiveStories();
    setState(() {
      _stories = stories;
      _isLoadingStories = false;
    });
  }

  Future<void> _refreshAll() async {
    await _initializeData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7ED),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withOpacity(0.25)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                _buildSearchBar(),
                const SizedBox(height: 30),
                _buildSectionHeader('Colony Stories', 'VIEW ALL'),
                const SizedBox(height: 15),
                _buildStoriesList(),
                const SizedBox(height: 30),
                const Text('Nearby Peoples',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E30))),
                const SizedBox(height: 15),
                _buildNearbyPeoplesList(),
                const SizedBox(height: 30),
                _buildSectionHeader('Nearby Groups', 'JOIN NEW'),
                const SizedBox(height: 15),
                _buildNearbyGroupsList(),
                const SizedBox(height: 30),
                const Text('Community Highlights',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E30))),
                const SizedBox(height: 15),
                _buildCommunityHighlightCard(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFA3E9A5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on, color: Color(0xFF14471E), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Colony',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF14471E))),
                if (_isLoadingLocation)
                  const Text('Fetching location...',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey))
                else if (_userLocation != null)
                  Text(_userLocation!.locationText,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey))
                else
                  GestureDetector(
                    onTap: _fetchLocation,
                    child: const Row(
                      children: [
                        Icon(Icons.refresh, size: 12, color: Colors.orange),
                        SizedBox(width: 4),
                        Text('Tap to fetch location',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        const Icon(Icons.notifications, color: Color(0xFF14471E)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'Search neighbors, groups or events...',
          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E30))),
        Text(action,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E6B3B))),
      ],
    );
  }

  Widget _buildStoriesList() {
    if (_isLoadingStories) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: Color(0xFF1B5A27)),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildAddStoryBtn(),
          const SizedBox(width: 15),
          if (_stories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Text('No stories yet', style: TextStyle(color: Colors.grey)),
            )
          else
            ..._stories.map((story) => Padding(
              padding: const EdgeInsets.only(right: 15),
              child: _buildStoryItem(story),
            )),
        ],
      ),
    );
  }

  Widget _buildAddStoryBtn() {
    return GestureDetector(
      onTap: () {
        // TODO: Implement add story
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add story feature coming soon!')),
        );
      },
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade400, width: 2, style: BorderStyle.solid),
            ),
            child: const Icon(Icons.add, color: Color(0xFF2E6B3B), size: 30),
          ),
          const SizedBox(height: 8),
          const Text('Add Story', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStoryItem(Story story) {
    return GestureDetector(
      onTap: () {
        // TODO: View story
      },
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF17F36), width: 3),
            ),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              backgroundImage: story.user.avatarUrl != null
                  ? NetworkImage(story.user.avatarUrl!)
                  : const NetworkImage('https://i.pravatar.cc/150'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            story.user.username ?? story.user.displayName ?? 'User',
            style: const TextStyle(fontSize: 12, color: Color(0xFF2C3E30), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyPeoplesList() {
    if (_isLoadingUsers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: Color(0xFF1B5A27)),
        ),
      );
    }

    if (_nearbyUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.people_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 10),
            Text(
              _userLocation == null 
                  ? 'Enable location to see nearby people'
                  : 'No people found within 5km',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _nearbyUsers.map((user) {
          return Padding(
            padding: const EdgeInsets.only(right: 15),
            child: _buildPeopleCard(user),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPeopleCard(NearbyUser user) {
    return _PeopleCard(
      user: user,
      dataService: _dataService,
    );
  }

  Widget _buildNearbyGroupsList() {
    if (_isLoadingGroups) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: Color(0xFF1B5A27)),
        ),
      );
    }

    if (_nearbyGroups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.group_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 10),
            Text(
              _userLocation == null 
                  ? 'Enable location to see nearby groups'
                  : 'No groups found within 5km',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _nearbyGroups.take(3).map((group) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: _buildGroupCard(group),
        );
      }).toList(),
    );
  }

  Widget _buildGroupCard(NearbyGroup group) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFE8F2E4),
            ),
            child: group.coverImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(group.coverImageUrl!, fit: BoxFit.cover),
                  )
                : const Icon(Icons.group, color: Color(0xFF1B5A27), size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA3E9A5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        group.category?.toUpperCase() ?? 'GROUP',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF14471E)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.location_on, size: 12, color: Colors.grey.shade600),
                    Text(group.displayDistance, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  group.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E30)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${group.memberCount} members',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await _dataService.joinGroup(group.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Joined ${group.name}!' : 'Failed to join group'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
                if (success) {
                  _fetchNearbyData();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5A27),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityHighlightCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5A27), Color(0xFF2E6B3B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Welcome to Colony!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text(
              'Connect with ${_nearbyUsers.length} neighbors and ${_nearbyGroups.length} groups nearby.',
              style: const TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1B5A27),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Explore Community'),
          ),
        ],
      ),
    );
  }
}

// People card widget with wave status and message button
class _PeopleCard extends StatefulWidget {
  final NearbyUser user;
  final DataService dataService;

  const _PeopleCard({
    required this.user,
    required this.dataService,
  });

  @override
  State<_PeopleCard> createState() => _PeopleCardState();
}

class _PeopleCardState extends State<_PeopleCard> {
  String? _waveStatus;
  bool _canChat = false;
  bool _isLoading = true;
  bool _isWaving = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final waveStatus = await widget.dataService.getWaveStatus(widget.user.id);
    final canChat = await widget.dataService.canChatWith(widget.user.id);
    if (mounted) {
      setState(() {
        _waveStatus = waveStatus;
        _canChat = canChat;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendWave() async {
    setState(() => _isWaving = true);
    final success = await widget.dataService.sendWave(widget.user.id);
    if (mounted) {
      if (success) {
        await _loadStatus();
      }
      setState(() => _isWaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Wave sent!' : 'Failed to send wave'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _openChat() async {
    final conv = await widget.dataService.getOrCreateConversation(widget.user.id);
    if (!mounted) return;
    if (conv == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open chat right now')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          conversationId: conv.id,
          otherUserId: widget.user.id,
          otherUserName: widget.user.displayName ?? widget.user.username ?? 'User',
          otherUserAvatar: widget.user.avatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(userId: widget.user.id),
          ),
        ).then((_) => _loadStatus()); // Refresh status when returning
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F2E4),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.black,
                  backgroundImage: widget.user.avatarUrl != null
                      ? NetworkImage(widget.user.avatarUrl!)
                      : const NetworkImage('https://i.pravatar.cc/150'),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 10, color: Color(0xFF14471E)),
                      const SizedBox(width: 2),
                      Text(widget.user.displayDistance,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF14471E))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.user.displayName ?? widget.user.username ?? 'User',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E30)),
            ),
            const SizedBox(height: 4),
            Text(
              widget.user.bio ?? 'Colony Member',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B5A27)),
                      ),
                    )
                  : _canChat
                      ? ElevatedButton(
                          onPressed: _openChat,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5A27),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Message', style: TextStyle(fontSize: 12)),
                        )
                      : ElevatedButton(
                          onPressed: _isWaving || _waveStatus == 'pending' ? null : _sendWave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF17F36),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: _isWaving
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  _waveStatus == 'pending' ? 'Wave Sent' : 'Wave',
                                  style: const TextStyle(fontSize: 12),
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
