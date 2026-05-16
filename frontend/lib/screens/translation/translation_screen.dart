// import 'package:flutter/material.dart';
// import '../../core/colors.dart';
// import '../../services/api_service.dart';     // Import the API
// import '../../models/skeleton_frame.dart';    // Import the Data Model
// import 'package:video_player/video_player.dart';

// class TranslationScreen extends StatefulWidget {
//   final String? initialText;
//   final ProcessResponse? initialResponse;

//   const TranslationScreen({super.key, this.initialText, this.initialResponse});

//   @override
//   State<TranslationScreen> createState() => _TranslationScreenState();
// }

// class _TranslationScreenState extends State<TranslationScreen> {
//   final TextEditingController _textController = TextEditingController();
  
//   bool _isLoading = false;
//   ProcessResponse? _apiResponse; 
  
//   VideoPlayerController? _videoController;
//   int _currentVideoIndex = 0;

//   @override
//   void initState() {
//     super.initState();
//     if (widget.initialText != null) {
//       _textController.text = widget.initialText!;
//     }
//     if (widget.initialResponse != null) {
//       _apiResponse = widget.initialResponse;
//       if (_apiResponse!.data.isNotEmpty) {
//         // Wait for the UI to build, then start the video!
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           _initializeVideo(_apiResponse!.data.first.skeletonUrl);
//         });
//       }
//     }
//   }

//   // 1. The Listener: Detects when a video finishes
//   void _videoListener() {
//     if (_videoController != null && 
//         _videoController!.value.isInitialized && 
//         !_videoController!.value.isPlaying &&
//         _videoController!.value.position >= _videoController!.value.duration) {
      
//       // Video is done! Remove listener to prevent double-firing
//       _videoController!.removeListener(_videoListener);
//       _playNextVideo();
//     }
//   }

//   // 2. Play the next video in the sequence
//   void _playNextVideo() {
//     if (_apiResponse == null || _apiResponse!.data.isEmpty) return;

//     _currentVideoIndex++;
    
//     // If we reached the end of the sentence, loop back to the first word!
//     if (_currentVideoIndex >= _apiResponse!.data.length) {
//       _currentVideoIndex = 0; 
//     }
    
//     _initializeVideo(_apiResponse!.data[_currentVideoIndex].skeletonUrl);
//   }

//   // 3. Initialize specific video
//   Future<void> _initializeVideo(String url) async {
//     if (_videoController != null) {
//       await _videoController!.dispose();
//     }

//     final parsedUrl = url.replaceAll('127.0.0.1', '100.116.62.123');
//     _videoController = VideoPlayerController.networkUrl(Uri.parse(parsedUrl));
    
//     await _videoController!.initialize();
    
//     _videoController!.addListener(_videoListener);
    
//     if (mounted) {
//       setState(() {}); 
//       _videoController!.play(); 
//     }
//   }

//   Future<void> _processTranslation() async {
//     final text = _textController.text.trim();
//     if (text.isEmpty) return;

//     setState(() {
//       _isLoading = true;
//       _apiResponse = null;
//       _videoController?.pause(); 
//     });

//     final response = await ApiService.processText(text, forceMode: "translation");
    
//     if (mounted) {
//       setState(() {
//         _isLoading = false;
//         _apiResponse = response;
//         _currentVideoIndex = 0;
//       });
      
