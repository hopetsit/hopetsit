// v569 — Kit commun des BANDEAUX D'ACTION et de leurs BOUTONS.
//
// Daniel (19/09) : « modernise les bandeaux de notification et d'acceptation
// de service, de tous les rôles » puis « les boutons etc., accepter demande ».
//
// ⚠️ DESIGN UNIQUEMENT. Ce fichier ne contient aucun appel réseau, aucune
// règle d'affichage et aucune navigation : les écrans gardent leurs
// conditions, leurs callbacks et leurs routes. Il ne fournit que le rendu.
//
// UN SEUL GABARIT pour tous les états (`ActionBanner`) :
//   surface du thème teintée ~7 % de la couleur de l'ÉTAT, coins 20, ombre
//   très douce, liseré vertical 4 px à gauche, pastille ronde 40 px avec
//   icône pleine, titre 15/800 sur 1 ligne, sous-titre 13/400 gris sur
//   2 lignes, et à droite soit un chevron soit UN bouton compact.
//   Point pulsé discret quand l'état attend une action de l'utilisateur ;
//   compteur « +N » quand plusieurs actions du même type sont en attente.
//
// COULEURS PAR NATURE D'ÉTAT (identiques owner / sitter / walker) :
//   neutre « tout est à jour » → couleur du RÔLE, très pâle
//   demande reçue / à traiter  → ambre  #E8920A
//   accepté / succès / reçu    → vert   #16A34A
//   à payer                    → orange #C92A12 (rôle propriétaire)
//   refusé / annulé / problème → rouge  #DC2626
//   ami / social               → rose   #E0568B
//   remise-rendu / en direct   → violet #7C3AED
//
// BOUTONS (`ActionPillButton`) : hauteur tactile ≥ 44 px, coins 14, action
// principale pleine, secondaire en contour, destructive en rouge texte,
// retour haptique optionnel (accepter / refuser) et indicateur « en cours »
// qui neutralise le double tap.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';

// ─── Palette des états ──────────────────────────────────────────────────────

/// Couleurs par NATURE d'état. Elles ne dépendent PAS du rôle : un « paiement
/// reçu » est vert chez le gardien comme chez le promeneur.
class ActionTone {
  const ActionTone._();

  /// Demande reçue, candidature, avis à laisser — bref : à traiter.
  static const Color pending = Color(0xFFE8920A);

  /// Accepté, payé, encaissé, terminé.
  static const Color success = Color(0xFF16A34A);

  /// À payer (couleur du rôle propriétaire).
  static const Color pay = Color(0xFFC92A12);

  /// Refusé, annulé, en retard, problème.
  static const Color danger = Color(0xFFDC2626);

  /// Ami / social.
  static const Color social = Color(0xFFE0568B);

  /// Remise-rendu de l'animal, suivi en direct, famille PawFollow.
  static const Color live = Color(0xFF7C3AED);

  // Couleurs de rôle — utilisées uniquement pour l'état NEUTRE et les accents
  // d'avatar, jamais pour qualifier un état.
  static const Color owner = Color(0xFFC92A12);
  static const Color sitter = Color(0xFF2563EB);
  static const Color walker = Color(0xFF16A34A);

  static Color forRole(String? role) {
    switch ((role ?? '').toLowerCase()) {
      case 'walker':
        return walker;
      case 'sitter':
        return sitter;
      default:
        return owner;
    }
  }
}

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Fond du bandeau : la surface du thème, teintée très légèrement de la
/// couleur de l'état (6-10 % en clair, un peu plus en sombre pour rester
/// lisible). Plus jamais d'aplat de couleur vive plein écran.
Color actionBannerSurface(BuildContext context, Color tone) {
  final dark = _isDark(context);
  return Color.alphaBlend(
    tone.withValues(alpha: dark ? 0.20 : 0.07),
    AppColors.card(context),
  );
}

// ─── Point d'urgence ────────────────────────────────────────────────────────

