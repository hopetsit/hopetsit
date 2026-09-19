import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Bouton principal de l'app.
///
/// v569 — Daniel : « tous les boutons de l'ancien style doivent être
/// modernisés ». Même API qu'avant (19 écrans l'utilisent : connexion,
/// inscription, mot de passe, réservation, paiement, code promo, dialogues…),
/// seul le rendu change : dégradé vertical doux, coins 16, ombre colorée
/// diffuse, onde au toucher bien découpée, léger enfoncement à l'appui,
/// retour haptique, état désactivé lisible, variante « contour » quand une
/// bordure est demandée sur fond clair.
class CustomButton extends StatefulWidget {
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
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    final Color base = widget.bgColor ?? AppColors.primaryColor;
    final double r = widget.radius ?? 16.0.r;
    final BorderRadius br = BorderRadius.circular(r);

    // Fond clair / transparent + bordure = bouton « contour » (secondaire).
    final bool outlined = widget.borderColor != null &&
        !widget.isGradient &&
        (base.a < 0.05 || base.computeLuminance() > 0.85);

    final Gradient? gradient = outlined
        ? null
        : widget.isGradient
            ? AppColors.linearGradient
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(base, Colors.white, 0.10)!,
                  Color.lerp(base, Colors.black, 0.06)!,
                ],
              );

    final Color fg = widget.textColor ??
        (outlined ? (widget.borderColor ?? base) : Colors.white);

    return AnimatedScale(
      scale: _pressed && enabled ? 0.975 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.55,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: widget.height ?? 52.h,
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            borderRadius: br,
            boxShadow: enabled && !outlined
                ? [
                    BoxShadow(
                      color: base.withValues(alpha: _pressed ? 0.16 : 0.28),
                      blurRadius: _pressed ? 8 : 16,
                      spreadRadius: -2,
                      offset: Offset(0, _pressed ? 3 : 8),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: outlined ? base : Colors.transparent,
            borderRadius: br,
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: br,
                border: widget.borderColor != null
                    ? Border.all(color: widget.borderColor!, width: 1.4)
                    : null,
              ),
              child: InkWell(
                borderRadius: br,
                splashColor: fg.withValues(alpha: 0.16),
                highlightColor: fg.withValues(alpha: 0.06),
                onTapDown: enabled ? (_) => _setPressed(true) : null,
                onTapCancel: enabled ? () => _setPressed(false) : null,
                onTap: enabled
                    ? () {
                        _setPressed(false);
                        HapticFeedback.selectionClick();
                        widget.onTap!();
                      }
                    : null,
                child: Center(
                  child: widget.child ??
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: InterText(
                            text: widget.title ?? '',
                            fontSize: widget.fontSize ?? 16,
                            fontWeight: widget.fontWeight ?? FontWeight.w700,
                            color: fg,
                          ),
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
