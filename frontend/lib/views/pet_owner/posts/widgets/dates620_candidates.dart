// 620 (PAM, 24/10/2026 — contrat §C.3) — candidatures sur une demande « dates
// à prévoir » : tarif UNITAIRE (« 12 €/visite · indicatif »), bandeau « Pose
// tes dates pour valider » qui ouvre l'édition de la demande, bouton Choisir
// désactivé tant que les dates ne sont pas posées. Après les dates, le
// serveur recalcule (totaux réels) et notifie `application_pricing_updated`.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../models/application_model.dart';
import '../../../../models/booking_model.dart';
import '../../../../repositories/post_repository.dart';
import '../../../../utils/app_colors.dart';
import '../../../../utils/currency_helper.dart';
import '../../../../utils/services620.dart';
import '../../../../widgets/app_text.dart';
import '../../../../widgets/custom_snackbar_widget.dart';
import 'post_dates_sheet2610.dart';

/// Vrai quand la candidature n'a pas de total (demande sans dates, ou
/// « tarif à venir »).
bool applicationIsIndicative620(ApplicationModel app) {
  final p = app.pricing;
  if (p == null) return false;
  if (p.indicative || p.stale) return true;
  return (p.totalPrice == null || p.totalPrice! <= 0) && p.unitRate != null;
}

/// 621 — « tarif à venir » : la demande a changé de service et ce candidat
/// n'a pas encore de tarif pour le nouveau (serveur 620b, `pricing.stale`).
bool applicationIsStale620(ApplicationModel app) => app.pricing?.stale == true;

/// 621 — vrai quand il manque les DATES (indicatif mais pas « tarif à
/// venir ») : c'est ce cas, et lui seul, qui appelle « Pose tes dates ».
bool applicationNeedsDates620(ApplicationModel app) =>
    applicationIsIndicative620(app) && !applicationIsStale620(app);

/// Unité du tarif d'une candidature : celle du serveur, sinon déduite du
/// palier (`visit` / `walk` / `daily`…), sinon du rôle.
String _unitOf(BookingPricing p, String providerRole) {
  if (p.unit.isNotEmpty) return p.unit;
  switch ((p.pricingTier ?? '').toLowerCase()) {
    case 'visit':
      return 'visit';
    case 'walk':
      return 'walk';
    case 'daily':
    case 'day':
      return 'day';
    case 'night':
      return 'night';
    case 'hourly':
    case 'hour':
      return 'hour';
    case 'weekly':
      return 'week';
    case 'monthly':
      return 'month';
  }
  return providerRole == 'walker' ? 'walk' : 'day';
}

/// « 12 €/visite · indicatif » ; vide sans tarif.
String indicativePriceLabel620(ApplicationModel app) {
  final p = app.pricing;
  // 624 (ZOE) — tarif FRAIS COMPRIS pour le propriétaire quand le serveur le donne.
  final r = (p?.ownerUnitRate != null && p!.ownerUnitRate! > 0) ? p.ownerUnitRate : p?.unitRate;
  if (p == null || r == null) return '';
  final cur = (p.currency ?? '').isNotEmpty ? p.currency! : app.sitter.currency;
  final suffix = priceUnitSuffix620(_unitOf(p, app.providerRole));
  final amount = CurrencyHelper.formatCompact(cur.isNotEmpty ? cur : 'EUR', r);
  return 'dates620_indicative'.tr
      .replaceAll('@price', amount)
      .replaceAll('/@unit', suffix.isEmpty ? '' : suffix);
}

/// Prix à afficher sur une carte de candidat : total réel, sinon tarif
/// unitaire indicatif, sinon vide.
String candidatePriceLabel620(ApplicationModel app) {
  final p = app.pricing;
  if (p == null) return '';
  if (p.stale) return 'dates620_stale_label'.tr; // 621
  if (!applicationIsIndicative620(app) && p.totalPrice != null && p.totalPrice! > 0) {
    final cur = (p.currency ?? '').isNotEmpty ? p.currency! : 'EUR';
    return CurrencyHelper.formatCompact(cur, p.totalPrice!);
  }
  return indicativePriceLabel620(app);
}

