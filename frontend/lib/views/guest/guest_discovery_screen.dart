import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/services/firebase_analytics_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/guest/signup_wall_sheet.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v535 — SPEC ONBOARDING P1.1 : l'ÉCRAN DÉCOUVERTE INVITÉ.
/// v538 — refonte « pro & beau » (Daniel) : 3 onglets — CARTE (atterrissage,
/// l'ADN GPS de l'app), LISTE (cartes riches : badge ✓ payant mis en valeur,
/// tarif, note) et DEMANDES (annonces publiques des propriétaires → recrute
/// les prestataires). Toute action ouvre le mur contextuel [SignupWallSheet].
class GuestDiscoveryScreen extends StatefulWidget {
  const GuestDiscoveryScreen({super.key});

  @override
  State<GuestDiscoveryScreen> createState() => _GuestDiscoveryScreenState();
}

class _GuestDiscoveryScreenState extends State<GuestDiscoveryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _providers = const [];

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

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: SafeArea(
        child: Column(
          children: [
            // ── En-tête : logo + connexion ─────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 8.w, 6.h),
              child: Row(
                children: [
                  Image.asset('assets/brand/png/logo-mark.png',
                      width: 38.w, height: 38.w),
                  SizedBox(width: 8.w),
                  PoppinsText(
                    text: 'HoPetSit',
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Get.to(() => const LoginScreen()),
                    child: InterText(
                      text: 'guest_login'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            // ── Promesse en une ligne ──────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InterText(
                  text: 'guest_tagline'.tr,
                  fontSize: 13.sp,
                  color: Colors.grey,
                ),
              ),
            ),
            SizedBox(height: 10.h),
            SizedBox(height: 4.h),
            // ── Liste des prestataires (v539 : liste seule — la carte
            // révélait la position exacte des sitters, retirée à la demande
            // de Daniel ; l'onglet Demandes attendra d'avoir des annonces).
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _listView(),
            ),
          ],
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
            14.h + MediaQuery.viewPaddingOf(context).bottom),
        child: SafeArea(
          top: false,
          bottom: false,
          child: SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton(
              onPressed: () => SignupWallSheet.show(trigger: 'cta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
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
    );
  }







  // ── Onglet LISTE ─────────────────────────────────────────────────────────
  Widget _listView() {
    if (_providers.isEmpty) {
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 90.h),
        itemCount: _providers.length,
        itemBuilder: (_, i) => _card(_providers[i]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> m, {bool inSheet = false}) {
    final name = (m['name'] ?? '').toString();
    final city = _cityOf(m);
    final avatar = _avatarOf(m);
    final isWalker = m['_role'] == 'walker';
    final rating = _ratingOf(m);
    final reviews = _num(m['reviewsCount'])?.toInt() ?? 0;
    final verified = _isVerified(m);
    final price = _priceOf(m);
    final currency = (m['currency'] ?? 'EUR').toString() == 'EUR' ? '€' : (m['currency'] ?? '€').toString();
    final roleColor =
        isWalker ? const Color(0xFF16A34A) : const Color(0xFF2563EB);
    return Container(
      margin: EdgeInsets.only(bottom: inSheet ? 0 : 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: inSheet
            ? null
            : Border.all(
                color: verified
                    ? const Color(0xFFF4C04A).withValues(alpha: 0.55)
                    : Colors.grey.withValues(alpha: 0.15),
              ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: avatar.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatar,
                    width: 60.w,
                    height: 60.w,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _fallbackAvatar(roleColor),
                  )
                : _fallbackAvatar(roleColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: PoppinsText(
                        text: name.isEmpty
                            ? (isWalker
                                ? 'pawmap_default_walker'.tr
                                : 'pawmap_default_sitter'.tr)
                            : name,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        maxLines: 1,
                      ),
                    ),
                    if (verified) ...[
                      SizedBox(width: 6.w),
                      // v538 — le badge ✓ est PAYANT : mise en valeur or.
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4C04A),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: InterText(
                          text: '✓ ${'guest_verified'.tr}',
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF3D2E00),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 7.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: InterText(
                        text: isWalker
                            ? 'pawmap_default_walker'.tr
                            : 'pawmap_default_sitter'.tr,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: roleColor,
                      ),
                    ),
                    if (rating > 0) ...[
                      SizedBox(width: 8.w),
                      Icon(Icons.star_rounded,
                          size: 14.sp, color: const Color(0xFFF4C04A)),
                      InterText(
                        text:
                            ' ${rating.toStringAsFixed(1)}${reviews > 0 ? ' ($reviews)' : ''}',
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(context),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    if (city.isNotEmpty) ...[
                      Icon(Icons.place_outlined,
                          size: 12.sp, color: Colors.grey),
                      Flexible(
                        child: InterText(
                          text: city,
                          fontSize: 11.sp,
                          color: Colors.grey,
                          maxLines: 1,
                        ),
                      ),
                    ],
                    if (price != null) ...[
                      if (city.isNotEmpty) SizedBox(width: 8.w),
                      InterText(
                        text: 'guest_from_price'.trParams(
                            {'price': '${price.toStringAsFixed(0)} $currency'}),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryColor,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!inSheet) ...[
            SizedBox(width: 8.w),
            ElevatedButton(
              onPressed: () => SignupWallSheet.show(trigger: 'contact'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding:
                    EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: InterText(
                text: 'guest_contact'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fallbackAvatar(Color color) => Container(
        width: 60.w,
        height: 60.w,
        color: color.withValues(alpha: 0.15),
        child: Icon(Icons.pets, color: color, size: 26.sp),
      );




}
