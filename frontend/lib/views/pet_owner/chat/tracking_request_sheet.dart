// v23.1.192 — Daniel mockup SUIVI EN DIRECT (cote OWNER) : ecran qui
// s'ouvre quand l'owner tape "Suivre en direct mon animal" dans le chat.
//
// v23.1.194 — Reverif 3x du mockup Daniel : refonte stricte pour matcher
// EXACTEMENT le screenshot envoye (cote owner gauche) :
//   - Titre : "Detail de la garde" (pas "Suivre mon animal")
//   - Pet card : avatar + nom + emoji paw + race + badge "En garde" +
//     dates dans encart orange (calendar icon)
//   - Panel "Suivi en direct" : pill verte "Disponible" + description
//     + GROS bouton orange seul (PAS de "Plus tard" cote owner)
//   - "Informations pratiques" : 3 rows
//       * Sitter / Walker + nom + bouton chat
//       * Telephone + numero + bouton appel
//       * Adresse de depart + adresse + bouton map
//   - Banner "Transparence & confiance"
//   - Le back AppBar suffit pour annuler

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/models/booking_model.dart' show BookingModel;
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

class TrackingRequestSheet extends StatelessWidget {
  const TrackingRequestSheet({
    super.key,
    this.booking,
    this.fallbackContactName = '',
    this.fallbackContactImage = '',
    required this.onConfirm,
  });

  /// Booking lie a la conversation (pet, dates, sitter/walker info).
  final BookingModel? booking;

  /// Nom du contact de la conversation (si pas de booking).
  final String fallbackContactName;

  /// Image du contact de la conversation (si pas de booking).
  final String fallbackContactImage;

  /// Callback declenche au tap "Suivre mon animal".
  final Future<void> Function() onConfirm;

