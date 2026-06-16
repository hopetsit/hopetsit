import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/sitter_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/pet_species_color.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/boost_badge.dart';
import 'package:hopetsit/widgets/verified_badge.dart';

/// Premium pet-sitter card for the Owner's "Pet-sitters" tab.
///
/// Visual parity with [WalkerCard] — same premium layout, only the accent
/// colour (blue for sitters) and the tariff labels differ. Built to match the
/// premium mockups: avatar with online dot, name + verified + role chip,
/// rating / city / distance, a right-hand stats column (services done,
/// availability, response time), a bordered tariff group, an "À propos de moi"
/// box and a full-width CTA.
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
  final VoidCallback? onBlock;

  /// Retained for constructor compatibility with the home screen. The premium
  /// card no longer renders an estimate line, so these may be unused.
  final double? estimatedCost;
  final int? estimatedDays;

  /// Sitter segment accent — premium mockup blue.
  static const Color _sitterBlue = Color(0xFF2563EB);

  /// Currency symbol helper — keeps the card footprint small.
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

  /// True when the sitter has configured NO availability at all (no calendar
  /// dates and no recurring weekly slots). Drives the "Indisponible" label.
  bool get _hasNoAvailability =>
      sitter.availableDates.isEmpty && sitter.availableTimeSlots.isEmpty;

  /// Availability label derived from the sitter's calendar.
  /// v440 — « Indisponible » quand AUCUNE disponibilité n'est renseignée
  /// (calendrier vide + aucun créneau récurrent) ; sinon reflète le calendrier.
  String _availabilityLabel() {
    if (_hasNoAvailability) return 'card_unavailable'.tr;
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final today = sitter.availableDates.any((d) => sameDay(d, now));
    if (today) return 'card_available_today'.tr;
    final tmr = sitter.availableDates.any((d) => sameDay(d, tomorrow));
    if (tmr) return 'card_available_tomorrow'.tr;
    return 'card_available_on_request'.tr;
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = sitter.avatar.url;
    final rating =
        sitter.averageRating > 0 ? sitter.averageRating : sitter.rating;
    final city = sitter.displayCity;
    final distance = sitter.distanceKm;
    final currency = _currencySymbol(sitter.currency);
    final bio = sitter.bio?.trim() ?? '';

    final bool isBoosted = sitter.isBoosted;
    const Color boostGold = Color(0xFFD4AF37);

    // Tariff cells — only rates that are configured (> 0) are shown.
    final cells = <_TariffCell>[
      if (sitter.dailyRate > 0)
        _TariffCell(
          label: 'Tarif jour',
          value: '${sitter.dailyRate.toStringAsFixed(0)}$currency',
          sub: '+ de 10h',
        ),
      if (sitter.weeklyRate > 0)
        _TariffCell(
          label: 'Tarif semaine',
          value: '${sitter.weeklyRate.toStringAsFixed(0)}$currency',
          sub: '7 jours',
        ),
      if (sitter.monthlyRate > 0)
        _TariffCell(
          label: 'Tarif mois',
          value: '${sitter.monthlyRate.toStringAsFixed(0)}$currency',
          sub: '30 jours',
        ),
      if (sitter.extraPetRate > 0)
        _TariffCell(
          label: 'card_extra_pet'.tr,
          value: '+ ${sitter.extraPetRate.toStringAsFixed(0)}$currency',
          sub: '/ animal',
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
            if (sitter.acceptedPetTypes.isNotEmpty) ...[
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
                  ? Icon(Icons.pets_rounded, size: 26.sp, color: Colors.white)
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
                      text: sitter.name.isNotEmpty ? sitter.name : 'Sitter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (sitter.identityVerified) ...[
                    SizedBox(width: 5.w),
                    VerifiedBadge(
                      isVerified: true,
                      tooltipText: 'profile_identity_verified'.tr,
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
                      text: '(${sitter.reviewsCount} avis)',
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
                  text: 'À ${distance.toStringAsFixed(1)} km de vous',
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: 8.w),
        // Stats column + badges/menu.
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sitter.isBoosted) const BoostBadge(),
                if (onBlock != null)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        size: 18.sp, color: AppColors.textSecondary(context)),
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
                                size: 16.sp, color: AppColors.primaryColor),
                            SizedBox(width: 8.w),
                            InterText(
                              text: 'service_card_block'.tr,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryColor,
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
            SizedBox(height: 4.h),
            _statRow(
              context,
              Icons.pets_rounded,
              '${sitter.completedServicesCount} ${'card_keepings_done'.tr}',
            ),
            SizedBox(height: 4.h),
            _statRow(context, Icons.calendar_today_rounded, _availabilityLabel()),
            if (sitter.responseTimeMinutes > 0) ...[
              SizedBox(height: 4.h),
              _statRow(
                context,
                Icons.schedule_rounded,
                '${'card_response_in'.tr} ${sitter.responseTimeMinutes} min',
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _roleChip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: _sitterBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: InterText(
        text: 'card_role_sitter'.tr,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: _sitterBlue,
      ),
    );
  }

  Widget _statRow(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13.sp, color: _sitterBlue),
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
          color: _sitterBlue.withValues(alpha: 0.25),
        ));
      }
    }
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
      decoration: BoxDecoration(
        color: _sitterBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _sitterBlue.withValues(alpha: 0.20), width: 1),
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
            color: _sitterBlue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
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
      ),
    );
  }

  /// v440 — petite ligne d'icônes des espèces gardées (chien/chat/NAC…),
  /// dérivée de acceptedPetTypes. Pastilles neutres rondes avec l'emoji.
  Widget _buildAnimalChips(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.pets_rounded, size: 13.sp, color: _sitterBlue),
        SizedBox(width: 6.w),
        InterText(
          text: 'card_kept_animals'.tr,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: sitter.acceptedPetTypes
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
        color: _sitterBlue.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: _sitterBlue.withValues(alpha: 0.20), width: 1),
      ),
      child: Text(emoji, style: TextStyle(fontSize: 13.sp)),
    );
  }

  Widget _buildAboutBox(BuildContext context, String bio) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: _sitterBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 14.sp, color: _sitterBlue),
              SizedBox(width: 6.w),
              InterText(
                text: 'post_about_owner'.tr,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _sitterBlue,
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
        onPressed: onSendRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: _sitterBlue,
          padding: EdgeInsets.symmetric(vertical: 13.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
          ),
          elevation: 0,
        ),
        icon: Icon(Icons.send_rounded, size: 16.sp, color: Colors.white),
        label: InterText(
          text: 'card_request_sitter'.tr,
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
