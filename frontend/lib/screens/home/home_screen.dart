import 'package:flutter/material.dart';
import '../../core/colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end, // Aligns text to the right for Arabic
        children: [
          // 1. Top Header
          const Center(
            child: Text(
              "Signly - Jordanian Sign Language",
              style: TextStyle(fontSize: 20, color: AppColors.textBlack),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.borderGray, thickness: 1),
          const SizedBox(height: 24),

          // 2. Red Welcome Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.primaryRed,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent, width: 2), // The blue outline from the design
            ),
            child: const Center(
              child: Text(
                "مرحبا بك في signly!!", // Welcome to signly!!
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Chat Input Box
          TextField(
            maxLines: 4, // Makes the box tall like in your design
            decoration: InputDecoration(
              hintText: "Enter Chat...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderGray),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Action Buttons (Send, Categories, Bookmarks)
          Row(
            children: [
              // Red Send Button
              Expanded(
                flex: 1,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text("إرسال"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Grey Category Button
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: AppColors.textBlack,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: const Text("التصنيفات"),
                ),
              ),
              const SizedBox(width: 16),
              // Grey Bookmark Button
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: AppColors.textBlack,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: const Text("المحفوظات"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}