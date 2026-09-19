// This file is kept for backward compatibility
// Import the main forgot password email screen instead
//
// v569 — il sert AUSSI de petite trousse visuelle commune aux 4 écrans du
// parcours « mot de passe oublié » (e-mail → code → nouveau mot de passe →
// succès), pour qu'ils partagent le même gabarit : barre sobre, pastille
// ronde teintée + icône, titre 26/800, sous-titre, carte de formulaire.
// RENDU SEULEMENT : aucun de ces éléments ne touche au contrôleur.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

export 'forgot_password_email_screen.dart' show ForgotPasswordEmailScreen;

/// Barre du haut commune : fond de page, pas d'ombre, titre discret (le vrai
/// titre de l'écran est dans le [ForgotFlowHeader]).
PreferredSizeWidget forgotFlowAppBar(BuildContext context, String title) {
  return AppBar(
    automaticallyImplyLeading: true,
    title: InterText(
      text: title,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary(context),
    ),
    centerTitle: true,
    backgroundColor: AppColors.scaffold(context),
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
  );
}

/// Pastille ronde teintée + icône, titre, sous-titre.
class ForgotFlowHeader extends StatelessWidget {
  const ForgotFlowHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Variante quand le sous-titre est réactif (Obx) ou composé.
  final Widget? subtitleWidget;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 62.w,
          height: 62.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryColor
                .withValues(alpha: isDark ? 0.18 : 0.10),
          ),
          child: Icon(icon, size: 30.sp, color: AppColors.primaryColor),
        ),
        SizedBox(height: 18.h),
        PoppinsText(
          text: title,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(context),
          maxLines: 2,
        ),
        if (subtitleWidget != null) ...[
          SizedBox(height: 8.h),
          subtitleWidget!,
        ] else if (subtitle != null) ...[
          SizedBox(height: 8.h),
          InterText(
            text: subtitle!,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary(context),
            maxLines: 4,
          ),
        ],
      ],
    );
  }
}

/// Carte blanche du parcours (mêmes coins et même ombre que la connexion).
class ForgotFlowCard extends StatelessWidget {
  const ForgotFlowCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : const Color(0xFFF1E8E0),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.primaryColor.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: child,
    );
  }
}
