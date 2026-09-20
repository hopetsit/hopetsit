// v571 — Kit « vraiment rien à afficher » des accueils prestataires.
//
// Daniel : « quand il n'y a pas d'annonce, l'écran est triste » (icône boîte
// grise + « Aucune publication disponible » + « Rafraîchir » en rouge). Ce kit
// le remplace par un état vide accueillant : le logo PawMap qui respire, un
// titre chaleureux, une phrase qui rassure, puis 3 cartes d'action utiles et un
// bouton « Rafraîchir » à la couleur du rôle.
//
// Les widgets sont PUBLICS et paramétrés par la couleur d'accent : l'accueil
// gardien (bleu), promeneur (vert) et, le cas échéant, propriétaire (orange)
// peuvent tous s'en servir. Aucune navigation ici — tout passe par callbacks,
// pour que le kit reste testable et réutilisable.
//
// ⚠️ Le kit ne défile PAS tout seul : il s'insère dans le scroll de l'écran
// appelant, qui porte déjà le dégagement du menu flottant du bas
// (`110.h + appBottomInset(context)` sur l'accueil gardien/promeneur).
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart' show PawGlyph;

/// Illustration de l'état vide : le logo PawMap posé dans un halo teinté à
/// l'accent du rôle, avec une douce animation de respiration.
class HomeEmptyIllustration extends StatefulWidget {
  const HomeEmptyIllustration({
    super.key,
    required this.accent,
    this.size = 116,
  });

  final Color accent;

  /// Diamètre du halo (en dp logiques, passé tel quel — l'appelant décide s'il
  /// veut le multiplier par `.w`).
  final double size;

  @override
  State<HomeEmptyIllustration> createState() => _HomeEmptyIllustrationState();
}

