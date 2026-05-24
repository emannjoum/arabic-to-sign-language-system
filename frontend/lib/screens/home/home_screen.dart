import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/colors.dart';
import '../../services/api_service.dart';
import '../../models/skeleton_frame.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToBookmarks;
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onNavigateToLearning;
  final VoidCallback? onNavigateToTranslation;
  final void Function(int index, String text, ProcessResponse response)?
  onNavigateWithResponse;
  const HomeScreen({
    super.key,
    this.onNavigateToBookmarks,
    this.onNavigateToProfile,
    this.onNavigateToLearning,
    this.onNavigateToTranslation,
    this.onNavigateWithResponse,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleSend() async {
    final text = _searchController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isLoading = true);
    final response = await ApiService.processText(text);
    if (mounted) {
      setState(() => _isLoading = false);
      if (response != null) {
        if (response.mode == "translation") {
          widget.onNavigateWithResponse?.call(2, text, response);
        } else if (response.mode == "teaching") {
          widget.onNavigateWithResponse?.call(1, text, response);
        }
        _searchController.clear();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("تعذّر الاتصال بالخادم")));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            const SizedBox(height: 16),
            _buildHeroCard(),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 28),
            _buildQuickAccess(),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.notifications_outlined,
            size: 18,
            color: AppColors.ink,
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14004B49),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/SignlyLogo.jpeg',
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  // ── Hero card ─────────────────────────────────────────────────────────────

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -10,
            bottom: -10,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
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
                      'مدرّب في Signly',
                      style: GoogleFonts.tajawal(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'ماذا تودّ أن\nتتعلّم اليوم؟',
                style: GoogleFonts.tajawal(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.3,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ابحث عن أي كلمة وشاهد إشاراتها',
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10004B49),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isLoading ? null : _handleSend,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(11),
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
                        const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ابحث',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.tajawal(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'اكتب كلمة أو موضوعاً...',
                hintStyle: GoogleFonts.tajawal(
                  fontSize: 15,
                  color: AppColors.mute,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick access ──────────────────────────────────────────────────────────

  Widget _buildQuickAccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الوصول السريع',
          style: GoogleFonts.tajawal(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final ratio = constraints.maxWidth < 400 ? 1.8 : 2.8;
            return GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: ratio,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _QuickCard(
                  label: 'ترجمة',
                  sub: 'نص ← إشارة',
                  icon: Icons.translate_outlined,
                  bg: AppColors.primarySoft,
                  iconColor: AppColors.primary,
                  onTap: widget.onNavigateToTranslation,
                ),
                _QuickCard(
                  label: 'تعلّم',
                  sub: 'إشاراتي',
                  icon: Icons.menu_book_outlined,
                  bg: const Color(0xFFFFF4EC),
                  iconColor: AppColors.accent,
                  onTap: widget.onNavigateToLearning,
                ),
                _QuickCard(
                  label: 'المحفوظات',
                  sub: 'قائمتي',
                  icon: Icons.bookmark_border,
                  bg: const Color(0xFFEDF5F3),
                  iconColor: AppColors.primary,
                  onTap: widget.onNavigateToBookmarks,
                ),
                _QuickCard(
                  label: 'الملف الشخصي',
                  sub: 'حسابي',
                  icon: Icons.person_outline,
                  bg: const Color(0xFFF0EEFF),
                  iconColor: const Color(0xFF7C5CBF),
                  onTap: widget.onNavigateToProfile,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _QuickCard extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  final Color bg;
  final Color iconColor;
  final VoidCallback? onTap;

  const _QuickCard({
    required this.label,
    required this.sub,
    required this.icon,
    required this.bg,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.tajawal(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  sub,
                  style: GoogleFonts.tajawal(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mute,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
