// v569 — « Post card kit » : primitives de DESIGN partagées par la carte
// d'annonce d'un propriétaire (PetPostCard) telle que la voient le gardien et
// le promeneur, et par les blocs qu'elle affiche.
//
// Règles :
//  • design uniquement — aucun de ces widgets ne connaît l'API ni les
//    contrôleurs ; ils reçoivent un callback et un libellé déjà traduit ;
//  • perf : la carte vit dans de longues listes sur téléphones modestes —
//    pas de BackdropFilter, pas d'animation permanente, `const` partout où
//    c'est possible, ombres à blur très court (cf. AppColors.cardShadow) ;
//  • accessibilité : toute cible tactile fait au moins 44 px.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Jetons de design de la carte d'annonce (rayons, cibles tactiles).
class PostCardKit {
  const PostCardKit._();

  /// Coins de la carte (Daniel v569 : « coins 22 »).
  static const double cardRadius = 22;

  /// Coins des blocs internes (essentiel, description, gain…).
  static const double blockRadius = 16;

  /// Coins des pilules d'action.
  static const double pillRadius = 24;

  /// Cible tactile minimale d'un bouton-icône.
  static const double tapTarget = 44;
}

/// Petite pastille « type de demande » (garde / promenade / visite…), posée à
/// droite de l'en-tête propriétaire.
class PostTypeChip extends StatelessWidget {
  const PostTypeChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 132.w),
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 5.w),
          Flexible(
            child: InterText(
              text: label,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w700,
              color: color,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une puce à icône du bloc « l'essentiel » : pastille ronde + libellé discret
/// + valeur lisible d'un coup d'œil. Remplace les anciennes colonnes serrées
/// (qui débordaient en allemand et en polonais).
class PostBullet extends StatelessWidget {
  const PostBullet({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28.w,
            height: 28.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15.sp, color: accent),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: label,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.h),
                InterText(
                  text: value,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.textPrimary(context),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Texte clampé à [maxLines] avec un « Voir plus » / « Voir moins » affiché
/// UNIQUEMENT quand le texte déborde vraiment (mesuré au layout).
class PostExpandableText extends StatefulWidget {
  const PostExpandableText({
    super.key,
    required this.text,
    required this.moreLabel,
    required this.lessLabel,
    required this.accent,
    this.maxLines = 3,
    this.fontSize,
  });

  final String text;
  final String moreLabel;
  final String lessLabel;
  final Color accent;
  final int maxLines;
  final double? fontSize;

  @override
  State<PostExpandableText> createState() => _PostExpandableTextState();
}

class _PostExpandableTextState extends State<PostExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.fontSize ?? 12.5.sp;
    final style = GoogleFonts.inter(
      fontSize: size,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary(context),
    ).copyWith(fontFamilyFallback: cjkFontFallback);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : widget.maxLines,
              overflow:
                  _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
            ),
            if (overflows) ...[
              SizedBox(height: 4.h),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(8.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: InterText(
                    text: _expanded ? widget.lessLabel : widget.moreLabel,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: widget.accent,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Bouton-icône discret de la rangée basse (j'aime / partager), avec un
/// compteur facultatif posé à côté. Cible tactile 44 px garantie.
class PostIconAction extends StatelessWidget {
  const PostIconAction({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    this.count,
    this.isActive = false,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final int? count;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isActive ? color : AppColors.textSecondary(context);
    final n = count ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: tooltip,
          child: Material(
            color: isActive
                ? color.withValues(alpha: 0.10)
                : Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: PostCardKit.tapTarget.w,
                height: PostCardKit.tapTarget.w,
                child: Icon(icon, size: 21.sp, color: fg),
              ),
            ),
          ),
        ),
        if (n > 0) ...[
          SizedBox(width: 2.w),
          InterText(
            text: '$n',
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ],
      ],
    );
  }
}

/// Les 4 tenues de la pilule d'action principale.
enum PostPillStyle {
  /// Pleine, couleur du rôle — action principale disponible.
  filled,

  /// Contour couleur du rôle — état « déjà fait » (demande envoyée).
  outlined,

  /// Grise et inerte — état indisponible (annonce déjà réservée).
  ghost,
}

/// Pilule d'action : bouton principal du prestataire et boutons du
/// propriétaire parlent le même langage.
///
/// [isLoading] affiche un petit indicateur DANS la pilule ; l'appelant passe
/// alors `onTap: null` pour la rendre non cliquable.
class PostPill extends StatelessWidget {
  const PostPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.onTap,
    this.style = PostPillStyle.filled,
    this.isLoading = false,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;
  final PostPillStyle style;
  final bool isLoading;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final Color bg;
    final Color fg;
    final Color border;
    switch (style) {
      case PostPillStyle.filled:
        bg = disabled && !isLoading ? color.withValues(alpha: 0.45) : color;
        fg = Colors.white;
        border = Colors.transparent;
        break;
      case PostPillStyle.outlined:
        bg = color.withValues(alpha: 0.06);
        fg = color;
        border = color.withValues(alpha: 0.55);
        break;
      case PostPillStyle.ghost:
        // Audit mode sombre — le gris clair à 35 % formait une pilule claire
        // sur la carte sombre, et son libellé gris s'y perdait.
        bg = Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.grey300Color.withValues(alpha: 0.35);
        fg = AppColors.textTertiary(context);
        border = Colors.transparent;
        break;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(PostCardKit.pillRadius.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PostCardKit.pillRadius.r),
        child: Container(
          constraints: BoxConstraints(
            minHeight: (dense ? 40 : PostCardKit.tapTarget).w,
          ),
          padding: EdgeInsets.symmetric(horizontal: dense ? 14.w : 16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PostCardKit.pillRadius.r),
            border: Border.all(color: border, width: 1.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading) ...[
                SizedBox(
                  width: 15.w,
                  height: 15.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(fg),
                  ),
                ),
                SizedBox(width: 8.w),
              ] else if (icon != null) ...[
                Icon(icon, size: 17.sp, color: fg),
                SizedBox(width: 7.w),
              ],
              Flexible(
                child: InterText(
                  text: label,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton secondaire (contour discret) — « Voir les animaux », « Modifier ».
class PostSecondaryButton extends StatelessWidget {
  const PostSecondaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final fg = disabled ? AppColors.textTertiary(context) : color;
    return Material(
      color: disabled
          ? AppColors.grey300Color.withValues(alpha: 0.18)
          : color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(PostCardKit.pillRadius.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PostCardKit.pillRadius.r),
        child: Container(
          constraints: BoxConstraints(minHeight: PostCardKit.tapTarget.w),
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PostCardKit.pillRadius.r),
            border: Border.all(
              color: disabled
                  ? AppColors.grey300Color
                  : color.withValues(alpha: 0.30),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16.sp, color: fg),
              SizedBox(width: 7.w),
              Flexible(
                child: InterText(
                  text: label,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Action destructive : texte rouge, sans fond — jamais un gros bouton plein.
class PostDestructiveButton extends StatelessWidget {
  const PostDestructiveButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(PostCardKit.pillRadius.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PostCardKit.pillRadius.r),
        child: Container(
          constraints: BoxConstraints(minHeight: PostCardKit.tapTarget.w),
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16.sp, color: AppColors.errorColor),
              SizedBox(width: 6.w),
              Flexible(
                child: InterText(
                  text: label,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.errorColor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bloc encadré discret (l'essentiel, description, informations…).
class PostBlock extends StatelessWidget {
  const PostBlock({
    super.key,
    required this.child,
    required this.accent,
    this.title,
    this.titleIcon,
    this.trailing,
    this.background,
    this.borderColor,
  });

  final Widget child;
  final Color accent;
  final String? title;
  final IconData? titleIcon;
  final Widget? trailing;
  final Color? background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final hasTitle = (title ?? '').trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: background ?? accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(PostCardKit.blockRadius.r),
        border: Border.all(
          color: borderColor ?? accent.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTitle) ...[
            Row(
              children: [
                if (titleIcon != null) ...[
                  Icon(titleIcon, size: 15.sp, color: accent),
                  SizedBox(width: 7.w),
                ],
                Expanded(
                  child: InterText(
                    text: title!,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            SizedBox(height: 8.h),
          ],
          child,
        ],
      ),
    );
  }
}
