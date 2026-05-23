import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../core/colors.dart';
import '../../services/api_service.dart';
import '../../models/skeleton_frame.dart';

class _SignResult {
  final String word;
  final String? skeletonUrl;
  bool saved;
  _SignResult({required this.word, this.skeletonUrl}) : saved = false;
}

class LearningScreen extends StatefulWidget {
  final String? initialText;
  final ProcessResponse? initialResponse;
  const LearningScreen({super.key, this.initialText, this.initialResponse});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  List<String> _topics = [];
  bool _isLoadingTopics = true;

  String? _selectedTopic;
  List<_SignResult> _results = [];
  bool _isLoadingResults = false;

  @override
  void initState() {
    super.initState();
    _loadTopics();
    if (widget.initialResponse != null &&
        widget.initialResponse!.data.isNotEmpty) {
      _results = widget.initialResponse!.data
          .map((f) => _SignResult(word: f.label, skeletonUrl: f.skeletonUrl))
          .toList();
      _selectedTopic = widget.initialText;
    }
  }

  Future<void> _loadTopics() async {
    setState(() => _isLoadingTopics = true);
    final topics = await ApiService.fetchTopics();
    if (!mounted) return;
    setState(() {
      _topics = topics;
      _isLoadingTopics = false;
    });
  }

  Future<void> _selectTopic(String topic) async {
    setState(() {
      _selectedTopic = topic;
      _isLoadingResults = true;
      _results = [];
    });
    final response = await ApiService.processText(topic, forceMode: "teaching");
    if (!mounted) return;
    setState(() {
      _isLoadingResults = false;
      _results = response != null && response.data.isNotEmpty
          ? response.data
                .map(
                  (f) => _SignResult(word: f.label, skeletonUrl: f.skeletonUrl),
                )
                .toList()
          : [];
    });
  }

