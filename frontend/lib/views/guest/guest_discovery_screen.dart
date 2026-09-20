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
import 'package:hopetsit/views/shared/widgets/home_empty_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

/// v535 — SPEC ONBOARDING P1.1 : l'ÉCRAN DÉCOUVERTE INVITÉ.
/// v540 — maquette LAP écran 3 « Gardiens près de chez vous » : grille
/// d'avatars circulaires avec anneau couleur rôle (bleu gardien / vert
/// promeneur), filtres Tous / Pet sitters / Pet walkers, cellule « +N Voir
/// tout », et FICHE PROFIL INVITÉ complète en bottom sheet (photo, badge ✓,
/// note, ville, bio, services & tarifs). Toute action de contact ouvre le
/// mur d'inscription contextuel [SignupWallSheet].
///
/// v573 — MISE AU DESIGN DE L'APP, rendu seulement (chargement des données,
/// tri, filtres et navigation inchangés) : plus une seule couleur en dur ni
/// un seul ternaire `isDark` écrit à la main — tout passe par les helpers
/// contextuels d'`AppColors` ; le spinner nu devient un squelette de grille,
/// l'état vide passe par `HomeEmptyKit`, et les deux boutons pleine largeur
/// par `CustomButton`.
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

  /// Accents de rôle de l'app (mêmes valeurs que `RoleChip` et les accueils).
  /// `accentOn` les éclaircit sur fond sombre quand ils servent de texte.
  static const Color _sitterBlue = AppColors.sitterAccent;
  static const Color _walkerGreen = AppColors.walkerAccent;

  /// Dégradé de fond, dérivé des helpers (crème en clair, nuit en sombre).
  static List<Color> _pageGradient(BuildContext context) {
    final Color base = AppColors.scaffold(context);
    return <Color>[
      Color.lerp(base, AppColors.card(context), 0.55)!,
      base,
    ];
  }

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
    final Color brand = AppColors.accentOn(context, AppColors.primaryColor);
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _pageGradient(context),
          ),
        ),
        child: PawPatternBackground(
          color: AppColors.primaryColor,
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
                      _SquareIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            Get.offAll(() => const GuestLandingScreen());
                          }
                        },
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PoppinsText(
                              text: 'guest_near_title'.tr,
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 1.h),
                            InterText(
                              text: _topCity.isEmpty
                                  ? 'guest_latest'.tr
                                  : '${'guest_latest'.tr} · $_topCity',
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // v573 — le `TextButton` brut devient une pilule
                      // « contour » cohérente avec le reste de l'app.
                      CustomButton(
                        bgColor: Colors.transparent,
                        borderColor: brand,
                        textColor: brand,
                        title: 'guest_login'.tr,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        radius: 999.r,
                        height: 34.h,
                        width: 92.w,
                        onTap: () => Get.to(() => const LoginScreen()),
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
                      // « Tous » prenait l'encre #1B222E en dur : en mode
                      // sombre l'aplat devenait quasi invisible. Il prend
                      // désormais l'orange de la marque.
                      Flexible(
                        child: _chip('guest_filter_all'.tr, 'all',
                            AppColors.primaryColor),
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: _chip(
                            'pawmap_default_sitter'.tr, 'sitter', _sitterBlue),
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: _chip(
                            'pawmap_default_walker'.tr, 'walker', _walkerGreen),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 6.h),

                // ── Grille d'avatars ───────────────────────────────────────
                Expanded(
                  child: _loading ? const _GuestGridSkeleton() : _grid(),
                ),
              ],
            ),
          ),
        ),
      ),
      // ── CTA permanent : créer un compte ────────────────────────────────
      // v537 — Daniel (Samsung, nav 3 boutons) : le CTA passait SOUS la barre
      // système. Avec targetSdk 35 l'app est edge-to-edge et le SafeArea du
      // bottomSheet recevait un padding déjà consommé par le Scaffold →
      // on utilise viewPadding (valeur brute, jamais consommée).
      bottomSheet: Container(
        color: AppColors.scaffold(context),
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w,
            14.h + appBottomInset(context)),
        child: SafeArea(
          top: false,
          bottom: false,
          child: CustomButton(
            isGradient: true,
            title: 'guest_create_account'.tr,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            radius: 16.r,
            height: 50.h,
            onTap: () => SignupWallSheet.show(trigger: 'cta'),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    final selected = _filter == value;
    // Sélectionnée : aplat SATURÉ de la couleur (texte blanc lisible dans les
    // deux thèmes). Non sélectionnée : surface de carte + bord du thème.
    final bg = selected ? color : AppColors.card(context);
    final fg = selected ? Colors.white : AppColors.textSecondary(context);
    return GestureDetector(
      onTap: () => setState(() {
        _filter = value;
        _showAll = false;
      }),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999.r),
          border: selected
              ? null
              : Border.all(color: AppColors.divider(context), width: 1),
        ),
        child: InterText(
          text: label,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: fg,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _grid() {
    final items = _filtered;
    if (items.isEmpty) {
      // v573 — l'ancien état vide = une ligne de texte gris centrée. Le kit
      // partagé des accueils (patte animée + titre + phrase + « Rafraîchir »)
      // rend l'écran accueillant au lieu de vide.
      return ListView(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 96.h),
        children: <Widget>[
          HomeEmptyKit(
            accent: AppColors.primaryColor,
            onRefresh: _load,
            title: 'home571_empty_title'.tr,
            body: 'guest_empty'.tr,
          ),
        ],
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
            return _seeAllCell(extra);
          }
          return _gridCell(shown[i]);
        },
      ),
    );
  }

  Widget _gridCell(Map<String, dynamic> m) {
    final name = (m['name'] ?? '').toString();
    final avatar = _avatarOf(m);
    final isWalker = m['_role'] == 'walker';
    final verified = _isVerified(m);
    final roleColor = AppColors.accentOn(
        context, isWalker ? _walkerGreen : _sitterBlue);

    return GestureDetector(
      onTap: () => _openProfile(m),
      behavior: HitTestBehavior.opaque,
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
                  color: AppColors.card(context),
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
                        color: AppColors.card(context),
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
            color: AppColors.textPrimary(context),
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

  Widget _seeAllCell(int extra) {
    final Color brand = AppColors.accentOn(context, AppColors.primaryColor);
    return GestureDetector(
      onTap: () => setState(() => _showAll = true),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: brand.withValues(alpha: 0.08),
              border: Border.all(
                color: brand.withValues(alpha: 0.45),
                width: 1.6,
              ),
            ),
            child: Center(
              child: PoppinsText(
                text: '+$extra',
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: brand,
              ),
            ),
          ),
          SizedBox(height: 6.h),
          InterText(
            text: 'guest_see_all'.tr,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
            color: brand,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    final roleColor = AppColors.accentOn(
        context, isWalker ? _walkerGreen : _sitterBlue);
    final Color ink = AppColors.textPrimary(context);
    final Color muted = AppColors.textSecondary(context);
    final Color brand = AppColors.accentOn(context, AppColors.primaryColor);

    Get.bottomSheet(
      isScrollControlled: true,
      Container(
        constraints: BoxConstraints(maxHeight: Get.height * 0.82),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w,
            16.h + appBottomInset(context)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.divider(context),
                  borderRadius: BorderRadius.circular(999.r),
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
                            color: AppColors.card(context),
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
                color: ink,
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
                      color: ink,
                    ),
                    SizedBox(width: 12.w),
                  ],
                  if (city.isNotEmpty) ...[
                    Icon(Icons.place_outlined, size: 14.sp, color: muted),
                    Flexible(
                      child: InterText(
                        text: ' $city',
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                        color: muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                      color: brand,
                      maxLines: 1,
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
                    color: ink,
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.scaffold(context),
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(
                      color: AppColors.divider(context).withValues(alpha: 0.8),
                      width: 1,
                    ),
                  ),
                  child: InterText(
                    text: bio,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w500,
                    color: muted,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              // Services & tarifs
              if (services.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Container(
                      width: 26.w,
                      height: 26.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9.r),
                      ),
                      child: Icon(Icons.sell_rounded,
                          size: 14.sp, color: roleColor),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: PoppinsText(
                        text: 'guest_services'.tr,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: ink,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                ...services.map(
                  (s) => Container(
                    margin: EdgeInsets.only(bottom: 6.h),
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: AppColors.scaffold(context),
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(
                        color:
                            AppColors.divider(context).withValues(alpha: 0.8),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InterText(
                            text: _serviceLabel(s.key),
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            color: ink,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        InterText(
                          text: '${s.value.toStringAsFixed(0)} $currency',
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w800,
                          color: brand,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              SizedBox(height: 18.h),

              // Contacter → mur d'inscription contextuel
              CustomButton(
                isGradient: true,
                title: 'guest_contact'.tr,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                radius: 16.r,
                height: 50.h,
                onTap: () {
                  Get.back();
                  SignupWallSheet.show(trigger: 'contact');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton carré de l'en-tête (retour), posé sur la carte du thème.
class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(14.r);
    return Material(
      color: AppColors.card(context),
      borderRadius: br,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: br,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(9.w),
          decoration: BoxDecoration(
            borderRadius: br,
            border: Border.all(color: AppColors.divider(context), width: 1),
          ),
          child: Icon(icon,
              size: 20.sp, color: AppColors.textPrimary(context)),
        ),
      ),
    );
  }
}

/// Squelette de la grille pendant le chargement.
///
/// v573 — remplace le `CircularProgressIndicator` seul : l'invité voit tout de
/// suite la FORME de l'écran qui arrive, ce qui le fait paraître plus rapide.
class _GuestGridSkeleton extends StatefulWidget {
  const _GuestGridSkeleton();

  @override
  State<_GuestGridSkeleton> createState() => _GuestGridSkeletonState();
}

class _GuestGridSkeletonState extends State<_GuestGridSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color base = AppColors.divider(context).withValues(alpha: 0.55);
    final Color hi = AppColors.divider(context).withValues(alpha: 0.20);

    Widget cell() => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(color: base, shape: BoxShape.circle),
            ),
            SizedBox(height: 8.h),
            Container(
              width: 46.w,
              height: 9.h,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(999.r),
              ),
            ),
            SizedBox(height: 6.h),
            Container(
              width: 60.w,
              height: 12.h,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(999.r),
              ),
            ),
          ],
        );

    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? child) {
        final double t = _c.value * 2 - 0.5;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect rect) => LinearGradient(
            begin: Alignment(-1 + t * 2, -0.4),
            end: Alignment(t * 2, 0.4),
            colors: <Color>[base, hi, base],
          ).createShader(rect),
          child: child,
        );
      },
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 96.h),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14.h,
          crossAxisSpacing: 10.w,
          childAspectRatio: 0.72,
        ),
        itemCount: 9,
        itemBuilder: (_, __) => cell(),
      ),
    );
  }
}
