// import 'package:flutter/material.dart';
// import '../../core/colors.dart';
// import '../../services/api_service.dart';

// class BookmarksScreen extends StatefulWidget {
//   const BookmarksScreen({super.key});

//   @override
//   State<BookmarksScreen> createState() => _BookmarksScreenState();
// }

// class _BookmarksScreenState extends State<BookmarksScreen> {
//   List<Map<String, dynamic>> _bookmarks = [];
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadBookmarks();
//   }

//   Future<void> _loadBookmarks() async {
//     setState(() => _isLoading = true);
//     final data = await ApiService.getBookmarks();
//     if (mounted) {
//       setState(() {
//         _bookmarks = data;
//         _isLoading = false;
//       });
//     }
//   }

//   Future<void> _removeBookmark(String word) async {
//     // Optimistic update
//     setState(() => _bookmarks.removeWhere((b) => b['word'] == word));

//     final success = await ApiService.removeBookmark(word);

//     if (!success && mounted) {
//       // Revert — reload from server
//       _loadBookmarks();
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("فشل الحذف. حاول مجدداً.")),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Directionality(
//       textDirection: TextDirection.rtl,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             "المحفوظات",
//             style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textBlack),
//           ),
//           const SizedBox(height: 24),

//           if (_isLoading)
//             const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)))

//           else if (_bookmarks.isEmpty)
//             const Expanded(
//               child: Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.bookmark_border, size: 64, color: AppColors.textGray),
//                     SizedBox(height: 16),
//                     Text(
//                       "لا توجد محفوظات بعد",
//                       style: TextStyle(fontSize: 16, color: AppColors.textGray),
//                     ),
//                     SizedBox(height: 8),
//                     Text(
//                       "ترجم نصاً واحفظ الكلمات التي تريدها",
//                       style: TextStyle(fontSize: 13, color: AppColors.textGray),
//                     ),
//                   ],
//                 ),
//               ),
//             )

//           else
//             Expanded(
//               child: LayoutBuilder(
//                 builder: (context, constraints) {
//                   int crossAxisCount = constraints.maxWidth < 400 ? 2 : 3;
//                   return GridView.builder(
//                     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                       crossAxisCount: crossAxisCount,
//                       crossAxisSpacing: 16,
//                       mainAxisSpacing: 16,
//                       childAspectRatio: 1.2,
//                     ),
//                     itemCount: _bookmarks.length,
//                     itemBuilder: (context, index) {
//                       return _buildBookmarkCard(_bookmarks[index]);
//                     },
//                   );
//                 },
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildBookmarkCard(Map<String, dynamic> bookmark) {
//     final word = bookmark['word'] as String;

//     return Container(
//       decoration: BoxDecoration(
//         color: AppColors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
//       ),
//       clipBehavior: Clip.antiAlias,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           // Video area
//           Expanded(
//             flex: 3,
//             child: Container(
//               color: Colors.black,
//               child: const Center(
//                 child: Icon(Icons.accessibility_new, color: Colors.white54, size: 40),
//               ),
//             ),
//           ),

//           // Label + unbookmark button
//           Expanded(
//             flex: 1,
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 12.0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     word,
//                     style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
//                   ),
//                   GestureDetector(
//                     onTap: () => _removeBookmark(word),
//                     child: const Icon(Icons.bookmark, color: AppColors.primaryRed, size: 20),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/colors.dart';
import '../../services/api_service.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getBookmarks();
    if (mounted) {
      setState(() {
        _bookmarks = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeBookmark(String word) async {
    setState(() => _bookmarks.removeWhere((b) => b['word'] == word));
    final success = await ApiService.removeBookmark(word);
    if (!success && mounted) {
      _loadBookmarks();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل الحذف. حاول مجدداً.")),
      );
    }
  }

  void _openVideoDialog(Map<String, dynamic> bookmark) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _VideoDialog(
        word: bookmark['word'] as String,
        skeletonUrl: bookmark['skeleton_url'] as String,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "المحفوظات",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textBlack),
          ),
          const SizedBox(height: 24),

          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)))

          else if (_bookmarks.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bookmark_border, size: 64, color: AppColors.textGray),
                    SizedBox(height: 16),
                    Text("لا توجد محفوظات بعد", style: TextStyle(fontSize: 16, color: AppColors.textGray)),
                    SizedBox(height: 8),
                    Text("ترجم نصاً واحفظ الكلمات التي تريدها", style: TextStyle(fontSize: 13, color: AppColors.textGray)),
                  ],
                ),
              ),
            )

          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = constraints.maxWidth < 400 ? 2 : 3;
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _bookmarks.length,
                    itemBuilder: (context, index) {
                      return _buildBookmarkCard(_bookmarks[index]);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBookmarkCard(Map<String, dynamic> bookmark) {
    final word = bookmark['word'] as String;

    return GestureDetector(
      onTap: () => _openVideoDialog(bookmark),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tap to play area
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.play_circle_outline, color: Colors.white54, size: 48),
                ),
              ),
            ),

            // Label + remove bookmark button
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        word,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeBookmark(word),
                      child: const Icon(Icons.bookmark, color: AppColors.primaryRed, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Fullscreen Video Dialog ──────────────────────────────────────────────────

class _VideoDialog extends StatefulWidget {
  final String word;
  final String skeletonUrl;

  const _VideoDialog({required this.word, required this.skeletonUrl});

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.skeletonUrl.replaceAll('127.0.0.1', '192.168.1.11');
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await _controller!.initialize();
    _controller!.setLooping(true);
    _controller!.play();
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            // Video player
            SizedBox(
              height: 300,
              child: _isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    )
                  : const Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
            ),

            // Word label
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.word,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),

            // Play/Pause button
            if (_isInitialized)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: IconButton(
                  iconSize: 48,
                  icon: Icon(
                    _controller!.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _controller!.value.isPlaying
                          ? _controller!.pause()
                          : _controller!.play();
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}