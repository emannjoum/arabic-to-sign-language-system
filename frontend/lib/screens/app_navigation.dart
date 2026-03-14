import 'package:flutter/material.dart';
import '../widgets/main_layout.dart';
import 'home/home_screen.dart';
import 'learning/learning_screen.dart';
import 'translation/translation_screen.dart';
import 'bookmarks/bookmarks_screen.dart';
import 'profile/profile_screen.dart';

class AppNavigation extends StatefulWidget {
  const AppNavigation({super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  int _currentIndex = 0; // Starts on the Home Screen

  // The list of screens in the exact order of your bottom navigation bar
  final List<Widget> _screens = [
    const HomeScreen(),
    const LearningScreen(),
    const TranslationScreen(),
    const BookmarksScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      selectedIndex: _currentIndex,
      // When a tab is tapped, update the index and redraw the screen!
      onTabTapped: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      child: _screens[_currentIndex],
    );
  }
}