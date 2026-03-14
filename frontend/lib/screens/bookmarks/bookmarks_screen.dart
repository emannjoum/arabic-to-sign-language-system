import 'package:flutter/material.dart';
import '../../core/colors.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data matching the text in your screenshot exactly
    final List<String> mockBookmarks = [
      "جامعة", "صحن", "اللغه الانجليزيه", "بيت", "افعى", "مكتبة"
    ];

    return Directionality(
      textDirection: TextDirection.rtl, // RTL for Arabic layout
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Page Title
          const Text(
            "المحفوظات",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textBlack),
          ),
          const SizedBox(height: 24),

          // 2. Responsive Grid of Saved Videos
          Expanded( // Expanded allows the grid to scroll within the column
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Adjust columns based on screen width (Phones = 2, Tablets = 3+)
                int crossAxisCount = constraints.maxWidth < 400 ? 2 : 3;

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2, // Adjusts the height vs width of the cards
                  ),
                  itemCount: mockBookmarks.length,
                  itemBuilder: (context, index) {
                    return _buildBookmarkCard(mockBookmarks[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to draw the individual video cards
  Widget _buildBookmarkCard(String title) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias, // This ensures the black box doesn't spill over the rounded corners
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top: Mock Video Area (Black)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: const Center(
                // A simple placeholder for the skeleton animation
                child: Icon(Icons.accessibility_new, color: Colors.white54, size: 40), 
              ),
            ),
          ),
          
          // Bottom: White Label Area
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                  ),
                  const Icon(Icons.bookmark, color: AppColors.textBlack, size: 20), // Filled bookmark icon
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}