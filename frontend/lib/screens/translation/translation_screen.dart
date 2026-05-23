import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../core/colors.dart';
import '../../services/api_service.dart';
import '../../models/skeleton_frame.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class _WordGroup {
  final String label;
  final String english;
  final String duration;
  final List<SkeletonFrame> frames;
  _WordGroup({
    required this.label,
    required this.duration,
    required this.frames,
  }) : english = '';
}

String _fmtMs(int ms) {
  final s = (ms / 1000).round();
  return '0:${s.toString().padLeft(2, '0')}';
}

// ─── Main widget ──────────────────────────────────────────────────────────────

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
  int _activeWordIndex = 0;
  List<_WordGroup> _wordGroups = [];
  Set<String> _bookmarkedWords = {};

  List<_WordGroup> get _groups => _wordGroups;

  String get _totalDuration {
    final ms = _groups.fold(
      0,
      (s, g) => s + g.frames.fold(0, (a, f) => a + f.delayMs),
    );
    return _fmtMs(ms);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) _textController.text = widget.initialText!;
    if (widget.initialResponse != null) {
      _apiResponse = widget.initialResponse;
      _buildWordGroups(_apiResponse!.data);
      if (_apiResponse!.data.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _initVideo(_apiResponse!.data.first.skeletonUrl),
        );
      }
    }
  }

  void _buildWordGroups(List<SkeletonFrame> frames) {
    final groups = <_WordGroup>[];
    int i = 0;
    while (i < frames.length) {
      final frame = frames[i];
      if (_isSingleLetter(frame.label)) {
        var name = frame.label;
        final grp = [frame];
        int j = i + 1;
        while (j < frames.length && _isSingleLetter(frames[j].label)) {
          name += frames[j].label;
          grp.add(frames[j]);
          j++;
        }
        final ms = grp.fold(0, (s, f) => s + f.delayMs);
        groups.add(_WordGroup(label: name, duration: _fmtMs(ms), frames: grp));
        i = j;
      } else {
        groups.add(
          _WordGroup(
            label: frame.label,
            duration: _fmtMs(frame.delayMs),
            frames: [frame],
          ),
        );
        i++;
      }
    }
    setState(() => _wordGroups = groups);
  }

  bool _isSingleLetter(String l) =>
      l.length == 1 && RegExp(r'[\u0600-\u06FF]').hasMatch(l);

  void _videoListener() {
    if (_videoController == null) return;
    final v = _videoController!.value;
    if (v.isInitialized && !v.isPlaying && v.position >= v.duration) {
      _videoController!.removeListener(_videoListener);
      _seekToWord((_activeWordIndex + 1) % _groups.length);
    }
  }

  void _seekToWord(int idx) {
    setState(() => _activeWordIndex = idx);
    if (_wordGroups.isEmpty) return;
    int flat = 0;
    for (int i = 0; i < idx && i < _wordGroups.length; i++) {
      flat += _wordGroups[i].frames.length;
    }
    if (flat < (_apiResponse?.data.length ?? 0)) {
      _initVideo(_apiResponse!.data[flat].skeletonUrl);
    }
  }

  Future<void> _initVideo(String url) async {
    _videoController?.removeListener(_videoListener);
    await _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
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
      _activeWordIndex = 0;
    });
    _videoController?.pause();
    final response = await ApiService.processText(
      text,
      forceMode: "translation",
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _apiResponse = response;
      _activeWordIndex = 0;
    });
    if (response != null && response.data.isNotEmpty) {
      _buildWordGroups(response.data);
      _initVideo(response.data.first.skeletonUrl);
    }
  }

  Future<void> _toggleBookmark(String word) async {
    final had = _bookmarkedWords.contains(word);
    setState(
      () => had ? _bookmarkedWords.remove(word) : _bookmarkedWords.add(word),
    );
    final ok = had
        ? await ApiService.removeBookmark(word)
        : await ApiService.addBookmark(word);
    if (!ok && mounted) {
      setState(
        () => had ? _bookmarkedWords.add(word) : _bookmarkedWords.remove(word),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("فشل الحفظ. حاول مجدداً.")));
    }
  }

  void _togglePlayPause() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }
    setState(() {
      _videoController!.value.isPlaying
          ? _videoController!.pause()
          : _videoController!.play();
    });
  }

  void _replay() {
    _videoController?.seekTo(Duration.zero);
    _videoController?.play();
    setState(() {});
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
    final isPushed = widget.initialResponse != null;
    final isWide = MediaQuery.of(context).size.width >= 800;
    final hPad = isWide ? 36.0 : 20.0;
    final groups = _groups;
    final activeWord = groups.isNotEmpty ? groups[_activeWordIndex] : null;
    final videoReady =
        _videoController != null && _videoController!.value.isInitialized;
    final isPlaying = videoReady && _videoController!.value.isPlaying;

    final content = Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _buildInputCard(),
              if (groups.isNotEmpty) ...[
                const SizedBox(height: 18),
                _buildChipsRow(groups),
                const SizedBox(height: 20),
                if (isWide)
                  _buildWide(activeWord, groups, videoReady, isPlaying)
                else
                  _buildNarrow(activeWord, groups, videoReady, isPlaying),
                const SizedBox(height: 22),
                _buildSequenceStrip(groups),
              ],
            ],
          ),
        ),
      ),
    );

    return isPushed
        ? Scaffold(backgroundColor: AppColors.surface, body: content)
        : content;
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ترجمة فورية',
          style: GoogleFonts.tajawal(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.mute,
          ),
        ),
        Text(
          'اكتب جملة وترجمها إلى لغة الإشارة',
          style: GoogleFonts.tajawal(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  // ── Input card ─────────────────────────────────────────────────────────────

  Widget _buildInputCard() {
    final charCount = _textController.text.length;
    final wordCount = _textController.text.trim().isEmpty
        ? 0
        : _textController.text.trim().split(RegExp(r'\s+')).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E004B49),
            blurRadius: 30,
            offset: Offset(0, 10),
            spreadRadius: -16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.translate_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _textController,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  style: GoogleFonts.tajawal(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'اكتب جملة بالعربية...',
                    hintStyle: GoogleFonts.tajawal(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mute,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CustomPaint(
            size: const Size(double.infinity, 1),
            painter: _DashedLinePainter(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        '$charCount حرفاً · $wordCount كلمات',
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mute,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const SizedBox(width: 8),
                      const SizedBox(width: 8),
                      _MiniBtn(
                        icon: Icons.clear,
                        label: 'مسح',
                        onTap: () {
                          _textController.clear();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _isLoading ? null : _processTranslation,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40004B49),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ترجم إلى الإشارة',
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 14,
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sentence chips row ─────────────────────────────────────────────────────

  Widget _buildChipsRow(List<_WordGroup> groups) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(
            'الجملة:',
            style: GoogleFonts.tajawal(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: List.generate(groups.length, (i) {
                final active = i == _activeWordIndex;
                return GestureDetector(
                  onTap: () => _seekToWord(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: active
                          ? const [
                              BoxShadow(
                                color: Color(0x40004B49),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      groups[i].label,
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _seekToWord(0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_circle_outline,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'شغّل الكل',
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Wide / Narrow layouts ──────────────────────────────────────────────────

  Widget _buildWide(
    _WordGroup? active,
    List<_WordGroup> groups,
    bool videoReady,
    bool isPlaying,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 16,
          child: _buildPlayer(active, groups, videoReady, isPlaying),
        ),
        const SizedBox(width: 18),
        Expanded(flex: 10, child: _buildSideCol(active)),
      ],
    );
  }

  Widget _buildNarrow(
    _WordGroup? active,
    List<_WordGroup> groups,
    bool videoReady,
    bool isPlaying,
  ) {
    return Column(
      children: [
        _buildPlayer(active, groups, videoReady, isPlaying),
        const SizedBox(height: 18),
        _buildSideCol(active),
      ],
    );
  }

  // ── Featured player ────────────────────────────────────────────────────────

  Widget _buildPlayer(
    _WordGroup? active,
    List<_WordGroup> groups,
    bool videoReady,
    bool isPlaying,
  ) {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: const Color(0xFF003634),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 50,
            offset: Offset(0, 24),
            spreadRadius: -20,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: videoReady
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  )
                : CustomPaint(
                    painter: _SignPosePainter(poseIndex: _activeWordIndex % 6),
                  ),
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.mintDot,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'إشارة ${_activeWordIndex + 1} من ${groups.length}',
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _GlassBtn(
                  icon: _bookmarkedWords.contains(active?.label ?? '')
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  onTap: active != null
                      ? () => _toggleBookmark(active.label)
                      : null,
                ),
                const SizedBox(width: 6),
                const _GlassBtn(icon: Icons.fullscreen),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                children: [
                  videoReady
                      ? ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: _videoController!,
                          builder: (_, v, __) {
                            final p = v.duration.inMilliseconds > 0
                                ? (v.position.inMilliseconds /
                                          v.duration.inMilliseconds)
                                      .clamp(0.0, 1.0)
                                : 0.0;
                            return _ProgBar(progress: p);
                          },
                        )
                      : const _ProgBar(progress: 0),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _seekToWord(
                          (_activeWordIndex - 1).clamp(0, groups.length - 1),
                        ),
                        child: const Icon(
                          Icons.skip_previous,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () =>
                            _seekToWord((_activeWordIndex + 1) % groups.length),
                        child: const Icon(
                          Icons.skip_next,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      videoReady
                          ? ValueListenableBuilder<VideoPlayerValue>(
                              valueListenable: _videoController!,
                              builder: (_, v, __) {
                                String f(Duration d) =>
                                    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
                                return Text(
                                  '${f(v.position)} / ${f(v.duration)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontFamily: 'monospace',
                                  ),
                                );
                              },
                            )
                          : const Text(
                              '0:00 / 0:00',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontFamily: 'monospace',
                              ),
                            ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '1x',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _replay,
                        child: const Icon(
                          Icons.replay,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Side column ────────────────────────────────────────────────────────────

  Widget _buildSideCol(_WordGroup? active) {
    if (active == null) return const SizedBox.shrink();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الإشارة الحالية',
                          style: GoogleFonts.tajawal(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mute,
                          ),
                        ),
                        Text(
                          active.label,
                          style: GoogleFonts.tajawal(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        if (active.english.isNotEmpty)
                          Text(
                            active.english,
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.mute,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'اسم',
                      style: GoogleFonts.tajawal(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Sequence strip ─────────────────────────────────────────────────────────

  Widget _buildSequenceStrip(List<_WordGroup> groups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'تسلسل الإشارات',
              style: GoogleFonts.tajawal(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            Text(
              'المدة الكلية: $_totalDuration',
              style: GoogleFonts.tajawal(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.mute,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(groups.length, (i) {
            final active = i == _activeWordIndex;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i > 0 ? 12.0 : 0),
                child: GestureDetector(
                  onTap: () => _seekToWord(i),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active ? AppColors.primary : AppColors.line,
                        width: active ? 2 : 1,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.13,
                                ),
                                spreadRadius: 4,
                                blurRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            SizedBox(
                              height: 92,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: CustomPaint(
                                  size: const Size(double.infinity, 92),
                                  painter: _SignPosePainter(poseIndex: i % 6),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 5,
                              left: 5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.accent
                                      : Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 5,
                              right: 5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  groups[i].duration,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          groups[i].label,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        if (groups[i].english.isNotEmpty)
                          Text(
                            groups[i].english,
                            style: GoogleFonts.tajawal(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.mute,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _MiniBtn({required this.icon, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.mute),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.tajawal(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mute,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _GlassBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _ProgBar extends StatelessWidget {
  final double progress;
  const _ProgBar({required this.progress});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        FractionallySizedBox(
          widthFactor: progress,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.tajawal(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.mute,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.tajawal(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActBtn({required this.icon, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceWarm,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppColors.ink),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.tajawal(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
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

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 6, 0), p);
      x += 10;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
