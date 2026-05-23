import 'package:flutter/material.dart';
import '../core/colors.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final Function(int) onTabTapped;

  const MainLayout({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onTabTapped,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: child,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.mute,
          backgroundColor: AppColors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          onTap: onTabTapped,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: "الرئيسية",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined),
              label: "التعلم",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.translate_outlined),
              label: "الترجمة",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_border),
              label: "المحفوظات",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: "حسابي",
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 250,
            color: AppColors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo header ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                  child: Image.asset(
                    'assets/images/SignlyHeader.jpeg',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
                Divider(height: 1, color: AppColors.line),
                const SizedBox(height: 12),
                // ── Nav items ────────────────────────────────────────
                _NavItem(
                  icon: Icons.home_outlined,
                  label: "الرئيسية",
                  isActive: selectedIndex == 0,
                  onTap: () => onTabTapped(0),
                ),
                _NavItem(
                  icon: Icons.school_outlined,
                  label: "التعلم",
                  isActive: selectedIndex == 1,
                  onTap: () => onTabTapped(1),
                ),
                _NavItem(
                  icon: Icons.translate_outlined,
                  label: "الترجمة",
                  isActive: selectedIndex == 2,
                  onTap: () => onTabTapped(2),
                ),
                _NavItem(
                  icon: Icons.bookmark_border,
                  label: "المحفوظات",
                  isActive: selectedIndex == 3,
                  onTap: () => onTabTapped(3),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  label: "الملف الشخصي",
                  isActive: selectedIndex == 4,
                  onTap: () => onTabTapped(4),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(color: AppColors.backgroundGray, child: child),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon,
          color: isActive ? AppColors.primary : AppColors.mute,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.primary : AppColors.mute,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
