// v571 — « kit » de présentation de l'accueil PROPRIÉTAIRE.
//
// Le propriétaire est celui qui paie : l'objectif de ces widgets est de
// l'amener à sa première réservation au lieu de le laisser devant un onglet
// « Mes annonces » vide. Tout ce fichier est purement visuel :
//   · aucun accès au State de `home_screen.dart`, aucun contrôleur GetX ;
//   · tous les libellés arrivent en paramètre (i18n résolue par l'appelant),
//     ce qui rend ces widgets testables sans traductions chargées ;
//   · mode sombre / clair via `AppColors.card|divider|textPrimary|textSecondary`.
//
// Contrainte de largeur : tout doit tenir à 320 dp, y compris en allemand et
// en polonais → titres bornés (`maxLines` + ellipsis), rangée de confiance en
// colonnes `Expanded` (jamais de `Row` non borné qui déborde).
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

/// Dégradé « garde » — bleu gardien (v571, Daniel : « mets-la en bleu » :
/// même code couleur que l'onglet Pet-sitters, vert = promeneurs).
List<Color> ownerSittingGradient() => const <Color>[
  Color(0xFF2F6FD6),
  Color(0xFF1E4FB0),
];

/// Dégradé « promenade » — vert promeneur.
const List<Color> kOwnerWalkingGradient = <Color>[
  Color(0xFF2FAE4E),
  Color(0xFF15803D),
];

// ───────────────────────────────────────────────────────────────────────────
// 1. Les deux grandes cartes d'action
// ───────────────────────────────────────────────────────────────────────────

/// Une carte d'action (garde ou promenade).
///
/// `compact` = variante basse (une seule ligne, ~56 dp) utilisée dès que le
/// propriétaire a déjà publié une annonce : elle ne doit plus manger l'écran.
class OwnerActionCard extends StatefulWidget {
  const OwnerActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.compact = false,
  });

  final String title;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<OwnerActionCard> createState() => _OwnerActionCardState();
}

