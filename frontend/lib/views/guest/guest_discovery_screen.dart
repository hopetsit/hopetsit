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
///
/// C'est le nouvel atterrissage d'un utilisateur SANS compte (le splash
/// n'envoie plus vers le mur login/signup). Il montre la valeur AVANT de
/// demander quoi que ce soit : la liste des gardiens et promeneurs proches,
/// en lecture seule, depuis les endpoints publics (les mêmes que le site
/// web ; champs privés retirés côté serveur depuis la v535).
///
/// Toute tentative d'AGIR (contacter, réserver) ouvre le mur contextuel
/// [SignupWallSheet]. L'événement `guest_browse` (P3) mesure l'entrée dans
/// ce mode.
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
    // Profils avec photo et ville d'abord (vitrine plus crédible).
    out.sort((a, b) {
      int score(Map<String, dynamic> x) {
        var s = 0;
        if (_avatarOf(x).isNotEmpty) s += 2;
        if (_cityOf(x).isNotEmpty) s += 1;
        return s;
      }

      return score(b).compareTo(score(a));
    });
    if (mounted) {
      setState(() {
        _providers = out;
        _loading = false;
      });
    }
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
            SizedBox(height: 8.h),
            // ── Liste des prestataires (lecture seule) ─────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _providers.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.w),
                            child: InterText(
                              text: 'guest_empty'.tr,
                              fontSize: 14.sp,
                              color: Colors.grey,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding:
                                EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 90.h),
                            itemCount: _providers.length,
                            itemBuilder: (_, i) => _card(_providers[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
      // ── CTA permanent : créer un compte ────────────────────────────────
      bottomSheet: Container(
        color: AppColors.scaffold(context),
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 14.h),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton(
              onPressed: () =>
                  SignupWallSheet.show(trigger: 'cta'),
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

  Widget _card(Map<String, dynamic> m) {
    final name = (m['name'] ?? '').toString();
    final city = _cityOf(m);
    final avatar = _avatarOf(m);
    final isWalker = m['_role'] == 'walker';
    final rating = (m['averageRating'] as num?)?.toDouble() ?? 0;
    final roleColor =
        isWalker ? const Color(0xFF16A34A) : const Color(0xFF2563EB);
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: avatar.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatar,
                    width: 52.w,
                    height: 52.w,
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
                PoppinsText(
                  text: name.isEmpty
                      ? (isWalker
                          ? 'pawmap_default_walker'.tr
                          : 'pawmap_default_sitter'.tr)
                      : name,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  maxLines: 1,
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6.r),
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
                    if (city.isNotEmpty) ...[
                      SizedBox(width: 6.w),
                      Flexible(
                        child: InterText(
                          text: '📍 $city',
                          fontSize: 11.sp,
                          color: Colors.grey,
                          maxLines: 1,
                        ),
                      ),
                    ],
                    if (rating > 0) ...[
                      SizedBox(width: 6.w),
                      InterText(
                        text: '★ ${rating.toStringAsFixed(1)}',
                        fontSize: 11.sp,
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // Agir = mur contextuel avec le prénom (l'intention est là).
          ElevatedButton(
            onPressed: () =>
                SignupWallSheet.show(trigger: 'contact', name: name),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
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
      ),
    );
  }

  Widget _fallbackAvatar(Color color) => Container(
        width: 52.w,
        height: 52.w,
        color: color.withValues(alpha: 0.15),
        child: Icon(Icons.pets_rounded, color: color, size: 26.sp),
      );
}
