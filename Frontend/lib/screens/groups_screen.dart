import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../data_service.dart';
import '../location_service.dart';
import '../supabase_service.dart';
import '../storage_service.dart';

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
    if (_latitude == null || _longitude == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final nearbyGroups = await _dataService.getNearbyGroups(
      latitude: _latitude!,
      longitude: _longitude!,
      radiusKm: 10.0,
    );

    // Get user's joined groups
    final userId = SupabaseService().client.auth.currentUser?.id;
    final myGroups = nearbyGroups.where((g) => g.isMember).toList();

    setState(() {
      _nearbyGroups = nearbyGroups;
      _myGroups = myGroups;
      _isLoading = false;
    });
  }

  Future<void> _joinGroup(NearbyGroup group) async {
    final success = await _dataService.joinGroup(group.id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully joined ${group.name}'),
          backgroundColor: const Color(0xFF2E6B3B),
        ),
      );
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
        SnackBar(
          content: Text('Left ${group.name}'),
          backgroundColor: const Color(0xFF2E6B3B),
        ),
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
          const SnackBar(
            content: Text('Group cover updated'),
            backgroundColor: Color(0xFF1B5A27),
          ),
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.25),
                      ),
                    ),
                    child: coverImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              coverImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.image, size: 40);
                              },
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isUploadingCover ? Icons.hourglass_empty : Icons.image_outlined,
                                color: const Color(0xFF1B5A27),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isUploadingCover
                                    ? 'Uploading cover...'
                                    : 'Tap to add cover image',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Group created successfully!'),
                      backgroundColor: Color(0xFF2E6B3B),
                    ),
                  );
                  await _fetchGroups();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to create group'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5A27),
              ),
              child: const Text('Create'),
            ),
          ],
        ),
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Find your hive.',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2C3E30),
                      letterSpacing: -1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Discover local communities or manage the groups you\'ve nurtured.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildTabs(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2E6B3B),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildNearbyGroupsList(),
                        _buildMyGroupsList(),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupDialog,
        backgroundColor: const Color(0xFFA3E9A5),
        elevation: 2,
        child: const Icon(Icons.add, color: Color(0xFF14471E), size: 30),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF14471E), size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _locationText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF14471E),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF14471E)),
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

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
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
        labelColor: const Color(0xFF2E6B3B),
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'Nearby Groups'),
          Tab(text: 'My Groups'),
        ],
      ),
    );
  }

  Widget _buildNearbyGroupsList() {
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
        return _buildGroupCard(group);
      },
    );
  }

  Widget _buildMyGroupsList() {
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
        return _buildGroupCard(group, isMyGroup: true);
      },
    );
  }

  Widget _buildGroupCard(NearbyGroup group, {bool isMyGroup = false}) {
    final category = group.category ?? 'SOCIAL';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
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
                    color: _getCategoryColor(category).withOpacity(0.3),
                    child: Center(
                      child: Icon(
                        Icons.group,
                        size: 48,
                        color: _getCategoryColor(category),
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
                      color: _getCategoryColor(category),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E30),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              height: 100,
              color: _getCategoryColor(category).withOpacity(0.3),
              child: Center(
                child: Icon(
                  Icons.group,
                  size: 48,
                  color: _getCategoryColor(category),
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
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E30),
                          height: 1.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F6E8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 10, color: Color(0xFF14471E)),
                          const SizedBox(width: 4),
                          Text(
                            group.displayDistance,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF14471E),
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
                    const Icon(Icons.people, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${group.memberCount} members',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                if (group.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    group.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 20),
                if (isMyGroup) ...[
                  OutlinedButton.icon(
                    onPressed: () => _updateGroupCover(group),
                    icon: const Icon(Icons.image_outlined, color: Color(0xFF1B5A27)),
                    label: const Text(
                      'Update cover',
                      style: TextStyle(
                        color: Color(0xFF1B5A27),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF1B5A27)),
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
                          ? const Color(0xFFE8F6E8)
                          : const Color(0xFF1A5822),
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
                            ? const Color(0xFF14471E)
                            : Colors.white,
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
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'TECH':
        return const Color(0xFF7DE6ED);
      case 'FITNESS':
        return const Color(0xFFF1B7C9);
      case 'LIFESTYLE':
        return const Color(0xFFA3E9A5);
      case 'ART':
        return const Color(0xFFE9D5A3);
      case 'MUSIC':
        return const Color(0xFFA3C4E9);
      case 'BUSINESS':
        return const Color(0xFFE9A3A3);
      default:
        return const Color(0xFFA3E9A5);
    }
  }
}
