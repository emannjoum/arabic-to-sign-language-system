import 'package:flutter/material.dart';
import '../../core/colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("الملف الشخصي", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
            const SizedBox(height: 24),

            // Profile Info Card (No internet image, just a clean icon)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.grey[200],
                    child: const Icon(Icons.person, size: 40, color: AppColors.textGray),
                  ),
                  const SizedBox(width: 20),
                  const Text("نور النجوم", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            const Text("إعدادات الحساب", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
            const SizedBox(height: 16),

            // Settings List (Language removed!)
            _buildSettingItem(Icons.person_add_alt_1_outlined, "تعديل الملف الشخصي"),
            const SizedBox(height: 12),
            _buildSettingItem(Icons.lock_outline, "تغيير كلمة السر"),
            const SizedBox(height: 12),
            _buildSettingItem(Icons.bookmark_border, "المحفوظات"),
            const SizedBox(height: 12),
            _buildSettingItem(Icons.exit_to_app, "تسجيل الخروج", isLogout: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(IconData icon, String title, {bool isLogout = false}) {
    final color = isLogout ? AppColors.primaryRed : AppColors.textBlack;
    return Container(
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(8)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isLogout ? Colors.red.withOpacity(0.1) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}