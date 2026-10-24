// 620 (PAM, 24/10/2026) — briques de « Publier ma demande » pour les dates à
// prévoir, les visites à domicile et l'estimation (contrat §C.1) :
//   · `DateModeCards620`  : 3 cartes Dates précises / Période approximative /
//                           Dates à prévoir ;
//   · `VisitsPerDayPicker620` : 1 | 2 visites par jour ;
//   · `EstimateLine620`   : « Environ 90 € pour 5 visites » (réponse du moteur
//                           serveur), ou « Tarif affiché à l'unité… » en tbd ;
//   · `TbdHint620`        : explication du mode « à prévoir » ;
//   · `TargetProviderBanner620` : « Demande adressée à <prénom> » (PawMap).
// Aucun gris : fonds à la couleur du rôle, texte des helpers AppColors.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../utils/app_colors.dart';
import '../../../../utils/currency_helper.dart';
import '../../../../utils/dates620.dart';
import '../../../../utils/services620.dart';
import '../../../../widgets/app_text.dart';

/// Texte de l'estimation (pur, testable) : total + quantité, quantité seule,
/// ou phrase « à l'unité » en tbd. Vide si rien d'exploitable.
String estimateText620(PricingEstimate620? e, {required bool tbd}) {
  if (tbd) return 'dates620_estimate_tbd'.tr;
  if (e == null) return '';
  if (e.indicative) return 'dates620_estimate_tbd'.tr;
  if (!e.hasQuantity) return '';
  final qty = quantityLabel620(e.quantity!, e.unit, night: e.night);
  if (e.hasTotal) {
    final cur = e.currency.isNotEmpty ? e.currency : 'EUR';
    return 'dates620_estimate_total'.tr
        .replaceAll('@total', CurrencyHelper.formatCompact(cur, e.ownerTotal!))
        .replaceAll('@qty', qty);
  }
  return 'dates620_estimate_qty_only'.tr.replaceAll('@qty', qty);
}

class DateModeCards620 extends StatelessWidget {
  const DateModeCards620({
    super.key,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final DateMode620 value;
  final Color accent;
  final ValueChanged<DateMode620> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget card(DateMode620 m, IconData icon, String title, String sub) {
      final selected = value == m;
      return Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: GestureDetector(
          key: Key('dates620_mode_${dateMode620Wire(m)}'),
          onTap: () => onChanged(m),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.08)
                  : AppColors.inputFill(context),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: selected ? accent : accent.withValues(alpha: 0.18),
                width: selected ? 1.8 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: selected ? accent : accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11.r),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon,
                      size: 19.sp,
                      color: selected ? Colors.white : AppColors.accentOn(context, accent)),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InterText(
                        text: title,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.accentOn(context, accent)
                            : AppColors.textPrimary(context),
                      ),
                      SizedBox(height: 2.h),
                      InterText(
                        text: sub,
                        fontSize: 11.sp,
                        color: AppColors.textSecondary(context),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded,
                      size: 20.sp, color: AppColors.accentOn(context, accent)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: 'dates620_mode_title'.tr,
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondaryStrong(context),
        ),
        SizedBox(height: 8.h),
        card(DateMode620.exact, Icons.event_available_rounded,
            'dates620_mode_exact'.tr, 'dates620_mode_exact_sub'.tr),
        card(DateMode620.approx, Icons.date_range_rounded,
            'dates620_mode_approx'.tr, 'dates620_mode_approx_sub'.tr),
        card(DateMode620.tbd, Icons.help_outline_rounded,
            'dates620_mode_tbd'.tr, 'dates620_mode_tbd_sub'.tr),
      ],
    );
  }
}

class VisitsPerDayPicker620 extends StatelessWidget {
  const VisitsPerDayPicker620({
    super.key,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final int value;
  final Color accent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(int n, String label) {
      final selected = value == n;
      return GestureDetector(
        key: Key('dates620_visits_$n'),
        onTap: () => onChanged(n),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: selected ? accent : AppColors.inputFill(context),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
                color: selected ? accent : accent.withValues(alpha: 0.3)),
          ),
          child: InterText(
            text: label,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.accentOn(context, accent),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: 'dates620_visits_title'.tr,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          children: [
            chip(1, 'dates620_visits_one'.tr),
            chip(2, 'dates620_visits_two'.tr),
          ],
        ),
      ],
    );
  }
}

class EstimateLine620 extends StatelessWidget {
  const EstimateLine620({
    super.key,
    required this.estimate,
    required this.loading,
    required this.tbd,
    required this.accent,
  });

  final PricingEstimate620? estimate;
  final bool loading;
  final bool tbd;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final String text = loading && estimate == null && !tbd
        ? 'dates620_estimate_loading'.tr
        : estimateText620(estimate, tbd: tbd);
    if (text.isEmpty) return const SizedBox.shrink();
    final on = AppColors.accentOn(context, accent);
    return Container(
      key: const Key('dates620_estimate'),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate_rounded, size: 16.sp, color: on),
          SizedBox(width: 8.w),
          Expanded(
            child: InterText(
              text: text,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: on,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class TbdHint620 extends StatelessWidget {
  const TbdHint620({super.key, required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final on = AppColors.accentOn(context, accent);
    return Container(
      key: const Key('dates620_tbd_hint'),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, size: 18.sp, color: on),
          SizedBox(width: 8.w),
          Expanded(
            child: InterText(
              text: 'dates620_tbd_hint'.tr,
              fontSize: 12.sp,
              color: AppColors.textPrimary(context),
              maxLines: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class TargetProviderBanner620 extends StatelessWidget {
  const TargetProviderBanner620({super.key, required this.provider});
  final TargetProvider620 provider;

  @override
  Widget build(BuildContext context) {
    final Color tone = provider.role == 'walker'
        ? const Color(0xFF16A34A)
        : const Color(0xFF2563EB);
    final on = AppColors.accentOn(context, tone);
    final name = provider.firstName;
    return Container(
      key: const Key('dates620_target_banner'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(
                provider.role == 'walker'
                    ? Icons.directions_walk_rounded
                    : Icons.home_rounded,
                size: 19.sp,
                color: Colors.white),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PoppinsText(
                  text: 'dates620_target_title'.tr.replaceAll('@name', name),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: on,
                  maxLines: 2,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: 'dates620_target_sub'.tr.replaceAll('@name', name),
                  fontSize: 11.5.sp,
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

/// « 12 €/visite » / « 18 €/jour » / « 10 €/balade » pour le tarif unitaire
/// d'un prestataire visé sur le service choisi (vide sans tarif).
String targetRateLabel620(TargetProvider620 p, String? service) {
  final r = p.rateFor(service);
  if (r == null) return '';
  return priceWithUnit620(
      CurrencyHelper.formatCompact(p.currency, r), ServiceCatalog620.unitFor(service));
}
