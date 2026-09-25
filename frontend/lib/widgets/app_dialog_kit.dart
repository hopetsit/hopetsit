// v573 — lot 3 : kit de dialogues « maison », pour remplacer les derniers
// `AlertDialog` Material bruts (chat, blocage, thème, changement de profil,
// suppression d'animal).
//
// DESIGN UNIQUEMENT : aucun appelant ne change de logique, seul le rendu
// change. Le patron est celui de `custom_confirmation_dialog.dart` et du
// dialogue déjà refait dans `sitter_individual_chat_screen.dart` :
//   · carte `AppColors.card(context)`, coins 22, voile sombre du barrier ;
//   · disque teinté 56 px + icône en tête ;
//   · titre `PoppinsText`, corps `InterText`, tout centré ;
//   · boutons du kit (`CustomButton`) empilés pleine largeur : principal plein
//     (rouge `AppColors.errorColor` quand l'action est destructive), puis
//     secondaire « contour ».
//
// Trois pièces publiques :
//   · [showAppConfirmDialog] — confirmation Oui/Non → `Future<bool?>` ;
//   · [AppDialogCard] — la carte seule, pour un dialogue à contenu libre
//     (rangées de choix du thème, par exemple) ;
//   · [AppChoiceRow] — rangée de choix maison (style du kit Profil) avec une
//     pastille radio DESSINÉE à l'accent du rôle, en remplacement des
//     `RadioListTile` / `ListTile` Material.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

/// Indicateur d'attente thémé (remplace les `CircularProgressIndicator` nus,
/// qui prennent la couleur primaire du thème Material et non celle du rôle).
class AppSpinner extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;
  const AppSpinner({super.key, this.size = 22, this.color, this.strokeWidth = 2.4});

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? AppColors.accentOn(context, AppColors.activeRoleAccent());
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(c),
      ),
    );
  }
}

/// Carte de dialogue « maison ». À poser dans un [showDialog] ; le contenu
/// libre ([content]) s'insère entre le message et les boutons.
class AppDialogCard extends StatelessWidget {
  final String title;
  final String? message;
  final IconData? icon;

  /// Couleur de rôle. Par défaut l'accent du rôle actif.
  final Color? accent;

  /// Action destructive : disque et bouton principal en rouge.
  final bool destructive;

  final Widget? content;

  /// Boutons empilés (déjà espacés par la carte).
  final List<Widget> actions;

  const AppDialogCard({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.accent,
    this.destructive = false,
    this.content,
    this.actions = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color tint = AppColors.accentOn(
      context,
      destructive
          ? AppColors.errorColor
          : (accent ?? AppColors.activeRoleAccent()),
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 24.h),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 380.w),
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 16.h),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(22.r),
              border: dark
                  ? Border.all(color: AppColors.dividerDark, width: 1)
                  : null,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.shadow(dark ? 0.5 : 0.16),
                  blurRadius: 26,
                  spreadRadius: -8,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Container(
                    width: 56.w,
                    height: 56.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: dark ? 0.22 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: tint, size: 27.sp),
                  ),
                  SizedBox(height: 14.h),
                ],
                PoppinsText(
                  text: title,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (message != null && message!.trim().isNotEmpty) ...<Widget>[
                  SizedBox(height: 8.h),
                  InterText(
                    text: message!,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                    color: AppColors.textSecondary(context),
                    textAlign: TextAlign.center,
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (content != null) ...<Widget>[
                  SizedBox(height: 16.h),
                  content!,
                ],
                if (actions.isNotEmpty) SizedBox(height: 18.h),
                for (int i = 0; i < actions.length; i++) ...<Widget>[
                  if (i > 0) SizedBox(height: 10.h),
                  actions[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton principal d'un dialogue (plein, couleur du rôle ou rouge).
class AppDialogPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? accent;
  final bool destructive;
  final bool busy;
  const AppDialogPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.accent,
    this.destructive = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = destructive
        ? AppColors.errorColor
        : (accent ?? AppColors.activeRoleAccent());
    return CustomButton(
      width: double.infinity,
      height: 50.h,
      radius: 14.r,
      title: label,
      fontSize: 15.sp,
      fontWeight: FontWeight.w700,
      bgColor: bg,
      textColor: Colors.white,
      onTap: busy ? null : onTap,
      // v584 (25/09, point 6) — « deux roues qui tournent » : le kit dessine
      // déjà la roue de chargement dans son disque ; on ne lui en superpose
      // plus une seconde.
      isLoading: busy,
    );
  }
}

/// Bouton secondaire d'un dialogue (contour discret).
class AppDialogSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const AppDialogSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      width: double.infinity,
      height: 50.h,
      radius: 14.r,
      title: label,
      fontSize: 15.sp,
      fontWeight: FontWeight.w600,
      bgColor: Colors.transparent,
      borderColor: AppColors.divider(context),
      textColor: AppColors.textSecondaryStrong(context),
      onTap: onTap,
    );
  }
}

