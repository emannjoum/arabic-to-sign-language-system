import 'package:flutter/material.dart';
import '../core/colors.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final Function(int) onTabTapped;

  const MainLayout({super.key, required this.child, required this.selectedIndex, required this.onTabTapped});

  @override
  Widget build(BuildContext context) {
    // 1. Measure the screen width!
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    // 2. If it's a mobile phone, use a Bottom Navigation Bar
    if (isMobile) {
      return Scaffold(
        backgroundColor: AppColors.backgroundGray,
        body: SafeArea( // SafeArea keeps content out of the phone's top notch
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          selectedItemColor: AppColors.primaryRed,
          unselectedItemColor: AppColors.textGray,
          type: BottomNavigationBarType.fixed, // Keeps all icons visible
          onTap: onTabTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "الرئيسية"),
            BottomNavigationBarItem(icon: Icon(Icons.school_outlined), label: "التعلم"),
            BottomNavigationBarItem(icon: Icon(Icons.translate_outlined), label: "الترجمة"),
            BottomNavigationBarItem(icon: Icon(Icons.bookmark_border), label: "المحفوظات"),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "حسابي"),
          ],
        ),
      );
    }

    // 3. If it's a Tablet/Web, use your original Sidebar design
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 250,
            color: AppColors.white,
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text("Signly", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                _NavItem(icon: Icons.home_outlined, label: "الرئيسية", isActive: selectedIndex == 0),
                _NavItem(icon: Icons.school_outlined, label: "التعلم", isActive: selectedIndex == 1),
                _NavItem(icon: Icons.translate_outlined, label: "الترجمة", isActive: selectedIndex == 2),
                _NavItem(icon: Icons.bookmark_border, label: "المحفوظات", isActive: selectedIndex == 3),
                _NavItem(icon: Icons.person_outline, label: "الملف الشخصي", isActive: selectedIndex == 4),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: AppColors.backgroundGray,
              padding: const EdgeInsets.all(20),
              child: child,
            ),
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

  const _NavItem({required this.icon, required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: isActive 
          ? const BoxDecoration(border: Border(right: BorderSide(color: AppColors.primaryRed, width: 4))) 
          : null,
      child: ListTile(
        leading: Icon(icon, color: isActive ? AppColors.primaryRed : AppColors.textBlack),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.primaryRed : AppColors.textBlack,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {},
      ),
    );
  }
}