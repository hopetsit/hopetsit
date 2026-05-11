// v23.1 part 109 — Daniel : "le boost marche pas".
// Petit row de badges ("Boost actif", "PawSpot actif", "Premium actif")
// affiché en haut du profil pour que le user voie immédiatement après
// achat que son achat a bien pris effet.
//
// v23.1 part 114 — appel direct à GET /users/me/benefits (route dédiée
// qui marche pour les 3 rôles owner/sitter/walker, contrairement à
// /users/me/profile qui était réservé aux owners). On rafraichit à
// chaque mount + sur demande externe via refreshAfterPurchase().

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

class ActiveBenefitsRow extends StatefulWidget {
  const ActiveBenefitsRow({super.key, this.compact = false});

  /// Quand `compact: true`, badges plus petits (utile dans le header).
  final bool compact;

  @override
  State<ActiveBenefitsRow> createState() => _ActiveBenefitsRowState();

  // v23.1 part 114 — clé statique pour forcer un refresh global (utilisé
  // par refreshAfterPurchase). Tous les widgets ActiveBenefitsRow
  // observent _refreshTick et re-fetchent.
  static final RxInt _refreshTick = 0.obs;
  static void notifyChanged() {
    _refreshTick.value += 1;
  }

  // v23.1 part 115 — exposé pour que KycStatusBanner (et autres widgets
  // dépendants de /users/me/benefits) puissent aussi se rafraichir
  // après un changement (achat, KYC submit, etc.).
  // ignore: prefer_const_declarations
  static RxInt get refreshTickAccessor => _refreshTick;
}

class _ActiveBenefitsRowState extends State<ActiveBenefitsRow> {
  Map<String, dynamic> _benefits = const {};
  bool _loaded = false;
  Worker? _tickWorker;

  @override
  void initState() {
    super.initState();
    _load();
    _tickWorker = ever<int>(ActiveBenefitsRow._refreshTick, (_) => _load());
  }

  @override
  void dispose() {
    _tickWorker?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      final api = Get.find<ApiClient>();
      final r = await api.get('/users/me/benefits', requiresAuth: true);
      if (!mounted) return;
      if (r is Map) {
        setState(() {
          _benefits = Map<String, dynamic>.from(r);
          _loaded = true;
        });
      }
    } catch (_) {
      // best-effort, on cache simplement la row.
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final p = _benefits;
    final now = DateTime.now();
    final boostExpiry = _toDate(p['boostExpiry']);
    final mapBoostExpiry = _toDate(p['mapBoostExpiry']);
    final isPremium = p['isPremium'] == true;
    final boostActive = boostExpiry != null && boostExpiry.isAfter(now);
    final pawSpotActive = mapBoostExpiry != null && mapBoostExpiry.isAfter(now);

    final children = <Widget>[];
    if (isPremium) {
      children.add(_badge(context, '⭐', 'Premium', const Color(0xFFFFD700)));
    }
    if (boostActive) {
      final days = boostExpiry!.difference(now).inDays;
      final label = days <= 0 ? 'Boost' : 'Boost · ${days}j';
      children.add(_badge(context, '🚀', label, const Color(0xFFE8472A)));
    }
    if (pawSpotActive) {
      final days = mapBoostExpiry!.difference(now).inDays;
      final label = days <= 0 ? 'PawSpot' : 'PawSpot · ${days}j';
      children.add(_badge(context, '📍', label, const Color(0xFF10B981)));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Wrap(
        spacing: 6.w,
        runSpacing: 4.h,
        children: children,
      ),
    );
  }

  Widget _badge(BuildContext context, String emoji, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 8.w : 10.w,
        vertical: widget.compact ? 3.h : 5.h,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: TextStyle(fontSize: widget.compact ? 11.sp : 13.sp),
          ),
          SizedBox(width: 4.w),
          InterText(
            text: label,
            fontSize: widget.compact ? 10.sp : 12.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ],
      ),
    );
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