/// Petit point pulsé. L'animation est FOURNIE par l'écran (un seul
/// `AnimationController` pour toute la bande, arrêté quand rien ne pulse).
class ActionPulseDot extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  final Color ringColor;
  final double size;

  const ActionPulseDot({
    super.key,
    required this.animation,
    required this.color,
    required this.ringColor,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value.clamp(0.0, 1.0);
        return Container(
          width: size.w,
          height: size.w,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: ringColor, width: 1.6),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45 * (1 - t)),
                blurRadius: 0,
                spreadRadius: 3.0 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Pastille d'icône ───────────────────────────────────────────────────────

class _ActionBadge extends StatelessWidget {
  final Color tone;
  final IconData icon;
  final Animation<double>? pulse;
  final Color ringColor;

  const _ActionBadge({
    required this.tone,
    required this.icon,
    required this.ringColor,
    this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return SizedBox(
      width: 40.w,
      height: 40.w,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: dark ? 0.28 : 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.accentOn(context, tone), size: 21.sp),
          ),
          if (pulse != null)
            Positioned(
              right: -1,
              top: -1,
              child: ActionPulseDot(
                animation: pulse!,
                color: tone,
                ringColor: ringColor,
              ),
            ),
        ],
      ),
    );
  }
}

/// Compteur discret « +2 » quand plusieurs actions du même type attendent.
class ActionCountChip extends StatelessWidget {
  final int count;
  final Color tone;
  const ActionCountChip({super.key, required this.count, required this.tone});

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: dark ? 0.32 : 0.16),
        borderRadius: BorderRadius.circular(9.r),
      ),
      child: PoppinsText(
        text: '+$count',
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.accentOn(context, tone),
      ),
    );
  }
}

// ─── Le gabarit unique ──────────────────────────────────────────────────────

class ActionBanner extends StatelessWidget {
  /// Couleur de l'ÉTAT (cf. [ActionTone]).
  final Color tone;
  final IconData icon;
  final String title;
  final String subtitle;

  /// Tap sur toute la carte — même navigation qu'avant.
  final VoidCallback? onTap;

  /// Zone de droite : un [ActionPillButton] compact, plusieurs boutons dans
  /// une `Row`, ou `null` → chevron.
  final Widget? trailing;

  /// Animation du point d'urgence ; `null` = pas de point.
  final Animation<double>? pulse;

  /// « +N » quand d'autres actions identiques attendent (0 = rien).
  final int extraCount;

  /// Croix de fermeture, quand l'écran en propose déjà une.
  final VoidCallback? onDismiss;

  final EdgeInsetsGeometry? margin;

  const ActionBanner({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.onTap,
    this.trailing,
    this.pulse,
    this.extraCount = 0,
    this.onDismiss,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final surface = actionBannerSurface(context, tone);

    final head = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: PoppinsText(
            text: title,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
            // v571 — « Pas de demande en atten… » était coupé : 2 lignes.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (extraCount > 0) ...[
          SizedBox(width: 6.w),
          ActionCountChip(count: extraCount, tone: tone),
        ],
      ],
    );

    final body = Row(
      children: [
        _ActionBadge(
          tone: tone,
          icon: icon,
          ringColor: surface,
          pulse: pulse,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              head,
              if (subtitle.isNotEmpty) ...[
                SizedBox(height: 3.h),
                InterText(
                  text: subtitle,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: 10.w),
        trailing ??
            Icon(
              Icons.chevron_right_rounded,
              size: 22.sp,
              color: AppColors.textSecondary(context).withValues(alpha: 0.7),
            ),
        if (onDismiss != null) ...[
          SizedBox(width: 2.w),
          _BannerIconButton(
            icon: Icons.close_rounded,
            color: AppColors.textSecondary(context),
            onTap: onDismiss!,
          ),
        ],
      ],
    );

    return Padding(
      padding: margin ?? EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: dark
              ? const <BoxShadow>[]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  // Liseré vertical de la couleur de l'état.
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 4.w, color: tone),
                  ),
                  ConstrainedBox(
                    // Hauteur stable d'un état à l'autre : pas de saut de mise
                    // en page quand le bandeau change de contenu.
                    constraints: BoxConstraints(minHeight: 74.h),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 12.w, 12.h),
                      child: body,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BannerIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 20.r,
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Icon(icon, size: 18.sp, color: color.withValues(alpha: 0.75)),
      ),
    );
  }
}

