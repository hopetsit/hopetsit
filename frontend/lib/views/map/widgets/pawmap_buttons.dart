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
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../utils/pawmap_theme.dart';
import '../../../widgets/paw_button_kit.dart';

// v585 (lot D) — le kit de TOUTE l'app vit dans `widgets/paw_button_kit.dart` ;
// ces noms restent exportés pour la PawMap et ses tests.
export '../../../widgets/paw_button_kit.dart'
    show PawButtonKind, PawButtonAction, pawRoleGradient, pawTwoLines;

/// Bouton signature de la PawMap (lot C) : même API, rendu par [PawButton].
class PawSignatureButton extends StatelessWidget {
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
    this.action = PawButtonAction.none,
    this.earns = false,
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
  final PawButtonAction action;
  final bool earns;

  @override
  Widget build(BuildContext context) {
    return PawButton(
      label: label,
      onTap: onTap,
      color: color,
      icon: icon,
      kind: kind,
      price: price,
      loading: loading,
      enabled: enabled,
      disabledReason: disabledReason,
      expand: expand,
      action: action,
      earns: earns,
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
