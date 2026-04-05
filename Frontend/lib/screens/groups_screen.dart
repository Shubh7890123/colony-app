import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../colony_theme.dart';
import '../data_service.dart';
import '../location_service.dart';
import '../supabase_service.dart';
import '../storage_service.dart';
import 'group_chat_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DataService _dataService = DataService();
  
  List<NearbyGroup> _nearbyGroups = [];
  List<NearbyGroup> _myGroups = [];
  bool _isLoading = true;
  String _locationText = 'Fetching location...';
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Get user's location
    final locationResult = await LocationService().fetchAndUpdateLocation();
    if (locationResult.success && locationResult.locationText != null) {
      setState(() {
        _locationText = locationResult.locationText!;
        _latitude = locationResult.latitude;
        _longitude = locationResult.longitude;
      });
    }

    // Fetch groups
    await _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    List<NearbyGroup> nearbyGroups = [];
    if (_latitude != null && _longitude != null) {
      nearbyGroups = await _dataService.getNearbyGroups(
        latitude: _latitude!,
        longitude: _longitude!,
        radiusKm: DataService.maxNearbyRadiusKm,
      );
    }

    // Always load memberships — do not depend on GPS (fixes empty "My groups").
    final myGroups = await _dataService.getMyJoinedGroups();

    if (!mounted) return;
    setState(() {
      _nearbyGroups = nearbyGroups;
      _myGroups = myGroups;
      _isLoading = false;
    });
  }

  void _openGroupChat(NearbyGroup group) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => GroupChatScreen(
          groupId: group.id,
          groupName: group.name,
          coverImageUrl: group.coverImageUrl,
        ),
      ),
    ).then((_) => _fetchGroups());
  }

  Future<void> _joinGroup(NearbyGroup group) async {
    final success = await _dataService.joinGroup(group.id);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully joined ${group.name}')),
        );
        _tabController.animateTo(1);
      }
      await _fetchGroups();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to join group'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _leaveGroup(NearbyGroup group) async {
    final success = await _dataService.leaveGroup(group.id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Left ${group.name}')),
      );
      await _fetchGroups();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to leave group'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateGroupCover(NearbyGroup group) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (xfile == null) return;

    try {
      final url = await StorageService().uploadGroupCover(xfile);
      final success = await _dataService.updateGroupCover(
        groupId: group.id,
        coverImageUrl: url,
      );

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group cover updated')),
        );
        await _fetchGroups();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update group cover (maybe not creator)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update cover: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'SOCIAL';
    bool isPrivate = false;
    String? coverImageUrl;
    bool isUploadingCover = false;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dc = ColonyColors.of(context);
          return AlertDialog(
          title: const Text('Create New Group'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: isUploadingCover
                      ? null
                      : () async {
                          setDialogState(() => isUploadingCover = true);
                          final xfile = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (xfile != null) {
                            try {
                              final url = await StorageService()
                                  .uploadGroupCover(xfile);
                              setDialogState(() => coverImageUrl = url);
                            } catch (_) {
                              // ignore; show snackbar after create attempt
                            }
                          }
                          setDialogState(() => isUploadingCover = false);
                        },
                  child: Container(
                    height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: dc.card,
                      border: Border.all(
                        color: dc.divider.withOpacity(0.5),
                      ),
                    ),
                    child: coverImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              coverImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.image, size: 40, color: dc.iconMuted);
                              },
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isUploadingCover ? Icons.hourglass_empty : Icons.image_outlined,
                                color: dc.outlineButtonFg,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isUploadingCover
                                    ? 'Uploading cover...'
                                    : 'Tap to add cover image',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dc.secondaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: ['SOCIAL', 'TECH', 'FITNESS', 'LIFESTYLE', 'ART', 'MUSIC', 'BUSINESS']
                      .map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: isPrivate,
                  onChanged: (v) {
                    setDialogState(() => isPrivate = v);
                  },
                  title: const Text('Make this group private'),
                  subtitle: const Text('Private groups are hidden from nearby discovery'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                
                Navigator.pop(context);
                
                final success = await _dataService.createGroup(
                  name: nameController.text,
                  description: descriptionController.text,
                  category: selectedCategory,
                  latitude: _latitude,
                  longitude: _longitude,
                  coverImageUrl: coverImageUrl,
                  isPrivate: isPrivate,
                );
                
                if (success) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Group created successfully!')),
                    );
                    _tabController.animateTo(1);
                  }
                  await _fetchGroups();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to create group'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: dc.filledButtonBg,
                foregroundColor: dc.filledButtonFg,
              ),
              child: const Text('Create'),
            ),
          ],
        );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ColonyColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(c),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find your hive.',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: c.primaryText,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Discover local communities or manage the groups you\'ve nurtured.',
                    style: TextStyle(
                      fontSize: 14,
                      color: c.secondaryText,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildTabs(c),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: c.accent),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildNearbyGroupsList(c),
                        _buildMyGroupsList(c),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupDialog,
        backgroundColor: c.fabBackground,
        elevation: 2,
        child: Icon(Icons.add, color: c.fabForeground, size: 30),
      ),
    );
  }

  Widget _buildHeader(ColonyColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.location_on, color: c.primaryText, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _locationText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: c.primaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: c.primaryText),
            onPressed: _loadData,
          ),
          StreamBuilder<AuthState>(
            stream: SupabaseService().client.auth.onAuthStateChange,
            builder: (context, snapshot) {
              final user = snapshot.data?.session?.user;
              final avatarUrl = user?.userMetadata?['avatar_url'];
              return CircleAvatar(
                radius: 16,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : const NetworkImage('https://i.pravatar.cc/150'),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(ColonyColors c) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: c.segmentedTrack,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: c.divider.withOpacity(c.isDark ? 0.4 : 0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: c.segmentedSelectedBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!c.isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        labelColor: c.segmentedSelectedFg,
        unselectedLabelColor: c.segmentedUnselectedFg,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'Nearby Groups'),
          Tab(text: 'My Groups'),
        ],
      ),
    );
  }

  Widget _buildNearbyGroupsList(ColonyColors c) {
    if (_nearbyGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.group_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No nearby groups found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _showCreateGroupDialog,
              child: const Text('Create the first group!'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _nearbyGroups.length,
      itemBuilder: (context, index) {
        final group = _nearbyGroups[index];
        return _buildGroupCard(c, group);
      },
    );
  }

  Widget _buildMyGroupsList(ColonyColors c) {
    if (_myGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.group_add,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'You haven\'t joined any groups yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('Browse nearby groups'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _myGroups.length,
      itemBuilder: (context, index) {
        final group = _myGroups[index];
        return _buildGroupCard(c, group, isMyGroup: true);
      },
    );
  }

  Widget _buildGroupCard(ColonyColors c, NearbyGroup group, {bool isMyGroup = false}) {
    final category = group.category ?? 'SOCIAL';
    final tint = c.categoryTint(category);
    final chipBg = c.isDark ? c.categoryChipBg : tint;
    final chipFg = c.isDark ? c.categoryChipFg : const Color(0xFF2C3E30);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: group.isMember
            ? () => _openGroupChat(group)
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Join "${group.name}" to open group chat'),
                  ),
                );
              },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: c.divider.withOpacity(c.isDark ? 0.45 : 0.15)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.coverImageUrl != null)
            Stack(
              children: [
                Image.network(
                  group.coverImageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 160,
                    color: c.isDark ? c.pillBackground : tint.withOpacity(0.3),
                    child: Center(
                      child: Icon(
                        Icons.group,
                        size: 48,
                        color: c.isDark ? c.primaryText : tint,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 15,
                  left: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: chipFg,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              height: 100,
              color: c.isDark ? c.pillBackground : tint.withOpacity(0.3),
              child: Center(
                child: Icon(
                  Icons.group,
                  size: 48,
                  color: c.isDark ? c.primaryText : tint,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        group.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: c.primaryText,
                          height: 1.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.pillBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 10, color: c.primaryText),
                          const SizedBox(width: 4),
                          Text(
                            group.displayDistance,
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people, size: 12, color: c.iconMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${group.memberCount} members',
                      style: TextStyle(fontSize: 12, color: c.secondaryText),
                    ),
                  ],
                ),
                if (group.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    group.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.secondaryText,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 20),
                if (group.isMember) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openGroupChat(group),
                      icon: Icon(Icons.chat_bubble_outline,
                          color: c.filledButtonFg, size: 20),
                      label: Text(
                        'Open group chat',
                        style: TextStyle(
                          color: c.filledButtonFg,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.filledButtonBg,
                        foregroundColor: c.filledButtonFg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (isMyGroup && group.isMember) ...[
                  OutlinedButton.icon(
                    onPressed: () => _updateGroupCover(group),
                    icon: Icon(Icons.image_outlined, color: c.outlineButtonFg),
                    label: Text(
                      'Update cover',
                      style: TextStyle(
                        color: c.outlineButtonFg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: c.outlineButtonBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (group.isMember) {
                        _leaveGroup(group);
                      } else {
                        _joinGroup(group);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: group.isMember
                          ? c.secondaryButtonBg
                          : c.filledButtonBg,
                      foregroundColor: group.isMember
                          ? c.secondaryButtonFg
                          : c.filledButtonFg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      group.isMember ? 'Leave Group' : 'Join Group',
                      style: TextStyle(
                        color: group.isMember
                            ? c.secondaryButtonFg
                            : c.filledButtonFg,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}
