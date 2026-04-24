import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/sitter_model.dart';
import 'package:hopetsit/utils/app_colors.dart';

/// Session v15-3 — compact pet-sitter card for the Owner's "Pet-sitters" tab.
///
/// Visual parity with [WalkerCard]: small avatar, inline rating + city +
/// distance, pill row for the sitter's rates (daily / weekly / monthly),
/// optional "Estimation" line when the Owner has an active reservation post,
/// and a full-width CTA. The segment control uses blue for sitters, so this
/// card uses the same blue (0xFF1A73E8) for accents and CTA to tie the
/// visual language together.
///
/// We keep the existing [ServiceProviderCard] untouched for other usages
/// (booking detail, sitter application) — this card is only for the home
/// browse list.
class SitterCard extends StatelessWidget {
  const SitterCard({
    super.key,
    required this.sitter,
    required this.onSendRequest,
    this.onTap,
    this.onBlock,
    this.estimatedCost,
    this.estimatedDays,
  });

  final SitterModel sitter;
  final VoidCallback onSendRequest;
  final VoidCallback? onTap;

  /// Optional "block this sitter" action shown in the card's ⋮ menu.
  /// Keeps feature parity with the legacy [ServiceProviderCard] when used
  /// from the home browse list.
  final VoidCallback? onBlock;

  /// Pre-computed estimate for the Owner's latest active post, rendered
  /// under the rate pills. Null when the Owner has no active post.
  final double? estimatedCost;
  final int? estimatedDays;

  /// Sitter segment accent. Matches the blue of the home segmented control.
  static const Color _sitterBlue = Color(0xFF1A73E8);

  /// Currency symbol helper. Keeps the card footprint small without
  /// pulling in the full CurrencyHelper for just the display char.
  String _currencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'CHF':
        return 'CHF';
      case 'EUR':
      default:
        return '€';
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = sitter.avatar.url;
    final rating = sitter.averageRating > 0
        ? sitter.averageRating
        : sitter.rating;
    final city = sitter.displayCity;
    final distance = sitter.distanceKm;
    final currency = _currencySymbol(sitter.currency);

    // Daily rate — Session v15-3 derives one whenever possible so the Owner
    // always sees a "Jour" pill, otherwise we'd only show Semaine+Mois on
    // sitters who priced multi-day stays (very common).
    //   1. dailyRate directly           — exact value
    //   2. hourlyRate × 8               — derived
    //   3. weeklyRate  / 7              — derived
    //   4. monthlyRate / 30             — derived
    double effectiveDaily = 0;
    bool dailyIsDerived = false;
    if (sitter.dailyRate > 0) {
      effectiveDaily = sitter.dailyRate;
    } else if (sitter.hourlyRate > 0) {
      effectiveDaily = sitter.hourlyRate * 8;
      dailyIsDerived = true;
    } else if (sitter.weeklyRate > 0) {
      effectiveDaily = sitter.weeklyRate / 7;
      dailyIsDerived = true;
    } else if (sitter.monthlyRate > 0) {
      effectiveDaily = sitter.monthlyRate / 30;
      dailyIsDerived = true;
    }

