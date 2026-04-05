import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7ED),
      appBar: _currentIndex == 0
          ? AppBar(
              backgroundColor: const Color(0xFFF2F7ED),
              elevation: 0,
              title: const Text(
                'Colony',
                style: TextStyle(
                  color: Color(0xFF14471E),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Color(0xFF14471E),
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
        color: const Color(0xFFF2F7ED),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, Icons.home_filled),
              _buildNavItem(1, Icons.people_alt),
              _buildNavItem(2, Icons.chat_bubble),
              _buildNavItem(3, Icons.person),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFA3E9A5) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          icon,
          color: isActive ? const Color(0xFF14471E) : const Color(0xFF4A554A),
          size: 28,
        ),
      ),
    );
  }
}
