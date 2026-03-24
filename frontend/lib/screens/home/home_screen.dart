import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../services/api_service.dart';
import '../translation/translation_screen.dart';
import '../learning/learning_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 1. Controller to read what you type!
  final TextEditingController _chatController = TextEditingController();
  bool _isLoading = false;

  // 2. The Send Function
  Future<void> _handleSend() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);

    // Call your FastAPI backend! (Notice we do NOT force a mode here)
    final response = await ApiService.processText(text);

    if (mounted) {
      setState(() => _isLoading = false);
      
      if (response != null) {
        // THE SMART ROUTER: Navigate based on the AI's decision!
        if (response.mode == "translation") {
          print("🚀 AI Routing to Translation Screen!");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TranslationScreen(
                initialText: text,
                initialResponse: response, 
              ),
            ),
          );
        } else if (response.mode == "teaching") {
          print("🚀 AI Routing to Learning Screen!");
          // TODO: Once you build the LearningScreen, uncomment this!
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LearningScreen(
                initialText: text,
                initialResponse: response, 
              ),
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("AI Detected 'Teaching' Mode! (Screen pending)")),
          );
        }

        _chatController.clear(); // Clear the box after sending
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error connecting to backend.")),
        );
      }
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Top Header
          const Center(
            child: Text("Signly - Jordanian Sign Language", style: TextStyle(fontSize: 20, color: AppColors.textBlack)),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.borderGray, thickness: 1),
          const SizedBox(height: 24),

          // Red Welcome Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.primaryRed,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent, width: 2),
            ),
            child: const Center(
              child: Text("مرحبا بك في signly!!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.white)),
            ),
          ),
          const SizedBox(height: 24),

          // Chat Input Box WIRED UP
          TextField(
            controller: _chatController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "Enter Chat...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderGray),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              // Red Send Button WIRED UP
              Expanded(
                flex: 1,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleSend,
                  icon: _isLoading 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_outlined, size: 18),
                  label: Text(_isLoading ? "..." : "إرسال"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Grey Category Button (Stubbed)
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], foregroundColor: AppColors.textBlack, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0),
                  child: const Text("التصنيفات"),
                ),
              ),
              const SizedBox(width: 16),
              // Grey Bookmark Button (Stubbed)
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], foregroundColor: AppColors.textBlack, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0),
                  child: const Text("المحفوظات"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}