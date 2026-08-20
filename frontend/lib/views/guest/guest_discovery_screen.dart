import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/services/firebase_analytics_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/guest/guest_landing_screen.dart';
import 'package:hopetsit/views/guest/signup_wall_sheet.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v535 — SPEC ONBOARDING P1.1 : l'ÉCRAN DÉCOUVERTE INVITÉ.
/// v540 — maquette LAP écran 3 « Gardiens près de chez vous » : grille
/// d'avatars circulaires avec anneau couleur rôle (bleu gardien / vert
/// promeneur), filtres Tous / Pet sitters / Pet walkers, cellule « +N Voir
/// tout », et FICHE PROFIL INVITÉ complète en bottom sheet (photo, badge ✓,
/// note, ville, bio, services & tarifs). Toute action de contact ouvre le
/// mur d'inscription contextuel [SignupWallSheet].
class GuestDiscoveryScreen extends StatefulWidget {
  const GuestDiscoveryScreen({super.key});

  @override
  State<GuestDiscoveryScreen> createState() => _GuestDiscoveryScreenState();
}

class _GuestDiscoveryScreenState extends State<GuestDiscoveryScreen> {
  bool _loading = true;
  bool _showAll = false;
  String _filter = 'all'; // all | sitter | walker
  List<Map<String, dynamic>> _providers = const [];

  static const _ink = Color(0xFF1B222E);
  static const _muted = Color(0xFF6B6259);
  static const _sitterBlue = Color(0xFF3A78EE);
  static const _walkerGreen = Color(0xFF27AE60);

  @override
  void initState() {
    super.initState();
    FirebaseAnalyticsService.instance.logFunnel('guest_browse');
    _load();
  }

  Future<void> _load() async {
    final api = Get.isRegistered<ApiClient>()
        ? Get.find<ApiClient>()
        : Get.put(ApiClient(), permanent: true);
    final out = <Map<String, dynamic>>[];
    // Gardiens puis promeneurs — les deux listes sont publiques. Chaque appel
    // est best-effort : si l'un échoue (réseau), on montre l'autre.
    for (final entry in const [
      ['/sitters', 'sitters', 'sitter'],
      ['/walkers', 'walkers', 'walker'],
    ]) {
      try {
        final r = await api.get(entry[0]);
        final list = (r is Map ? r[entry[1]] : null) as List<dynamic>?;
        if (list == null) continue;
        for (final raw in list) {
          if (raw is! Map) continue;
          final m = Map<String, dynamic>.from(raw);
          m['_role'] = entry[2];
          out.add(m);
        }
      } catch (_) {/* best-effort */}
    }
    // v537 — vitrine PRO : on masque les profils fantômes (ni photo ni
    // ville) qui décrédibilisaient la première impression (Daniel).
    out.removeWhere((x) => _avatarOf(x).isEmpty && _cityOf(x).isEmpty);
    // v538 — badge ✓ (payant) d'abord, puis photo+ville, puis note.
    out.sort((a, b) {
      int score(Map<String, dynamic> x) {
        var s = 0;
        if (_isVerified(x)) s += 8;
        if (_avatarOf(x).isNotEmpty) s += 2;
        if (_cityOf(x).isNotEmpty) s += 1;
        return s;
      }

      final d = score(b).compareTo(score(a));
      if (d != 0) return d;
      return _ratingOf(b).compareTo(_ratingOf(a));
    });
    if (mounted) {
      setState(() {
        _providers = out;
        _loading = false;
      });
    }
  }

  // ── Helpers données ──────────────────────────────────────────────────────
  /// v539 — FIX « écran gris » : certains champs (tarifs, notes) arrivent en
  /// String depuis d'anciennes fiches → un cast `as num?` levait une
  /// exception de build en release (= zone grise). Conversion tolérante.
  static num? _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  static String _avatarOf(Map<String, dynamic> m) {
    final a = m['avatar'];
    if (a is Map) return (a['url'] ?? '').toString();
    return (a ?? m['profileImage'] ?? '').toString();
  }

  static String _cityOf(Map<String, dynamic> m) {
    final loc = m['location'];
    if (loc is Map) return (loc['city'] ?? '').toString();
    return (m['city'] ?? '').toString();
  }

  static bool _isVerified(Map<String, dynamic> m) =>
      m['identityVerified'] == true || m['kycStatus'] == 'verified';

  static double _ratingOf(Map<String, dynamic> m) =>
      _num(m['averageRating'])?.toDouble() ?? 0;

