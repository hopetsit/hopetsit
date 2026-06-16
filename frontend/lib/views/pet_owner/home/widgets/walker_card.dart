import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/walker_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/pet_species_color.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/boost_badge.dart';
import 'package:hopetsit/widgets/verified_badge.dart';

/// Premium dog-walker card for the Owner's "Promeneurs" tab.
///
/// Visual parity with [SitterCard] — same premium layout, only the accent
/// colour (green for walkers) and the tariff labels differ. Built to match the
/// premium mockups: avatar with online dot, name + verified + role chip,
/// rating / city / distance, a right-hand stats column (walks done,
/// availability, response time), a bordered tariff group (30 min / 1h / 2h),
/// an "À propos de moi" box and a full-width CTA.
class WalkerCard extends StatelessWidget {
  const WalkerCard({
    super.key,
    required this.walker,
    required this.onRequestWalk,
    this.onTap,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  final WalkerModel walker;
  final VoidCallback onRequestWalk;
  final VoidCallback? onTap;

  /// v444 — Favoris : true quand l'owner a « liké » ce walker (cœur plein).
  /// [onToggleFavorite] ajoute/retire des favoris. Quand le callback est null
  /// (ex. rôle non-owner), le cœur n'est pas rendu.
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  /// Walker accent — green premium mockup.
  static const Color _accent = AppColors.greenColor;

  /// Price for a specific duration (30 / 60 / 120 min). Null when the walker
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
  double? get _twoHourRate => _rateFor(120);

  /// True when the walker has configured NO availability at all (no calendar
  /// dates and no recurring weekly slots). Drives the "Indisponible" label.
  bool get _hasNoAvailability =>
      walker.availableDates.isEmpty && walker.availableTimeSlots.isEmpty;

  /// Availability label derived from the walker's calendar.
  /// v440 — « Indisponible » quand AUCUNE disponibilité n'est renseignée
  /// (calendrier vide + aucun créneau récurrent) ; sinon reflète le calendrier.
  String _availabilityLabel() {
    if (_hasNoAvailability) return 'card_unavailable'.tr;
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final today = walker.availableDates.any((d) => sameDay(d, now));
    if (today) return 'card_available_today'.tr;
    final tmr = walker.availableDates.any((d) => sameDay(d, tomorrow));
    if (tmr) return 'card_available_tomorrow'.tr;
    return 'card_available_on_request'.tr;
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = walker.avatar.url;
    final rating =
        walker.averageRating > 0 ? walker.averageRating : walker.rating;
    final city = walker.displayCity.isNotEmpty
        ? walker.displayCity
        : walker.coverageCity;
    final distance = walker.distanceKm;
    final bio = walker.bio?.trim() ?? '';

    final bool isBoosted = walker.isBoosted;
    const Color boostGold = Color(0xFFD4AF37);

    final halfHourRate = _halfHourRate;
    final hourRate = _hourlyRate;
    final twoHourRate = _twoHourRate;

    // Tariff cells — only configured durations are shown. Currency kept as "€".
    final cells = <_TariffCell>[
      if (halfHourRate != null)
        _TariffCell(
          label: 'card_tariff_30min'.tr,
          value: '${halfHourRate.toStringAsFixed(0)}€',
          sub: '',
        ),
      if (hourRate != null)
        _TariffCell(
          label: 'card_tariff_1h'.tr,
          value: '${hourRate.toStringAsFixed(0)}€',
          sub: '',
        ),
      if (twoHourRate != null)
        _TariffCell(
          label: 'card_tariff_2h'.tr,
          value: '${twoHourRate.toStringAsFixed(0)}€',
          sub: '',
        ),
      if (walker.extraPetRate > 0)
        _TariffCell(
          label: 'card_extra_pet'.tr,
          value: '+ ${walker.extraPetRate.toStringAsFixed(0)}€',
          sub: 'card_per_animal'.tr,
        ),
    ];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 14.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20.r),
          border: isBoosted ? Border.all(color: boostGold, width: 2.5) : null,
          boxShadow: [
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
            _buildHeader(context, avatarUrl, rating, city, distance),
            if (cells.isNotEmpty) ...[
              SizedBox(height: 14.h),
              _buildTariffGroup(context, cells),
            ],
            if (walker.acceptedPetTypes.isNotEmpty) ...[
              SizedBox(height: 12.h),
              _buildAnimalChips(context),
            ],
            if (bio.isNotEmpty) ...[
              SizedBox(height: 14.h),
              _buildAboutBox(context, bio),
            ],
            SizedBox(height: 14.h),
            _buildCta(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String avatarUrl,
    double rating,
    String city,
    double? distance,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar with green online dot.
        Stack(
          children: [
            CircleAvatar(
              radius: 30.r,
              backgroundColor: AppColors.grey300Color,
              backgroundImage: avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl, maxWidth: 180)
                  : null,
              child: avatarUrl.isEmpty
                  ? Icon(Icons.directions_walk_rounded,
                      size: 26.sp, color: Colors.white)
                  : null,
            ),
            Positioned(
              right: 1.w,
              bottom: 1.h,
              child: Container(
                width: 13.w,
                height: 13.w,
                decoration: BoxDecoration(
                  color: AppColors.greenColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.card(context), width: 2),
                ),
              ),
            ),
          ],
        ),
        SizedBox(width: 12.w),
        // Identity column.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: InterText(
                      text: walker.name.isNotEmpty
                          ? walker.name
                          : 'card_role_walker'.tr,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (walker.identityVerified) ...[
                    SizedBox(width: 5.w),
                    VerifiedBadge(
                      isVerified: true,
                      tooltipText: 'identity_badge_verified'.tr,
                    ),
                  ],
                ],
              ),
              SizedBox(height: 4.h),
              _roleChip(),
              SizedBox(height: 5.h),
              Row(
                children: [
                  Icon(Icons.star_rounded,
                      size: 15.sp, color: const Color(0xFFFFB300)),
                  SizedBox(width: 3.w),
                  InterText(
                    text: rating.toStringAsFixed(1),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                  SizedBox(width: 3.w),
                  Flexible(
                    child: InterText(
                      text: '(${walker.reviewsCount} avis)',
                      fontSize: 11.5,
                      color: AppColors.textSecondary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (city.isNotEmpty) ...[
                SizedBox(height: 3.h),
                Row(
                  children: [
                    Icon(Icons.place_rounded,
                        size: 14.sp, color: AppColors.textSecondary(context)),
                    SizedBox(width: 3.w),
                    Flexible(
                      child: InterText(
                        text: city,
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (distance != null) ...[
                SizedBox(height: 3.h),
                InterText(
                  text: 'card_distance_from_you'
                      .trParams({'km': distance.toStringAsFixed(1)}),
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: 8.w),
        // Stats column + badges.
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onToggleFavorite != null) _buildFavoriteButton(context),
                if (walker.isBoosted)
                  const BoostBadge()
                else if (walker.isTopWalker)
                  const TopProviderBadge(),
              ],
            ),
            SizedBox(height: 4.h),
            _statRow(
              context,
              Icons.directions_walk_rounded,
              '${walker.completedWalksCount} ${'card_walks_done'.tr}',
            ),
            SizedBox(height: 4.h),
            _statRow(context, Icons.calendar_today_rounded, _availabilityLabel()),
            if (walker.responseTimeMinutes > 0) ...[
              SizedBox(height: 4.h),
              _statRow(
                context,
                Icons.schedule_rounded,
                '${'card_response_in'.tr} ${walker.responseTimeMinutes} min',
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// v444 — cœur favori. Plein rouge quand liké, contour sinon. Tap → toggle.
  Widget _buildFavoriteButton(BuildContext context) {
    const Color favRed = Color(0xFFE53935);
    return Semantics(
      button: true,
      label: isFavorite
          ? 'favorite_remove_tooltip'.tr
          : 'favorite_add_tooltip'.tr,
      child: InkResponse(
        onTap: onToggleFavorite,
        radius: 20.r,
        child: Padding(
          padding: EdgeInsets.all(2.w),
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 20.sp,
            color: isFavorite ? favRed : AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _roleChip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: InterText(
        text: 'card_role_walker'.tr,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: _accent,
      ),
    );
  }

  Widget _statRow(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13.sp, color: _accent),
        SizedBox(width: 4.w),
        Flexible(
          child: InterText(
            text: text,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildTariffGroup(BuildContext context, List<_TariffCell> cells) {
    final children = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      children.add(Expanded(child: _tariffCellWidget(context, cells[i])));
      if (i != cells.length - 1) {
        children.add(Container(
          width: 0.8,
          height: 42.h,
          color: _accent.withValues(alpha: 0.25),
        ));
      }
    }
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _accent.withValues(alpha: 0.20), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _tariffCellWidget(BuildContext context, _TariffCell cell) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InterText(
            text: cell.label,
            fontSize: 9.5,
            color: AppColors.textSecondary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2.h),
          InterText(
            text: cell.value,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _accent,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (cell.sub.isNotEmpty) ...[
            SizedBox(height: 1.h),
            InterText(
              text: cell.sub,
              fontSize: 9,
              color: AppColors.textSecondary(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// v440 — petite ligne d'icônes des espèces promenées (chien/chat/NAC…),
  /// dérivée de acceptedPetTypes. Pastilles neutres rondes avec l'emoji.
  Widget _buildAnimalChips(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.pets_rounded, size: 13.sp, color: _accent),
        SizedBox(width: 6.w),
        InterText(
          text: 'card_walked_animals'.tr,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: walker.acceptedPetTypes
                .map((t) => _animalDot(context, petSpeciesEmoji(t)))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _animalDot(BuildContext context, String emoji) {
    return Container(
      width: 26.w,
      height: 26.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: _accent.withValues(alpha: 0.20), width: 1),
      ),
      child: Text(emoji, style: TextStyle(fontSize: 13.sp)),
    );
  }

  Widget _buildAboutBox(BuildContext context, String bio) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 14.sp, color: _accent),
              SizedBox(width: 6.w),
              InterText(
                text: 'post_about_owner'.tr,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _accent,
              ),
            ],
          ),
          SizedBox(height: 6.h),
          InterText(
            text: bio,
            fontSize: 12,
            color: AppColors.textSecondary(context),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCta() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onRequestWalk,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          padding: EdgeInsets.symmetric(vertical: 13.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
          ),
          elevation: 0,
        ),
        icon: Icon(Icons.send_rounded, size: 16.sp, color: Colors.white),
        label: InterText(
          text: 'card_request_walk'.tr,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Single tariff cell data holder for the bordered tariff group.
class _TariffCell {
  const _TariffCell({
    required this.label,
    required this.value,
    required this.sub,
  });

  final String label;
  final String value;
  final String sub;
}