// ─── Boutons ────────────────────────────────────────────────────────────────

enum ActionPillKind {
  /// Action principale : pilule pleine de la couleur de l'état.
  filled,

  /// Action secondaire : contour de la couleur de l'état.
  outlined,

  /// Action destructive : rouge, en texte (pas d'aplat).
  danger,

  /// Action tertiaire : fond très pâle de la couleur de l'état.
  ghost,
}

/// Bouton d'action unique de l'app : bandeaux, feuilles d'action et cartes de
/// réservation / candidature. Hauteur tactile ≥ 44 px, coins 14.
class ActionPillButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color tone;
  final ActionPillKind kind;

  /// Callback inchangé. S'il renvoie un `Future`, le bouton affiche de
  /// lui-même l'indicateur « en cours » et ignore les taps suivants.
  final FutureOr<void> Function()? onPressed;

  /// Forcé par l'écran quand c'est lui qui connaît l'état « en cours ».
  final bool busy;

  /// Version compacte (dans un bandeau) : 40 px au lieu de 48.
  final bool compact;

  /// Occupe toute la largeur disponible.
  final bool expand;

  /// Retour haptique — accepter / refuser.
  final bool haptic;

  /// Largeur maximale, pour qu'un libellé allemand ou polonais s'ellipse au
  /// lieu de déborder.
  final double? maxWidth;

  const ActionPillButton({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.kind = ActionPillKind.filled,
    this.onPressed,
    this.busy = false,
    this.compact = false,
    this.expand = false,
    this.haptic = false,
    this.maxWidth,
  });

  @override
  State<ActionPillButton> createState() => _ActionPillButtonState();
}

class _ActionPillButtonState extends State<ActionPillButton> {
  bool _localBusy = false;

  bool get _busy => widget.busy || _localBusy;
  bool get _enabled => widget.onPressed != null && !_busy;

  Future<void> _handleTap() async {
    if (!_enabled) return;
    if (widget.haptic) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {/* pas de moteur haptique */}
    }
    final result = widget.onPressed!();
    if (result is Future) {
      setState(() => _localBusy = true);
      try {
        await result;
      } finally {
        if (mounted) setState(() => _localBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // v585 (lot D) — rendu par le kit signature (`PawButton`) : plein =
    // principal (dégradé + disque + reflet), contour = secondaire, danger =
    // rouge (supprimer / annuler), ghost = secondaire. Libellé JAMAIS coupé.
    // Même callback, même « en cours », même haptique qu'avant.
    final PawButtonKind kind;
    switch (widget.kind) {
      case ActionPillKind.filled:
        kind = PawButtonKind.primary;
        break;
      case ActionPillKind.danger:
        kind = PawButtonKind.danger;
        break;
      case ActionPillKind.outlined:
      case ActionPillKind.ghost:
        kind = PawButtonKind.secondary;
        break;
    }
    Widget pill = PawButton(
      label: widget.label,
      onTap: _enabled ? _handleTap : null,
      color: widget.tone,
      icon: widget.icon,
      kind: kind,
      loading: _busy,
      enabled: widget.onPressed != null,
      expand: widget.expand,
      compact: true,
      height: widget.compact ? 40.h : 48.h,
      haptic: false,
    );
    if (widget.maxWidth != null) {
      pill = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth!),
        child: pill,
      );
    }
    if (widget.expand) {
      pill = SizedBox(width: double.infinity, child: pill);
    }
    return pill;
  }
}

