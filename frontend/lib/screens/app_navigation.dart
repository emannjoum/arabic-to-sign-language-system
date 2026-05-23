import 'package:flutter/material.dart';
import '../widgets/main_layout.dart';
import '../models/skeleton_frame.dart';
import '../services/api_service.dart';
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
  int _currentIndex = 0;

  // Store the response from the home screen to pass to the target screen
  ProcessResponse? _pendingResponse;
  String? _pendingText;

  void _navigateWithResponse(int index, String text, ProcessResponse response) {
    setState(() {
      _currentIndex = index;
      _pendingText = text;
      _pendingResponse = response;
    });
  }

  void _clearPending() {
    _pendingResponse = null;
    _pendingText = null;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onNavigateToBookmarks: () => setState(() => _currentIndex = 3),
        onNavigateToProfile: () => setState(() => _currentIndex = 4),
        onNavigateToLearning: () => setState(() => _currentIndex = 1),
        onNavigateToTranslation: () => setState(() => _currentIndex = 2),
        onNavigateWithResponse: _navigateWithResponse,
      ),
      LearningScreen(
        initialText: _currentIndex == 1 ? _pendingText : null,
        initialResponse: _currentIndex == 1 ? _pendingResponse : null,
      ),
      TranslationScreen(
        initialText: _currentIndex == 2 ? _pendingText : null,
        initialResponse: _currentIndex == 2 ? _pendingResponse : null,
      ),
      const BookmarksScreen(),
      const ProfileScreen(),
    ];

    return MainLayout(
      selectedIndex: _currentIndex,
      onTabTapped: (index) {
        _clearPending();
        setState(() => _currentIndex = index);
      },
      child: screens[_currentIndex],
    );
  }
}
