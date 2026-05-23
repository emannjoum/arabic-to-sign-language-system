import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/colors.dart';
import '../../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _isLoading = true;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await ApiService.getProfile();
    if (!mounted) return;
    setState(() {
      _profile = data;
      _isLoading = false;
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'تسجيل الخروج',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          content: Text(
            'هل أنت متأكد؟ سيتم حفظ تقدّمك تلقائياً.',
            style: GoogleFonts.tajawal(color: AppColors.mute),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'إلغاء',
                style: GoogleFonts.tajawal(color: AppColors.mute),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'خروج',
                style: GoogleFonts.tajawal(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirm == true && mounted) await ApiService.logout();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    final hPad = isWide ? 36.0 : 20.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 22),
                    _buildIdentityCard(),
                    const SizedBox(height: 22),
                    _buildSettingsGroup(
                      eyebrow: 'إعدادات الحساب',
                      rows: [
                        const _SettingRow(
                          icon: Icons.waving_hand_outlined,
                          title: 'تعديل الملف الشخصي',
                          sub: 'الاسم، الصورة، نبذة عنك',
                        ),
                        const _SettingRow(
                          icon: Icons.check_circle_outline,
                          title: 'تغيير كلمة المرور',
                          sub: 'تغيير كلمة المرور الخاصة بك',
                        ),
                        _SettingRow(
                          icon: Icons.bookmark_border,
                          title: 'المحفوظات',
                          sub: '${_profile?['bookmarks_count'] ?? 0} إشارة',
                        ),
                        const _SettingRow(
                          icon: Icons.translate_outlined,
                          title: 'اللغة وتفضيلات العرض',
                          sub: 'العربية · فاتح',
                          badge: 'عربي',
                          badgeBg: AppColors.surfaceWarm,
                          badgeColor: AppColors.ink,
                        ),
                        _SettingRow(
                          icon: Icons.notifications_outlined,
                          title: 'الإشعارات',
                          sub: 'تفعيل أو إيقاف الإشعارات',
                          toggle: true,
                          toggleValue: _notificationsEnabled,
                          onToggle: (v) =>
                              setState(() => _notificationsEnabled = v),
                          isLast: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _buildSettingsGroup(
                      eyebrow: 'المساعدة والدعم',
                      rows: [
                        const _SettingRow(
                          icon: Icons.chat_bubble_outline,
                          title: 'مركز المساعدة',
                          sub: 'أسئلة شائعة وأدلة مصورة',
                        ),
                        const _SettingRow(
                          icon: Icons.send_outlined,
                          title: 'تواصل معنا',
                          sub: 'فريق الدعم يردّ خلال ساعة',
                          isLast: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _buildLogoutButton(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إدارة الحساب',
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mute,
                ),
              ),
              Text(
                'الملف الشخصي',
                style: GoogleFonts.tajawal(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdentityCard() {
    final username = _profile?['username'] ?? '';
    final email = _profile?['email'] ?? '';
    final initial = username.isNotEmpty ? username[0] : '؟';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primarySoft.withOpacity(0.4),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(initial: initial, size: 80),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: GoogleFonts.tajawal(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mute,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.line),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.waving_hand_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'تعديل',
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({
    required String eyebrow,
    required List<_SettingRow> rows,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: GoogleFonts.tajawal(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.mute,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            children: rows.map((r) => _buildSettingRow(r)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow(_SettingRow r) {
    return Column(
      children: [
        InkWell(
          onTap: r.toggle ? null : () {},
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(r.icon, color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.sub,
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mute,
                        ),
                      ),
                    ],
                  ),
                ),
                if (r.badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: r.badgeBg ?? AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      r.badge!,
                      style: GoogleFonts.tajawal(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: r.badgeColor ?? AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (r.toggle)
                  _Toggle(
                    value: r.toggleValue ?? false,
                    onChanged: r.onToggle ?? (_) {},
                  )
                else
                  const Icon(
                    Icons.arrow_back_ios,
                    size: 14,
                    color: AppColors.mute,
                  ),
              ],
            ),
          ),
        ),
        if (!r.isLast)
          Divider(height: 1, thickness: 1, color: AppColors.line, indent: 66),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _handleLogout,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.logout,
                color: AppColors.accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تسجيل الخروج',
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'سنحفظ تقدّمك تلقائياً',
                    style: GoogleFonts.tajawal(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mute,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_back_ios, size: 14, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────

class _SettingRow {
  final IconData icon;
  final String title;
  final String sub;
  final String? badge;
  final Color? badgeBg;
  final Color? badgeColor;
  final bool toggle;
  final bool? toggleValue;
  final void Function(bool)? onToggle;
  final bool isLast;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.sub,
    this.badge,
    this.badgeBg,
    this.badgeColor,
    this.toggle = false,
    this.toggleValue,
    this.onToggle,
    this.isLast = false,
  });
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String initial;
  final double size;
  const _Avatar({required this.initial, required this.size});

  @override
  Widget build(BuildContext context) {
    final dotSize = size * 0.22;
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDeep],
            ),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80004B49),
                blurRadius: 20,
                offset: Offset(0, 8),
                spreadRadius: -8,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: GoogleFonts.tajawal(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        Positioned(
          bottom: 2,
          left: 2,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.mintDot,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Toggle ───────────────────────────────────────────────────────────────────

class _Toggle extends StatelessWidget {
  final bool value;
  final void Function(bool) onChanged;
  const _Toggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 22,
        decoration: BoxDecoration(
          color: value ? AppColors.primary : const Color(0xFFD6D2C9),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: value ? Alignment.centerLeft : Alignment.centerRight,
        padding: const EdgeInsets.all(2),
        child: Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x2E000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
