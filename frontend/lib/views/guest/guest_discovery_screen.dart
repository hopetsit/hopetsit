import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  // Onglets : 0 = carte, 1 = liste, 2 = demandes.
  int _tab = 0;
  bool _loadingRequests = false;
  bool _requestsLoaded = false;
  List<Map<String, dynamic>> _requests = const [];

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

  Future<void> _loadRequests() async {
    if (_requestsLoaded || _loadingRequests) return;
    setState(() => _loadingRequests = true);
    final api = Get.isRegistered<ApiClient>()
        ? Get.find<ApiClient>()
        : Get.put(ApiClient(), permanent: true);
    var out = const <Map<String, dynamic>>[];
    try {
      final r = await api.get('/posts/requests/public');
      final list = (r is Map ? r['requests'] : null) as List<dynamic>?;
      if (list != null) {
        out = [
          for (final raw in list)
            if (raw is Map) Map<String, dynamic>.from(raw),
        ];
      }
    } catch (_) {/* best-effort */}
    if (mounted) {
      setState(() {
        _requests = out;
        _requestsLoaded = true;
        _loadingRequests = false;
      });
    }
  }

  // ── Helpers données ──────────────────────────────────────────────────────
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
      (m['averageRating'] as num?)?.toDouble() ?? 0;

  static LatLng? _latLngOf(Map<String, dynamic> m) {
    final loc = m['location'];
    if (loc is! Map) return null;
    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return LatLng(lat, lng);
  }

  /// Plus petit tarif renseigné (> 0), pour « À partir de X € ».
  static num? _priceOf(Map<String, dynamic> m) {
    final candidates = <num?>[];
    final sp = m['servicePricing'];
    if (sp is Map) {
      for (final v in sp.values) {
        if (v is Map) candidates.add(v['basePrice'] as num?);
      }
    }
    candidates
      ..add(m['hourlyRate'] as num?)
      ..add(m['dailyRate'] as num?)
      ..add(m['rate'] as num?);
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
            // ── v538 : onglets Carte / Liste / Demandes ────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  children: [
                    _segBtn(0, Icons.map_outlined, 'guest_tab_map'.tr),
                    _segBtn(1, Icons.view_list_outlined, 'guest_tab_list'.tr),
                    _segBtn(2, Icons.campaign_outlined, 'guest_tab_requests'.tr),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8.h),
            // ── Contenu de l'onglet ────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _tab == 0
                      ? _mapView()
                      : _tab == 1
                          ? _listView()
                          : _requestsView(),
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

  Widget _segBtn(int index, IconData icon, String label) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tab = index);
          if (index == 2) _loadRequests();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).cardColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11.r),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16.sp,
                  color: selected
                      ? AppColors.primaryColor
                      : Colors.grey),
              SizedBox(width: 5.w),
              InterText(
                text: label,
                fontSize: 12.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? AppColors.textPrimary(context)
                    : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Onglet CARTE ─────────────────────────────────────────────────────────
  Widget _mapView() {
    final markers = <Marker>{};
    LatLng? first;
    for (var i = 0; i < _providers.length; i++) {
      final m = _providers[i];
      final pos = _latLngOf(m);
      if (pos == null) continue;
      first ??= pos;
      markers.add(Marker(
        markerId: MarkerId('p$i'),
        position: pos,
        onTap: () => _showProviderSheet(m),
      ));
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 90.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            // Centre : 1er prestataire localisé, sinon vue Europe.
            target: first ?? const LatLng(46.6, 2.3),
            zoom: first != null ? 5.2 : 3.6,
          ),
          markers: markers,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
      ),
    );
  }

  void _showProviderSheet(Map<String, dynamic> m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: EdgeInsets.all(12.w),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _card(m, inSheet: true),
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              height: 46.h,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  SignupWallSheet.show(trigger: 'map_contact');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: PoppinsText(
                  text: 'guest_contact'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
          ],
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
    final reviews = (m['reviewsCount'] as num?)?.toInt() ?? 0;
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

  // ── Onglet DEMANDES ──────────────────────────────────────────────────────
  Widget _requestsView() {
    if (_loadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_requests.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: InterText(
            text: 'guest_no_requests'.tr,
            fontSize: 14.sp,
            color: Colors.grey,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 90.h),
      itemCount: _requests.length,
      itemBuilder: (_, i) => _requestCard(_requests[i]),
    );
  }

  Widget _requestCard(Map<String, dynamic> r) {
    final owner = r['owner'] is Map ? r['owner'] as Map : const {};
    final ownerName = (owner['name'] ?? '').toString();
    final ownerAvatar = (owner['avatar'] ?? '').toString();
    final body = (r['body'] ?? '').toString();
    final city = (r['city'] ?? '').toString();
    final types = (r['animalTypes'] as List?)?.cast<dynamic>() ?? const [];
    String dates = '';
    final sd = DateTime.tryParse((r['startDate'] ?? '').toString());
    final ed = DateTime.tryParse((r['endDate'] ?? '').toString());
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    if (sd != null && ed != null) {
      dates = '${fmt(sd)} → ${fmt(ed)}';
    } else if (sd != null) {
      dates = fmt(sd);
    }
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: ownerAvatar.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: ownerAvatar,
                        width: 36.w,
                        height: 36.w,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _fallbackAvatar(AppColors.primaryColor),
                      )
                    : Container(
                        width: 36.w,
                        height: 36.w,
                        color:
                            AppColors.primaryColor.withValues(alpha: 0.12),
                        child: Icon(Icons.person,
                            color: AppColors.primaryColor, size: 20.sp),
                      ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: ownerName.isEmpty ? 'HoPetSit' : ownerName,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      maxLines: 1,
                    ),
                    Row(
                      children: [
                        if (city.isNotEmpty) ...[
                          Icon(Icons.place_outlined,
                              size: 11.sp, color: Colors.grey),
                          InterText(
                            text: '$city  ',
                            fontSize: 10.5.sp,
                            color: Colors.grey,
                          ),
                        ],
                        if (dates.isNotEmpty)
                          InterText(
                            text: '📅 $dates',
                            fontSize: 10.5.sp,
                            color: Colors.grey,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () =>
                    SignupWallSheet.show(trigger: 'request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: EdgeInsets.symmetric(
                      horizontal: 12.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: InterText(
                  text: 'guest_respond'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            SizedBox(height: 8.h),
            InterText(
              text: body,
              fontSize: 12.sp,
              color: AppColors.textSecondary(context),
              maxLines: 3,
            ),
          ],
          if (types.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6.w,
              children: [
                for (final t in types.take(4))
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: InterText(
                      text: t.toString(),
                      fontSize: 10.sp,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
