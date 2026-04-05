import 'package:flutter/material.dart';
import '../colony_theme.dart';
import '../location_service.dart';
import '../data_service.dart';
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
      // Prefer live GPS so nearby lists match your current position (5 km discovery).
      final result = await _locationService.fetchAndUpdateLocation();
      if (result.success &&
          result.latitude != null &&
          result.longitude != null) {
        setState(() {
          _userLocation = UserLocation(
            latitude: result.latitude!,
            longitude: result.longitude!,
            locationText: result.locationText ?? 'Unknown',
          );
        });
      } else {
        final cached = await _locationService.getUserLocation();
        setState(() {
          _userLocation = cached;
          _errorMessage = result.errorMessage ??
              (cached == null
                  ? 'Turn on location permission to see people and groups within 5 km.'
                  : 'Using last saved location. Open location settings for best results.');
        });
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
      radiusKm: DataService.maxNearbyRadiusKm,
    );

    final groups = await _dataService.getNearbyGroups(
      latitude: _userLocation!.latitude,
      longitude: _userLocation!.longitude,
      radiusKm: DataService.maxNearbyRadiusKm,
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
    final c = ColonyColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: c.accent,
          onRefresh: _refreshAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(c),
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
                _buildSearchBar(c),
                const SizedBox(height: 30),
                _buildSectionHeader(c, 'Colony Stories', 'VIEW ALL'),
                const SizedBox(height: 15),
                _buildStoriesList(c),
                const SizedBox(height: 30),
                Text(
                  'Nearby people',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: c.primaryText,
                  ),
                ),
                const SizedBox(height: 15),
                _buildNearbyPeoplesList(c),
                const SizedBox(height: 30),
                _buildSectionHeader(c, 'Nearby Groups', 'JOIN NEW'),
                const SizedBox(height: 15),
                _buildNearbyGroupsList(c),
                const SizedBox(height: 30),
                Text(
                  'Community Highlights',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: c.primaryText,
                  ),
                ),
                const SizedBox(height: 15),
                _buildCommunityHighlightCard(c),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColonyColors c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.headerBadgeBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on, color: c.primaryText, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Colony',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: c.primaryText,
                  ),
                ),
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
        Icon(Icons.notifications, color: c.primaryText),
      ],
    );
  }

  Widget _buildSearchBar(ColonyColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.searchBarFill,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: c.divider.withOpacity(0.6)),
        boxShadow: [
          if (!c.isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              spreadRadius: 2,
            ),
        ],
      ),
      child: TextField(
        style: TextStyle(color: c.primaryText, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search neighbors, groups or events...',
          hintStyle: TextStyle(color: c.secondaryText, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: c.iconMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ColonyColors c, String title, String action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: c.primaryText,
          ),
        ),
        Text(
          action,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: c.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildStoriesList(ColonyColors c) {
    if (_isLoadingStories) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: CircularProgressIndicator(color: c.accent),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildAddStoryBtn(c),
          const SizedBox(width: 15),
          if (_stories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Text('No stories yet', style: TextStyle(color: c.secondaryText)),
            )
          else
            ..._stories.map((story) => Padding(
              padding: const EdgeInsets.only(right: 15),
              child: _buildStoryItem(c, story),
            )),
        ],
      ),
    );
  }

  Widget _buildAddStoryBtn(ColonyColors c) {
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
            child: Icon(Icons.add, color: c.accent, size: 30),
          ),
          const SizedBox(height: 8),
          Text('Add Story', style: TextStyle(fontSize: 12, color: c.secondaryText)),
        ],
      ),
    );
  }

  Widget _buildStoryItem(ColonyColors c, Story story) {
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
            style: TextStyle(
              fontSize: 12,
              color: c.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyPeoplesList(ColonyColors c) {
    if (_isLoadingUsers) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: CircularProgressIndicator(color: c.accent),
        ),
      );
    }

    if (_nearbyUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 48, color: c.iconMuted),
            const SizedBox(height: 10),
            Text(
              _userLocation == null 
                  ? 'Enable location to see nearby people'
                  : 'No people found within 5km',
              style: TextStyle(color: c.secondaryText),
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

  Widget _buildNearbyGroupsList(ColonyColors c) {
    if (_isLoadingGroups) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: CircularProgressIndicator(color: c.accent),
        ),
      );
    }

    if (_nearbyGroups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.group_outlined, size: 48, color: c.iconMuted),
            const SizedBox(height: 10),
            Text(
              _userLocation == null 
                  ? 'Enable location to see nearby groups'
                  : 'No groups found within 5km',
              style: TextStyle(color: c.secondaryText),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _nearbyGroups.take(3).map((group) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: _buildGroupCard(c, group),
        );
      }).toList(),
    );
  }

  Widget _buildGroupCard(ColonyColors c, NearbyGroup group) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.divider.withOpacity(c.isDark ? 0.5 : 0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: c.pillBackground,
            ),
            child: group.coverImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(group.coverImageUrl!, fit: BoxFit.cover),
                  )
                : Icon(Icons.group, color: c.primaryText, size: 30),
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
                        color: c.categoryChipBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        group.category?.toUpperCase() ?? 'GROUP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: c.categoryChipFg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.location_on, size: 12, color: c.iconMuted),
                    Text(
                      group.displayDistance,
                      style: TextStyle(fontSize: 10, color: c.iconMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  group.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${group.memberCount} members',
                  style: TextStyle(fontSize: 12, color: c.secondaryText),
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
              backgroundColor: c.filledButtonBg,
              foregroundColor: c.filledButtonFg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityHighlightCard(ColonyColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.communityBannerTop, c.communityBannerBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: c.isDark ? Border.all(color: c.divider) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to Colony!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect with ${_nearbyUsers.length} neighbors and ${_nearbyGroups.length} groups nearby.',
            style: TextStyle(fontSize: 14, color: c.communityBodyText),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: c.communityCtaFg,
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
          content: Text(
            success
                ? 'Wave sent!'
                : 'Could not send wave — stay within 5 km with location enabled.',
          ),
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
    final c = ColonyColors.of(context);
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
          color: c.rowCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.divider.withOpacity(c.isDark ? 0.4 : 0.2)),
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
                  backgroundColor: c.isDark ? c.pillBackground : Colors.black,
                  backgroundImage: widget.user.avatarUrl != null
                      ? NetworkImage(widget.user.avatarUrl!)
                      : const NetworkImage('https://i.pravatar.cc/150'),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.pillBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 10, color: c.primaryText),
                      const SizedBox(width: 2),
                      Text(
                        widget.user.displayDistance,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: c.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.user.displayName ?? widget.user.username ?? 'User',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: c.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.user.bio ?? 'Colony Member',
              style: TextStyle(fontSize: 12, color: c.secondaryText),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _isLoading
                  ? Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                      ),
                    )
                  : _canChat
                      ? ElevatedButton(
                          onPressed: _openChat,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.filledButtonBg,
                            foregroundColor: c.filledButtonFg,
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