/// Bouton rond compact (✓ / ✗ d'un bandeau). Même langage visuel que
/// [ActionPillButton], mais sans libellé — donc jamais de débordement.
class ActionRoundButton extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final bool filled;
  final VoidCallback? onPressed;
  final bool haptic;
  final String? semanticLabel;

  const ActionRoundButton({
    super.key,
    required this.icon,
    required this.tone,
    this.filled = true,
    this.onPressed,
    this.haptic = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final bg = filled ? tone : tone.withValues(alpha: dark ? 0.24 : 0.12);
    final fg = filled ? Colors.white : tone;
    final radius = BorderRadius.circular(13.r);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed == null
                ? null
                : () {
                    if (haptic) {
                      try {
                        HapticFeedback.mediumImpact();
                      } catch (_) {/* pas de moteur haptique */}
                    }
                    onPressed!();
                  },
            child: SizedBox(
              width: 40.w,
              height: 40.w,
              child: Icon(icon, size: 20.sp, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Feuilles d'action ──────────────────────────────────────────────────────

/// Décoration commune des feuilles d'action (coins 24, surface du thème).
BoxDecoration actionSheetDecoration(BuildContext context) => BoxDecoration(
      color: AppColors.card(context),
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    );

/// Poignée + croix de fermeture facultative.
class ActionSheetHandle extends StatelessWidget {
  final VoidCallback? onClose;
  const ActionSheetHandle({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Center(
          child: Container(
            width: 42.w,
            height: 4.h,
            margin: EdgeInsets.only(bottom: 14.h),
            decoration: BoxDecoration(
              color: AppColors.textSecondary(context).withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        ),
        if (onClose != null)
          Positioned(
            right: 0,
            top: -4,
            child: _BannerIconButton(
              icon: Icons.close_rounded,
              color: AppColors.textSecondary(context),
              onTap: onClose!,
            ),
          ),
      ],
    );
  }
}

/// En-tête d'une feuille d'action : avatar + nom + pastille d'état.
class ActionSheetHeader extends StatelessWidget {
  final String avatarUrl;
  final String name;
  final String? roleLabel;
  final String statusLabel;
  final IconData statusIcon;
  final Color tone;
  final Widget? trailing;

  const ActionSheetHeader({
    super.key,
    required this.name,
    required this.tone,
    required this.statusLabel,
    required this.statusIcon,
    this.avatarUrl = '',
    this.roleLabel,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 27.r,
          backgroundColor: tone.withValues(alpha: dark ? 0.28 : 0.14),
          backgroundImage: avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(avatarUrl, maxWidth: 200)
              : null,
          child: avatarUrl.isEmpty
              ? Icon(Icons.person,
                  color: AppColors.accentOn(context, tone), size: 27.sp)
              : null,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PoppinsText(
                text: name,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 6.h),
              Wrap(
                spacing: 6.w,
                runSpacing: 4.h,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ActionStatusPill(
                    label: statusLabel,
                    icon: statusIcon,
                    tone: tone,
                  ),
                  if (roleLabel != null && roleLabel!.isNotEmpty)
                    ActionStatusPill(
                      label: roleLabel!,
                      tone: AppColors.textSecondary(context),
                      muted: true,
                    ),
                ],
              ),
            ],
          ),
        ),
        if (trailing != null) ...[SizedBox(width: 8.w), trailing!],
      ],
    );
  }
}

/// Pastille d'état (feuilles d'action).
class ActionStatusPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color tone;
  final bool muted;

  const ActionStatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final alpha = muted ? (dark ? 0.20 : 0.10) : (dark ? 0.30 : 0.14);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(9.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.sp, color: AppColors.accentOn(context, tone)),
            SizedBox(width: 4.w),
          ],
          PoppinsText(
            text: label,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.accentOn(context, tone),
          ),
        ],
      ),
    );
  }
}

/// Ligne de récapitulatif d'une feuille d'action (date, service, animal, prix).
class ActionSheetRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? tone;
  final bool strong;

  const ActionSheetRow({
    super.key,
    required this.icon,
    required this.text,
    this.tone,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = tone == null
        ? AppColors.textSecondary(context)
        : AppColors.accentOn(context, tone!);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1.h),
            child: Icon(icon, size: 17.sp, color: accent),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: InterText(
              text: text,
              fontSize: 13,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              color: strong
                  ? (tone ?? AppColors.textPrimary(context))
                  : AppColors.textPrimary(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Titre centré d'une feuille d'action.
class ActionSheetTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color tone;
  final IconData? icon;

  const ActionSheetTitle({
    super.key,
    required this.title,
    required this.tone,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Center(
            child: Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: dark ? 0.28 : 0.14),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: tone, size: 28.sp),
            ),
          ),
          SizedBox(height: 12.h),
        ],
        PoppinsText(
          text: title,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(context),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          SizedBox(height: 5.h),
          InterText(
            text: subtitle!,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary(context),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
