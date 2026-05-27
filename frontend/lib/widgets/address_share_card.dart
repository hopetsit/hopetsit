// v23.1 part 240 — Daniel : "sur les 3 profile rajoute partager mon adresse
// pour rdv fais un truc styler pour les 3 profile qduand y font recuperer
// lanimal y senvoi ladresse directement dans le chat".
//
// Carte chat affichee pour les messages de type 'address_share' (envoyes via
// POST /conversations/:id/share-address). UI styled : icone pin + libelle
// "Adresse pour le rendez-vous" + addresse multi-ligne + bouton "Itineraire"
// qui ouvre Google Maps via url_launcher (gere les 3 plateformes mobile).
//
// Usage : dans le _buildMessageItem du chat (owner / sitter / walker), avant
// le rendu texte par defaut, on intercepte si `message.isAddressShare` et
// on renvoie une AddressShareCard.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:url_launcher/url_launcher.dart';

class AddressShareCard extends StatelessWidget {
  const AddressShareCard({
    super.key,
    required this.address,
    required this.city,
    this.lat,
    this.lng,
    required this.isFromCurrentUser,
  });

  final String address;
  final String city;
  final double? lat;
  final double? lng;
  final bool isFromCurrentUser;

  static const _orangeBrand = Color(0xFFEF4324);
  static const _orangeLight = Color(0xFFFFF1ED);

  Future<void> _openInMaps() async {
    // Prefer GPS coords (most accurate) ; fallback on address+city string.
    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
    } else {
      final q = [address, city].where((s) => s.trim().isNotEmpty).join(', ');
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}',
      );
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {/* silent — let Maps fail naturally */}
  }

  @override
  Widget build(BuildContext context) {
    final fullAddress = [address, city]
        .where((s) => s.trim().isNotEmpty)
        .join('\n');
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 14.w),
      child: Align(
        alignment:
            isFromCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 320.w),
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
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header : icone pin + titre ─────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 10.h),
                  child: Row(
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
                        child: Icon(Icons.location_on_rounded,
                            color: Colors.white, size: 20.sp),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InterText(
                              text: 'address_share_title'.tr,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                              maxLines: 1,
                            ),
                            SizedBox(height: 2.h),
                            InterText(
                              text: 'address_share_subtitle'.tr,
                              fontSize: 11.sp,
                              color: AppColors.textSecondary(context),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Bloc adresse ───────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 10.h),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: _orangeLight,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: _orangeBrand.withValues(alpha: 0.20),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.home_rounded,
                            color: _orangeBrand, size: 18.sp),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: InterText(
                            text: fullAddress.isEmpty
                                ? 'address_share_empty'.tr
                                : fullAddress,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                            maxLines: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Bouton Itineraire ─────────────────────────────────
                if (fullAddress.isNotEmpty || (lat != null && lng != null))
                  Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.directions_rounded,
                            color: Colors.white),
                        label: Padding(
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                          child: InterText(
                            text: 'address_share_open_directions'.tr,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orangeBrand,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 11.h),
                          elevation: 3,
                          shadowColor: _orangeBrand.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        onPressed: _openInMaps,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
