// v575 — Daniel : « "À propos de moi" et "Langue" doivent être pareils, même
// style, sur les 3 profils — moderne et HD ».
//
// AVANT, les trois écrans « Modifier le profil » divergeaient :
//   • propriétaire : bio sur 4 lignes + un CHAMP TEXTE LIBRE « Langue »
//     (saisie à la main, aucune aide) ;
//   • gardien / promeneur : bio sur 4 lignes + 15 puces de langues.
// Et le libellé « Langue » se confondait avec « Langue de l'app ».
//
// Ici : DEUX widgets partagés, utilisés à l'identique et au même endroit par
// les 3 écrans.
//   • [ProfileAboutField] — présentation (PROPRE à chaque rôle : un gardien et
//     un propriétaire ne se présentent pas pareil) ;
//   • [ProfileLanguageField] — « Langues parlées » (information PARTAGÉE entre
//     les 3 profils et visible par les autres membres), rangée moderne +
//     feuille de sélection multiple.
//
// Aucune logique serveur changée : même champ `bio`, même champ `language`.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/utils/profile_completion.dart' show kProfileBioMinLength;
import 'package:hopetsit/views/profile/widgets/profile_field_widgets.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

/// Présentation libre. Compteur discret + aide qui explique le minimum retenu
/// par la barre « profil complété » (avant, une bio de 5 caractères était
/// enregistrée mais l'élément restait « manquant », sans explication).
class ProfileAboutField extends StatefulWidget {
  final TextEditingController controller;
  final Color accent;
  final FocusNode? focusNode;
  final int maxLines;
  final int maxLength;

  const ProfileAboutField({
    super.key,
    required this.controller,
    required this.accent,
    this.focusNode,
    this.maxLines = 5,
    this.maxLength = 600,
  });

  @override
  State<ProfileAboutField> createState() => _ProfileAboutFieldState();
}

class _ProfileAboutFieldState extends State<ProfileAboutField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final length = widget.controller.text.trim().length;
    final enough = length >= kProfileBioMinLength;
    return Column(
      key: const ValueKey<String>('profile_about_field'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileInput(
          label: 'label_about_me'.tr,
          hint: 'hint_bio'.tr,
          controller: widget.controller,
          accent: widget.accent,
          focusNode: widget.focusNode,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          maxLines: widget.maxLines,
        ),
        SizedBox(height: 6.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InterText(
                // ⚠️ `trParams` attend `@min` : ce paquet écrit `{min}`, donc
                // on remplace à la main (règle du projet).
                text: 'about_helper'
                    .tr
                    .replaceAll('{min}', '$kProfileBioMinLength'),
                fontSize: 11.5.sp,
                color: enough
                    ? AppColors.textTertiary(context)
                    : AppColors.textSecondary(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8.w),
            InterText(
              text: '$length/${widget.maxLength}',
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: enough
                  ? widget.accent
                  : AppColors.textTertiary(context),
              maxLines: 1,
            ),
          ],
        ),
      ],
    );
  }
}

/// Langues que la personne PARLE (≠ langue d'affichage de l'app, qui vit dans
/// Préférences › « Langue de l'app »). Sélection multiple.
class ProfileLanguageField extends StatelessWidget {
  final RxList<String> selected;
  final Color accent;

  /// Reçoit la liste jointe (« Français, English ») pour l'API.
  final ValueChanged<String>? onChanged;

  const ProfileLanguageField({
    super.key,
    required this.selected,
    required this.accent,
    this.onChanged,
  });

  /// Liste historique conservée (le champ serveur est un texte libre).
  static const languages = <List<String>>[
    ['🇫🇷', 'Français'],
    ['🇬🇧', 'English'],
    ['🇪🇸', 'Español'],
    ['🇩🇪', 'Deutsch'],
    ['🇮🇹', 'Italiano'],
    ['🇵🇹', 'Português'],
    ['🇵🇱', 'Polski'],
    ['🇰🇷', '한국어'],
    ['🇯🇵', '日本語'],
    ['🇸🇦', 'العربية'],
    ['🇨🇳', '中文'],
    ['🇷🇺', 'Русский'],
    ['🇹🇷', 'Türkçe'],
    ['🇳🇱', 'Nederlands'],
    ['🇮🇳', 'हिन्दी'],
  ];

