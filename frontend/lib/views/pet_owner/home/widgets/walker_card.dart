import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/walker_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/boost_badge.dart';
import 'package:hopetsit/widgets/verified_badge.dart';

/// Lightweight card used by the "Promeneurs" tab on the owner home screen.
///
/// Mirrors the visual density of the sitter card but only surfaces bits
/// relevant to a dog walker: 60-min walk rate, coverage city, distance,
/// rating and a CTA to send a walking request.
class WalkerCard extends StatelessWidget {
  const WalkerCard({
    super.key,
    required this.walker,
    required this.onRequestWalk,
    this.onTap,
  });

  final WalkerModel walker;
  final VoidCallback onRequestWalk;
  final VoidCallback? onTap;

  /// Price for a specific duration (30 min or 60 min). Null when the walker
  /// hasn't configured that tier yet.
  double? _rateFor(int minutes) {
    for (final r in walker.walkRates) {
      if (r.durationMinutes == minutes && r.enabled && r.basePrice > 0) {
        return r.basePrice;
      }
    }
    return null;
  }

  double? get _halfHourRate => _rateFor(30);
  double? get _hourlyRate => _rateFor(60);

  @override
  Widget build(BuildContext context) {
    final avatarUrl = walker.avatar.url;
    final rating = walker.averageRating > 0 ? walker.averageRating : walker.rating;
    final city = walker.displayCity.isNotEmpty
        ? walker.displayCity
        : walker.coverageCity;
    final distance = walker.distanceKm;
    final halfHourRate = _halfHourRate;
    final hourRate = _hourlyRate;
    final hasAnyRate = halfHourRate != null || hourRate != null;

    // v23.1.147 — cadre doré + glow pour les walkers avec boost actif payé.
    // Demande Daniel : "lorsque l'option boost est payée je veux que la
    // publication apparaisse avec le cadre boost sur les 3 profils".
    final bool isBoosted = walker.isBoosted;
    const Color boostGold = Color(0xFFD4AF37);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 14.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14.r),
          border: isBoosted
              ? Border.all(color: boostGold, width: 2.5)
              : null,
          boxShadow: [
            // v23.1 part 250 — perf : blur boost 14→8 (peinture GPU low-end).
            if (isBoosted)
              BoxShadow(
                color: boostGold.withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // v20.0.9 — Role-accent ring (walker = green) + soft halo.
                Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.walkerAccent, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.walkerAccent.withValues(alpha: 0.25),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 26.r,
                    backgroundColor: AppColors.grey300Color,
                    // v23.1 part 240 — maxWidth: 180 (HD avatar, low mem).
                    backgroundImage: avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl, maxWidth: 180)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Icon(Icons.directions_walk_rounded,
                            size: 24.sp, color: Colors.white)
                        : null,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // v18.9.8 — nom + badge Identité vérifiée (shield vert
                      // via AppColors.walkerAccent) si walker.identityVerified.
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              walker.name.isNotEmpty ? walker.name : 'Promeneur',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // v23.1 part 251 — badge KYC only (cf. sitter_card),
                          // flag legacy `verified` retire (true pour tous).
                          if (walker.identityVerified) ...[
                            SizedBox(width: 6.w),
                            VerifiedBadge(
                              isVerified: true,
                              tooltipText: 'identity_badge_verified'.tr,
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 14.sp, color: const Color(0xFFFFB300)),
                          SizedBox(width: 2.w),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          if (walker.reviewsCount > 0) ...[
                            SizedBox(width: 3.w),
                            Text(
                              '(${walker.reviewsCount})',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                          if (city.isNotEmpty) ...[
                            SizedBox(width: 8.w),
                            Icon(Icons.place_rounded,
                                size: 14.sp,
                                color: AppColors.textSecondary(context)),
                            SizedBox(width: 2.w),
                            Flexible(
                              child: Text(
                                city,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppColors.textSecondary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (distance != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          'À ${distance.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // v23.1 part 253 — badges Boost/Top harmonises (widgets
                // partages BoostBadge/TopProviderBadge, memes que sitter +
                // service_provider). Boost = flamme i18n ; Top = or premium.
                if (walker.isBoosted)
                  const BoostBadge()
                else if (walker.isTopWalker)
                  const TopProviderBadge(),
              ],
            ),
            // v427 — maquette : stat "promenades réalisées".
            if (walker.completedWalksCount > 0) ...[
              SizedBox(height: 10.h),
              Row(
                children: [
                  Icon(Icons.directions_walk_rounded,
                      size: 14.sp, color: AppColors.greenColor),
                  SizedBox(width: 5.w),
                  Text(
                    '${walker.completedWalksCount} ${'card_walks_done'.tr}',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: AppColors.textSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 12.h),
            // Session v15 — 2 tarifs (30 min / 1 h) + estimation 1 balade
            // Le total réel se calcule dans SendRequestScreen selon durées.
            if (hasAnyRate) ...[
              Row(
                children: [
                  if (halfHourRate != null)
                    Expanded(
                      child: _ratePill(
                        icon: Icons.timer_outlined,
                        label: '30 min',
                        value: '${halfHourRate.toStringAsFixed(0)} €',
                      ),
                    ),
                  if (halfHourRate != null && hourRate != null)
                    SizedBox(width: 8.w),
                  if (hourRate != null)
                    Expanded(
                      child: _ratePill(
                        icon: Icons.schedule_rounded,
                        label: '1 heure',
                        value: '${hourRate.toStringAsFixed(0)} €',
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(Icons.attach_money_rounded,
                      size: 14.sp, color: AppColors.textSecondary(context)),
                  SizedBox(width: 4.w),
                  Text(
                    'walker_card_estimate_1h'.trParams({
                      'amount': (hourRate ?? (halfHourRate! * 2)).toStringAsFixed(0),
                    }),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.greenColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 14.sp, color: AppColors.greenColor),
                    SizedBox(width: 4.w),
                    Text(
                      'walker_card_rate_to_confirm'.tr,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.greenColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // v427 — maquette : "À propos de moi" encadré (vert promeneur).
            if (walker.bio != null && walker.bio!.trim().isNotEmpty) ...[
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.greenColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: 14.sp, color: AppColors.greenColor),
                        SizedBox(width: 6.w),
                        Text(
                          'post_about_owner'.tr,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.greenColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      walker.bio!,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary(context),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRequestWalk,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.greenColor,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  elevation: 0,
                ),
                icon:
                    Icon(Icons.send_rounded, size: 16.sp, color: Colors.white),
                label: Text(
                  'card_request_person'.tr,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Small rate chip used for 30 min / 1 h price breakdown on the card.
  Widget _ratePill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.greenColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
            color: AppColors.greenColor.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: AppColors.greenColor),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: AppColors.greenColor.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.greenColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
