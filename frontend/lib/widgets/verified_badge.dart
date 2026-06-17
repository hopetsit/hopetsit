import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// v23.1 part 36 — badge "✓ Vérifié" affiche a cote du nom des
/// sitters/walkers dont kycStatus == 'verified' (passeport ou CNI verifie
/// via Persona).
///
/// v23.1 part 247 — Daniel : "met un badge jolie et verifie les
/// traductions". Refonte design :
///   - Gradient bleu (Material Blue 600 → 800) au lieu d'un flat color
///   - Ombre subtile (shadowBlur 6, opacity 30%)
///   - Icone verified_rounded blanche dans un fond gradient
///   - Texte "Verifie" 100% i18n via la cle kyc_badge_verified
///   - Variante `large` plus visible pour les profile screens
///
/// Variants :
/// - `inline` (default) : petit badge (juste icone) a cote d'un nom
/// - `large` : icone + texte i18n pour le profil
class VerifiedBadge extends StatelessWidget {
  /// Si false, le widget ne render rien (utilise conditionnellement).
  final bool isVerified;
  final bool large;
  final String? tooltipText;

  const VerifiedBadge({
    super.key,
    required this.isVerified,
    this.large = false,
    this.tooltipText,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();
    // v449 — Daniel : le badge vérifié un peu PLUS GROS + VERT (plus bleu), et
    // UNIQUEMENT sur les profils qui ont payé la vérification (3€) → géré par
    // `isVerified` que l'appelant doit câbler sur le VRAI flag (kycStatus ==
    // 'verified'), pas en dur.
    final iconSize = large ? 20.sp : 17.sp;
    final padding = large
        ? EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h)
        : EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h);

    // Palette VERTE confiance (green 700 -> 500) — gradient premium, lisible en
    // dark mode.
    const c1 = Color(0xFF15803D); // Green 700
    const c2 = Color(0xFF22C55E); // Green 500

    final widget = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [c1, c2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: c1.withValues(alpha: 0.30),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            size: iconSize,
            color: Colors.white,
          ),
          if (large) ...[
            SizedBox(width: 5.w),
            Text(
              // v23.1 part 247 — i18n via cle dediee kyc_badge_verified.
              // Existe en fr/en/es/de/it/pt.
              'kyc_badge_verified'.tr,
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
    if (tooltipText != null && tooltipText!.isNotEmpty) {
      return Tooltip(message: tooltipText!, child: widget);
    }
    // Default tooltip i18n si pas overrride manuellement.
    return Tooltip(
      message: 'kyc_badge_verified_tooltip'.tr,
      child: widget,
    );
  }
}
