import 'package:flutter/material.dart';
import '../../core/colors.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // RTL for Arabic layout
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Page Title
            const Text(
              "التعلم",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textBlack),
            ),
            const SizedBox(height: 24),

            // 2. Chat/Search Input Box
            TextField(
              decoration: InputDecoration(
                hintText: "Enter Chat...",
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderGray),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // 3. Section Title
            const Text(
              "مواضيع مقترحه", // Suggested Topics
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textBlack),
            ),
            const SizedBox(height: 16),

            // 4. Topic Cards Grid (Responsive!)
            LayoutBuilder(
              builder: (context, constraints) {
                // If the screen is super narrow, show 2 per row. Otherwise, show 3.
                int crossAxisCount = constraints.maxWidth < 350 ? 2 : 3;
                
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true, // Required when putting a Grid inside a ScrollView
                  physics: const NeverScrollableScrollPhysics(), // Disables inner scrolling
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildTopicCard(Icons.science_outlined, "كيمياء"),
                    _buildTopicCard(Icons.emoji_emotions_outlined, "مشاعر"),
                    _buildTopicCard(Icons.wb_sunny_outlined, "الفصول"),
                  ],
                );
              }
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to draw the square topic cards
  Widget _buildTopicCard(IconData icon, String title) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell( // Adds the ripple effect when tapped
          onTap: () {
            // TODO: Fetch videos for this specific topic from backend
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: AppColors.textBlack),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textBlack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}