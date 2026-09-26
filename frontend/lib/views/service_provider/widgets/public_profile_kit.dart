// v573 — kit d'interface des FICHES DE PROFIL PUBLIC.
//
// Daniel : « quand les gardiens, promeneurs ou propriétaires regardent le
// profil de la personne depuis une annonce, ces pages doivent être
// modernisées » — au même niveau que les accueils et les réservations refaits
// aux builds 569-571. Puis, capture à l'appui sur la fiche gardien : « c'est la
// vieille page, le design d'avant, pas possible ».
//
// Ce fichier ne contient QUE du rendu : widgets publics, paramétrés par la
// couleur du rôle regardé, sans aucune dépendance à un State, un contrôleur ou
// un modèle. Les 3 écrans (gardien / promeneur / propriétaire) s'en servent
// pour avoir exactement la même structure visuelle :
//
//   en-tête héro (bandeau dégradé + avatar cerclé de blanc)
//   → rangée de 3 tuiles de statistiques
//   → sections en cartes (coins 20, titre avec icône dans un rond teinté)
//   → barre d'action collante en bas.
//
// Règles tenues ici :
//   · ⚠️ AUCUNE image de repli « catalogue » (`AppImages.placeholderImage`) :
//     sans photo, l'avatar affiche l'initiale sur un aplat à la couleur du
//     rôle. Daniel voyait un visuel marketing en pleine largeur en guise de
//     couverture — il n'y a plus de couverture photo du tout.
//   · mode sombre : aucune couleur de texte / de fond en dur, tout passe par
//     `AppColors.*(context)` et `AppColors.accentOn(context, c)` quand une
//     couleur de marque sert de texte. Le blanc sur le bandeau dégradé est
//     légitime (fond toujours foncé).
//   · 320 dp : chaque texte est `Flexible` + `ellipsis` ou `FittedBox`, les
//     pastilles passent par un `Wrap` — aucun débordement même en allemand ou
//     en polonais.
//   · barre du bas : dégagement `appBottomInset(context)` OBLIGATOIRE (barre
//     de navigation Samsung, cf. `lib/utils/bottom_inset.dart`).
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';
import 'package:hopetsit/widgets/role_chip.dart';

/// Rayon des cartes de section.
const double kPublicProfileRadius = 20;

/// v589 (26/09, Daniel : « moderniser, comme ça tout est HD ») — bandeau plus
/// haut et grande photo nette : mêmes valeurs pour l'en-tête et le squelette.
const double kPublicProfileBannerH = 128;
const double kPublicProfileAvatarD = 124;