class _HomeEmptyIllustrationState extends State<HomeEmptyIllustration>
    with SingleTickerProviderStateMixin {
  // v571 — Daniel : « la patte un peu animée, mais classe ». Une seule boucle
  // lente (5,2 s) pilote tout : deux ondes « je cherche autour de toi » qui
  // partent de l'épingle, une respiration douce, et les 4 doigts qui se
  // rangent puis ressortent l'un après l'autre une fois par cycle.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  /// Progression d'un doigt (0 rangé → 1 sorti) à l'instant [t] du cycle.
  static double _toe(double t, int i) {
    const double inStart = 0.02, inLen = 0.08; // les 4 rentrent ensemble
    final double outStart = 0.14 + 0.07 * i; // puis ressortent en cascade
    const double outLen = 0.16;
    if (t < inStart) return 1;
    if (t < inStart + inLen) {
      return 1 - Curves.easeInCubic.transform((t - inStart) / inLen);
    }
    if (t < outStart) return 0;
    if (t < outStart + outLen) {
      return Curves.easeOutBack.transform((t - outStart) / outLen);
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _loop,
        builder: (BuildContext context, Widget? _) {
          final double t = _loop.value;
          // Respiration : 2 allers-retours par cycle, amplitude discrète.
          final double breath = 0.5 - 0.5 * math.cos(t * 4 * math.pi);
          final List<double> toes =
              List<double>.generate(4, (int i) => _toe(t, i));
          return SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Halo de fond.
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        widget.accent.withValues(alpha: 0.10 + 0.06 * breath),
                        widget.accent.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                ),
                // Deux ondes décalées d'un demi-cycle.
                for (final double phase in const <double>[0.0, 0.5])
                  _ring(size, (t * 2 + phase) % 1.0),
                Transform.scale(
                  scale: 1.0 + 0.035 * breath,
                  child: PawGlyph(
                    size: size * 0.52,
                    toeProgress: toes,
                    toeOpacity: toes,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _ring(double size, double p) {
    final double eased = Curves.easeOutCubic.transform(p);
    final double d = size * (0.42 + 0.58 * eased);
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.accent.withValues(alpha: 0.30 * (1 - p)),
          width: 1.4,
        ),
      ),
    );
  }
}

/// Carte d'action de l'état vide : icône dans un rond teinté, titre,
/// sous-titre, chevron.
class HomeEmptyActionCard extends StatelessWidget {
  const HomeEmptyActionCard({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18.r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: AppColors.divider(context).withValues(alpha: 0.8),
                width: 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38.w,
                  height: 38.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(icon, size: 19.sp, color: accent),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PoppinsText(
                        text: title,
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      InterText(
                        text: subtitle,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18.sp,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// État vide complet des accueils prestataires.
///
/// Les 3 cartes sont optionnelles : une action sans callback n'est pas
/// affichée (l'accueil propriétaire, par exemple, n'a pas de « Mets-toi en
/// avant » au même endroit).
class HomeEmptyKit extends StatelessWidget {
  const HomeEmptyKit({
    super.key,
    required this.accent,
    required this.onRefresh,
    this.onCompleteProfile,
    this.onInvite,
    this.onBoost,
    this.title,
    this.body,
  });

  final Color accent;
  final VoidCallback onRefresh;
  final VoidCallback? onCompleteProfile;
  final VoidCallback? onInvite;
  final VoidCallback? onBoost;

  /// Titre / texte personnalisés (par défaut : les clés `home571_empty_*`).
  final String? title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(child: HomeEmptyIllustration(accent: accent, size: 116.w)),
          SizedBox(height: 16.h),
          PoppinsText(
            text: title ?? 'home571_empty_title'.tr,
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
            textAlign: TextAlign.center,
            maxLines: 3,
          ),
          SizedBox(height: 6.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: InterText(
              text: body ?? 'home571_empty_body'.tr,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary(context),
              textAlign: TextAlign.center,
              maxLines: 4,
            ),
          ),
          SizedBox(height: 18.h),
          if (onCompleteProfile != null)
            HomeEmptyActionCard(
              key: const ValueKey<String>('home_empty_profile'),
              accent: accent,
              icon: Icons.person_rounded,
              title: 'home571_card_profile_title'.tr,
              subtitle: 'home571_card_profile_sub'.tr,
              onTap: onCompleteProfile!,
            ),
          if (onInvite != null)
            HomeEmptyActionCard(
              key: const ValueKey<String>('home_empty_invite'),
              accent: accent,
              icon: Icons.person_add_alt_1_rounded,
              title: 'home571_card_invite_title'.tr,
              subtitle: 'home571_card_invite_sub'.tr,
              onTap: onInvite!,
            ),
          if (onBoost != null)
            HomeEmptyActionCard(
              key: const ValueKey<String>('home_empty_boost'),
              accent: accent,
              icon: Icons.rocket_launch_rounded,
              title: 'home571_card_boost_title'.tr,
              subtitle: 'home571_card_boost_sub'.tr,
              onTap: onBoost!,
            ),
          SizedBox(height: 8.h),
          Center(
            child: TextButton.icon(
              key: const ValueKey<String>('home_empty_refresh'),
              onPressed: onRefresh,
              icon: Icon(Icons.refresh_rounded, color: accent, size: 18.sp),
              label: Text(
                'common_refresh'.tr,
                style: TextStyle(
                  color: accent,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte-info « Rien dans un rayon de {km} km » + bouton « Élargir à {km} km ».
///
/// Affichée en tête de la section « Les plus proches de toi » quand le filtre
/// distance ne laisse rien mais qu'il existe des annonces plus loin.
class HomeRadiusHintCard extends StatelessWidget {
  const HomeRadiusHintCard({
    super.key,
    required this.accent,
    required this.currentKm,
    required this.suggestedKm,
    this.onExpand,
  });

  final Color accent;

  /// Rayon courant (celui qui ne donne rien).
  final int currentKm;

  /// Rayon proposé : la plus petite valeur (arrondie au 10 km supérieur,
  /// bornée au max) qui inclut l'annonce la plus proche.
  final int suggestedKm;

  /// null quand le rayon est déjà au maximum : la carte reste informative,
  /// sans bouton qui ne changerait rien.
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 12.w, 12.h),
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: accent.withValues(alpha: 0.20), width: 1),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.explore_rounded, size: 20.sp, color: accent),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PoppinsText(
                  text: 'home571_nothing_within'
                      .tr
                      .replaceAll('{km}', '$currentKm'),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 2,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: 'home571_nothing_within_sub'.tr,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary(context),
                  maxLines: 3,
                ),
                if (onExpand != null) ...<Widget>[
                SizedBox(height: 8.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Material(
                    color: accent,
                    borderRadius: BorderRadius.circular(999.r),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: const ValueKey<String>('home_expand_radius'),
                      onTap: onExpand,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 8.h,
                        ),
                        child: InterText(
                          text: 'home571_expand_to'
                              .tr
                              .replaceAll('{km}', '$suggestedKm'),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille « à 82 km » posée au-dessus d'une carte d'annonce hors rayon.
class HomeDistancePill extends StatelessWidget {
  const HomeDistancePill({
    super.key,
    required this.accent,
    required this.km,
  });

  final Color accent;
  final int km;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h, left: 2.w),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999.r),
            border: Border.all(
              color: accent.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.near_me_rounded, size: 12.sp, color: accent),
              SizedBox(width: 5.w),
              InterText(
                text: 'home571_distance_away'.tr.replaceAll('{km}', '$km'),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