class _OwnerActionCardState extends State<OwnerActionCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final double radius = 20.r;
    final BorderRadius br = BorderRadius.circular(radius);
    final bool compact = widget.compact;
    final double box = compact ? 26.w : 34.w;

    final Widget badge = Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
      child: Icon(
        widget.icon,
        size: compact ? 15.sp : 19.sp,
        color: Colors.white,
      ),
    );

    final Widget label = InterText(
      text: widget.title,
      fontSize: compact ? 12.sp : 13.sp,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      height: 1.15,
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
    );

    final Widget content = compact
        ? Row(
            children: <Widget>[
              badge,
              SizedBox(width: 8.w),
              Expanded(child: label),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              badge,
              SizedBox(height: 8.h),
              Flexible(child: label),
            ],
          );

    return Semantics(
      button: true,
      label: widget.title,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          height: compact ? 56.h : 96.h,
          decoration: BoxDecoration(
            borderRadius: br,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.gradient.last.withValues(alpha: 0.26),
                blurRadius: 14,
                spreadRadius: -3,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: br,
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: br,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.gradient,
                ),
              ),
              child: InkWell(
                borderRadius: br,
                splashColor: Colors.white.withValues(alpha: 0.16),
                highlightColor: Colors.white.withValues(alpha: 0.06),
                onTapDown: (_) => _setPressed(true),
                onTapCancel: () => _setPressed(false),
                onTap: () {
                  _setPressed(false);
                  HapticFeedback.selectionClick();
                  widget.onTap();
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10.w : 12.w,
                    vertical: compact ? 8.h : 12.h,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Les deux cartes côte à côte (garde / promenade).
class OwnerActionCards extends StatelessWidget {
  const OwnerActionCards({
    super.key,
    required this.sittingTitle,
    required this.walkingTitle,
    required this.onSitting,
    required this.onWalking,
    this.compact = false,
    this.sittingIcon = Icons.home_work_rounded,
    this.walkingIcon = Icons.directions_walk_rounded,
  });

  final String sittingTitle;
  final String walkingTitle;
  final VoidCallback onSitting;
  final VoidCallback onWalking;
  final bool compact;
  final IconData sittingIcon;
  final IconData walkingIcon;

  @override
  Widget build(BuildContext context) {
    // ⚠️ Jamais `CrossAxisAlignment.stretch` ici : ces cartes vivent dans un
    // sliver (hauteur non bornée) → contrainte infinie. Les deux cartes ont de
    // toute façon la même hauteur fixe.
    return Row(
      children: <Widget>[
        Expanded(
          child: OwnerActionCard(
            key: const ValueKey<String>('owner_action_sitting'),
            title: sittingTitle,
            icon: sittingIcon,
            gradient: ownerSittingGradient(),
            compact: compact,
            onTap: onSitting,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: OwnerActionCard(
            key: const ValueKey<String>('owner_action_walking'),
            title: walkingTitle,
            icon: walkingIcon,
            gradient: kOwnerWalkingGradient,
            compact: compact,
            onTap: onWalking,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// 2. Bandeau de confiance
// ───────────────────────────────────────────────────────────────────────────

/// Un élément du bandeau de confiance (icône + libellé court).
class OwnerTrustItem {
  const OwnerTrustItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Bandeau discret « 🔒 Paiement sécurisé · ✅ Identité vérifiée · ↩️ Annulation ».
///
/// Chaque élément vit dans un `Expanded` : la largeur est donc toujours bornée
/// et le libellé se replie sur deux lignes (puis ellipse) au lieu de déborder,
/// y compris à 320 dp en allemand ou en polonais.
class OwnerTrustRow extends StatelessWidget {
  const OwnerTrustRow({super.key, required this.items, this.accent});

  final List<OwnerTrustItem> items;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color tint = accent ?? AppColors.primaryColor;
    return Container(
      key: const ValueKey<String>('owner_trust_row'),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider(context), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          for (int i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: 6.w),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(items[i].icon, size: 13.sp, color: tint),
                  SizedBox(width: 4.w),
                  Flexible(
                    child: InterText(
                      text: items[i].label,
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                      height: 1.15,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// 3. Carte « Publie ta première annonce »
// ───────────────────────────────────────────────────────────────────────────

/// Carte d'accueil de l'onglet « Mes annonces » quand il est vide :
/// un titre, trois étapes numérotées, UN seul gros bouton.
class OwnerFirstPostCard extends StatelessWidget {
  const OwnerFirstPostCard({
    super.key,
    required this.title,
    required this.steps,
    required this.ctaLabel,
    required this.onCta,
    this.accent,
    this.stepIcons = kOwnerFirstPostStepIcons,
  });

  static const List<IconData> kOwnerFirstPostStepIcons = <IconData>[
    Icons.edit_note_rounded,
    Icons.local_offer_rounded,
    Icons.lock_rounded,
  ];

  final String title;
  final List<String> steps;
  final String ctaLabel;
  final VoidCallback onCta;
  final Color? accent;
  final List<IconData> stepIcons;

  @override
  Widget build(BuildContext context) {
    final Color tint = accent ?? AppColors.primaryColor;
    return Container(
      key: const ValueKey<String>('owner_first_post_card'),
      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.divider(context), width: 1),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 62.w,
              height: 62.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    tint.withValues(alpha: 0.18),
                    tint.withValues(alpha: 0.06),
                  ],
                ),
              ),
              // v580 — Daniel, 22/09 : « le haut-parleur, c'est celui-là ! »
              // Le mégaphone de « Publie ta première annonce » s'anime : il
              // s'incline doucement et laisse partir deux ondes, comme s'il
              // appelait les gardiens autour de toi.
              child: AnimatedMegaphone(size: 30.sp, color: tint),
            ),
          ),
          SizedBox(height: 12.h),
          PoppinsText(
            text: title,
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 14.h),
          for (int i = 0; i < steps.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: 10.h),
            _OwnerStepRow(
              index: i + 1,
              icon: i < stepIcons.length ? stepIcons[i] : Icons.check_rounded,
              label: steps[i],
              accent: tint,
            ),
          ],
          SizedBox(height: 18.h),
          CustomButton(
            title: ctaLabel,
            bgColor: tint,
            radius: 16.r,
            onTap: onCta,
          ),
        ],
      ),
    );
  }
}

class _OwnerStepRow extends StatelessWidget {
  const _OwnerStepRow({
    required this.index,
    required this.icon,
    required this.label,
    required this.accent,
  });

  final int index;
  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 26.w,
          height: 26.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          child: InterText(
            text: '$index',
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        SizedBox(width: 10.w),
        Icon(icon, size: 16.sp, color: accent),
        SizedBox(width: 8.w),
        Expanded(
          child: InterText(
            text: label,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
            height: 1.2,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// 4. Onglets Gardiens / Promeneurs vides
// ───────────────────────────────────────────────────────────────────────────

/// État vide accueillant des onglets « Gardiens » et « Promeneurs ».
///
/// `widenLabel` / `onWiden` sont optionnels : l'appelant ne les fournit que
/// lorsqu'un rayon plus large est réellement disponible.
class OwnerProvidersEmpty extends StatelessWidget {
  const OwnerProvidersEmpty({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.inviteTitle,
    required this.inviteBody,
    required this.inviteCta,
    required this.onInvite,
    this.widenLabel,
    this.onWiden,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String inviteTitle;
  final String inviteBody;
  final String inviteCta;
  final VoidCallback onInvite;
  final String? widenLabel;
  final VoidCallback? onWiden;

  @override
  Widget build(BuildContext context) {
    final bool canWiden = widenLabel != null && onWiden != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: EdgeInsets.fromLTRB(16.w, 22.h, 16.w, 16.h),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.divider(context), width: 1),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 78.w,
                  height: 78.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        accent.withValues(alpha: 0.20),
                        accent.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Icon(icon, size: 36.sp, color: accent),
                ),
              ),
              SizedBox(height: 14.h),
              PoppinsText(
                text: title,
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 6.h),
              InterText(
                text: body,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(context),
                textAlign: TextAlign.center,
                height: 1.3,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 16.h),
              CustomButton(
                title: primaryLabel,
                bgColor: accent,
                radius: 16.r,
                onTap: onPrimary,
              ),
              if (canWiden) ...<Widget>[
                SizedBox(height: 10.h),
                CustomButton(
                  title: widenLabel!,
                  bgColor: Colors.transparent,
                  borderColor: accent,
                  textColor: accent,
                  radius: 16.r,
                  height: 46.h,
                  onTap: onWiden,
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 12.h),
        OwnerInviteCard(
          title: inviteTitle,
          body: inviteBody,
          ctaLabel: inviteCta,
          onTap: onInvite,
          accent: accent,
        ),
      ],
    );
  }
}

/// Carte « Invite un gardien que tu connais » → partage du lien d'invitation.
class OwnerInviteCard extends StatelessWidget {
  const OwnerInviteCard({
    super.key,
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.onTap,
    this.accent,
  });

  final String title;
  final String body;
  final String ctaLabel;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color tint = accent ?? AppColors.primaryColor;
    final BorderRadius br = BorderRadius.circular(18.r);
    return Material(
      color: AppColors.card(context),
      borderRadius: br,
      child: InkWell(
        borderRadius: br,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
          decoration: BoxDecoration(
            borderRadius: br,
            border: Border.all(color: AppColors.divider(context), width: 1),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 20.sp,
                  color: tint,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    InterText(
                      text: title,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3.h),
                    InterText(
                      text: body,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(context),
                      height: 1.25,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.ios_share_rounded, size: 13.sp, color: tint),
                        SizedBox(width: 5.w),
                        Flexible(
                          child: InterText(
                            text: ctaLabel,
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w800,
                            color: tint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// 5. Carte « Ajoute ton animal »
// ───────────────────────────────────────────────────────────────────────────

/// Carte fine affichée au-dessus des onglets tant que le propriétaire n'a
/// aucun animal : sans animal, il ne peut pas réserver.
class OwnerAddPetCard extends StatelessWidget {
  const OwnerAddPetCard({
    super.key,
    required this.title,
    required this.ctaLabel,
    required this.onTap,
    this.accent,
  });

  final String title;
  final String ctaLabel;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color tint = accent ?? AppColors.primaryColor;
    final BorderRadius br = BorderRadius.circular(16.r);
    return Material(
      color: AppColors.card(context),
      borderRadius: br,
      child: InkWell(
        borderRadius: br,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          key: const ValueKey<String>('owner_add_pet_card'),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            borderRadius: br,
            border: Border.all(color: tint.withValues(alpha: 0.35), width: 1),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.pets_rounded, size: 17.sp, color: tint),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: InterText(
                  text: title,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  height: 1.2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: InterText(
                        text: ctaLabel,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w800,
                        color: tint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18.sp,
                      color: tint,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// v580 — Mégaphone ANIMÉ de la carte « Publie ta première annonce ».
///
/// Boucle de 2,4 s : le porte-voix s'incline de 6° et revient, pendant que
/// deux ondes sortent du pavillon l'une après l'autre, en fondu. Dessiné au
/// `CustomPainter` pour suivre exactement la couleur du rôle. L'animation se
/// coupe si le téléphone demande moins d'animations.
class AnimatedMegaphone extends StatefulWidget {
  const AnimatedMegaphone({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  State<AnimatedMegaphone> createState() => _AnimatedMegaphoneState();
}

class _AnimatedMegaphoneState extends State<AnimatedMegaphone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _loop,
          builder: (BuildContext context, Widget? _) => CustomPaint(
            painter: _MegaphonePainter(
              color: widget.color,
              t: still ? 0.35 : _loop.value,
            ),
          ),
        ),
      ),
    );
  }
}

class _MegaphonePainter extends CustomPainter {
  _MegaphonePainter({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint body = Paint()..color = color;

    // Balancement du porte-voix : ±6°, aller-retour doux.
    final double tilt = 0.105 * math.sin(t * 2 * math.pi);
    canvas.save();
    canvas.translate(w * 0.30, h * 0.62);
    canvas.rotate(tilt);
    canvas.translate(-w * 0.30, -h * 0.62);

    // Poignée.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.17, h * 0.62, w * 0.09, h * 0.24),
        Radius.circular(w * 0.03),
      ),
      body,
    );
    // Pavillon, pointé vers le haut à droite.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.12, h * 0.44)
        ..lineTo(w * 0.60, h * 0.16)
        ..lineTo(w * 0.60, h * 0.72)
        ..lineTo(w * 0.12, h * 0.62)
        ..close(),
      body,
    );
    canvas.restore();

    // Deux ondes qui s'échappent du pavillon.
    for (int i = 0; i < 2; i++) {
      final double phase = (t + i * 0.5) % 1.0;
      final double eased = Curves.easeOut.transform(phase);
      final double radius = w * (0.12 + 0.20 * eased);
      final double fade = (1 - phase).clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(w * 0.60, h * 0.44), radius: radius),
        -math.pi / 3.4,
        2 * math.pi / 3.4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.085
          ..color = color.withValues(alpha: 0.9 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_MegaphonePainter old) =>
      old.t != t || old.color != color;
}