  static String flagOf(String language) {
    for (final l in languages) {
      if (l[1] == language) return l[0];
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('profile_language_field'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileFieldLabel('label_spoken_languages'.tr),
        SizedBox(height: 6.h),
        Obx(() {
          final current = selected.toList();
          final summary = current.isEmpty
              ? 'spoken_languages_empty'.tr
              : current
                  .map((l) => '${flagOf(l)} $l'.trim())
                  .join(' · ');
          return GestureDetector(
            key: const ValueKey<String>('profile_language_row'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _openPicker(context),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.divider(context), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(Icons.record_voice_over_rounded,
                        size: 18.sp, color: accent),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: PoppinsText(
                      text: summary,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w600,
                      color: current.isEmpty
                          ? AppColors.textSecondary(context)
                          : AppColors.textPrimary(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Icon(Icons.arrow_forward_ios,
                      size: 14.sp, color: AppColors.textSecondary(context)),
                ],
              ),
            ),
          );
        }),
        SizedBox(height: 6.h),
        InterText(
          text: 'spoken_languages_helper'.tr,
          fontSize: 11.5.sp,
          color: AppColors.textTertiary(context),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _openPicker(BuildContext context) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        // `Get.bottomSheet` ne protège jamais le bas : le `Builder` donne un
        // contexte AU-DESSUS du SafeArea pour n'ajouter que le complément.
        child: Builder(
          builder: (ctx) => SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12.h),
                // v576 — Daniel : « quand j'ajoute mes langues, il n'y a ni
                // bouton valider ni retour ». La poignée devient CLIQUABLE
                // (fermeture) et une croix est posée en haut à droite : sur
                // Android le geste « glisser vers le bas » n'était pas évident
                // et rien ne le disait.
                GestureDetector(
                  key: const ValueKey<String>('profile_language_handle'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Get.back<void>(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: AppColors.divider(ctx),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: Row(
                    children: [
                      SizedBox(width: 36.w),
                      Expanded(
                        child: PoppinsText(
                          text: 'label_spoken_languages'.tr,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(ctx),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 36.w,
                        child: IconButton(
                          key: const ValueKey<String>('profile_language_close'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'common_close'.tr,
                          onPressed: () => Get.back<void>(),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20.sp,
                            color: AppColors.textSecondary(ctx),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: InterText(
                    text: 'spoken_languages_helper'.tr,
                    fontSize: 12.sp,
                    color: AppColors.textSecondary(ctx),
                    maxLines: 3,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 10.h),
                Flexible(
                  child: SingleChildScrollView(
                    child: Obx(() {
                      final current = selected.toList();
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: languages.map((l) {
                          final isSel = current.contains(l[1]);
                          return Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                            child: AppChoiceRow(
                              label: l[1],
                              leadingText: l[0],
                              accent: accent,
                              selected: isSel,
                              onTap: () {
                                if (isSel) {
                                  selected.remove(l[1]);
                                } else {
                                  selected.add(l[1]);
                                }
                                onChanged?.call(selected.join(', '));
                              },
                            ),
                          );
                        }).toList(),
                      );
                    }),
                  ),
                ),
                // v576 — bouton principal « Valider » : la sélection est déjà
                // appliquée au fil des taps (`onChanged`), il ferme donc la
                // feuille — mais il rend l'action ÉVIDENTE et termine l'écran
                // proprement, comme partout ailleurs dans l'app.
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w,
                      12.h + appBottomInsetInsideSafeArea(ctx)),
                  child: CustomButton(
                    key: const ValueKey<String>('profile_language_validate'),
                    title: 'fixes576_validate'.tr,
                    bgColor: accent,
                    textColor: Colors.white,
                    height: 50.h,
                    radius: 14.r,
                    onTap: () {
                      onChanged?.call(selected.join(', '));
                      Get.back<void>();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}
