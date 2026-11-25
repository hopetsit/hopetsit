// 646 (PAM, 25/11/2026 — ordre de Daniel : « je veux que les clients
// comprennent », « ça doit être ludique ») — UNE petite feuille, UNE action.
//
//  · après l'envoi d'une candidature en « tarif à venir » : « Candidature
//    envoyée 💶 — Il manque ton prix par jour… » + « Ajouter mon tarif » ;
//  · quand le serveur refuse faute de tarif (visite, balade…) : la phrase qui
//    dit quoi faire et où + « Ouvrir Mes tarifs ».
// Le bouton ouvre Mes tarifs sur la bonne rubrique, curseur dans le champ.
// Marge basse : `lib/utils/bottom_inset.dart` (règle du dépôt).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/rate646.dart';
import 'package:hopetsit/views/profile/my_rates_screen.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

class RateSheet646 {
  RateSheet646._();

  /// Ouvre Mes tarifs sur la rubrique [focus] ('day' | 'visit' | 'walk' |
  /// 'auto'). Remplaçable en test.
  static void Function(String role, String focus) openRates = _openRatesDefault;

  static void resetForTest() => openRates = _openRatesDefault;

  static void _openRatesDefault(String role, String focus) {
    Get.to(() => MyRatesScreen(role: role, focus: focus));
  }

  /// Après l'envoi : la candidature est partie, il manque le prix par jour.
  static Future<void> showSent({BuildContext? context, required String role}) {
    return _show(
      context: context,
      role: role,
      sheetKey: const Key('rate646_sent_sheet'),
      icon: Icons.check_circle_rounded,
      titleKey: 'pam646_sent_title',
      bodyKey: 'pam646_sent_body',
      ctaKey: 'pam646_sent_cta',
      focus: role.toLowerCase() == 'walker' ? 'walk' : 'day',
    );
  }

  /// Le serveur a refusé faute de tarif : quoi faire, et où.
  static Future<void> showNeed(String need, {BuildContext? context, required String role}) {
    final bool notForMe = need == 'not_for_walker';
    return _show(
      context: context,
      role: role,
      sheetKey: const Key('rate646_need_sheet'),
      icon: notForMe ? Icons.visibility_rounded : Icons.payments_rounded,
      titleKey: notForMe ? 'pam646_walker_not_for_you_title' : 'pam646_need_title',
      bodyKey: needKey646(need),
      ctaKey: notForMe ? null : 'pam646_open_rates',
      focus: need == 'any' ? 'auto' : need,
    );
  }

  /// Si [error] est un refus « il manque ton tarif », montre la feuille et
  /// renvoie `true` ; sinon `false` (l'appelant garde son message habituel).
  static Future<bool> handleApplyError(Object error,
      {BuildContext? context, required String role, String service = ''}) async {
    final String? need = rateNeedOfError646(error, role: role, service: service);
    if (need == null) return false;
    await showNeed(need, context: context, role: role);
    return true;
  }

  static Future<void> _show({
    required BuildContext? context,
    required String role,
    required Key sheetKey,
    required IconData icon,
    required String titleKey,
    required String bodyKey,
    required String? ctaKey,
    required String focus,
  }) async {
    try {
      final BuildContext? host = context ?? Get.context;
      if (host == null || !host.mounted) return;
      final bool? open = await showModalBottomSheet<bool>(
        context: host,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final Color tone = AppColors.activeRoleAccent();
          return Container(
            key: sheetKey,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.86),
            decoration: BoxDecoration(
              color: AppColors.scaffold(ctx),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h + appBottomInset(ctx)),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 14.h),
                    decoration: BoxDecoration(
                      color: AppColors.divider(ctx),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  Container(
                    width: 60.w,
                    height: 60.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 30.sp, color: AppColors.accentOn(ctx, tone)),
                  ),
                  SizedBox(height: 12.h),
                  PoppinsText(
                    text: titleKey.tr,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(ctx),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6.h),
                  InterText(
                    text: bodyKey.tr,
                    fontSize: 14.sp,
                    height: 1.4,
                    color: AppColors.textSecondary(ctx),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 18.h),
                  if (ctaKey != null)
                    ActionPillButton(
                      key: const Key('rate646_cta'),
                      label: ctaKey.tr,
                      icon: Icons.payments_rounded,
                      tone: tone,
                      expand: true,
                      onPressed: () => Navigator.of(ctx).pop(true),
                    )
                  else
                    ActionPillButton(
                      key: const Key('rate646_ok'),
                      label: 'common_ok'.tr,
                      tone: tone,
                      expand: true,
                      onPressed: () => Navigator.of(ctx).pop(false),
                    ),
                  if (ctaKey != null) ...[
                    SizedBox(height: 4.h),
                    Semantics(
                      button: true,
                      child: InkWell(
                        key: const Key('rate646_later'),
                        borderRadius: BorderRadius.circular(10.r),
                        onTap: () => Navigator.of(ctx).pop(false),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44, minWidth: 120),
                          child: Center(
                            widthFactor: 1,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                              child: InterText(
                                text: 'cand644_photo_later'.tr,
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary(ctx),
                                textDecoration: TextDecoration.underline,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
      if (open == true) openRates(role, focus);
    } catch (e) {
      AppLogger.logError('[rate646] feuille tarif', error: e);
    }
  }
}