  Future<void> _toggleSave(int index) async {
    final word = _results[index].word;
    final wasSaved = _results[index].saved;
    setState(() => _results[index].saved = !wasSaved);
    final ok = wasSaved
        ? await ApiService.removeBookmark(word)
        : await ApiService.addBookmark(word);
    if (!ok && mounted) {
      setState(() => _results[index].saved = wasSaved);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("فشل الحفظ. حاول مجدداً.")));
    }
  }

  void _openVideo(_SignResult r) {
    if (r.skeletonUrl == null) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _VideoDialog(word: r.word, skeletonUrl: r.skeletonUrl!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPushed = widget.initialResponse != null;
    final isWide = MediaQuery.of(context).size.width >= 600;
    final hPad = isWide ? 36.0 : 20.0;
    final cols = isWide ? 4 : 2;

    final content = Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────
                    if (isPushed) ...[
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.line),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      'مساحة التعلّم',
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mute,
                      ),
                    ),
                    Text(
                      'اختر موضوعاً',
                      style: GoogleFonts.tajawal(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Topics ──────────────────────────────────────
                    if (_isLoadingTopics)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else if (_topics.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'لا توجد مواضيع',
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              color: AppColors.mute,
                            ),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _topics.map((topic) {
                          final isSelected = topic == _selectedTopic;
                          return GestureDetector(
                            onTap: _isLoadingResults
                                ? null
                                : () => _selectTopic(topic),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.line,
                                ),
                                boxShadow: isSelected
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x40004B49),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    topic,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 24),

                    // ── Results header ───────────────────────────────
                    if (_selectedTopic != null &&
                        !_isLoadingResults &&
                        _results.isNotEmpty) ...[
                      Row(
                        children: [
                          Text(
                            '«$_selectedTopic»',
                            style: GoogleFonts.tajawal(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${_results.length} إشارة',
                              style: GoogleFonts.tajawal(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ),

            // ── Loading spinner ──────────────────────────────────────
            if (_isLoadingResults)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            // ── No results ───────────────────────────────────────────
            else if (_selectedTopic != null &&
                _results.isEmpty &&
                !_isLoadingTopics)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        color: AppColors.mute,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'لا توجد إشارات لهذا الموضوع',
                        style: GoogleFonts.tajawal(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            // ── Hint (nothing selected yet) ───────────────────────────
            else if (_selectedTopic == null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.auto_awesome,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'اختر موضوعاً من القائمة',
                        style: GoogleFonts.tajawal(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ستظهر إشاراته هنا',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mute,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            // ── Results grid ─────────────────────────────────────────
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 40),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _SignCard(
                      result: _results[i],
                      poseIndex: i % 6,
                      onPlay: () => _openVideo(_results[i]),
                      onToggleSave: () => _toggleSave(i),
                    ),
                    childCount: _results.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.82,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return isPushed
        ? Scaffold(backgroundColor: AppColors.surface, body: content)
        : content;
  }
}

// ─── Sign Card (same style as bookmarks) ─────────────────────────────────────

class _SignCard extends StatelessWidget {
  final _SignResult result;
  final int poseIndex;
  final VoidCallback onPlay;
  final VoidCallback onToggleSave;

  const _SignCard({
    required this.result,
    required this.poseIndex,
    required this.onPlay,
    required this.onToggleSave,
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
          GestureDetector(
            onTap: onPlay,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: SizedBox(
                height: 150,
                child: CustomPaint(
                  painter: _SignPosePainter(poseIndex: poseIndex),
                ),
              ),
            ),
          ),
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
                        result.word,
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
                GestureDetector(
                  onTap: onToggleSave,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: result.saved
                          ? AppColors.primary
                          : AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      result.saved ? Icons.bookmark : Icons.bookmark_border,
                      color: result.saved ? Colors.white : AppColors.primary,
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

// ─── Painters ─────────────────────────────────────────────────────────────────

class _SignPosePainter extends CustomPainter {
  final int poseIndex;
  const _SignPosePainter({required this.poseIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF003634),
    );
    final dot = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    for (double x = 18; x < size.width; x += 18)
      for (double y = 18; y < size.height; y += 18) {
        canvas.drawCircle(Offset(x, y), 1, dot);
      }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(cx, cy * 1.1),
                radius: size.width * 0.6,
              ),
            ),
    );
    final fig = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final acc = Paint()
      ..color = const Color(0xFF9CE0C7)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(cx, cy - 36), 10, fig);
    canvas.drawLine(Offset(cx, cy - 26), Offset(cx, cy - 14), fig);
    canvas.drawLine(Offset(cx, cy - 14), Offset(cx, cy + 12), fig);
    canvas.drawLine(Offset(cx, cy + 12), Offset(cx - 14, cy + 36), fig);
    canvas.drawLine(Offset(cx, cy + 12), Offset(cx + 14, cy + 36), fig);
    switch (poseIndex % 6) {
      case 0:
        canvas.drawLine(Offset(cx, cy - 12), Offset(cx - 28, cy - 28), fig);
        canvas.drawLine(Offset(cx, cy - 12), Offset(cx + 28, cy - 28), acc);
        break;
      case 1:
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx - 12, cy + 6), fig);
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx + 32, cy - 6), acc);
        break;
      case 2:
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx - 30, cy - 4), fig);
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx + 30, cy - 4), fig);
        break;
      case 3:
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx - 30, cy + 8), fig);
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx + 30, cy + 8), acc);
        break;
      case 4:
        canvas.drawLine(Offset(cx, cy - 12), Offset(cx - 24, cy - 24), acc);
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx + 20, cy + 4), fig);
        break;
      case 5:
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx - 26, cy - 16), fig);
        canvas.drawLine(Offset(cx, cy - 10), Offset(cx + 26, cy - 16), acc);
        canvas.drawLine(Offset(cx - 26, cy - 16), Offset(cx - 14, cy - 2), fig);
        break;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 10, 28, 28),
        const Radius.circular(9),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    canvas.drawPath(
      Path()
        ..moveTo(19, 18)
        ..lineTo(19, 30)
        ..lineTo(30, 24)
        ..close(),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _SignPosePainter old) =>
      old.poseIndex != poseIndex;
}

// ─── Video Dialog ─────────────────────────────────────────────────────────────

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
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.skeletonUrl),
    );
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
