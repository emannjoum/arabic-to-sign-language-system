import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("فشل الحذف. حاول مجدداً.")));
    }
  }

  void _openVideoDialog(Map<String, dynamic> bookmark) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _VideoDialog(
        word: bookmark['word'] as String,
        skeletonUrl: bookmark['skeleton_url'] as String,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    final hPad = isWide ? 36.0 : 20.0;
    final vPadTop = isWide ? 32.0 : 20.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, vPadTop, hPad, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left block (RTL: right — title area)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المكتبة الشخصية',
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mute,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'المحفوظات',
                              style: GoogleFonts.tajawal(
                                fontSize: isWide ? 30 : 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${_bookmarks.length} كلمة',
                                style: GoogleFonts.tajawal(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'كل الإشارات التي حفظتها في مكان واحد',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mute,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── Grid ─────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 40),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _bookmarks.isEmpty
                    ? _EmptyState()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final cols = constraints.maxWidth < 500
                              ? 2
                              : constraints.maxWidth < 900
                              ? 3
                              : 4;
                          return GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  crossAxisSpacing: 18,
                                  mainAxisSpacing: 18,
                                  childAspectRatio: 0.95,
                                ),
                            itemCount: _bookmarks.length,
                            itemBuilder: (context, index) {
                              final b = _bookmarks[index];
                              return _BookmarkCard(
                                word: b['word'] as String,
                                poseIndex: index % 6,
                                onPlay: () => _openVideoDialog(b),
                                onRemove: () =>
                                    _removeBookmark(b['word'] as String),
                              );
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(22),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.bookmark_border,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد محفوظات بعد',
            style: GoogleFonts.tajawal(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ترجم نصاً واحفظ الكلمات التي تريدها',
            style: GoogleFonts.tajawal(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.mute,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bookmark Card ────────────────────────────────────────────────────────────

class _BookmarkCard extends StatelessWidget {
  final String word;
  final int poseIndex;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  const _BookmarkCard({
    required this.word,
    required this.poseIndex,
    required this.onPlay,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail
          GestureDetector(
            onTap: onPlay,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: SizedBox(
                height: 110,
                child: CustomPaint(
                  painter: _SignPosePainter(poseIndex: poseIndex),
                ),
              ),
            ),
          ),
          // Caption
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.tajawal(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'لغة الإشارة الأردنية',
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mute,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Play chip
                GestureDetector(
                  onTap: onPlay,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.play_arrow,
                      color: AppColors.primary,
                      size: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Bookmark chip
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.bookmark,
                      color: AppColors.primary,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sign Pose Painter ────────────────────────────────────────────────────────

class _SignPosePainter extends CustomPainter {
  final int poseIndex;
  const _SignPosePainter({required this.poseIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Deep teal background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF003634),
    );

    // Subtle dot grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;
    const step = 18.0;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1, gridPaint);
      }
    }

    // Radial spotlight
    final spotlight = Paint()
      ..shader =
          RadialGradient(
            colors: [Colors.white.withValues(alpha: 0.08), Colors.transparent],
            stops: const [0.0, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: Offset(cx, cy * 1.1),
              radius: size.width * 0.6,
            ),
          );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), spotlight);

    // Figure paint (white strokes)
    final fig = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Accent paint (mint)
    final acc = Paint()
      ..color = const Color(0xFF9CE0C7)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Head
    canvas.drawCircle(Offset(cx, cy - 36), 10, fig);

    // Neck + body
    canvas.drawLine(Offset(cx, cy - 26), Offset(cx, cy - 14), fig);
    canvas.drawLine(Offset(cx, cy - 14), Offset(cx, cy + 12), fig);

    // Legs
    canvas.drawLine(Offset(cx, cy + 12), Offset(cx - 14, cy + 36), fig);
    canvas.drawLine(Offset(cx, cy + 12), Offset(cx + 14, cy + 36), fig);

    // Arms — 6 poses
    _drawArms(canvas, cx, cy, poseIndex, fig, acc);

    // Play badge — top-left glass square
    final glassPaint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 10, 28, 28),
        const Radius.circular(9),
      ),
      glassPaint,
    );
    // Play triangle
    final triPath = Path()
      ..moveTo(19, 18)
      ..lineTo(19, 30)
      ..lineTo(30, 24)
      ..close();
    canvas.drawPath(
      triPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Duration badge — bottom-right pill
    final pillPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - 48, size.height - 22, 40, 16),
      const Radius.circular(999),
    );
    canvas.drawRRect(pillRect, pillPaint);
  }

  void _drawArms(
    Canvas canvas,
    double cx,
    double cy,
    int pose,
    Paint fig,
    Paint acc,
  ) {
    switch (pose % 6) {
      case 0: // arms raised
        canvas.drawLine(Offset(cx, cy - 12), Offset(cx - 28, cy - 28), fig);
        canvas.drawLine(Offset(cx, cy - 12), Offset(cx + 28, cy - 28), acc);
        break;
      case 1: // right arm out, left arm down
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx - 12, cy + 6), fig);
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx + 32, cy - 6), acc);
        break;
      case 2: // both arms forward-diagonal
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx - 30, cy - 4), fig);
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx + 30, cy - 4), fig);
        break;
      case 3: // arms wide low
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx - 30, cy + 8), fig);
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx + 30, cy + 8), acc);
        break;
      case 4: // one arm up, one bent
        canvas.drawLine(Offset(cx, cy - 12), Offset(cx - 24, cy - 24), acc);
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx + 20, cy + 4), fig);
        break;
      case 5: // arms crossed center
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx - 26, cy - 16), fig);
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx + 26, cy - 16), acc);
        canvas.drawLine(Offset(cx - 26, cy - 16), Offset(cx - 14, cy - 2), fig);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _SignPosePainter old) =>
      old.poseIndex != poseIndex;
}

// ─── Video Dialog (unchanged) ─────────────────────────────────────────────────

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
    final url = widget.skeletonUrl;
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await _controller!.initialize();
    _controller!.setLooping(true);
    _controller!.play();
    if (mounted) setState(() => _isInitialized = true);
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
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(
              height: 300,
              child: _isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.word,
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_isInitialized)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: IconButton(
                  iconSize: 48,
                  icon: Icon(
                    _controller!.value.isPlaying
                        ? Icons.pause_circle
                        : Icons.play_circle,
                    color: Colors.white,
                  ),
                  onPressed: () => setState(() {
                    _controller!.value.isPlaying
                        ? _controller!.pause()
                        : _controller!.play();
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
