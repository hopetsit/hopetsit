// v449 — Daniel : « améliore le chat partager mon numéro sur les 3 profils ».
//
// Carte chat affichée pour les messages de type 'phone_share' (envoyés via
// POST /conversations/:id/share-phone). UI stylée, à parité avec
// AddressShareCard : icône téléphone + libellé « Numéro de téléphone » + le
// numéro + 2 boutons « Appeler » (tel:) et « Copier » (presse-papiers).
//
// Usage : dans le _buildMessageItem du chat (owner / sitter / walker), avant
// le rendu texte par défaut, on intercepte si `message.isPhoneShare` et on
// renvoie une PhoneShareCard.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneShareCard extends StatelessWidget {
  const PhoneShareCard({
    super.key,
    required this.phone,
    required this.isFromCurrentUser,
  });

  final String phone;
  final bool isFromCurrentUser;

  static const _orangeBrand = Color(0xFFC92A12);
  static const _callGreen = Color(0xFF16A34A);

  Future<void> _call() async {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: digits);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {/* silencieux — laisse le dialer échouer naturellement */}
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: phone));
    CustomSnackbar.showSuccess(
      title: 'phone_share_title'.tr,
      message: 'phone_share_copied'.tr,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 14.w),
      child: Align(
        alignment:
            isFromCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 320.w),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card(context),
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
                // ── Header : icône téléphone + titre ───────────────────
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
                        child: Icon(Icons.phone_rounded,
                            color: Colors.white, size: 20.sp),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InterText(
                              text: 'phone_share_title'.tr,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                              maxLines: 1,
                            ),
                            SizedBox(height: 2.h),
                            InterText(
                              text: 'phone_share_subtitle'.tr,
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

                // ── Bloc numéro ────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 10.h),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: _orangeBrand.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: _orangeBrand.withValues(alpha: 0.20),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone_in_talk_rounded,
                            color: _orangeBrand, size: 18.sp),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: SelectableText(
                            phone,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Boutons Appeler + Copier ───────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.call_rounded,
                              color: Colors.white),
                          label: Padding(
                            padding: EdgeInsets.symmetric(vertical: 2.h),
                            child: InterText(
                              text: 'phone_share_call'.tr,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _callGreen,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 11.h),
                            elevation: 3,
                            shadowColor: _callGreen.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          onPressed: _call,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.copy_rounded,
                              color: _orangeBrand, size: 18.sp),
                          label: Padding(
                            padding: EdgeInsets.symmetric(vertical: 2.h),
                            child: InterText(
                              text: 'phone_share_copy'.tr,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                              color: _orangeBrand,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 11.h),
                            side: BorderSide(
                              color: _orangeBrand.withValues(alpha: 0.5),
                              width: 1.3,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          onPressed: _copy,
                        ),
                      ),
                    ],
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
