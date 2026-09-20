// v573 — kit partagé des feuilles, listes, dialogues et états de la PawMap
// (lot 2 : `alerts_screen.dart` + `pawspot_sheets.dart`).
//
// DESIGN UNIQUEMENT. Aucune logique produit ici : ce fichier ne contient que
// des briques de rendu, réutilisées par les deux écrans du lot pour supprimer
// les `ListTile` / `AlertDialog` Material bruts et les `circular(12|14)`
// hérités des premières versions.
//
// Règles suivies (design 567-571) :
//   · cartes coins 18-22 sur `AppColors.card(context)`, filet
//     `AppColors.divider(context)`, ombre `AppColors.cardShadow(context)` ;
//   · titres `PoppinsText`, textes `InterText` ;
//   · boutons `CustomButton` (kit) — jamais d'`ElevatedButton` brut ;
//   · rangées de choix « maison » : icône dans un rond teinté + libellé +
//     coche, à la place de `ListTile` / `RadioListTile` ;
//   · feuilles : poignée, coins 24, `appBottomInset(context)` — rappel :
//     `showModalBottomSheet(useSafeArea: true)` ne protège PAS le bas ;
//   · couleurs uniquement via les helpers contextuels d'`AppColors`
//     (`accentOn` pour qu'une couleur de marque reste lisible en sombre).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

// ════════════════════════════════════════════════════════════════════════════
// FEUILLES
// ════════════════════════════════════════════════════════════════════════════

/// Poignée d'une feuille modale (barre arrondie centrée).
class MapSheetHandle extends StatelessWidget {
  const MapSheetHandle({super.key, this.bottomSpacing});

  final double? bottomSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing ?? 12.h),
      child: Center(
        child: Container(
          width: 42.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: AppColors.divider(context),
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
      ),
    );
  }
}

/// En-tête d'une feuille : emoji ou icône dans un rond teinté, titre
/// `PoppinsText`, sous-titre optionnel et croix de fermeture optionnelle.
class MapSheetTitle extends StatelessWidget {
  const MapSheetTitle({
    super.key,
    required this.title,
    this.emoji,
    this.icon,
    this.tint,
    this.subtitle,
    this.onClose,
    this.fontSize,
  });

  final String title;
  final String? emoji;
  final IconData? icon;
  final Color? tint;
  final String? subtitle;
  final VoidCallback? onClose;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final Color tone = AppColors.accentOn(
      context,
      tint ?? AppColors.primaryColor,
    );
    Widget? lead;
    if (emoji != null) {
      lead = Text(emoji!, style: TextStyle(fontSize: 20.sp));
    } else if (icon != null) {
      lead = Container(
        width: 38.w,
        height: 38.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tone.withValues(alpha: _isDark(context) ? 0.22 : 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19.sp, color: tone),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (lead != null) ...[lead, SizedBox(width: 10.w)],
            Expanded(
              child: PoppinsText(
                text: title,
                fontSize: fontSize ?? 17.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClose != null)
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 20.sp,
                  color: AppColors.textSecondary(context),
                ),
                tooltip: 'common_close'.tr,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 34.w, minHeight: 34.h),
                onPressed: onClose,
              ),
          ],
        ),
        if (subtitle != null) ...[
          SizedBox(height: 4.h),
          InterText(
            text: subtitle!,
            fontSize: 12.sp,
            color: AppColors.textSecondary(context),
            height: 1.35,
          ),
        ],
      ],
    );
  }
}

