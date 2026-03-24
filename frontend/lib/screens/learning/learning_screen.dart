import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/colors.dart';
import '../../models/skeleton_frame.dart';

class LearningScreen extends StatefulWidget {
  final String? initialText;
  final ProcessResponse? initialResponse;

  const LearningScreen({super.key, this.initialText, this.initialResponse});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  VideoPlayerController? _videoController;
  int _currentIndex = 0;
  List<SkeletonFrame> _vocabList = [];

  @override
  void initState() {
    super.initState();
    // Load the vocabulary list sent from the AI Backend!
    if (widget.initialResponse != null && widget.initialResponse!.data.isNotEmpty) {
      _vocabList = widget.initialResponse!.data;
      _initializeVideo(_vocabList[_currentIndex].skeletonUrl);
    }
  }

  Future<void> _initializeVideo(String url) async {
    if (_videoController != null) {
      await _videoController!.dispose();
    }

    final parsedUrl = url.replaceAll('127.0.0.1', '100.116.62.123');
    _videoController = VideoPlayerController.networkUrl(Uri.parse(parsedUrl));

    await _videoController!.initialize();
    _videoController!.setLooping(true); // Loop the single word so they can study it
    
    if (mounted) {
      setState(() {});
      _videoController!.play();
    }
  }

  void _nextWord() {
    if (_currentIndex < _vocabList.length - 1) {
      setState(() => _currentIndex++);
      _initializeVideo(_vocabList[_currentIndex].skeletonUrl);
    }
  }

  void _previousWord() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _initializeVideo(_vocabList[_currentIndex].skeletonUrl);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_vocabList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("التعلم"), backgroundColor: AppColors.white, foregroundColor: AppColors.textBlack),
        body: const Center(child: Text("لا توجد كلمات (No vocabulary found)")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("تعلم المفردات", style: TextStyle(color: AppColors.textBlack, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textBlack),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "موضوع: ${widget.initialText ?? 'مفردات'}",
                style: const TextStyle(fontSize: 18, color: AppColors.textGray),
              ),
              const SizedBox(height: 24),

              // The Video Player
              Container(
                width: double.infinity,
                height: 350,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.hardEdge,
                child: (_videoController != null && _videoController!.value.isInitialized)
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                    : const Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
              ),
              const SizedBox(height: 32),

              // The Word Label
              Text(
                _vocabList[_currentIndex].label,
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
              ),
              const SizedBox(height: 48),

              // Flashcard Navigation Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _currentIndex < _vocabList.length - 1 ? _nextWord : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text("التالي", style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  Text("${_currentIndex + 1} / ${_vocabList.length}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _currentIndex > 0 ? _previousWord : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("السابق", style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}