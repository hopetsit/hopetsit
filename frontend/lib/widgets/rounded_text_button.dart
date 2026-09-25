import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';

/// Bouton principal de l'app — MÊME API qu'avant (34 fichiers : connexion,
/// inscription, mot de passe, réservation, paiement, code promo, dialogues…).
///
/// v585 (lot D) — rendu par le kit « signature HoPetSit »
/// (`widgets/paw_button_kit.dart`, NORME_DESIGN.md) : dégradé HORIZONTAL de
/// la couleur, reflet verre, empreinte de patte au toucher, libellé jamais
/// coupé (2 lignes puis réduction), désactivé en teinte pâle pleine.
/// `borderColor` sur fond clair = bouton secondaire (contour). `child` =
/// contenu libre posé dans la coque. Aucune action ne change.
class CustomButton extends StatelessWidget {
  final Widget? child;
  final String? title;
  final bool isGradient;
  final Color? bgColor;
  final Color? textColor;
  final Color? borderColor;
  final FontWeight? fontWeight;
  final double? fontSize;
  final double? radius;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  /// v584 (25/09, point 6) — chargement : UN seul petit rond dans le disque
  /// du bouton (le libellé reste). Avant, les dialogues posaient leur propre
  /// roue en `child` pendant que le kit en dessinait une autre → deux roues.
  final bool isLoading;

  const CustomButton({
    super.key,
    this.child,
    this.title,
    this.isGradient = false,
    this.bgColor,
    this.textColor,
    this.borderColor,
    this.fontWeight,
    this.fontSize,
    this.radius,
    this.width,
    this.height,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    final Color base = bgColor ?? AppColors.primaryColor;

    // Fond clair / transparent + bordure = bouton « contour » (secondaire).
    final bool outlined = borderColor != null &&
        !isGradient &&
        (base.a < 0.05 || base.computeLuminance() > 0.85);

    // Contenu libre : on garde exactement ce que l'écran a construit.
    final Widget? custom = child;

    final Widget button = PawButton(
      label: title ?? '',
      onTap: onTap,
      color: outlined ? (borderColor ?? base) : base,
      kind: outlined ? PawButtonKind.secondary : PawButtonKind.primary,
      enabled: enabled || isLoading,
      loading: isLoading,
      expand: width == null || width == double.infinity,
      height: height ?? 52.h,
      textColor: outlined ? null : textColor,
      child: custom == null
          ? null
          : DefaultTextStyle.merge(
              style: TextStyle(color: textColor ?? (outlined ? (borderColor ?? base) : Colors.white)),
              child: IconTheme.merge(
                data: IconThemeData(color: textColor ?? (outlined ? (borderColor ?? base) : Colors.white)),
                child: custom,
              ),
            ),
    );
    if (width != null && width != double.infinity) {
      return SizedBox(width: width, child: button);
    }
    return button;
  }
}
