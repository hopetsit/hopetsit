// v567 — Daniel : « si quelqu'un supprime son compte, demander 3 raisons et que
// ça me le dise dans l'admin ».
//
// Feuille « Avant de partir… » affichée AVANT le dialogue de confirmation
// existant : jusqu'à 3 raisons cochées (au moins 1 obligatoire) + un
// commentaire libre facultatif (300 caractères). Les identifiants de raison
// sont STABLES et partagés avec le serveur (models/AccountDeletion.js) ; seuls
// les libellés sont traduits (localization/v565/delete567_i18n.dart).
//
// Règles maison respectées ici : aucun `Obx`, aucun `CrossAxisAlignment.stretch`
// avec un `Expanded` dans un scroll, tous les textes via `.tr`.

import 'package:flutter/material.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Identifiants de raison acceptés par le serveur, dans l'ordre d'affichage.
/// NE PAS renommer : `backend/src/models/AccountDeletion.js` filtre sur cette
/// liste et l'admin les regroupe par identifiant.
const List<String> kDeleteAccountReasonIds = <String>[
  'no_providers_nearby',
  'no_clients',
  'too_expensive',
  'too_complicated',
  'bugs',
  'notifications_too_many',
  'found_other_app',
  'privacy',
  'no_longer_need',
  'temporary_break',
  'other',
];

/// Nombre maximum de raisons cochables (consigne : 3).
const int kDeleteAccountMaxReasons = 3;

/// Longueur maximale du commentaire libre (alignée sur le serveur).
const int kDeleteAccountMaxComment = 300;

/// Ce que l'utilisateur a répondu dans la feuille.
class DeleteAccountReasons {
  const DeleteAccountReasons({required this.reasons, required this.comment});

  final List<String> reasons;
  final String comment;
}

/// Ouvre la feuille « Avant de partir… ».
///
/// Renvoie `null` si l'utilisateur annule (ou ferme la feuille), sinon les
/// raisons cochées (1 à 3) et le commentaire éventuel. L'appelant enchaîne
/// ensuite sur le dialogue de confirmation EXISTANT.
Future<DeleteAccountReasons?> showDeleteAccountReasonsSheet(
  BuildContext context, {
  Color? accent,
}) {
  final Color resolved = accent ?? AppColors.activeRoleAccent();
  return showModalBottomSheet<DeleteAccountReasons>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _DeleteAccountReasonsSheet(accent: resolved),
  );
}

class _DeleteAccountReasonsSheet extends StatefulWidget {
  const _DeleteAccountReasonsSheet({required this.accent});

  final Color accent;

  @override
  State<_DeleteAccountReasonsSheet> createState() =>
      _DeleteAccountReasonsSheetState();
}

class _DeleteAccountReasonsSheetState
    extends State<_DeleteAccountReasonsSheet> {
  // Liste (et non Set) : l'ordre des clics est conservé jusqu'au serveur.
  final List<String> _selected = <String>[];
  final TextEditingController _comment = TextEditingController();
  bool _maxHint = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    if (_selected.contains(id)) {
      setState(() {
        _selected.remove(id);
        _maxHint = false;
      });
      return;
    }
    if (_selected.length >= kDeleteAccountMaxReasons) {
      // 4e tentative : petit retour haptique, et rien ne se coche.
      HapticFeedback.mediumImpact();
      setState(() => _maxHint = true);
      return;
    }
    setState(() {
      _selected.add(id);
      _maxHint = false;
    });
  }

  void _submit() {
    if (_selected.isEmpty) return;
    Navigator.of(context).pop(
      DeleteAccountReasons(
        reasons: List<String>.unmodifiable(_selected),
        comment: _comment.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    // ⚠️ Bas d'écran Samsung : `viewPadding.bottom` peut valoir 0 alors que la
    // barre système couvre le bas de l'écran → repli sur une marge fixe.
    // v585 (lot D) — règle unique de l'app : `appBottomInset` (Android = jamais
    // moins de 48 px, même barre de gestes à 20 px ; iOS = inset réel).
    final double bottomInset = appBottomInset(context);

    final double maxHeight = media.size.height * 0.88;
    final bool canContinue = _selected.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.scaffold(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ProfileSheetHandle(),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: 'delete567_title'.tr,
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                    SizedBox(height: 6.h),
                    InterText(
                      text: 'delete567_subtitle'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary(context),
                      maxLines: 3,
                    ),
                    SizedBox(height: 12.h),
                    _CounterPill(
                      accent: widget.accent,
                      count: _selected.length,
                      warn: _maxHint,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
                  children: [
                    for (final id in kDeleteAccountReasonIds) ...[
                      _ReasonTile(
                        label: 'delete567_reason_$id'.tr,
                        selected: _selected.contains(id),
                        accent: widget.accent,
                        onTap: () => _toggle(id),
                      ),
                      SizedBox(height: 10.h),
                    ],
                    SizedBox(height: 6.h),
                    ProfileInput(
                      label: 'delete567_comment_label'.tr,
                      controller: _comment,
                      accent: widget.accent,
                      hint: 'delete567_comment_hint'.tr,
                      maxLines: 3,
                      maxLength: kDeleteAccountMaxComment,
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ProfilePrimaryButton(
                      label: 'delete567_continue'.tr,
                      accent: AppColors.errorColor,
                      onTap: canContinue ? _submit : null,
                    ),
                    SizedBox(height: 8.h),
                    ProfileSecondaryButton(
                      label: 'delete567_cancel'.tr,
                      accent: AppColors.textSecondary(context),
                      onTap: () => Navigator.of(context).pop(),
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

/// Pastille « @n sur 3 sélectionnées » — vire au rouge quand l'utilisateur
/// tente une 4e raison.
class _CounterPill extends StatelessWidget {
  const _CounterPill({
    required this.accent,
    required this.count,
    required this.warn,
  });

  final Color accent;
  final int count;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final Color tone = warn ? AppColors.errorColor : accent;
    final String label = warn
        ? 'delete567_max_reached'.tr
        : 'delete567_counter'.trParams({'n': '$count'});
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: InterText(
        text: label,
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: tone,
        maxLines: 2,
      ),
    );
  }
}

/// Case moderne à cocher (carte pleine largeur, bord teinté quand cochée).
class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.08)
                : AppColors.card(context),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected ? accent : AppColors.divider(context),
              width: selected ? 1.6 : 1.0,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22.w,
                height: 22.w,
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(7.r),
                  border: Border.all(
                    color: selected ? accent : AppColors.greyColor,
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 15.sp, color: Colors.white)
                    : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: InterText(
                  text: label,
                  fontSize: 14.sp,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: AppColors.textPrimary(context),
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