/// Ouvre l'édition de la demande (même formulaire que « Publier ma
/// demande ») pour poser les dates. Renvoie vrai si l'écran a été ouvert.
Future<bool> openPostDatesEditor620(String? postId) async {
  if (postId == null || postId.isEmpty) return false;
  if (!Get.isRegistered<PostRepository>()) return false;
  try {
    final post = await Get.find<PostRepository>().getPostById(postId);
    if (post == null) return false;
    // 624 (FLO) — plus le formulaire complet (animaux, lieu, code postal
    // exigé) : la petite feuille des DATES SEULES, comme le site.
    final ctx = Get.context;
    if (ctx == null || !ctx.mounted) return false;
    await PostDatesSheet2610.show(ctx, post);
    return true;
  } catch (_) {
    CustomSnackbar.showError(
        title: 'common_error'.tr, message: 'publish_request_error'.tr);
    return false;
  }
}

/// Bandeau « Pose tes dates pour valider » + bouton.
class SetDatesBanner620 extends StatelessWidget {
  const SetDatesBanner620({super.key, required this.postId, this.onOpened});
  final String? postId;
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context) {
    final tone = AppColors.primaryColor;
    final on = AppColors.accentOn(context, tone);
    return Container(
      key: const Key('dates620_set_dates_banner'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded, size: 18.sp, color: on),
              SizedBox(width: 8.w),
              Expanded(
                child: PoppinsText(
                  text: 'dates620_set_dates_banner'.tr,
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                  color: on,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          InterText(
            text: 'dates620_set_dates_sub'.tr,
            fontSize: 11.5.sp,
            color: AppColors.textSecondary(context),
            maxLines: 3,
          ),
          SizedBox(height: 8.h),
          GestureDetector(
            key: const Key('dates620_set_dates_button'),
            onTap: () async {
              onOpened?.call();
              await openPostDatesEditor620(postId);
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_calendar_rounded, size: 16.sp, color: Colors.white),
                  SizedBox(width: 6.w),
                  InterText(
                    text: 'dates620_set_dates_button'.tr,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 621 — bandeau « Tarif à venir » : au moins un candidat n'a pas encore de
/// tarif pour le service de la demande ; le serveur recalcule et prévient.
class StaleBanner620 extends StatelessWidget {
  const StaleBanner620({super.key, this.count = 0});
  final int count;

  @override
  Widget build(BuildContext context) {
    final tone = AppColors.primaryColor;
    final on = AppColors.accentOn(context, tone);
    return Container(
      key: const Key('dates620_stale_banner'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_top_rounded, size: 18.sp, color: on),
              SizedBox(width: 8.w),
              Expanded(
                child: PoppinsText(
                  text: 'dates620_stale_banner'.tr,
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                  color: on,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          InterText(
            text: 'dates620_stale_banner_sub'.tr.replaceAll('@n', '$count'),
            fontSize: 11.5.sp,
            color: AppColors.textSecondary(context),
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

/// 621 — appui sur « Tarif à venir » : explication, aucune action.
void warnStale620() {
  CustomSnackbar.showWarning(
    title: 'dates620_stale_label'.tr,
    message: 'dates620_stale_explain'.tr,
  );
}

/// Message quand on tente d'accepter une candidature indicative (ou que le
/// serveur répond 409 DATES_REQUIRED).
void warnDatesRequired620() {
  CustomSnackbar.showWarning(
    title: 'dates620_set_dates_banner'.tr,
    message: 'dates620_dates_required_error'.tr,
  );
}

/// Vrai si l'erreur serveur est le refus 409 « DATES_REQUIRED ».
bool isDatesRequiredError620(Object? error) {
  final t = error.toString();
  return t.contains('DATES_REQUIRED');
}
