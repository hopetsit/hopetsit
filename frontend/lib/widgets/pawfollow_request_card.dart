// v23.1.176 — Daniel : "demande suivre votre animale ds le chat ya pas".
// v23.1.188 — Daniel : "aplique sa dans le chat" (mockup SUIVI EN DIRECT).
//
// Widget partagé pour la carte chat de type 'pawfollow_request' (utilisé
// dans individual_chat_screen côté owner ET sitter_individual_chat_screen
// côté walker/sitter).
//
// Design v188 (mockup Daniel) :
//   - En-tête : icône paw orange + titre + statut pill (En attente /
//     Accepté / Refusé)
//   - Description courte (qui propose à qui)
//   - 3 bullets avec checkmarks oranges (transparence, contrôle, off à
//     tout moment) — visibles uniquement pour le responder pour rassurer.
//   - 2 boutons côte à côte si responder + pending :
//       * gros bouton orange "Accepter" (avec ombre, icône check)
//       * outlined "Plus tard" / "Refuser"
//   - Footer "Transparence & confiance" (bandeau orange clair) qui apparait
//     quand status='accepted' pour rappeler la sécurité.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:intl/intl.dart';

class PawfollowRequestCard extends StatelessWidget {
  const PawfollowRequestCard({
    super.key,
    required this.messageId,
    required this.requesterRole,
    required this.responderRole,
    required this.status,
    required this.myRole,
    required this.onAccept,
    required this.onRefuse,
    // v23.1 part 200 — snapshot booking pour le redesign mockup Daniel
    // (carte pet + dates orange + section GPS).
    this.petName,
    this.petPhoto,
    this.startAt,
    this.endAt,
    this.lastLat,
    this.lastLng,
    this.serviceType,
    // v23.1 part 206 — Daniel : "qd la demande accepte japuis sur le
    // bouton ds le chat et sa menvoi sur le map sur la geoloc du
    // walker/sitter". Callback déclenché par le bouton "Voir sur la
    // carte" affiché sur la carte quand status=='accepted' et que je
    // suis du côté receveur de la position (typiquement owner).
    this.onOpenMap,
  });

  final String messageId;
  final String requesterRole; // 'owner' | 'sitter' | 'walker'
  final String responderRole; // 'owner' | 'sitter' | 'walker'
  final String status; // 'pending' | 'accepted' | 'refused'
  final String myRole; // current user role
  final VoidCallback onAccept;
  final VoidCallback onRefuse;
  // v23.1 part 200 — données snapshot
  final String? petName;
  final String? petPhoto;
  final DateTime? startAt;
  final DateTime? endAt;
  final double? lastLat;
  final double? lastLng;
  final String? serviceType;
  // v23.1 part 206 — callback "Voir sur la carte" (cf. note plus haut)
  final VoidCallback? onOpenMap;

  static const _orangeBrand = Color(0xFFEF4324);
  static const _orangeLight = Color(0xFFFFF1ED);

