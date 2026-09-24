// v584 — lot C : boutons « signature HoPetSit » de la PawMap et de ses
// feuilles (NORME_DESIGN.md, validée par Daniel le 23/09).
//   · principal  : dégradé HORIZONTAL du rôle, reflet verre (moitié haute plus
//     claire), disque blanc à gauche avec l'icône à la couleur du rôle, texte
//     blanc, 56 px, coins 18, le prix DANS le bouton quand il y en a un ;
//   · secondaire : fond blanc (surface en sombre), contour 1,5 px couleur du
//     rôle, petit disque teinté avec l'icône, texte dans le foncé du rôle,
//     48 px, coins 16 ;
//   · lien       : texte couleur du rôle, sans cadre.
// États : appui 0,97 + vibration légère, chargement = petit rond DANS le
// bouton (libellé conservé), désactivé = teinte pâle PLEINE (jamais gris).
// ⛔ Le libellé n'est JAMAIS coupé : il passe sur 2 lignes puis se réduit
// (FittedBox), jamais « … ».
//
// Ces boutons ne changent aucune action : ils habillent. Habillage seul.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../utils/pawmap_theme.dart';

/// Dégradés horizontaux validés (les mêmes que le menu du bas).
LinearGradient pawRoleGradient(Color role) {
  final Color a = Color.lerp(role, Colors.white, 0.10)!;
  final Color b = Color.lerp(role, Colors.black, 0.16)!;
  return LinearGradient(
    colors: [a, b],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

/// Coupe un libellé en deux lignes à l'espace le plus central (jamais au
/// milieu d'un mot). Sans espace : une ligne, réduite par le FittedBox.
String pawTwoLines(String s) {
  final t = s.trim();
  if (t.length < 16) return t;
  final mid = t.length ~/ 2;
  int best = -1;
  for (int i = 0; i < t.length; i++) {
    if (t[i] == ' ' && (best < 0 || (i - mid).abs() < (best - mid).abs())) {
      best = i;
    }
  }
  if (best < 0) return t;
  return '${t.substring(0, best)}\n${t.substring(best + 1)}';
}

enum PawButtonKind { primary, secondary, link }

class PawSignatureButton extends StatefulWidget {
  const PawSignatureButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.color,
    this.icon,
    this.kind = PawButtonKind.primary,
    this.price,
    this.loading = false,
    this.enabled = true,
    this.disabledReason,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;
  final PawButtonKind kind;

  /// « Réserver Léa · 25 € » : le prix vit DANS le bouton.
  final String? price;
  final bool loading;
  final bool enabled;

  /// Message affiché quand on appuie sur un bouton désactivé.
  final String? disabledReason;
  final bool expand;

  @override
  State<PawSignatureButton> createState() => _PawSignatureButtonState();
}

class _PawSignatureButtonState extends State<PawSignatureButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = PawMapTheme.isDark(context);
    final Color role = widget.color;
    final Color dark = Color.lerp(role, Colors.black, 0.30)!;
    final bool active = widget.enabled && !widget.loading;
    final String text = widget.price == null || widget.price!.isEmpty
        ? widget.label
        : '${widget.label} · ${widget.price}';
    final bool primary = widget.kind == PawButtonKind.primary;
    final bool link = widget.kind == PawButtonKind.link;
    final double h = link ? 40.h : (primary ? 56.h : 48.h);
    final double radius = primary ? 18.r : 16.r;
    // Désactivé : teinte du rôle PÂLE et PLEINE, texte dans le foncé.
    final Color paleFill = Color.lerp(role, Colors.white, 0.82)!;
    final Color fg = link
        ? (isDark ? PawMapTheme.lighten(role, 0.25) : dark)
        : primary
            ? (active ? Colors.white : dark)
            : (isDark ? PawMapTheme.lighten(role, 0.25) : dark);

    Widget content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null && !link) ...[
          Container(
            width: primary ? 34.w : 28.w,
            height: primary ? 34.w : 28.w,
            decoration: BoxDecoration(
              color: primary
                  ? Colors.white
                  : role.withValues(alpha: isDark ? 0.24 : 0.12),
              shape: BoxShape.circle,
            ),
            child: widget.loading
                ? Padding(
                    padding: EdgeInsets.all(primary ? 8.w : 6.w),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: primary ? role : fg,
                    ),
                  )
                : Icon(widget.icon,
                    size: primary ? 19.sp : 16.sp,
                    color: primary ? (active ? role : dark) : fg),
          ),
          SizedBox(width: 10.w),
        ] else if (widget.icon != null && link) ...[
          Icon(widget.icon, size: 16.sp, color: fg),
          SizedBox(width: 6.w),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              pawTwoLines(text),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: primary ? 15.sp : 14.sp,
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: fg,
              ),
            ),
          ),
        ),
      ],
    );

    final Decoration deco = link
        ? const BoxDecoration()
        : primary
            ? BoxDecoration(
                gradient: active ? pawRoleGradient(role) : null,
                color: active ? null : paleFill,
                borderRadius: BorderRadius.circular(radius),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: role.withValues(alpha: 0.32),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              )
            : BoxDecoration(
                color: active
                    ? PawMapTheme.panelOn(context)
                    : paleFill.withValues(alpha: isDark ? 0.35 : 1),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: active
                      ? (isDark ? PawMapTheme.lighten(role, 0.2) : role)
                      : paleFill,
                  width: 1.5,
                ),
              );

    Widget box = Container(
      height: h,
      width: widget.expand ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: link ? 6.w : 14.w),
      decoration: deco,
      child: Stack(
        children: [
          // Reflet verre : moitié haute plus claire (principal actif).
          if (primary && active)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: h / 2,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(radius)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Center(child: content),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: active,
      label: text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: active ? (_) => _set(true) : null,
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: () {
          if (widget.loading) return;
          if (!widget.enabled) {
            final why = widget.disabledReason;
            if (why != null && why.isNotEmpty) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text(why)),
              );
            }
            return;
          }
          HapticFeedback.selectionClick();
          widget.onTap?.call();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: box,
        ),
      ),
    );
  }
}

/// Pastille d'information (« Identité vérifiée », « Disponible aujourd'hui »,
/// « Mis en avant ») : teinte PLEINE, jamais de gris.
class PawInfoChip extends StatelessWidget {
  const PawInfoChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bool isDark = PawMapTheme.isDark(context);
    final Color fg = isDark ? PawMapTheme.lighten(color, 0.35) : Color.lerp(color, Colors.black, 0.25)!;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13.sp, color: fg),
            SizedBox(width: 4.w),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
