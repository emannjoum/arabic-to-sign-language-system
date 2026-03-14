import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../services/api_service.dart';     // Import the API
import '../../models/skeleton_frame.dart';    // Import the Data Model

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  // 1. Controller for the Arabic text input
  final TextEditingController _textController = TextEditingController();
  
  bool _isLoading = false;
  ProcessResponse? _apiResponse; // This will hold the data from FastAPI

  // 2. The Translation Function
  Future<void> _processTranslation() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _apiResponse = null; // Clear previous results
    });

    // Send to FastAPI!
    final response = await ApiService.processText(text);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _apiResponse = response;
      });
      
      // Temporary debug print to show it worked
      if (response != null) {
        print("SUCCESS! Detected Mode: ${response.mode}");
        print("Received ${response.data.length} skeleton frames.");
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("الترجمة", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
            const SizedBox(height: 24),

            // Input Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("النص العربي", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                  const SizedBox(height: 16),
                  
                  // Text Field Wired Up!
                  TextField(
                    controller: _textController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "بيت...",
                      filled: true,
                      fillColor: AppColors.backgroundGray,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Button Wired Up!
                      ElevatedButton(
                        onPressed: _isLoading ? null : _processTranslation,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                        child: _isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("ترجمة النص", style: TextStyle(fontSize: 16)),
                      ),
                      const Text("يدعم اللغة العربية فقط", style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Video Player Placeholder (Updated to show real labels from backend!)
            Container(
              width: double.infinity,
              height: 400,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.accessibility_new, color: Colors.white54, size: 100),
                      const SizedBox(height: 16),
                      // Dynamic text based on API response!
                      Text(
                        _isLoading ? "Processing..." : 
                        _apiResponse != null ? "Loaded ${_apiResponse!.data.length} signs!" : "Waiting for translation...", 
                        style: const TextStyle(color: Colors.white54)
                      ),
                    ],
                  ),
                  
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Container(
                        height: 50, color: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Row(
                          children: [
                            Icon(Icons.play_arrow, color: Colors.white), SizedBox(width: 16),
                            Expanded(child: LinearProgressIndicator(value: 0.3, backgroundColor: Colors.white24, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed))),
                            SizedBox(width: 16), Icon(Icons.volume_up, color: Colors.white), SizedBox(width: 16), Icon(Icons.fullscreen, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}