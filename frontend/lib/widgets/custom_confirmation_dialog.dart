// v569 — refonte visuelle du dialogue de confirmation le plus utilisé de
// l'app (déconnexion, suppression de compte, annulation de réservation,
// déblocage, suppression d'annonce…).
//
// DESIGN UNIQUEMENT : l'API publique est inchangée (mêmes paramètres, mêmes
// valeurs par défaut, `onYes` / `onCancel` appelés après le même `pop()`).
// Ce qui change : carte coins 24, disque teinté 56 px avec icône, titre
// centré, message gris centré, boutons pleine largeur empilés (principal
// plein, secondaire gris très clair), retour haptique quand l'action est
// destructive, et plus de `BackdropFilter` (coûteux, et interdit au-dessus
// de la carte Google Maps) → simple voile sombre.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

class CustomConfirmationDialog extends StatelessWidget {
  final String message;
  final String yesText;
  final String cancelText;
  final VoidCallback onYes;
  final VoidCallback? onCancel;
  final Color? yesButtonColor;
  final Color? cancelButtonColor;

  const CustomConfirmationDialog({
    super.key,
    required this.message,
    this.yesText = 'Yes',
    this.cancelText = 'Cancel',
    required this.onYes,
    this.onCancel,
    this.yesButtonColor,
    this.cancelButtonColor,
  });

  /// Une couleur « rouge » demandée pour le bouton principal = action
  /// destructive → disque rouge, icône d'alerte et retour haptique.
  static bool _isDestructive(Color? c) {
    if (c == null) return false;
    final hsl = HSLColor.fromColor(c);
    if (hsl.saturation < 0.35 || hsl.lightness > 0.72) return false;
    return hsl.hue <= 18 || hsl.hue >= 342;
  }

  /// Texte lisible sur n'importe quel fond de bouton (certains appelants
  /// passent un fond clair : on ne peut pas forcer du blanc).
  static Color _onColor(Color background) =>
      background.computeLuminance() > 0.6
          ? const Color(0xFF201613)
          : AppColors.whiteColor;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool destructive = _isDestructive(yesButtonColor);

    final Color primaryBg = yesButtonColor ?? AppColors.primaryColor;
    final Color secondaryBg = cancelButtonColor ??
        (dark ? const Color(0xFF342420) : const Color(0xFFF6F1EF));

    // Teinte du disque : rouge si destructif, sinon la couleur de marque du
    // rôle courant (un fond clair passé par l'appelant serait invisible).
    final Color tint = destructive
        ? AppColors.errorColor
        : (yesButtonColor != null &&
                yesButtonColor!.computeLuminance() <= 0.6
            ? yesButtonColor!
            : AppColors.activeRoleAccent());

    return Material(
      color: Colors.transparent,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: dark ? 0.62 : 0.38),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 360.w),
              child: Container(
                padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 18.h),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(24.r),
                  border: dark
                      ? Border.all(color: AppColors.dividerDark, width: 1)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow(dark ? 0.5 : 0.16),
                      blurRadius: 28,
                      spreadRadius: -8,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Disque teinté + icône selon la nature de l'action.
                    Container(
                      width: 56.w,
                      height: 56.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: dark ? 0.22 : 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        destructive
                            ? Icons.warning_amber_rounded
                            : Icons.help_outline_rounded,
                        color: tint,
                        size: 28.sp,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    PoppinsText(
                      text: 'misc569_confirm_title'.tr,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8.h),
                    InterText(
                      text: message,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                      color: AppColors.textSecondary(context),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 22.h),
                    // Bouton principal — pleine largeur, 50 de haut, coins 14.
                    CustomButton(
                      width: double.infinity,
                      height: 50.h,
                      radius: 14.r,
                      title: yesText,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      bgColor: primaryBg,
                      textColor: _onColor(primaryBg),
                      onTap: () {
                        if (destructive) HapticFeedback.mediumImpact();
                        Navigator.of(context).pop();
                        onYes();
                      },
                    ),
                    SizedBox(height: 10.h),
                    // Bouton secondaire — fond gris très clair, sans bordure.
                    CustomButton(
                      width: double.infinity,
                      height: 50.h,
                      radius: 14.r,
                      title: cancelText,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      bgColor: secondaryBg,
                      textColor: _onColor(secondaryBg),
                      onTap: () {
                        Navigator.of(context).pop();
                        onCancel?.call();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void show({
    required BuildContext context,
    required String message,
    String yesText = 'Yes',
    String cancelText = 'Cancel',
    required VoidCallback onYes,
    VoidCallback? onCancel,
    Color? yesButtonColor,
    Color? cancelButtonColor,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomConfirmationDialog(
        message: message,
        yesText: yesText,
        cancelText: cancelText,
        onYes: onYes,
        onCancel: onCancel,
        yesButtonColor: yesButtonColor,
        cancelButtonColor: cancelButtonColor,
      ),
    );
  }
}
