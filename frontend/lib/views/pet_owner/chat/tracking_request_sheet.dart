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

// v569 — remise au format du lot « listes ».
//
// ⚠️ DESIGN UNIQUEMENT pour la mise en page : mêmes paramètres, même
// `onConfirm()` puis `pop(true)`, même contenu.
//
// Deux VRAIS bugs corrigés et signalés :
//   1. les 3 cartes étaient en `Colors.white` EN DUR alors que leur texte
//      suit le thème → en mode sombre, texte quasi blanc sur carte blanche
//      (illisible). Elles passent sur `AppColors.card(context)`, et l'encart
//      orange pâle est teinté à partir de la surface du thème ;
//   2. les boutons « Appeler » et « Ouvrir la carte » étaient des TODO vides
//      → taps morts. Ils composent maintenant `tel:` / `geo:` (url_launcher,
//      déjà dans les dépendances) et sont désactivés quand la donnée manque.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hopetsit/models/booking_model.dart' show BookingModel;
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/address_route.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

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

  static const _orange = Color(0xFFC92A12);

  /// Encart orange PÂLE construit à partir de la surface du thème : reste
  /// lisible en mode sombre (avant : `#FFF1ED` en dur).
  static Color _orangeBg(BuildContext context) => Color.alphaBlend(
        _orange.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.08,
        ),
        AppColors.card(context),
      );

  /// Décoration commune des 3 cartes — surface du thème, jamais du blanc dur.
  static BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.divider(context)),
        boxShadow: AppColors.cardShadow(context),
      );

  /// Ouvre une URL externe ; prévient l'utilisateur si le téléphone ne sait
  /// pas la traiter, au lieu de ne rien faire.
  static Future<void> _launch(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {
      // on tombe dans le message ci-dessous
    }
    CustomSnackbar.showError(
      title: 'common_error'.tr,
      message: 'lists569_action_unavailable'.tr,
    );
  }

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
      body: PawPatternBackground(
          color: AppColors.activeRoleAccent(),
          child: SafeArea(
        child: ListView(
          // Le SafeArea ne suffit pas sur les Samsung edge-to-edge (inset
          // annoncé à 0) : on ajoute le complément manquant.
          padding: EdgeInsets.fromLTRB(
            16.w,
            16.h,
            16.w,
            24.h + appBottomInsetInsideSafeArea(context),
          ),
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
      decoration: _cardDecoration(context),
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
                        color: AppColors.textSecondary(context),
                      ),
                    ],
                  ],
                ),
              ),
              ActionStatusPill(
                label: 'tracking_sheet_in_care_badge'.tr,
                tone: _orange,
              ),
            ],
          ),
          if (dateText.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: _orangeBg(context),
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
      decoration: _cardDecoration(context),
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
              ActionStatusPill(
                label: 'tracking_sheet_available'.tr,
                icon: Icons.circle,
                tone: ActionTone.success,
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
          ActionPillButton(
            label: 'tracking_sheet_follow_btn'.tr,
            icon: Icons.location_on_rounded,
            tone: _orange,
            expand: true,
            haptic: true,
            onPressed: () async {
              await onConfirm();
              if (context.mounted) Navigator.of(context).pop(true);
            },
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
      decoration: _cardDecoration(context),
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
                color: AppColors.textSecondary(context), size: 22.sp),
            labelKey: 'tracking_sheet_phone',
            value: phone.isEmpty ? '—' : phone,
            trailingIcon: Icons.call_rounded,
            trailingTooltip: 'lists569_call'.tr,
            trailingBg: _orange.withValues(alpha: 0.10),
            trailingColor: _orange,
            // v569 — bouton mort réparé : composition du numéro. Désactivé
            // (grisé) quand le prestataire n'a pas renseigné de téléphone.
            onTrailingTap: phone.isEmpty
                ? null
                : () => _launch(
                      Uri(
                        scheme: 'tel',
                        path: phone.replaceAll(RegExp(r'[^\d+]'), ''),
                      ),
                    ),
          ),

          SizedBox(height: 14.h),
          _infoRow(
            context,
            leading: Icon(Icons.location_on_outlined,
                color: AppColors.textSecondary(context), size: 22.sp),
            labelKey: 'tracking_sheet_address',
            value: address.isEmpty ? '—' : address,
            trailingIcon: Icons.map_rounded,
            trailingTooltip: 'lists569_open_map'.tr,
            trailingBg: _orange.withValues(alpha: 0.10),
            trailingColor: _orange,
            // v585 — l'adresse s'ouvre DANS la PawMap (itinéraire maison),
            // jamais dans Google Maps (Daniel : « nos concurrents »).
            onTrailingTap: address.isEmpty
                ? null
                : () => openAddressInPawMap(address: address),
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
    required VoidCallback? onTrailingTap,
    String? trailingTooltip,
  }) {
    final enabled = onTrailingTap != null;
    return Row(
      children: [
        SizedBox(width: 44.w, height: 44.w, child: Center(child: leading)),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InterText(
                text: labelKey.tr,
                fontSize: 11.sp,
                color: AppColors.textSecondary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
        SizedBox(width: 8.w),
        Tooltip(
          message: trailingTooltip ?? '',
          child: Material(
            color: enabled ? trailingBg : AppColors.divider(context),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTrailingTap,
              child: SizedBox(
                width: 44.w,
                height: 44.w,
                child: Icon(
                  trailingIcon,
                  color: enabled ? trailingColor : AppColors.grey500Color,
                  size: 19.sp,
                ),
              ),
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
        color: _orangeBg(context),
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
