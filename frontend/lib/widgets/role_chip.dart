// v569 — Daniel : « dans Accueil et Chat, en haut, le rôle modernisé à côté du
// nom ». Pastille unique pour les 3 rôles : pilule teintée, icône du rôle,
// liseré fin, libellé court qui ne déborde jamais.
//
// v576 — Daniel : « les petits boutons titre de rôle, erreur de traduction, à
// moderniser ». Deux défauts traités ici :
//   1. TROIS jeux de libellés cohabitaient — `role_owner/role_sitter/
//      role_walker` (cette pastille, « Petsitter » en français = franglais),
//      `role_pet_owner/role_pet_sitter/role_pet_walker` (variante LOCALE de
//      l'en-tête de profil) et `card_role_sitter` (cartes). Un seul jeu fait
//      désormais foi : `roleLabelKey()` → `fixes576_role_*`, 9 langues, sans
//      franglais (fr : Propriétaire · Gardien · Promeneur).
//   2. L'en-tête de profil redessinait sa propre pastille. Elle passe par ce
//      widget, avec la variante [RoleChipVariant.glass] (fond translucide +
//      logo) prévue pour les bandeaux en dégradé.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';

/// Rendu de la pastille.
enum RoleChipVariant {
  /// Pilule teintée de la couleur du rôle, sur fond clair/sombre.
  tinted,

  /// Pilule « verre » blanche + logo de l'app, pour un bandeau en dégradé.
  glass,
}

/// Clé i18n du libellé d'un rôle. UNE seule source pour toute l'app.
/// 'owner' | 'sitter' | 'walker' (insensible à la casse) ; toute autre valeur
/// est traitée comme propriétaire (comportement historique).
String roleLabelKey(String role) {
  switch (role.trim().toLowerCase()) {
    case 'walker':
      return 'fixes576_role_walker';
    case 'sitter':
      return 'fixes576_role_sitter';
    default:
      return 'fixes576_role_owner';
  }
}

/// Couleur d'accent du rôle (même palette que les accueils).
Color roleAccentColor(String role) {
  switch (role.trim().toLowerCase()) {
    case 'walker':
      return AppColors.walkerAccent;
    case 'sitter':
      return AppColors.sitterAccent;
    default:
      return AppColors.primaryColor;
  }
}

/// Icône du rôle.
IconData roleIconData(String role) {
  switch (role.trim().toLowerCase()) {
    case 'walker':
      return Icons.directions_walk_rounded;
    case 'sitter':
      return Icons.home_rounded;
    default:
      return Icons.pets_rounded;
  }
}

class RoleChip extends StatelessWidget {
  const RoleChip({
    super.key,
    required this.role,
    this.compact = false,
    this.variant = RoleChipVariant.tinted,
  });

  /// 'owner' | 'sitter' | 'walker' (insensible à la casse).
  final String role;

  /// Version serrée pour les barres de titre étroites.
  final bool compact;

  /// Rendu — teinté (défaut) ou « verre » sur un bandeau en dégradé.
  final RoleChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final lower = role.trim().toLowerCase();
    if (lower.isEmpty) return const SizedBox.shrink();
    final Color color = roleAccentColor(lower);
    final IconData icon = roleIconData(lower);
    final String label = roleLabelKey(lower).tr;

    if (variant == RoleChipVariant.glass) {
      return Container(
        padding: EdgeInsets.fromLTRB(6.w, 5.h, 13.w, 5.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.30), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: Image.asset(
                'assets/brand/png/ic_launcher.png',
                width: 22.w,
                height: 22.w,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(icon, size: 16.sp, color: Colors.white),
              ),
            ),
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7.w : 9.w,
        vertical: compact ? 2.5.h : 3.5.h,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 10.sp : 11.sp, color: color),
          SizedBox(width: 3.5.w),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: compact ? 9.5.sp : 10.5.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
