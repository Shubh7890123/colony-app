import 'package:flutter/material.dart';
import '../colony_theme.dart';
import 'home_screen.dart';
import 'groups_screen.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const GroupsScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ColonyColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: c.scaffold,
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