  static const _orange = Color(0xFFEF4324);
  static const _orangeBg = Color(0xFFFFF1ED);

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final providerName = b?.sitter.name ?? fallbackContactName;
    final providerAvatar = b?.sitter.avatar.url ?? fallbackContactImage;
    final providerPhone = (b != null && b.sitter.mobile.isNotEmpty)
        ? b.sitter.mobile
        : '';
    final providerAddress = b?.sitter.address ?? '';
    final petName = b != null
        ? (b.pets.isNotEmpty ? b.pets.first.petName : b.petName)
        : '';
    final petBreed = b != null && b.pets.isNotEmpty ? b.pets.first.breed : '';
    final petAvatar =
        b != null && b.pets.isNotEmpty ? b.pets.first.avatar.url : '';
    final dateText = b != null
        ? [b.date, b.timeSlot].where((s) => s.isNotEmpty).join(' • ')
        : '';

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _orange, size: 24.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: InterText(
          // v23.1.194 — Daniel mockup : "Detail de la garde" (pas
          // "Suivre mon animal" qui est le label du bouton).
          text: 'tracking_sheet_title_v2'.tr,
          fontSize: 17.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(context),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
          children: [
            // ── Pet card (mockup) ─────────────────────────────────────
            if (b != null)
              _buildPetCard(context,
                  name: petName,
                  breed: petBreed,
                  avatar: petAvatar,
                  dateText: dateText),
            if (b != null) SizedBox(height: 14.h),

            // ── Panel "Suivi en direct" + gros bouton orange seul ─────
            _buildLiveTrackingPanel(context),
            SizedBox(height: 14.h),

            // ── Informations pratiques (3 rows mockup) ───────────────
            _buildPracticalInfo(
              context,
              name: providerName,
              avatar: providerAvatar,
              phone: providerPhone,
              address: providerAddress,
            ),
            SizedBox(height: 14.h),

            // ── Transparence & confiance ──────────────────────────────
            _buildTrustBanner(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPetCard(
    BuildContext context, {
    required String name,
    required String breed,
    required String avatar,
    required String dateText,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.divider(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipOval(
                child: Container(
                  width: 56.w,
                  height: 56.w,
                  color: _orange.withValues(alpha: 0.12),
                  child: avatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatar,
                          memCacheWidth: 150, // v235.5.
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              Icon(Icons.pets, color: _orange, size: 28.sp),
                        )
                      : Icon(Icons.pets, color: _orange, size: 28.sp),
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
                          child: InterText(
                            text: name.isEmpty ? '—' : name,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                            maxLines: 1,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text('🐾', style: TextStyle(fontSize: 14.sp)),
                      ],
                    ),
                    if (breed.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      InterText(
                        text: breed,
                        fontSize: 12.sp,
                        color: AppColors.greyText,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: _orangeBg,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: _orange.withValues(alpha: 0.3)),
                ),
                child: InterText(
                  text: 'tracking_sheet_in_care_badge'.tr,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: _orange,
                ),
              ),
            ],
          ),
          if (dateText.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: _orangeBg,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      color: _orange, size: 14.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: InterText(
                      text: dateText,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveTrackingPanel(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.divider(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InterText(
                  text: 'tracking_sheet_panel_title'.tr,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
              // Pill verte "Disponible" (mockup).
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    InterText(
                      text: 'tracking_sheet_available'.tr,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF16A34A),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          InterText(
            text: 'tracking_sheet_panel_desc_v2'.tr,
            fontSize: 12.sp,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 14.h),
          // v23.1.194 — mockup owner side : GROS bouton seul, PAS de
          // "Plus tard". Le back arrow AppBar suffit pour annuler.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await onConfirm();
                if (context.mounted) Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.location_on_rounded, color: Colors.white),
              label: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: InterText(
                  text: 'tracking_sheet_follow_btn'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                elevation: 3,
                shadowColor: _orange.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticalInfo(
    BuildContext context, {
    required String name,
    required String avatar,
    required String phone,
    required String address,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.divider(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InterText(
            text: 'tracking_sheet_practical_info'.tr,
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 14.h),

          // Row 1 : Sitter / Walker avec avatar + bouton chat (mockup).
          _infoRow(
            context,
            leading: ClipOval(
              child: Container(
                width: 38.w,
                height: 38.w,
                color: _orange.withValues(alpha: 0.10),
                child: avatar.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatar,
                        memCacheWidth: 150, // v235.5.
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Icon(Icons.person, color: _orange, size: 22.sp),
                      )
                    : Icon(Icons.person, color: _orange, size: 22.sp),
              ),
            ),
            labelKey: 'tracking_sheet_sitter_walker',
            value: name.isEmpty ? '—' : name,
            trailingIcon: Icons.chat_bubble_rounded,
            trailingBg: _orange.withValues(alpha: 0.10),
            trailingColor: _orange,
            onTrailingTap: () => Navigator.of(context).pop(),
          ),

          // v23.1.197 — Daniel : "le chat n'est pas modifie comme la
          // photo". Les rows Telephone + Adresse etaient conditionnels
          // (if phone.isNotEmpty) : si le sitter n'a pas renseigne ses
          // coords, les rows disparaissaient et le sheet semblait
          // incomplet vs mockup. Maintenant TOUJOURS visibles, avec
          // placeholder "—" si vide.
          SizedBox(height: 14.h),
          _infoRow(
            context,
            leading: Icon(Icons.phone_outlined,
                color: AppColors.greyText, size: 22.sp),
            labelKey: 'tracking_sheet_phone',
            value: phone.isEmpty ? '—' : phone,
            trailingIcon: Icons.call_rounded,
            trailingBg: _orange.withValues(alpha: 0.10),
            trailingColor: _orange,
            onTrailingTap: () {
              // TODO : url_launcher tel: scheme quand phone dispo.
            },
          ),

          SizedBox(height: 14.h),
          _infoRow(
            context,
            leading: Icon(Icons.location_on_outlined,
                color: AppColors.greyText, size: 22.sp),
            labelKey: 'tracking_sheet_address',
            value: address.isEmpty ? '—' : address,
            trailingIcon: Icons.map_rounded,
            trailingBg: _orange.withValues(alpha: 0.10),
            trailingColor: _orange,
            onTrailingTap: () {
              // TODO : url_launcher geo: scheme quand adresse dispo.
            },
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required Widget leading,
    required String labelKey,
    required String value,
    required IconData trailingIcon,
    required Color trailingBg,
    required Color trailingColor,
    required VoidCallback onTrailingTap,
  }) {
    return Row(
      children: [
        SizedBox(width: 38.w, height: 38.w, child: Center(child: leading)),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InterText(
                text: labelKey.tr,
                fontSize: 11.sp,
                color: AppColors.greyText,
              ),
              SizedBox(height: 2.h),
              InterText(
                text: value,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                maxLines: 2,
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20.r),
            onTap: onTrailingTap,
            child: Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: trailingBg,
                shape: BoxShape.circle,
              ),
              child: Icon(trailingIcon, color: trailingColor, size: 18.sp),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrustBanner(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: _orangeBg,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_rounded, color: _orange, size: 22.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: 'tracking_sheet_trust_title'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: _orange,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: 'tracking_sheet_trust_msg'.tr,
                  fontSize: 11.sp,
                  color: AppColors.textSecondary(context),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
