// v569 — Daniel : « il y a un pop-up pour l'annulation 72 h, fais plus
// moderne ». Feuille du bas commune aux 3 rôles (remplace les AlertDialog).
// Mêmes clés de traduction qu'avant, même règle : gratuit et remboursé à plus
// de 72 h du début ; sinon information seule, sans bouton de confirmation.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Renvoie `true` si l'utilisateur confirme l'annulation (seulement possible
/// quand [canFree] est vrai).
Future<bool> showCancel72hSheet({required bool canFree}) async {
  final res = await Get.bottomSheet<bool>(
    _Cancel72hSheet(canFree: canFree),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
  return res == true;
}

class _Cancel72hSheet extends StatelessWidget {
  const _Cancel72hSheet({required this.canFree});

  final bool canFree;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFDC2626);
    const amber = Color(0xFFE8920A);
    final tone = canFree ? red : amber;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Une feuille modale ne protège jamais son bas : inset ajouté ici.
      padding: EdgeInsets.fromLTRB(
          20.w, 10.h, 20.w, 18.h + appBottomInset(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider(context),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(height: 20.h),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tone.withValues(alpha: 0.10),
              border: Border.all(color: tone.withValues(alpha: 0.25)),
            ),
            child: Icon(
              canFree ? Icons.event_busy_rounded : Icons.lock_clock_rounded,
              color: tone,
              size: 30,
            ),
          ),
          SizedBox(height: 14.h),
          PoppinsText(
            text: 'cancel_72h_dialog_title'.tr,
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          InterText(
            text: canFree
                ? 'cancel_72h_dialog_message'.tr
                : 'cancel_72h_closed_message'.tr,
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary(context),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 22.h),
          if (canFree) ...[
            _SheetButton(
              label: 'cancel_72h_dialog_confirm'.tr,
              background: red,
              foreground: Colors.white,
              onTap: () {
                HapticFeedback.mediumImpact();
                Get.back(result: true);
              },
            ),
            SizedBox(height: 10.h),
          ],
          _SheetButton(
            label: canFree ? 'common_cancel'.tr : 'common_ok'.tr,
            background: AppColors.textPrimary(context).withValues(alpha: 0.06),
            foreground: AppColors.textPrimary(context),
            onTap: () => Get.back(result: false),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: InterText(
                  text: label,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