bool _isDarkCtx(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Encre chaude des titres (jamais le noir pur ni un gris).
Color _inkOn(BuildContext context) => _isDarkCtx(context)
    ? AppColors.textPrimaryDark
    : const Color(0xFF17141F);

/// Liseré teinté à la couleur du rôle.
Color _tintBorder(BuildContext context, Color accent) =>
    accent.withValues(alpha: _isDarkCtx(context) ? 0.32 : 0.16);

/// Ombre teintée à la couleur du rôle (clair) / ombre chaude profonde (sombre).
List<BoxShadow> _tintShadow(BuildContext context, Color accent) =>
    _isDarkCtx(context)
        ? const <BoxShadow>[
            BoxShadow(
              color: Color(0x660B0706),
              blurRadius: 16,
              spreadRadius: -4,
              offset: Offset(0, 6),
            ),
          ]
        : <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 20,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.shadow(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ];

/// Définition de décodage d'une photo ronde : DEUX fois la taille affichée en
/// pixels réels (recadrage `cover` : même une photo paysage garde assez de
/// pixels), bornée 96–1600. Le cache ne l'agrandit jamais au-delà de
/// l'original.
int publicProfileDecodeWidth(BuildContext context, double logical) {
  final double dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3.0;
  return (logical * dpr * 2).round().clamp(96, 1600);
}

/// Palette d'une fiche publique : couleur d'accent (texte, icônes, prix) et
/// dégradé du bandeau héro / de la barre de titre.
class PublicProfilePalette {
  final Color accent;
  final List<Color> gradient;

  const PublicProfilePalette({required this.accent, required this.gradient});

  /// Première couleur du dégradé : sert de fond à l'AppBar pour que la barre
  /// de titre et le bandeau ne montrent aucune couture.
  Color get top => gradient.first;
}

/// Gardien — bleu.
const PublicProfilePalette kSitterProfilePalette = PublicProfilePalette(
  accent: AppColors.sitterAccent,
  gradient: <Color>[Color(0xFF2F6FD6), Color(0xFF1E4FB0)],
);

/// Promeneur — vert.
const PublicProfilePalette kWalkerProfilePalette = PublicProfilePalette(
  accent: AppColors.walkerAccent,
  gradient: <Color>[Color(0xFF2FAE4E), Color(0xFF15803D)],
);

/// Propriétaire — rouge de la marque.
const PublicProfilePalette kOwnerProfilePalette = PublicProfilePalette(
  accent: AppColors.ownerAccent,
  gradient: <Color>[AppColors.primaryColor, Color(0xFF8E1D0C)],
);

/// Dégagement bas du contenu défilant.
///
/// Avec une barre d'action collante, la barre porte déjà `appBottomInset` et
/// occupe sa propre place sous le défilement : il ne reste qu'une respiration.
/// Sans barre, le contenu doit lui-même dégager la barre système.
double publicProfileBottomPadding(
  BuildContext context, {
  bool hasActionBar = false,
}) =>
    hasActionBar ? 20.h : 24.h + appBottomInset(context);

/// Barre de titre d'une fiche publique : fond = haut du dégradé, titre et
/// icônes blancs, aucune ombre (le bandeau héro prend le relais juste en
/// dessous).
PreferredSizeWidget publicProfileAppBar({
  required PublicProfilePalette palette,
  required Widget title,
  List<Widget> actions = const <Widget>[],
}) {
  return AppBar(
    backgroundColor: palette.top,
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    iconTheme: const IconThemeData(color: Colors.white),
    title: title,
    titleSpacing: 4,
    actions: actions,
  );
}

/// Bouton rond translucide posé sur le bandeau (partage, signalement…).
class PublicProfileBannerAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const PublicProfileBannerAction({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: Material(
            color: Colors.white.withValues(alpha: 0.18),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 36.w,
                height: 36.w,
                child: Icon(icon, size: 18.sp, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar rond cerclé de blanc. Sans photo : initiale du nom sur un aplat à la
/// couleur du rôle (JAMAIS une image de catalogue).
class PublicProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final Color accent;
  final double diameter;

  /// v589 — anneau dégradé à la couleur du rôle (null = liseré blanc simple,
  /// comme avant : avatars des avis).
  final List<Color>? ringColors;

  /// Petit badge « vérifié » posé sur la photo (en plus de la pastille).
  final bool verified;

  const PublicProfileAvatar({
    super.key,
    required this.name,
    required this.accent,
    this.imageUrl,
    this.diameter = kPublicProfileAvatarD,
    this.ringColors,
    this.verified = false,
  });

  bool get _hasPhoto {
    final String url = (imageUrl ?? '').trim();
    return url.startsWith('http://') || url.startsWith('https://');
  }

  String get _initial {
    final String n = name.trim();
    if (n.isEmpty) return '';
    return n.substring(0, 1).toUpperCase();
  }

  Widget _fallback(BuildContext context) {
    final String letter = _initial;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: 0.12),
            accent.withValues(alpha: 0.26),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: letter.isEmpty
          ? Icon(
              Icons.person_rounded,
              size: (diameter * 0.46).sp,
              color: AppColors.accentOn(context, accent),
            )
          : PoppinsText(
              text: letter,
              fontSize: diameter * 0.34,
              fontWeight: FontWeight.w800,
              color: AppColors.accentOn(context, accent),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double d = diameter.r;
    final bool ring = ringColors != null && ringColors!.isNotEmpty;
    final double ringW = ring ? (diameter >= 90 ? 4.0 : 3.0).r : 0;
    final double gap = (diameter >= 90 ? 3.5 : 2.5).r;
    final double inner = d - 2 * (ringW + gap);
    final Widget photo = ClipOval(
      child: _hasPhoto
          ? CachedNetworkImage(
              imageUrl: imageUrl!.trim(),
              width: inner,
              height: inner,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              memCacheWidth: publicProfileDecodeWidth(context, inner),
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, __) => Container(
                color: accent.withValues(alpha: 0.14),
              ),
              errorWidget: (_, __, ___) => _fallback(context),
            )
          : SizedBox(width: inner, height: inner, child: _fallback(context)),
    );
    final Widget disc = Container(
      width: d,
      height: d,
      padding: EdgeInsets.all(ringW),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring ? null : Colors.white,
        gradient: ring
            ? SweepGradient(colors: <Color>[
                ...ringColors!,
                ringColors!.first,
              ])
            : null,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ring
                ? ringColors!.last.withValues(alpha: 0.35)
                : AppColors.shadow(0.16),
            blurRadius: ring ? 22 : 14,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(gap),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ring ? AppColors.card(context) : Colors.white,
        ),
        child: photo,
      ),
    );
    if (!verified) return disc;
    final double b = (diameter * 0.24).clamp(16.0, 30.0).r;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          disc,
          Positioned(
            right: d * 0.03,
            bottom: d * 0.03,
            child: Container(
              key: const ValueKey<String>('public_profile_avatar_verified'),
              width: b,
              height: b,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.card(context), width: 2.5),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x552563EB),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.check_rounded, size: b * 0.62, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête héro commun aux 3 fiches.
///
/// Bandeau dégradé à la couleur du rôle (semé de pattes blanches très
/// discrètes), grand avatar cerclé de blanc qui chevauche le bandeau, puis le
/// nom, la pastille de rôle, le badge « vérifié », une pastille de statut
/// facultative, la ville et la note.
class PublicProfileHero extends StatelessWidget {
  final PublicProfilePalette palette;

  /// 'owner' | 'sitter' | 'walker' — pour [RoleChip].
  final String role;
  final String name;
  final String? imageUrl;

  /// Badge « vérifié » (KYC payé) — affiché seulement si l'écran l'affichait
  /// déjà.
  final bool verified;

  /// Pastille de statut facultative (disponibilité du prestataire…).
  final Widget? statusChip;

  /// Ville / adresse déjà calculée par l'écran (jamais recalculée ici).
  final String? location;

  /// Ligne secondaire facultative (« Membre depuis … »).
  final String? subtitle;

  /// Note en étoiles (widget fourni par l'écran : `RatingStars`).
  final Widget? rating;

  const PublicProfileHero({
    super.key,
    required this.palette,
    required this.role,
    required this.name,
    this.imageUrl,
    this.verified = false,
    this.statusChip,
    this.location,
    this.subtitle,
    this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final double bannerH = kPublicProfileBannerH.h;
    final double avatarD = kPublicProfileAvatarD.r;
    final String city = (location ?? '').trim();
    final String sub = (subtitle ?? '').trim();
    final Color c0 = palette.gradient.first;
    final Color c1 = palette.gradient.last;

    return Column(
      children: <Widget>[
        SizedBox(
          height: bannerH + avatarD / 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: bannerH,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32.r),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color.lerp(c0, Colors.white, 0.10)!,
                          c0,
                          c1,
                        ],
                        stops: const <double>[0, 0.45, 1],
                      ),
                    ),
                    child: Stack(
                      children: <Widget>[
                        const Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: PawPatternPainter(
                                color: Colors.white,
                                opacity: 0.10,
                                cell: 74,
                              ),
                            ),
                          ),
                        ),
                        // Halos lumineux discrets (profondeur, effet « HD »).
                        Positioned(
                          top: -bannerH * 0.55,
                          right: -bannerH * 0.35,
                          child: _Glow(size: bannerH * 1.5, alpha: 0.18),
                        ),
                        Positioned(
                          bottom: -bannerH * 0.70,
                          left: -bannerH * 0.45,
                          child: _Glow(size: bannerH * 1.3, alpha: 0.10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: bannerH - avatarD / 2,
                left: 0,
                right: 0,
                child: Center(
                  child: PublicProfileAvatar(
                    name: name,
                    accent: palette.accent,
                    imageUrl: imageUrl,
                    diameter: kPublicProfileAvatarD,
                    ringColors: <Color>[
                      c0,
                      Color.lerp(c0, Colors.white, 0.35)!,
                      c0,
                      c1,
                    ],
                    verified: verified,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            children: <Widget>[
              PoppinsText(
                text: name,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: _inkOn(context),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 9.h),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6.w,
                runSpacing: 6.h,
                children: <Widget>[
                  RoleChip(role: role),
                  if (verified) const VerifiedPill(),
                  if (statusChip != null) statusChip!,
                ],
              ),
              if (city.isNotEmpty) ...<Widget>[
                SizedBox(height: 10.h),
                _IconLine(
                  icon: Icons.location_on_rounded,
                  text: city,
                  accent: palette.accent,
                ),
              ],
              if (sub.isNotEmpty) ...<Widget>[
                SizedBox(height: 6.h),
                _IconLine(
                  icon: Icons.event_available_rounded,
                  text: sub,
                  accent: palette.accent,
                ),
              ],
              if (rating != null) ...<Widget>[
                SizedBox(height: 12.h),
                Container(
                  key: const ValueKey<String>('public_profile_rating'),
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFF4C04A)
                          .withValues(alpha: _isDarkCtx(context) ? 0.55 : 0.70),
                      width: 1.2,
                    ),
                    boxShadow: _tintShadow(context, const Color(0xFFF4C04A)),
                  ),
                  child: FittedBox(fit: BoxFit.scaleDown, child: rating!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Halo blanc flou (décor du bandeau).
class _Glow extends StatelessWidget {
  final double size;
  final double alpha;
  const _Glow({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: alpha),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille verte « Vérifié », version plate de `VerifiedBadge` alignée sur les
/// autres pastilles du héro (même hauteur que [RoleChip]).
class VerifiedPill extends StatelessWidget {
  const VerifiedPill({super.key});

  static const Color _green = Color(0xFF15803D);

  @override
  Widget build(BuildContext context) {
    final Color c = AppColors.accentOn(context, _green);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.5.h),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _green.withValues(alpha: 0.30), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.verified_rounded, size: 11.sp, color: c),
          SizedBox(width: 3.5.w),
          Text(
            'kyc_badge_verified'.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne « icône + texte » centrée (ville, membre depuis…).
class _IconLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;

  const _IconLine({
    required this.icon,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15.sp, color: AppColors.accentOn(context, accent)),
        SizedBox(width: 5.w),
        Flexible(
          child: InterText(
            text: text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondaryStrong(context),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Une tuile de la rangée de statistiques.
class PublicProfileStat {
  final IconData icon;
  final String value;
  final String label;

  const PublicProfileStat({
    required this.icon,
    required this.value,
    required this.label,
  });
}

/// Rangée de tuiles (1 à 4) — jamais de débordement : chaque tuile est
/// `Expanded`, la valeur ET le libellé passent par un `FittedBox` sur UNE
/// ligne, ce qui donne à toutes les tuiles exactement la même hauteur sans
/// `CrossAxisAlignment.stretch` ni `IntrinsicHeight` (tous deux interdits avec
/// des `Expanded` dans un défilement : crash silencieux en release).
class PublicProfileStatsRow extends StatelessWidget {
  final Color accent;
  final List<PublicProfileStat> stats;

  const PublicProfileStatsRow({
    super.key,
    required this.accent,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    final List<Widget> tiles = <Widget>[];
    for (int i = 0; i < stats.length; i++) {
      if (i > 0) tiles.add(SizedBox(width: 10.w));
      tiles.add(Expanded(child: _tile(context, stats[i])));
    }
    return Row(children: tiles);
  }

  Widget _tile(BuildContext context, PublicProfileStat s) {
    final bool dark = _isDarkCtx(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 13.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.alphaBlend(accent.withValues(alpha: dark ? 0.14 : 0.07),
                AppColors.card(context)),
            AppColors.card(context),
          ],
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _tintBorder(context, accent)),
        boxShadow: _tintShadow(context, accent),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: dark ? 0.24 : 0.12),
            ),
            alignment: Alignment.center,
            child: Icon(
              s.icon,
              size: 16.sp,
              color: AppColors.accentOn(context, accent),
            ),
          ),
          SizedBox(height: 7.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: PoppinsText(
              text: s.value,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _inkOn(context),
              maxLines: 1,
            ),
          ),
          SizedBox(height: 2.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: InterText(
              text: s.label,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary(context),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte de section : coins 20, surface du thème, bord et ombre du thème,
/// titre avec une petite icône Material dans un rond teinté.
class PublicProfileSection extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String title;
  final Widget child;

  /// Widget aligné à droite du titre (compteur, pastille…).
  final Widget? trailing;

  const PublicProfileSection({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(kPublicProfileRadius.r),
        border: Border.all(color: _tintBorder(context, accent)),
        boxShadow: _tintShadow(context, accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11.r),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color.lerp(accent, Colors.white, 0.12)!,
                      Color.lerp(accent, Colors.black, 0.12)!,
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 17.sp,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 11.w),
              Expanded(
                child: PoppinsText(
                  text: title,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: _inkOn(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) ...<Widget>[
                SizedBox(width: 8.w),
                trailing!,
              ],
            ],
          ),
          SizedBox(height: 14.h),
          child,
        ],
      ),
    );
  }
}

/// Ligne discrète pour une section sans contenu (à l'intérieur de la carte,
/// jamais un gros bloc de vide flottant sur le fond).
class PublicProfileEmptyLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const PublicProfileEmptyLine({
    super.key,
    required this.text,
    this.icon = Icons.remove_circle_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 15.sp, color: AppColors.textTertiary(context)),
        SizedBox(width: 8.w),
        Expanded(
          child: InterText(
            text: text,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}

/// Paragraphe de section (bio, adresse, langue…).
class PublicProfileBody extends StatelessWidget {
  final String text;

  const PublicProfileBody({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return InterText(
      text: text,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: AppColors.textSecondaryStrong(context),
    );
  }
}

/// Ligne « libellé … prix » : le libellé s'ellipse, le prix reste entier et
/// bien lisible à droite.
class PublicProfileRateRow extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const PublicProfileRateRow({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: InterText(
              text: label,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: _inkOn(context),
              maxLines: 3,
            ),
          ),
          SizedBox(width: 10.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: _isDarkCtx(context) ? 0.22 : 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: PoppinsText(
              text: value,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.accentOn(context, accent),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne « libellé / valeur » neutre (langue, localisation…).
class PublicProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const PublicProfileInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: 15.sp,
            color: AppColors.accentOn(context, accent),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InterText(
                  text: label,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.h),
                InterText(
                  text: value,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille d'un tag (compétence, service, espèce acceptée).
class PublicProfileTag extends StatelessWidget {
  final String label;
  final Color accent;
  final IconData? icon;

  const PublicProfileTag({
    super.key,
    required this.label,
    required this.accent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 240.w),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: 13.sp,
              color: AppColors.accentOn(context, accent),
            ),
            SizedBox(width: 5.w),
          ],
          Flexible(
            child: InterText(
              text: label,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille de statut générique (disponibilité du prestataire).
class PublicProfileStatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tone;

  const PublicProfileStatusPill({
    super.key,
    required this.icon,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = AppColors.accentOn(context, tone);
    return Container(
      constraints: BoxConstraints(maxWidth: 200.w),
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.5.h),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.30), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11.sp, color: fg),
          SizedBox(width: 3.5.w),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 10.5.sp,
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

/// Carte d'avis : avatar, nom, étoiles, date, commentaire.
class PublicProfileReviewCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double rating;
  final String comment;
  final String? date;
  final Color accent;

  const PublicProfileReviewCard({
    super.key,
    required this.name,
    required this.rating,
    required this.comment,
    required this.accent,
    this.imageUrl,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    final String d = (date ?? '').trim();
    final String c = comment.trim();
    final bool dark = _isDarkCtx(context);
    return Container(
      padding: EdgeInsets.all(13.w),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withValues(alpha: dark ? 0.10 : 0.045),
            AppColors.card(context)),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _tintBorder(context, accent)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PublicProfileAvatar(
            name: name,
            accent: accent,
            imageUrl: imageUrl,
            diameter: 44,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: PoppinsText(
                        text: name,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _inkOn(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (d.isNotEmpty) ...<Widget>[
                      SizedBox(width: 8.w),
                      InterText(
                        text: d,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary(context),
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),
                _Stars(rating: rating),
                if (c.isNotEmpty) ...<Widget>[
                  SizedBox(height: 7.h),
                  InterText(
                    text: c,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                    color: AppColors.textSecondaryStrong(context),
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

class _Stars extends StatelessWidget {
  final double rating;
  const _Stars({required this.rating});

  // Or Premium de la marque (#F4C04A), un cran plus soutenu pour rester
  // lisible sur une carte blanche.
  static const Color _amber = Color(0xFFF2B42C);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ...List<Widget>.generate(5, (int i) {
          final IconData icon;
          if (i < rating.floor()) {
            icon = Icons.star_rounded;
          } else if (i == rating.floor() && rating - rating.floor() >= 0.25) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_outline_rounded;
          }
          return Icon(icon, size: 15.sp, color: _amber);
        }),
        SizedBox(width: 5.w),
        InterText(
          text: rating.toStringAsFixed(1),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _inkOn(context),
          maxLines: 1,
        ),
      ],
    );
  }
}

/// Barre d'action collante en bas.
///
/// Elle porte elle-même `appBottomInset(context)` : sur le Samsung de Daniel
/// l'inset annoncé est 0 alors que la barre à 3 boutons recouvre 48 px.
class PublicProfileActionBar extends StatelessWidget {
  /// Action principale (en général un `CustomButton`).
  final Widget child;

  /// Actions secondaires rondes (chat, partage…), à droite.
  final List<Widget> secondary;

  const PublicProfileActionBar({
    super.key,
    required this.child,
    this.secondary = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    final bool dark = _isDarkCtx(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border(
          top: BorderSide(
            color: dark
                ? const Color(0x33FFFFFF)
                : AppColors.divider(context).withValues(alpha: 0.9),
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: dark ? const Color(0x800B0706) : AppColors.shadow(0.10),
            blurRadius: 22,
            spreadRadius: -4,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16.w,
        12.h,
        16.w,
        12.h + appBottomInset(context),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: child),
          for (final Widget w in secondary) ...<Widget>[
            SizedBox(width: 10.w),
            w,
          ],
        ],
      ),
    );
  }
}

/// Bouton rond d'action secondaire de la barre du bas.
class PublicProfileRoundAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color accent;
  final VoidCallback? onTap;

  const PublicProfileRoundAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: accent.withValues(alpha: 0.12),
          shape: CircleBorder(
            side: BorderSide(color: accent.withValues(alpha: 0.26)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 52.h,
              height: 52.h,
              child: Icon(
                icon,
                size: 21.sp,
                color: AppColors.accentOn(context, accent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Squelette de chargement : le bandeau est déjà à la couleur du rôle, le
/// reste est un aplat neutre — aucune animation (pas de `pumpAndSettle` qui
/// boucle dans les tests).
class PublicProfileSkeleton extends StatelessWidget {
  final PublicProfilePalette palette;

  const PublicProfileSkeleton({super.key, required this.palette});

  Widget _bar(BuildContext context, double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.mediaPlaceholder(context),
          borderRadius: BorderRadius.circular(999),
        ),
      );

  Widget _card(BuildContext context, double h) => Container(
        width: double.infinity,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(kPublicProfileRadius.r),
          border: Border.all(color: _tintBorder(context, palette.accent)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final double bannerH = kPublicProfileBannerH.h;
    final double avatarD = kPublicProfileAvatarD.r;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: bannerH + avatarD / 2,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: bannerH,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: palette.gradient,
                      ),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(32.r),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: bannerH - avatarD / 2,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: avatarD,
                      height: avatarD,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      padding: EdgeInsets.all(4.r),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.accent.withValues(alpha: 0.16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          _bar(context, 150.w, 16.h),
          SizedBox(height: 8.h),
          _bar(context, 96.w, 12.h),
          SizedBox(height: 20.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: _card(context, 74.h)),
                    SizedBox(width: 10.w),
                    Expanded(child: _card(context, 74.h)),
                    SizedBox(width: 10.w),
                    Expanded(child: _card(context, 74.h)),
                  ],
                ),
                SizedBox(height: 14.h),
                _card(context, 120.h),
                SizedBox(height: 14.h),
                _card(context, 150.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// État d'erreur / introuvable, avec bouton « Réessayer » facultatif.
class PublicProfileErrorView extends StatelessWidget {
  final Color accent;
  final String message;
  final String? actionLabel;
  final VoidCallback? onRetry;
  final IconData icon;

  const PublicProfileErrorView({
    super.key,
    required this.accent,
    required this.message,
    this.actionLabel,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 30.sp,
                color: AppColors.accentOn(context, accent),
              ),
            ),
            SizedBox(height: 14.h),
            InterText(
              text: message,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              textAlign: TextAlign.center,
              color: AppColors.textSecondary(context),
            ),
            if (onRetry != null && (actionLabel ?? '').isNotEmpty) ...<Widget>[
              SizedBox(height: 18.h),
              SizedBox(
                width: 200.w,
                child: _RetryButton(
                  label: actionLabel!,
                  accent: accent,
                  onTap: onRetry!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _RetryButton({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(16.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 13.h, horizontal: 16.w),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: InterText(
                text: label,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fond à petites pattes derrière le contenu défilant d'une fiche publique.
class PublicProfileBackground extends StatelessWidget {
  final Color accent;
  final Widget child;

  const PublicProfileBackground({
    super.key,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) =>
      PawPatternBackground(color: accent, child: child);
}