  @override
  Widget build(BuildContext context) {
    final isResponder = responderRole == myRole;
    final isRequester = requesterRole == myRole;

    String headerText;
    if (isRequester) {
      headerText = 'pawfollow_request_sent_header'.tr;
    } else if (isResponder) {
      headerText = requesterRole == 'owner'
          ? 'pawfollow_request_owner_wants_to_follow'.tr
          : 'pawfollow_request_provider_wants_to_share'.tr;
    } else {
      headerText = 'pawfollow_request_generic'.tr;
    }

    String statusBadge;
    Color statusColor;
    IconData statusIcon;
    if (status == 'accepted') {
      statusBadge = 'pawfollow_status_accepted'.tr;
      statusColor = const Color(0xFF16A34A);
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'refused') {
      statusBadge = 'pawfollow_status_refused'.tr;
      statusColor = AppColors.errorColor;
      statusIcon = Icons.cancel_rounded;
    } else {
      statusBadge = 'pawfollow_status_pending'.tr;
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.schedule_rounded;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 14.w),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: _orangeBrand.withValues(alpha: 0.30),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: _orangeBrand.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header : icone paw + titre + badge statut ─────────────
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 10.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_orangeBrand, Color(0xFFFF6B45)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _orangeBrand.withValues(alpha: 0.40),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(Icons.pets_rounded,
                        color: Colors.white, size: 20.sp),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InterText(
                          text: 'pawfollow_card_title'.tr,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                          maxLines: 1,
                        ),
                        SizedBox(height: 2.h),
                        InterText(
                          text: headerText,
                          fontSize: 11.sp,
                          color: AppColors.textSecondary(context),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  // Pill statut.
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.40),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 11.sp),
                        SizedBox(width: 3.w),
                        InterText(
                          text: statusBadge,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── v23.1 part 200 — Pet card (mockup top) ─────────────────
            // Affichée si on a au moins le nom de l'animal. Tape du chat
            // typique : avatar circulaire + nom + service ("Walk" /
            // "Sitting" / etc.).
            if ((petName ?? '').isNotEmpty) ...[
              const Divider(height: 1, thickness: 0.6, color: Color(0xFFE5E7EB)),
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
                child: Row(
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _orangeLight,
                        border: Border.all(color: _orangeBrand, width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (petPhoto ?? '').startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: petPhoto!,
                              memCacheWidth: 200, // v235.5.
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Icon(
                                Icons.pets_rounded,
                                size: 22.sp,
                                color: _orangeBrand,
                              ),
                            )
                          : Icon(Icons.pets_rounded,
                              size: 22.sp, color: _orangeBrand),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InterText(
                            text: petName!,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                          if ((serviceType ?? '').isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            InterText(
                              text: _serviceLabel(serviceType!),
                              fontSize: 11.sp,
                              color: AppColors.textSecondary(context),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── v23.1 part 200 — Dates orange (mockup) ─────────────────
            if (startAt != null || endAt != null) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 10.h),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: _orangeLight,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: _orangeBrand.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          color: _orangeBrand, size: 16.sp),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: InterText(
                          text: _formatDateRange(),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: _orangeBrand,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── v23.1 part 200 — Section GPS (mockup) ──────────────────
            if (lastLat != null && lastLng != null) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36.w,
                        height: 36.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _orangeBrand.withValues(alpha: 0.12),
                        ),
                        child: Icon(Icons.gps_fixed_rounded,
                            color: _orangeBrand, size: 18.sp),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InterText(
                              text: 'pawfollow_gps_section_title'.tr,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                            SizedBox(height: 2.h),
                            InterText(
                              text: 'pawfollow_gps_section_subtitle'.tr,
                              fontSize: 10.sp,
                              color: AppColors.textSecondary(context),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── Bullets de rassurance (mockup : 3 cases avec check) ───
            if (status == 'pending' && isResponder) ...[
              const Divider(height: 1, thickness: 0.6, color: Color(0xFFE5E7EB)),
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bullet(context, 'pawfollow_bullet_transparency'.tr),
                    SizedBox(height: 6.h),
                    _bullet(context, 'pawfollow_bullet_control'.tr),
                    SizedBox(height: 6.h),
                    _bullet(context, 'pawfollow_bullet_anytime_off'.tr),
                  ],
                ),
              ),
            ],

            // ── Actions Accepter / Plus tard (mockup) ─────────────────
            if (status == 'pending' && isResponder) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 12.h),
                child: Column(
                  children: [
                    // Bouton plein orange "Accepter" (style mockup, pleine
                    // largeur, gradient + ombre).
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded,
                            color: Colors.white),
                        label: Padding(
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                          child: InterText(
                            text: 'pawfollow_accept'.tr,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orangeBrand,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          elevation: 3,
                          shadowColor: _orangeBrand.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        onPressed: onAccept,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          side: BorderSide(
                            color: _orangeBrand.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        onPressed: onRefuse,
                        child: InterText(
                          text: 'pawfollow_later'.tr,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: _orangeBrand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // v23.1 part 206 — CTA "Voir sur la carte" quand accepted.
            // Daniel : "qd la demande accepte japuis sur le bouton ds le
            // chat et sa menvoi sur la geoloc du walker/sitter sur mon
            // animal". Le bouton n'apparait que si l'écran parent a passé
            // un callback onOpenMap (typiquement le owner side qui sait
            // récupérer bookingId via metadata et naviguer vers
            // LiveWalkMapScreen).
            if (status == 'accepted' && onOpenMap != null) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 4.h),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.map_rounded, color: Colors.white),
                    label: Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      child: InterText(
                        text: 'pawfollow_open_map'.tr,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orangeBrand,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      elevation: 3,
                      shadowColor: _orangeBrand.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    onPressed: onOpenMap,
                  ),
                ),
              ),
            ],

            // ── Footer transparence (apparait quand accepted) ─────────
            if (status == 'accepted') ...[
              Container(
                margin: EdgeInsets.all(10.w),
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: _orangeLight,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_rounded,
                        color: _orangeBrand, size: 18.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InterText(
                            text: 'pawfollow_trust_title'.tr,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            color: _orangeBrand,
                          ),
                          SizedBox(height: 2.h),
                          InterText(
                            text: 'pawfollow_trust_msg'.tr,
                            fontSize: 10.sp,
                            color: AppColors.textSecondary(context),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              SizedBox(height: status == 'pending' && isResponder ? 0 : 12.h),
          ],
        ),
      ),
    );
  }

  // v23.1 part 200 — i18n service label depuis le snapshot backend
  String _serviceLabel(String type) {
    switch (type.toLowerCase()) {
      case 'walk':
      case 'walking':
        return 'pawfollow_service_walk'.tr;
      case 'sit':
      case 'sitting':
        return 'pawfollow_service_sitting'.tr;
      default:
        return type;
    }
  }

  // v23.1 part 200 — formate startAt → endAt en localisant. Fallback
  // intelligent : si juste startAt, on n'affiche que la date de début.
  String _formatDateRange() {
    final locale = Get.locale?.languageCode ?? 'fr';
    final df = DateFormat('d MMM, HH:mm', locale);
    if (startAt != null && endAt != null) {
      return '${df.format(startAt!)}  →  ${df.format(endAt!)}';
    }
    if (startAt != null) return df.format(startAt!);
    if (endAt != null) return df.format(endAt!);
    return '';
  }

  Widget _bullet(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 1.h),
          child: Icon(Icons.check_rounded, color: _orangeBrand, size: 14.sp),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: InterText(
            text: text,
            fontSize: 11.sp,
            color: AppColors.textSecondary(context),
            maxLines: 3,
          ),
        ),
      ],
    );
  }
}
