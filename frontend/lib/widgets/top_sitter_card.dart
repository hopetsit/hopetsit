import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/reviews/widgets/rating_stars.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Sprint 7 step 2 — Top Sitter status card for the sitter's own profile.
///
/// v569 — remise au format du lot : en-tête à pastille, note en ÉTOILES
/// (`RatingStars`, même composant que les fiches prestataire), barre de
/// progression vers l'objectif, et couleurs qui suivent le mode sombre (les
/// `TextStyle` en dur ne le faisaient pas).
/// ⚠️ DESIGN UNIQUEMENT : même appel `/sitters/:id`, mêmes champs lus, même
/// recharge (retour au premier plan + notification + filet 60 s).
class TopSitterCard extends StatefulWidget {
  const TopSitterCard({super.key});

  @override
  State<TopSitterCard> createState() => _TopSitterCardState();
}

class _TopSitterCardState extends State<TopSitterCard>
    with WidgetsBindingObserver {
  final ApiClient _api =
      Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient();
  bool _loading = true;
  bool _isTop = false;
  int _completed = 0;
  double _avg = 0;

  // v23.1.344 — Daniel : "vérifie aussi top sitter". Le reload ne se faisait
  // qu'au retour au premier plan (v295) → stale si on reste DANS l'app après
  // une confirmation de service. Ajout : reload à chaque notification reçue
  // + filet périodique 60s (même pattern que LoyaltyCard / bande d'accueil).
  Worker? _notifWorker;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    if (Get.isRegistered<NotificationsController>()) {
      final notifs = Get.find<NotificationsController>();
      _notifWorker = ever<int>(notifs.unreadCount, (_) => _load());
    }
    _refresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifWorker?.dispose();
    _refresh?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // v23.1.295 — Daniel : "top sitter pas à jour après prestation". La carte
    // ne se chargeait qu'au montage → stale après une confirmation de service.
    // On recharge dès que l'app revient au premier plan.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final profile = GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
      final sitterId = profile?['id']?.toString() ?? '';
      if (sitterId.isEmpty) return;
      final r = await _api.get('/sitters/$sitterId', requiresAuth: true);
      final sitter = (r is Map && r['sitter'] is Map)
          ? Map<String, dynamic>.from(r['sitter'])
          : (r is Map ? Map<String, dynamic>.from(r) : null);
      if (sitter != null) {
        setState(() {
          _isTop = sitter['isTopSitter'] == true;
          _completed = (sitter['completedServicesCount'] as num?)?.toInt() ?? 0;
          _avg = (sitter['averageRating'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (_) {
      // silent
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const int _goal = 20;
  static const Color _gold = Color(0xFFF4C04A);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final accent = _isTop ? _gold : ActionTone.sitter;
    final progress = (_completed / _goal).clamp(0.0, 1.0);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: AppColors.cardShadow(context),
        border: Border.all(
          color: accent.withValues(alpha: _isTop ? 0.65 : 0.22),
          width: _isTop ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  _isTop
                      ? Icons.emoji_events_rounded
                      : Icons.trending_up_rounded,
                  color: accent,
                  size: 21.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: PoppinsText(
                  text: _isTop
                      ? 'top_sitter_achieved'.tr
                      : 'top_sitter_badge'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Note en étoiles. `reviewsCount` n'est pas exposé par cette route :
          // on n'invente aucun compteur — 0 affiche la pastille « Nouveau ».
          RatingStars(
            rating: _avg,
            reviewsCount: _avg > 0 ? 1 : 0,
            showCount: false,
            newAccent: accent,
          ),
          SizedBox(height: 12.h),
          InterText(
            text: 'lists569_progress_goal'.tr
                .replaceAll('{done}', '$_completed')
                .replaceAll('{goal}', '$_goal'),
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7.h,
              backgroundColor: accent.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          SizedBox(height: 10.h),
          InterText(
            text: _isTop
                ? 'top_sitter_commission_15'.tr
                // v23.1.323 — Daniel : "Top sitter étoile à 0". Quand la note est
                // DÉJÀ ≥ 4.5 (condition remplie), on n'affiche plus "+ 0.0★"
                // (trompeur) : il ne reste QUE des prestations à faire.
                : (4.5 - _avg <= 0
                    ? 'top_sitter_need_bookings'.trParams({
                        'bookings':
                            (_goal - _completed).clamp(0, _goal).toString(),
                      })
                    : 'top_sitter_need_more'.trParams({
                        'bookings':
                            (_goal - _completed).clamp(0, _goal).toString(),
                        'rating': (4.5 - _avg).toStringAsFixed(1),
                      })),
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: _isTop
                ? ActionTone.success
                : AppColors.textSecondary(context),
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