/// Confirmation moderne, en remplacement d'`AlertDialog`.
///
/// Renvoie `true` (confirmé), `false` (annulé) ou `null` (fermé en tapant à
/// côté). Quand [onConfirm] est fourni, il est exécuté SANS fermer le
/// dialogue : le bouton principal passe en attente (spinner) et la fermeture
/// n'a lieu qu'au retour du futur — c'est le comportement attendu par
/// « Mes profils » (changement de rôle).
Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  IconData? icon,
  Color? accent,
  String? busyMessage,
  Future<void> Function()? onConfirm,
  bool barrierDismissible = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext ctx) => _AppConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      icon: icon,
      accent: accent,
      busyMessage: busyMessage,
      onConfirm: onConfirm,
    ),
  );
}

class _AppConfirmDialog extends StatefulWidget {
  const _AppConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    required this.icon,
    required this.accent,
    required this.busyMessage,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String? cancelLabel;
  final bool destructive;
  final IconData? icon;
  final Color? accent;
  final String? busyMessage;
  final Future<void> Function()? onConfirm;

  @override
  State<_AppConfirmDialog> createState() => _AppConfirmDialogState();
}

class _AppConfirmDialogState extends State<_AppConfirmDialog> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return;
    if (widget.destructive) HapticFeedback.mediumImpact();
    if (widget.onConfirm == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onConfirm!();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        // v573 — `onConfirm` peut avoir remplacé toute la pile (changement de
        // rôle = Get.offAll) : le dialogue n'est alors plus une route active
        // et un pop() ferait planter le Navigator (`_history.isNotEmpty`).
        final ModalRoute<dynamic>? route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).pop(true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String body = _busy && (widget.busyMessage ?? '').isNotEmpty
        ? widget.busyMessage!
        : widget.message;
    return PopScope(
      // Pendant l'attente (changement de rôle…) on ne laisse pas le retour
      // système fermer le dialogue sous l'opération en cours.
      canPop: !_busy,
      child: AppDialogCard(
        title: widget.title,
        message: body,
        icon: widget.icon,
        accent: widget.accent,
        destructive: widget.destructive,
        actions: <Widget>[
          AppDialogPrimaryButton(
            label: widget.confirmLabel,
            accent: widget.accent,
            destructive: widget.destructive,
            busy: _busy,
            onTap: _confirm,
          ),
          if ((widget.cancelLabel ?? '').isNotEmpty)
            AppDialogSecondaryButton(
              label: widget.cancelLabel!,
              onTap: _busy ? null : () => Navigator.of(context).pop(false),
            ),
        ],
      ),
    );
  }
}

/// Rangée de choix maison (thème, langue…), dans le style du kit Profil :
/// pastille d'icône ou drapeau, libellé, et pastille radio DESSINÉE à
/// l'accent du rôle. Remplace `RadioListTile` / `ListTile`.
class AppChoiceRow extends StatelessWidget {
  final String label;

  /// Emoji / drapeau affiché à gauche (sélecteur de langue).
  final String? leadingText;

  /// Icône affichée dans une pastille teintée (sélecteur de thème).
  final IconData? icon;

  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const AppChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.leadingText,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color on = AppColors.accentOn(context, accent);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
          decoration: BoxDecoration(
            color: selected
                ? on.withValues(alpha: dark ? 0.16 : 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: selected
                  ? on.withValues(alpha: 0.45)
                  : AppColors.divider(context).withValues(alpha: 0.7),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Container(
                  width: 34.w,
                  height: 34.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on.withValues(alpha: dark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(icon, size: 17.sp, color: on),
                ),
                SizedBox(width: 10.w),
              ] else if ((leadingText ?? '').isNotEmpty) ...<Widget>[
                Text(leadingText!, style: TextStyle(fontSize: 17.sp)),
                SizedBox(width: 10.w),
              ],
              Expanded(
                child: InterText(
                  text: label,
                  fontSize: 14.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              _ChoiceRadio(selected: selected, color: on),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille radio dessinée (aucun widget Material) : anneau à l'accent du
/// rôle quand c'est coché, filet gris sinon.
class _ChoiceRadio extends StatelessWidget {
  const _ChoiceRadio({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 21.w,
      height: 21.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? color : AppColors.divider(context),
          width: selected ? 2 : 1.6,
        ),
      ),
      child: selected
          ? Container(
              width: 11.w,
              height: 11.w,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          : null,
    );
  }
}