    final hasAnyRate = effectiveDaily > 0 ||
        sitter.weeklyRate > 0 ||
        sitter.monthlyRate > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 14.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
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
            // Header: avatar + name (+ verified / top / boost) + rating/city/dist
            Row(
              children: [
                // v20.0.9 — Role-accent ring (sitter = blue) + soft halo
                // so the provider type is readable at a glance on list cards.
                Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _sitterBlue, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: _sitterBlue.withValues(alpha: 0.25),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 26.r,
                    backgroundColor: AppColors.grey300Color,
                    backgroundImage: avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Icon(Icons.pets_rounded,
                            size: 24.sp, color: Colors.white)
                        : null,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              sitter.name.isNotEmpty ? sitter.name : 'Sitter',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (sitter.identityVerified) ...[
                            SizedBox(width: 4.w),
                            Tooltip(
                              message: 'profile_identity_verified'.tr,
                              child: Icon(Icons.verified,
                                  size: 14.sp, color: _sitterBlue),
                            ),
                          ],
                          if (sitter.isTopSitter) ...[
                            SizedBox(width: 4.w),
                            Text('🏆', style: TextStyle(fontSize: 12.sp)),
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
                          if (sitter.reviewsCount > 0) ...[
                            SizedBox(width: 3.w),
                            Text(
                              '(${sitter.reviewsCount})',
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
                if (sitter.isBoosted)
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange, Colors.red.shade400],
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🔥', style: TextStyle(fontSize: 10.sp)),
                        SizedBox(width: 2.w),
                        Text(
                          'Boost',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                // ⋮ menu — only shown when onBlock is provided (home browse).
                if (onBlock != null)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 18.sp,
                      color: AppColors.textSecondary(context),
                    ),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    color: AppColors.card(context),
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(Icons.block,
                                size: 16.sp,
                                color: AppColors.primaryColor),
                            SizedBox(width: 8.w),
                            Text(
                              'service_card_block'.tr,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'block') onBlock?.call();
                    },
                  ),
              ],
            ),

            // Optional bio blurb (max 2 lines).
            if (sitter.bio != null && sitter.bio!.trim().isNotEmpty) ...[
              SizedBox(height: 10.h),
              Text(
                sitter.bio!,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            SizedBox(height: 12.h),

            // Rate pills — day / week / month. Sitters keep a daily minimum,
            // so we skip "per hour" entirely (same decision as session v15).
            if (hasAnyRate) ...[
              Row(
                children: [
                  if (effectiveDaily > 0)
                    Expanded(
                      child: _ratePill(
                        icon: Icons.today_rounded,
                        label: 'Jour',
                        // Prefix with ~ when the value is derived from
                        // another tier, so the Owner knows it's approximate.
                        value:
                            '${dailyIsDerived ? '~' : ''}${effectiveDaily.toStringAsFixed(0)} $currency',
                      ),
                    ),
                  if (effectiveDaily > 0 && sitter.weeklyRate > 0)
                    SizedBox(width: 6.w),
                  if (sitter.weeklyRate > 0)
                    Expanded(
                      child: _ratePill(
                        icon: Icons.date_range_rounded,
                        label: 'Semaine',
                        value:
                            '${sitter.weeklyRate.toStringAsFixed(0)} $currency',
                      ),
                    ),
                  if (sitter.weeklyRate > 0 && sitter.monthlyRate > 0)
                    SizedBox(width: 6.w),
                  if (sitter.monthlyRate > 0)
                    Expanded(
                      child: _ratePill(
                        icon: Icons.calendar_month_rounded,
                        label: 'Mois',
                        value:
                            '${sitter.monthlyRate.toStringAsFixed(0)} $currency',
                      ),
                    ),
                ],
              ),
              if (estimatedCost != null && estimatedDays != null) ...[
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(Icons.attach_money_rounded,
                        size: 14.sp,
                        color: AppColors.textSecondary(context)),
                    SizedBox(width: 4.w),
                    Flexible(
                      child: Text(
                        'Estimation $estimatedDays jour${estimatedDays! > 1 ? 's' : ''} : ~${estimatedCost!.toStringAsFixed(0)} $currency',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.textSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: _sitterBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 14.sp, color: _sitterBlue),
                    SizedBox(width: 4.w),
                    Text(
                      'Tarif à confirmer',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: _sitterBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 12.h),

            // Full-width CTA — same shape as WalkerCard's "Demander".
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSendRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _sitterBlue,
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  elevation: 0,
                ),
                icon: Icon(Icons.send_rounded,
                    size: 16.sp, color: Colors.white),
                label: Text(
                  'service_card_send_request'.tr,
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

  /// Small rate chip — same visual weight as WalkerCard's pill, but blue.
  Widget _ratePill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: _sitterBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
            color: _sitterBlue.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: _sitterBlue),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: _sitterBlue.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: _sitterBlue,
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
