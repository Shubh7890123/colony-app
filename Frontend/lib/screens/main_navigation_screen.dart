import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../colony_theme.dart';
import 'home_screen.dart';
import 'groups_screen.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  int _notificationCount = 0;
  late final SupabaseClient _supabase;
  RealtimeChannel? _notificationChannel;

  final List<Widget> _screens = [
    const HomeScreen(),
    const GroupsScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _fetchNotificationCount();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _notificationChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchNotificationCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Count pending wave requests
      final response = await _supabase
          .from('waves')
          .select('id')
          .eq('receiver_id', userId)
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          _notificationCount = response.length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notification count: $e');
    }
  }

  void _subscribeToNotifications() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Subscribe to waves table changes
    _notificationChannel = _supabase.channel('notifications_$userId');
    
    _notificationChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'waves',
      callback: (payload) {
        // Refresh notification count when waves change
        _fetchNotificationCount();
      },
    ).subscribe();
  }

  void _navigateToNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
    // Refresh count after returning from notifications screen
    _fetchNotificationCount();
  }

  @override
  Widget build(BuildContext context) {
    final c = ColonyColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: _currentIndex == 0
          ? AppBar(
              backgroundColor: c.scaffold,
              elevation: 0,
              title: Text(
                'Colony',
                style: TextStyle(
                  color: c.accent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications_outlined,
                        color: c.accent,
                        size: 28,
                      ),
                      onPressed: _navigateToNotifications,
                    ),
                    if (_notificationCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            _notificationCount > 99 ? '99+' : '$_notificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        color: c.scaffold,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home, dark),
              _buildNavItem(1, Icons.people_outline, Icons.people, dark),
              _buildNavItem(2, Icons.chat_bubble_outline, Icons.chat_bubble, dark),
              _buildNavItem(3, Icons.person_outline, Icons.person, dark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData iconOutline,
    IconData iconFilled,
    bool dark,
  ) {
    final isActive = _currentIndex == index;
    final c = ColonyColors.of(context);
    final activeColor = dark ? Colors.white : c.accent;
    final inactiveColor = dark ? const Color(0xFF777777) : c.iconMuted;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = index),
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Icon(
              isActive ? iconFilled : iconOutline,
              color: isActive ? activeColor : inactiveColor,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