//       if (response != null && response.data.isNotEmpty) {
//         print("💡 PLAYLIST READY: Playing ${response.data.length} videos!");
//         _initializeVideo(response.data[_currentVideoIndex].skeletonUrl);
//       } else {
//         print("⚠️ BACKEND RETURNED 0 VIDEOS!");
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _textController.dispose();
//     _videoController?.removeListener(_videoListener);
//     _videoController?.dispose(); 
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Directionality(
//       textDirection: TextDirection.rtl,
//       child: SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text("الترجمة", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
//             const SizedBox(height: 24),

//             // Input Card 
//             Container(
//               padding: const EdgeInsets.all(24),
//               decoration: BoxDecoration(
//                 color: AppColors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text("النص العربي", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
//                   const SizedBox(height: 16),
//                   TextField(
//                     controller: _textController,
//                     maxLines: 4,
//                     decoration: InputDecoration(
//                       hintText: "أدخل النص هنا...",
//                       filled: true,
//                       fillColor: AppColors.backgroundGray,
//                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Wrap(
//                     alignment: WrapAlignment.spaceBetween,
//                     crossAxisAlignment: WrapCrossAlignment.center,
//                     children: [
//                       ElevatedButton(
//                         onPressed: _isLoading ? null : _processTranslation,
//                         style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
//                         child: _isLoading 
//                             ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
//                             : const Text("ترجمة النص", style: TextStyle(fontSize: 16)),
//                       ),
//                       const Text("يدعم اللغة العربية فقط", style: TextStyle(fontSize: 12, color: AppColors.textGray)),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 32),

//             // Video Player
//             Container(
//               width: double.infinity,
//               height: 400,
//               decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
//               clipBehavior: Clip.hardEdge,
//               child: _isLoading 
//                 ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
//                 : (_videoController != null && _videoController!.value.isInitialized)
//                     ? Stack(
//                         alignment: Alignment.center,
//                         children: [
//                           AspectRatio(
//                             aspectRatio: _videoController!.value.aspectRatio,
//                             child: VideoPlayer(_videoController!),
//                           ),
//                           // Label overlay dynamically updates with the current word!
//                           Positioned(
//                             bottom: 16,
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                               decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
//                               child: Text(
//                                 _apiResponse!.data[_currentVideoIndex].label, 
//                                 style: const TextStyle(color: Colors.white, fontSize: 18)
//                               ),
//                             ),
//                           )
//                         ],
//                       )
//                     : Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const Icon(Icons.videocam_off, color: Colors.white54, size: 80),
//                           const SizedBox(height: 16),
//                           Text(
//                             _apiResponse == null ? "Waiting for translation..." : "No video found.", 
//                             style: const TextStyle(color: Colors.white54)
//                           ),
//                         ],
//                       ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../services/api_service.dart';
import '../../models/skeleton_frame.dart';
import 'package:video_player/video_player.dart';

class TranslationScreen extends StatefulWidget {
  final String? initialText;
  final ProcessResponse? initialResponse;

  const TranslationScreen({super.key, this.initialText, this.initialResponse});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TextEditingController _textController = TextEditingController();

  bool _isLoading = false;
  ProcessResponse? _apiResponse;

  VideoPlayerController? _videoController;
  int _currentVideoIndex = 0;

  // Grouped words: each entry is the display label + list of frames
  // e.g. [("محمد", [frame_م, frame_ح, frame_م, frame_د]), ("ذهب", [frame_ذهب])]
  List<_WordGroup> _wordGroups = [];

  // Track which words are bookmarked
  Set<String> _bookmarkedWords = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      _textController.text = widget.initialText!;
    }
    if (widget.initialResponse != null) {
      _apiResponse = widget.initialResponse;
      _buildWordGroups(_apiResponse!.data);
      if (_apiResponse!.data.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeVideo(_apiResponse!.data.first.skeletonUrl);
        });
      }
    }
  }

  // Groups consecutive single-letter frames into one word group
  // Non-letter frames (full words) become their own group
  void _buildWordGroups(List<SkeletonFrame> frames) {
    List<_WordGroup> groups = [];
    int i = 0;

    while (i < frames.length) {
      final frame = frames[i];

      // Single letter → collect all consecutive letters as one name group
      if (_isSingleLetter(frame.label)) {
        String nameLabel = frame.label;
        List<SkeletonFrame> nameFrames = [frame];
        int j = i + 1;

        while (j < frames.length && _isSingleLetter(frames[j].label)) {
          nameLabel += frames[j].label;
          nameFrames.add(frames[j]);
          j++;
        }

        groups.add(_WordGroup(label: nameLabel, frames: nameFrames));
        i = j;
      } else {
        // Full word — one group with one frame
        groups.add(_WordGroup(label: frame.label, frames: [frame]));
        i++;
      }
    }

    setState(() => _wordGroups = groups);
  }

  bool _isSingleLetter(String label) {
    // Arabic letters are single characters
    return label.length == 1 && RegExp(r'[\u0600-\u06FF]').hasMatch(label);
  }

  void _videoListener() {
    if (_videoController != null &&
        _videoController!.value.isInitialized &&
        !_videoController!.value.isPlaying &&
        _videoController!.value.position >= _videoController!.value.duration) {
      _videoController!.removeListener(_videoListener);
      _playNextVideo();
    }
  }

  void _playNextVideo() {
    if (_apiResponse == null || _apiResponse!.data.isEmpty) return;
    _currentVideoIndex++;
    if (_currentVideoIndex >= _apiResponse!.data.length) {
      _currentVideoIndex = 0;
    }
    _initializeVideo(_apiResponse!.data[_currentVideoIndex].skeletonUrl);
  }

  Future<void> _initializeVideo(String url) async {
    if (_videoController != null) {
      await _videoController!.dispose();
    }
    final parsedUrl = url.replaceAll('127.0.0.1', '100.116.62.123');
    _videoController = VideoPlayerController.networkUrl(Uri.parse(parsedUrl));
    await _videoController!.initialize();
    _videoController!.addListener(_videoListener);
    if (mounted) {
      setState(() {});
      _videoController!.play();
    }
  }

  Future<void> _processTranslation() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _apiResponse = null;
      _wordGroups = [];
      _bookmarkedWords = {};
      _videoController?.pause();
    });

    final response = await ApiService.processText(text, forceMode: "translation");

    if (mounted) {
      setState(() {
        _isLoading = false;
        _apiResponse = response;
        _currentVideoIndex = 0;
      });

      if (response != null && response.data.isNotEmpty) {
        _buildWordGroups(response.data);
        _initializeVideo(response.data.first.skeletonUrl);
      }
    }
  }

  Future<void> _toggleBookmark(String word) async {
    final isBookmarked = _bookmarkedWords.contains(word);

    // Optimistic update
    setState(() {
      if (isBookmarked) {
        _bookmarkedWords.remove(word);
      } else {
        _bookmarkedWords.add(word);
      }
    });

    final success = isBookmarked
        ? await ApiService.removeBookmark(word)
        : await ApiService.addBookmark(word);

    // Revert if failed
    if (!success && mounted) {
      setState(() {
        if (isBookmarked) {
          _bookmarkedWords.add(word);
        } else {
          _bookmarkedWords.remove(word);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل الحفظ. حاول مجدداً.")),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundGray,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "الترجمة",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textBlack),
            ),
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
                  TextField(
                    controller: _textController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "أدخل النص هنا...",
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

            // Video Player
            Container(
              width: double.infinity,
              height: 400,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.hardEdge,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
                  : (_videoController != null && _videoController!.value.isInitialized)
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                            Positioned(
                              bottom: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                                child: Text(
                                  _apiResponse!.data[_currentVideoIndex].label,
                                  style: const TextStyle(color: Colors.white, fontSize: 18),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.videocam_off, color: Colors.white54, size: 80),
                            const SizedBox(height: 16),
                            Text(
                              _apiResponse == null ? "Waiting for translation..." : "No video found.",
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
            ),

            // Word Chips (shown after translation)
            if (_wordGroups.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                "اضغط على كلمة لحفظها",
                style: TextStyle(fontSize: 13, color: AppColors.textGray),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _wordGroups.map((group) {
                  final isBookmarked = _bookmarkedWords.contains(group.label);
                  return GestureDetector(
                    onTap: () => _toggleBookmark(group.label),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isBookmarked ? const Color(0xFFFCEBEB) : AppColors.white,
                        border: Border.all(
                          color: isBookmarked ? AppColors.primaryRed : AppColors.borderGray,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            size: 16,
                            color: isBookmarked ? AppColors.primaryRed : AppColors.textGray,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            group.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isBookmarked ? AppColors.primaryRed : AppColors.textBlack,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
        ),
      ),
    );
  }
}

// Helper class to group frames under one display label
class _WordGroup {
  final String label;
  final List<SkeletonFrame> frames;
  _WordGroup({required this.label, required this.frames});
}