  static String _bioOf(Map<String, dynamic> m) {
    for (final k in const ['bio', 'about', 'description']) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  static String _currencyOf(Map<String, dynamic> m) =>
      (m['currency'] ?? 'EUR').toString() == 'EUR'
          ? '€'
          : (m['currency'] ?? '€').toString();

  /// Plus petit tarif renseigné (> 0), pour « À partir de X € ».
  static num? _priceOf(Map<String, dynamic> m) {
    final candidates = <num?>[];
    final sp = m['servicePricing'];
    if (sp is Map) {
      for (final v in sp.values) {
        if (v is Map) candidates.add(_num(v['basePrice']));
      }
    }
    candidates
      ..add(_num(m['hourlyRate']))
      ..add(_num(m['dailyRate']))
      ..add(_num(m['rate']));
    final valid = candidates.whereType<num>().where((p) => p > 0).toList();
    if (valid.isEmpty) return null;
    valid.sort();
    return valid.first;
  }

  /// Services activés avec tarif (clé, prix) pour la fiche profil.
  static List<MapEntry<String, num>> _servicesOf(Map<String, dynamic> m) {
    final out = <MapEntry<String, num>>[];
    final sp = m['servicePricing'];
    if (sp is Map) {
      for (final e in sp.entries) {
        if (e.value is Map) {
          final p = _num((e.value as Map)['basePrice']);
          if (p != null && p > 0) out.add(MapEntry(e.key.toString(), p));
        }
      }
    }
    return out;
  }

  /// Libellé traduit d'un service (walk/daycare/boarding/visit…), avec
  /// repli lisible si la clé n'existe pas en i18n.
  static String _serviceLabel(String key) {
    final k = 'signup_service_$key';
    final t = k.tr;
    if (t != k) return t;
    final clean = key.replaceAll('_', ' ');
    return clean.isEmpty
        ? key
        : '${clean[0].toUpperCase()}${clean.substring(1)}';
  }

  String _roleName(bool isWalker) =>
      isWalker ? 'pawmap_default_walker'.tr : 'pawmap_default_sitter'.tr;

  List<Map<String, dynamic>> get _filtered => _filter == 'all'
      ? _providers
      : _providers.where((m) => m['_role'] == _filter).toList();

  /// Ville la plus fréquente parmi les profils, pour le sous-titre
  /// « Les derniers inscrits · ville ».
  String get _topCity {
    final counts = <String, int>{};
    for (final m in _providers) {
      final c = _cityOf(m);
      if (c.isNotEmpty) counts[c] = (counts[c] ?? 0) + 1;
    }
    if (counts.isEmpty) return '';
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : const Color(0xFFFFF9F4),
      body: Container(
        decoration: isDark
            ? null
            : const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF9F4), Color(0xFFFFF3EA)],
                ),
              ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête : retour + titres + connexion ─────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 12.w, 4.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Get.offAll(() => const GuestLandingScreen());
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(9.w),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isDark
                                ? AppColors.dividerDark
                                : const Color(0xFFECE5DE),
                          ),
                        ),
                        child: Icon(Icons.arrow_back_rounded,
                            size: 20.sp,
                            color: isDark ? Colors.white : _ink),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FredokaText(
                            text: 'guest_near_title'.tr,
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : _ink,
                            maxLines: 1,
                          ),
                          SizedBox(height: 1.h),
                          InterText(
                            text: _topCity.isEmpty
                                ? 'guest_latest'.tr
                                : '${'guest_latest'.tr} · $_topCity',
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : _muted,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Get.to(() => const LoginScreen()),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: InterText(
                        text: 'guest_login'.tr,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFC92A12),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),

              // ── Filtres : Tous / Pet sitters / Pet walkers ─────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    _chip('guest_filter_all'.tr, 'all',
                        isDark ? Colors.white : _ink, isDark),
                    SizedBox(width: 8.w),
                    _chip('pawmap_default_sitter'.tr, 'sitter', _sitterBlue,
                        isDark),
                    SizedBox(width: 8.w),
                    _chip('pawmap_default_walker'.tr, 'walker', _walkerGreen,
                        isDark),
                  ],
                ),
              ),
              SizedBox(height: 6.h),

              // ── Grille d'avatars ───────────────────────────────────────
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _grid(isDark),
              ),
            ],
          ),
        ),
      ),
      // ── CTA permanent : créer un compte ────────────────────────────────
      // v537 — Daniel (Samsung, nav 3 boutons) : le CTA passait SOUS la barre
      // système. Avec targetSdk 35 l'app est edge-to-edge et le SafeArea du
      // bottomSheet recevait un padding déjà consommé par le Scaffold →
      // on utilise viewPadding (valeur brute, jamais consommée).
      bottomSheet: Container(
        color: isDark ? AppColors.backgroundDark : const Color(0xFFFFF3EA),
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w,
            14.h + MediaQuery.viewPaddingOf(context).bottom),
        child: SafeArea(
          top: false,
          bottom: false,
          child: GestureDetector(
            onTap: () => SignupWallSheet.show(trigger: 'cta'),
            child: Container(
              width: double.infinity,
              height: 50.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE25822), Color(0xFFC92A12)],
                ),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC92A12).withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: PoppinsText(
                  text: 'guest_create_account'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color color, bool isDark) {
    final selected = _filter == value;
    final bg = selected
        ? (value == 'all' ? _ink : color)
        : (isDark ? AppColors.surfaceDark : Colors.white);
    final fg = selected
        ? Colors.white
        : (isDark ? AppColors.textSecondaryDark : _muted);
    return GestureDetector(
      onTap: () => setState(() {
        _filter = value;
        _showAll = false;
      }),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99.r),
          border: selected
              ? null
              : Border.all(
                  color: isDark
                      ? AppColors.dividerDark
                      : const Color(0xFFECE5DE),
                ),
        ),
        child: InterText(
          text: label,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _grid(bool isDark) {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: InterText(
            text: 'guest_empty'.tr,
            fontSize: 14.sp,
            color: Colors.grey,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // 8 profils visibles + cellule « +N Voir tout » si plus.
    const visibleCount = 8;
    final collapsed = !_showAll && items.length > visibleCount + 1;
    final shown = collapsed ? items.sublist(0, visibleCount) : items;
    final extra = items.length - shown.length;

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 96.h),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14.h,
          crossAxisSpacing: 10.w,
          childAspectRatio: 0.72,
        ),
        itemCount: shown.length + (collapsed ? 1 : 0),
        itemBuilder: (_, i) {
          if (collapsed && i == shown.length) {
            return _seeAllCell(extra, isDark);
          }
          return _gridCell(shown[i], isDark);
        },
      ),
    );
  }

  Widget _gridCell(Map<String, dynamic> m, bool isDark) {
    final name = (m['name'] ?? '').toString();
    final avatar = _avatarOf(m);
    final isWalker = m['_role'] == 'walker';
    final verified = _isVerified(m);
    final roleColor = isWalker ? _walkerGreen : _sitterBlue;

    return GestureDetector(
      onTap: () => _openProfile(m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 72.w,
                height: 72.w,
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: roleColor, width: 2.4),
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                ),
                child: ClipOval(
                  child: avatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatar,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _fallbackAvatar(roleColor),
                        )
                      : _fallbackAvatar(roleColor),
                ),
              ),
              if (verified)
                Positioned(
                  right: -1.w,
                  bottom: -1.h,
                  child: Container(
                    width: 21.w,
                    height: 21.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4C04A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.backgroundDark
                            : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Icon(Icons.check_rounded,
                        size: 12.sp, color: const Color(0xFF3D2E00)),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          PoppinsText(
            text: name.isEmpty ? _roleName(isWalker) : name.split(' ').first,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : _ink,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 3.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.5.h),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99.r),
            ),
            child: InterText(
              text: _roleName(isWalker),
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w700,
              color: roleColor,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _seeAllCell(int extra, bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _showAll = true),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? AppColors.surfaceDark
                  : const Color(0xFFC92A12).withValues(alpha: 0.06),
              border: Border.all(
                color: const Color(0xFFC92A12).withValues(alpha: 0.45),
                width: 1.6,
              ),
            ),
            child: Center(
              child: PoppinsText(
                text: '+$extra',
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFC92A12),
              ),
            ),
          ),
          SizedBox(height: 6.h),
          InterText(
            text: 'guest_see_all'.tr,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFC92A12),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(Color color) => Container(
        color: color.withValues(alpha: 0.15),
        child: Icon(Icons.pets, color: color, size: 26.sp),
      );

  // ── Fiche profil invité (mode invité COMPLET) ────────────────────────────
  void _openProfile(Map<String, dynamic> m) {
    FirebaseAnalyticsService.instance
        .logFunnel('guest_profile_view', params: {'role': '${m['_role']}'});
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = (m['name'] ?? '').toString();
    final city = _cityOf(m);
    final avatar = _avatarOf(m);
    final isWalker = m['_role'] == 'walker';
    final rating = _ratingOf(m);
    final reviews = _num(m['reviewsCount'])?.toInt() ?? 0;
    final verified = _isVerified(m);
    final bio = _bioOf(m);
    final services = _servicesOf(m);
    final price = _priceOf(m);
    final currency = _currencyOf(m);
    final roleColor = isWalker ? _walkerGreen : _sitterBlue;

    Get.bottomSheet(
      isScrollControlled: true,
      Container(
        constraints: BoxConstraints(maxHeight: Get.height * 0.82),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w,
            16.h + MediaQuery.viewPaddingOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99.r),
                ),
              ),
              SizedBox(height: 16.h),

              // Avatar + badge ✓
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 96.w,
                    height: 96.w,
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: roleColor, width: 3),
                    ),
                    child: ClipOval(
                      child: avatar.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatar,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _fallbackAvatar(roleColor),
                            )
                          : _fallbackAvatar(roleColor),
                    ),
                  ),
                  if (verified)
                    Positioned(
                      right: 0,
                      bottom: 2.h,
                      child: Container(
                        width: 26.w,
                        height: 26.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4C04A),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isDark ? AppColors.surfaceDark : Colors.white,
                            width: 2.4,
                          ),
                        ),
                        child: Icon(Icons.check_rounded,
                            size: 15.sp, color: const Color(0xFF3D2E00)),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 10.h),
              PoppinsText(
                text: name.isEmpty ? _roleName(isWalker) : name,
                fontSize: 19.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : _ink,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 6.h),

              // Rôle + ✓ Vérifié
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99.r),
                    ),
                    child: InterText(
                      text: _roleName(isWalker),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: roleColor,
                    ),
                  ),
                  if (verified) ...[
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4C04A),
                        borderRadius: BorderRadius.circular(99.r),
                      ),
                      child: InterText(
                        text: '✓ ${'guest_verified'.tr}',
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF3D2E00),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 10.h),

              // Note + ville + prix mini
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (rating > 0) ...[
                    Icon(Icons.star_rounded,
                        size: 16.sp, color: const Color(0xFFF4C04A)),
                    InterText(
                      text:
                          ' ${rating.toStringAsFixed(1)}${reviews > 0 ? ' ($reviews)' : ''}',
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : _ink,
                    ),
                    SizedBox(width: 12.w),
                  ],
                  if (city.isNotEmpty) ...[
                    Icon(Icons.place_outlined,
                        size: 14.sp,
                        color:
                            isDark ? AppColors.textSecondaryDark : _muted),
                    InterText(
                      text: ' $city',
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : _muted,
                    ),
                    SizedBox(width: 12.w),
                  ],
                  if (price != null)
                    InterText(
                      text: 'guest_from_price'.trParams({
                        'price': '${price.toStringAsFixed(0)} $currency'
                      }),
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFC92A12),
                    ),
                ],
              ),

              // Bio
              if (bio.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PoppinsText(
                    text: 'guest_about'.tr,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : _ink,
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.backgroundDark
                        : const Color(0xFFFFF9F4),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: isDark
                          ? AppColors.dividerDark
                          : const Color(0xFFECE5DE),
                    ),
                  ),
                  child: InterText(
                    text: bio,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textSecondaryDark : _muted,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              // Services & tarifs
              if (services.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PoppinsText(
                    text: 'guest_services'.tr,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : _ink,
                  ),
                ),
                SizedBox(height: 6.h),
                ...services.map(
                  (s) => Container(
                    margin: EdgeInsets.only(bottom: 6.h),
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.backgroundDark
                          : const Color(0xFFFFF9F4),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isDark
                            ? AppColors.dividerDark
                            : const Color(0xFFECE5DE),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InterText(
                            text: _serviceLabel(s.key),
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : _ink,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InterText(
                          text: '${s.value.toStringAsFixed(0)} $currency',
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFC92A12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              SizedBox(height: 18.h),

              // Contacter → mur d'inscription contextuel
              GestureDetector(
                onTap: () {
                  Get.back();
                  SignupWallSheet.show(trigger: 'contact');
                },
                child: Container(
                  width: double.infinity,
                  height: 50.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE25822), Color(0xFFC92A12)],
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Center(
                    child: PoppinsText(
                      text: 'guest_contact'.tr,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