/// Carte du nouveau design : coins 18 (réglables 18-22), surface `card`,
/// filet `divider` et ombre `cardShadow`. Cliquable si [onTap] est fourni.
class MapSheetCard extends StatelessWidget {
  const MapSheetCard({
    super.key,
    required this.child,
    this.padding,
    this.radius,
    this.onTap,
    this.borderColor,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(radius ?? 18.r);
    final Widget body = Container(
      padding: padding ?? EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color ?? AppColors.card(context),
        borderRadius: br,
        border: Border.all(color: borderColor ?? AppColors.divider(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: br, onTap: onTap, child: body),
    );
  }
}

/// Rangée de choix « maison » : icône dans un rond teinté + libellé (+ valeur
/// courante) + coche ou chevron. Remplace `ListTile` / `RadioListTile`.
class MapChoiceRow extends StatelessWidget {
  const MapChoiceRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.tint,
    this.selected = false,
    this.showChevron = false,
    this.onTap,
    this.trailing,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Color? tint;
  final bool selected;
  final bool showChevron;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Color tone = AppColors.accentOn(
      context,
      tint ?? AppColors.primaryColor,
    );
    final BorderRadius br = BorderRadius.circular(16.r);
    final double disc = dense ? 34.w : 38.w;

    Widget? end = trailing;
    end ??= selected
        ? Icon(Icons.check_circle_rounded, size: 20.sp, color: tone)
        : (showChevron
            ? Icon(
                Icons.chevron_right_rounded,
                size: 20.sp,
                color: AppColors.textTertiary(context),
              )
            : null);

    final Widget body = Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10.w,
        vertical: dense ? 8.h : 10.h,
      ),
      decoration: BoxDecoration(
        color: selected
            ? tone.withValues(alpha: _isDark(context) ? 0.16 : 0.07)
            : Colors.transparent,
        borderRadius: br,
      ),
      child: Row(
        children: [
          Container(
            width: disc,
            height: disc,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: _isDark(context) ? 0.22 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: dense ? 17.sp : 19.sp, color: tone),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InterText(
                  text: label,
                  fontSize: dense ? 13.sp : 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (value != null && value!.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  InterText(
                    text: value!,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (end != null) ...[SizedBox(width: 8.w), end],
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: br, onTap: onTap, child: body),
    );
  }
}

/// Une option de [showMapChoiceSheet].
class MapChoiceOption<T> {
  const MapChoiceOption({
    required this.value,
    required this.label,
    required this.icon,
    this.description,
    this.tint,
  });

  final T value;
  final String label;
  final IconData icon;
  final String? description;
  final Color? tint;
}

/// Feuille de choix unique (rayon, période…) : poignée, coins 24, rangées
/// maison, dégagement bas garanti. Renvoie la valeur choisie, ou `null`.
Future<T?> showMapChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required List<MapChoiceOption<T>> options,
  T? selected,
  String? subtitle,
  IconData? titleIcon,
  Color? tint,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: AppColors.card(ctx),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      // `useSafeArea` ne protège pas le bas d'une feuille : on ajoute
      // nous-mêmes l'inset (iOS = réel, Android = 48 mini).
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h + appBottomInset(ctx)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MapSheetHandle(),
          MapSheetTitle(
            title: title,
            subtitle: subtitle,
            icon: titleIcon,
            tint: tint,
          ),
          SizedBox(height: 8.h),
          ...options.map(
            (o) => MapChoiceRow(
              icon: o.icon,
              label: o.label,
              value: o.description,
              tint: o.tint ?? tint,
              selected: o.value == selected,
              onTap: () => Navigator.of(ctx).pop(o.value),
            ),
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// DIALOGUES
// ════════════════════════════════════════════════════════════════════════════

/// Coque commune des dialogues du lot : voile sombre, carte coins 22 sur
/// `AppColors.card`, disque teinté + titre `PoppinsText`.
class MapDialogShell extends StatelessWidget {
  const MapDialogShell({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.tint,
    this.subtitle,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Color? tint;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final bool dark = _isDark(context);
    final Color tone = AppColors.accentOn(
      context,
      tint ?? AppColors.primaryColor,
    );
    return Material(
      color: Colors.transparent,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: dark ? 0.62 : 0.38),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 380.w),
              child: Container(
                padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 16.h),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(22.r),
                  border: dark
                      ? Border.all(color: AppColors.divider(context))
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.5 : 0.16),
                      blurRadius: 28,
                      spreadRadius: -8,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (icon != null)
                      Center(
                        child: Container(
                          width: 52.w,
                          height: 52.w,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                tone.withValues(alpha: dark ? 0.22 : 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 26.sp, color: tone),
                        ),
                      ),
                    if (icon != null) SizedBox(height: 12.h),
                    PoppinsText(
                      text: title,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                      textAlign: TextAlign.center,
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 6.h),
                      InterText(
                        text: subtitle!,
                        fontSize: 13.sp,
                        height: 1.45,
                        color: AppColors.textSecondary(context),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    SizedBox(height: 16.h),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Champ de saisie du lot (recherche, commentaire…) : surface `scaffold`,
/// coins 14, filet `divider`, focus à la couleur de marque.
InputDecoration mapFieldDecoration(
  BuildContext context, {
  String? hint,
  Widget? prefixIcon,
  Color? focusTint,
  bool dense = true,
}) {
  final Color tone = AppColors.accentOn(
    context,
    focusTint ?? AppColors.primaryColor,
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 13.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary(context),
    ),
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: AppColors.scaffold(context),
    isDense: dense,
    counterText: '',
    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: BorderSide(color: AppColors.divider(context)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: BorderSide(color: AppColors.divider(context)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: BorderSide(color: tone, width: 1.5),
    ),
  );
}

/// Dialogue de saisie d'une ligne de texte.
///
/// Renvoie `null` si l'utilisateur ferme sans valider, la chaîne saisie
/// sinon — la chaîne VIDE correspond au bouton « effacer ».
Future<String?> showMapTextInputDialog({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  String? hint,
  String? subtitle,
  String initialValue = '',
  String? clearLabel,
  IconData icon = Icons.search_rounded,
  Color? tint,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _MapTextInputDialog(
      title: title,
      subtitle: subtitle,
      icon: icon,
      tint: tint,
      hint: hint,
      initialValue: initialValue,
      confirmLabel: confirmLabel,
      clearLabel: clearLabel,
    ),
  );
}

/// Le `TextEditingController` appartient au widget du dialogue, PAS à la
/// fonction appelante : le dialogue continue de se reconstruire pendant son
/// animation de sortie, donc un `dispose()` posé sur la fin du `showDialog`
/// déclenchait « A TextEditingController was used after being disposed ».
class _MapTextInputDialog extends StatefulWidget {
  const _MapTextInputDialog({
    required this.title,
    required this.confirmLabel,
    required this.icon,
    this.subtitle,
    this.tint,
    this.hint,
    this.initialValue = '',
    this.clearLabel,
  });

  final String title;
  final String confirmLabel;
  final IconData icon;
  final String? subtitle;
  final Color? tint;
  final String? hint;
  final String initialValue;
  final String? clearLabel;

  @override
  State<_MapTextInputDialog> createState() => _MapTextInputDialogState();
}

class _MapTextInputDialogState extends State<_MapTextInputDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapDialogShell(
      title: widget.title,
      subtitle: widget.subtitle,
      icon: widget.icon,
      tint: widget.tint,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
            decoration: mapFieldDecoration(
              context,
              hint: widget.hint,
              focusTint: widget.tint,
              prefixIcon: Icon(
                widget.icon,
                size: 18.sp,
                color: AppColors.textSecondary(context),
              ),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          SizedBox(height: 18.h),
          CustomButton(
            width: double.infinity,
            height: 50.h,
            radius: 14.r,
            title: widget.confirmLabel,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            bgColor: widget.tint ?? AppColors.primaryColor,
            textColor: Colors.white,
            onTap: () => Navigator.of(context).pop(_ctrl.text.trim()),
          ),
          if (widget.clearLabel != null) ...[
            SizedBox(height: 10.h),
            CustomButton(
              width: double.infinity,
              height: 50.h,
              radius: 14.r,
              title: widget.clearLabel!,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              bgColor: AppColors.scaffold(context),
              textColor: AppColors.textPrimary(context),
              borderColor: AppColors.divider(context),
              onTap: () => Navigator.of(context).pop(''),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialogue d'information : un bloc de texte (éventuellement long et
/// technique) sur une surface lisible + un bouton de fermeture du kit.
Future<void> showMapInfoDialog({
  required BuildContext context,
  required String title,
  required String body,
  String? closeLabel,
  IconData icon = Icons.info_outline_rounded,
  Color? tint,
  bool monospace = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => MapDialogShell(
      title: title,
      icon: icon,
      tint: tint,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.42,
            ),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.scaffold(ctx),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.divider(ctx)),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                body,
                style: TextStyle(
                  fontFamily: monospace ? 'monospace' : null,
                  fontSize: monospace ? 10.sp : 13.sp,
                  height: 1.45,
                  color: AppColors.textPrimary(ctx),
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          CustomButton(
            width: double.infinity,
            height: 50.h,
            radius: 14.r,
            title: closeLabel ?? 'common_close'.tr,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            bgColor: tint ?? AppColors.primaryColor,
            textColor: Colors.white,
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// CHARGEMENT — squelettes simples
// ════════════════════════════════════════════════════════════════════════════

/// Bloc gris neutre d'un squelette de chargement.
class MapSkeletonBox extends StatelessWidget {
  const MapSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius,
    this.circle = false,
  });

  final double? width;
  final double? height;
  final double? radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 12.h,
      decoration: BoxDecoration(
        color: AppColors.mediaPlaceholder(context),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius ?? 8.r),
      ),
    );
  }
}

/// Squelette d'une carte d'alerte / de spot : vignette carrée + 3 lignes.
class MapCardSkeleton extends StatelessWidget {
  const MapCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return MapSheetCard(
      padding: EdgeInsets.all(12.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MapSkeletonBox(width: 60.w, height: 60.w, radius: 12.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MapSkeletonBox(width: 120.w, height: 12.h),
                SizedBox(height: 8.h),
                MapSkeletonBox(height: 10.h),
                SizedBox(height: 6.h),
                MapSkeletonBox(width: 90.w, height: 10.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste de squelettes de cartes, pour remplacer un `CircularProgressIndicator`
/// centré pendant le premier chargement d'une liste.
class MapCardSkeletonList extends StatelessWidget {
  const MapCardSkeletonList({super.key, this.count = 4, this.padding});

  final int count;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding ?? EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
      itemCount: count,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (_, __) => const MapCardSkeleton(),
    );
  }
}

/// Squelette compact d'une ligne de texte (commentaires…).
class MapLineSkeletonList extends StatelessWidget {
  const MapLineSkeletonList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(
        count,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MapSkeletonBox(width: 22.w, height: 22.w, circle: true),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MapSkeletonBox(width: 80.w, height: 9.h),
                    SizedBox(height: 6.h),
                    MapSkeletonBox(height: 9.h),
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

// ════════════════════════════════════════════════════════════════════════════
// ÉTATS VIDES
// ════════════════════════════════════════════════════════════════════════════

/// État vide soigné : disque teinté + icône, titre, message, action optionnelle.
class MapEmptyBlock extends StatelessWidget {
  const MapEmptyBlock({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.tint,
    this.emoji,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color? tint;
  final String? emoji;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color tone = AppColors.accentOn(
      context,
      tint ?? AppColors.primaryColor,
    );
    final double disc = compact ? 72.w : 96.w;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: disc,
              height: disc,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tone.withValues(alpha: _isDark(context) ? 0.18 : 0.09),
              ),
            ),
            Icon(icon, size: compact ? 32.sp : 44.sp, color: tone),
            if (emoji != null)
              Positioned(
                bottom: 0,
                right: compact ? 6.w : 10.w,
                child: Text(emoji!, style: TextStyle(fontSize: 18.sp)),
              ),
          ],
        ),
        SizedBox(height: 14.h),
        PoppinsText(
          text: title,
          fontSize: compact ? 15.sp : 17.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(context),
          textAlign: TextAlign.center,
        ),
        if (message != null && message!.isNotEmpty) ...[
          SizedBox(height: 6.h),
          InterText(
            text: message!,
            fontSize: 13.sp,
            height: 1.45,
            color: AppColors.textSecondary(context),
            textAlign: TextAlign.center,
          ),
        ],
        if (action != null) ...[SizedBox(height: 16.h), action!],
      ],
    );
  }
}
