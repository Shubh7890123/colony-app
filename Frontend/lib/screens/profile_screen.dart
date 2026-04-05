import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../auth_service.dart';
import '../colony_theme.dart';
import '../supabase_service.dart';
import '../data_service.dart';
import '../location_service.dart';
import '../storage_service.dart';
import '../theme_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DataService _dataService = DataService();
  
  int _friendsCount = 0;
  int _groupsCount = 0;
  int _postsCount = 0;
  String _locationText = 'Unknown';
  bool _isLoading = true;
  UserProfile? _userProfile;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final userId = SupabaseService().client.auth.currentUser?.id;
    if (userId == null) return;

    // Get user profile
    final profile = await _dataService.getUserProfile(userId);
    
    // Get user location
    final location = await LocationService().getUserLocation();
    
    // TODO: Implement actual counts from backend
    // For now, use placeholder values
    
    setState(() {
      _userProfile = profile;
      _locationText = location?.locationText ?? 'Unknown';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ColonyColors.of(context);
    return Scaffold(
      backgroundColor: c.scaffold,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              _buildHeader(context, c),
              const SizedBox(height: 30),
              _buildProfileHeader(c),
              const SizedBox(height: 20),
              _buildActionButtons(context, c),
              const SizedBox(height: 30),
              _buildStatsRow(c),
              const SizedBox(height: 30),
              _buildLocationInfo(c),
              const SizedBox(height: 30),
              _buildLogoutButton(context),
              const SizedBox(height: 80), // Padding for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColonyColors c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(Icons.location_on, color: c.accent, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _locationText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: c.accent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: c.primaryText),
          onPressed: _loadProfileData,
        ),
        IconButton(
          icon: Icon(Icons.settings, color: c.primaryText),
          onPressed: () => _showSettingsBottomSheet(context),
        ),
      ],
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    final c = ColonyColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final pad = MediaQuery.of(sheetCtx).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: pad),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsTile(
                    Icons.person_outline,
                    'Edit Profile',
                    () {
                      Navigator.pop(sheetCtx);
                      _showEditProfileDialog(context);
                    },
                    c,
                  ),
                  _buildSettingsTile(
                    Icons.palette_outlined,
                    'Theme',
                    () {
                      Navigator.pop(sheetCtx);
                      _showThemeDialog(context);
                    },
                    c,
                  ),
                  _buildSettingsTile(Icons.notifications_outlined, 'Notifications',
                      () {
                    Navigator.pop(sheetCtx);
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Notifications'),
                        content: const Text(
                          'Message and wave alerts use push notifications when this device '
                          'has a valid FCM token saved. If you miss alerts, enable notifications '
                          'for this app in system settings and ensure you are signed in on one device.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }, c),
                  _buildSettingsTile(Icons.lock_outline, 'Privacy', () {}, c),
                  _buildSettingsTile(Icons.help_outline, 'Help & Support', () {}, c),
                  _buildSettingsTile(Icons.info_outline, 'About', () {}, c),
                  Divider(height: 32, color: c.divider),
                  _buildLogoutTile(context, sheetCtx, c),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ListenableBuilder(
        listenable: ThemeController.instance,
        builder: (context, _) {
          final dark = ThemeController.instance.useDark;
          return AlertDialog(
            title: const Text('Theme'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<bool>(
                  title: const Text('Light'),
                  value: false,
                  groupValue: dark,
                  onChanged: (v) async {
                    if (v != null) {
                      await ThemeController.instance.setUseDark(false);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                ),
                RadioListTile<bool>(
                  title: const Text('Dark'),
                  value: true,
                  groupValue: dark,
                  onChanged: (v) async {
                    if (v != null) {
                      await ThemeController.instance.setUseDark(true);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final displayNameController = TextEditingController();
    final bioController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
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
              Navigator.pop(context);
              
              final success = await _dataService.updateProfile(
                displayName: displayNameController.text.isNotEmpty 
                    ? displayNameController.text 
                    : null,
                bio: bioController.text.isNotEmpty 
                    ? bioController.text 
                    : null,
              );
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully!'),
                    backgroundColor: Color(0xFF2E6B3B),
                  ),
                );
                _loadProfileData();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to update profile'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5A27),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    IconData icon,
    String title,
    VoidCallback onTap,
    ColonyColors c,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.pillBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: c.accent, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: c.primaryText,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: c.secondaryText),
      onTap: onTap,
    );
  }

  Widget _buildLogoutTile(
    BuildContext context,
    BuildContext sheetContext,
    ColonyColors c,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final errBg = dark ? const Color(0xFF3D1515) : Colors.red.shade50;
    final errFg = dark ? const Color(0xFFFF8A8A) : Colors.red.shade700;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: errBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.logout, color: errFg, size: 24),
      ),
      title: Text(
        'Logout',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: errFg,
        ),
      ),
      onTap: () async {
        Navigator.pop(sheetContext);
        _handleLogout(context);
      },
    );
  }

  void _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5A27),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      final result = await AuthService().signOut();
      if (context.mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildProfileHeader(ColonyColors c) {
    return StreamBuilder<AuthState>(
      stream: SupabaseService().client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = snapshot.data?.session?.user;
        final displayName = _userProfile?.displayName ??
            user?.userMetadata?['display_name'] ??
            user?.userMetadata?['full_name'] ??
            user?.email?.split('@').first ?? 
            'User';
        final username = _userProfile?.username ??
            user?.userMetadata?['username'] ??
            '@${user?.email?.split('@').first ?? 'user'}';
        final email = user?.email ?? 'user@example.com';
        final avatarUrl = _userProfile?.avatarUrl ?? 
            user?.userMetadata?['avatar_url'];
        final bio = _userProfile?.bio;

        return Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: Theme.of(context).brightness == Brightness.dark
                          ? [const Color(0xFF444444), const Color(0xFF888888)]
                          : const [Color(0xFFF17F36), Color(0xFF2E6B3B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.scaffold,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : const NetworkImage('https://i.pravatar.cc/150'),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _showAvatarPickSheet(context, c),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E1E1E)
                            : const Color(0xFF14471E),
                        shape: BoxShape.circle,
                        border: Border.all(color: c.scaffold, width: 3),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: c.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              username,
              style: TextStyle(
                fontSize: 16,
                color: c.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.email_outlined, color: c.secondaryText, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: c.secondaryText,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            if (bio != null && bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                bio,
                style: TextStyle(
                  fontSize: 14,
                  color: c.primaryText,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _showAvatarPickSheet(BuildContext context, ColonyColors c) async {
    if (_isUploadingAvatar) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: c.accent),
              title: Text('Choose from gallery', style: TextStyle(color: c.primaryText)),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _pickAndUploadAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: c.accent),
              title: Text('Take a photo', style: TextStyle(color: c.primaryText)),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _pickAndUploadAvatar(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source);
    if (xfile == null || !mounted) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final url = await StorageService().uploadAvatar(xfile);

      // Update profile avatar_url in `profiles` table.
      await _dataService.updateProfile(avatarUrl: url);

      // Also update auth user metadata so header UIs using userMetadata stay in sync.
      await SupabaseService().updateProfile(avatarUrl: url);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated'),
          backgroundColor: Color(0xFF1B5A27),
        ),
      );

      await _loadProfileData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Widget _buildActionButtons(BuildContext context, ColonyColors c) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _showEditProfileDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  dark ? const Color(0xFF1E1E1E) : const Color(0xFF1A5822),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: const Text(
              'Edit Profile',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: c.pillBackground,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _showSettingsBottomSheet(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.settings, color: c.iconMuted, size: 24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(ColonyColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: c.statBackground,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('$_friendsCount', 'FRIENDS', c),
          _buildDivider(c),
          _buildStatItem('$_groupsCount', 'GROUPS', c),
          _buildDivider(c),
          _buildStatItem('$_postsCount', 'POSTS', c),
        ],
      ),
    );
  }

  Widget _buildStatItem(String val, String label, ColonyColors c) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: c.accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: c.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(ColonyColors c) {
    return Container(
      height: 30,
      width: 1,
      color: c.divider,
    );
  }

  Widget _buildLocationInfo(ColonyColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.pillBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.location_on,
              color: c.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Location',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _locationText,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final result = await LocationService().fetchAndUpdateLocation();
              if (result.success) {
                _loadProfileData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Location updated!'),
                      backgroundColor: Theme.of(context).brightness ==
                              Brightness.dark
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFF2E6B3B),
                    ),
                  );
                }
              }
            },
            child: Text(
              'Update',
              style: TextStyle(
                color: c.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () => _handleLogout(context),
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text(
          'Logout',
          style: TextStyle(
            color: Colors.red,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }
}
