// v565 — point 39 : briques partagées par les sous-pages « formulaire » du
// Profil (Modifier le profil owner/sitter/walker, fiche animal, tarifs, IBAN,
// carte, onboarding…). Complète `profile_ui_kit.dart` : carte de formulaire,
// avatar éditable, champ téléphone avec indicatif, puces de langues, rangée
// interrupteur, liste déroulante. Style Apple minimaliste + Paw Buttons ;
// `accent` = couleur du rôle.
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:hopetsit/utils/paw_menu_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_switch.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Carte blanche de formulaire : titre de section optionnel (petites
/// capitales, icône teintée) + enfants espacés verticalement.
class ProfileFormCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Color? accent;
  final List<Widget> children;
  final double gap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ProfileFormCard({
    super.key,
    required this.children,
    this.title,
    this.icon,
    this.accent,
    this.gap = 14,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final body = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      body.add(children[i]);
      if (i < children.length - 1) body.add(SizedBox(height: gap.h));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title!.isNotEmpty)
          ProfileSectionTitle(title!, icon: icon, color: accent),
        Container(
          width: double.infinity,
          margin: margin ?? EdgeInsets.only(bottom: 6.h),
          padding: padding ?? EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: body,
          ),
        ),
      ],
    );
  }
}

/// Avatar rond éditable (fichier local > URL > icône), badge « appareil
/// photo » teinté, indicateur de téléversement, bouton « retirer » optionnel.
class EditProfileAvatar extends StatelessWidget {
  final File? imageFile;
  final String imageUrl;
  final bool uploading;
  final Color accent;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final IconData placeholderIcon;
  final String? hint;
  final double radius;

  const EditProfileAvatar({
    super.key,
    required this.imageFile,
    required this.imageUrl,
    required this.accent,
    required this.onTap,
    this.uploading = false,
    this.onRemove,
    this.placeholderIcon = Icons.person_rounded,
    this.hint,
    this.radius = 56,
  });

  @override
  Widget build(BuildContext context) {
    final r = radius.r;
    ImageProvider? provider;
    if (imageFile != null) {
      provider = FileImage(imageFile!);
    } else if (imageUrl.isNotEmpty) {
      provider = CachedNetworkImageProvider(imageUrl);
    }
    return Column(
      children: [
        GestureDetector(
          onTap: uploading ? null : onTap,
          child: SizedBox(
            width: r * 2 + 12.w,
            height: r * 2 + 12.w,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.card(context),
                        boxShadow: AppColors.cardShadow(context),
                      ),
                      child: CircleAvatar(
                        radius: r,
                        backgroundColor: accent.withValues(alpha: 0.12),
                        backgroundImage: provider,
                        child: provider == null
                            ? Icon(placeholderIcon, size: r * 0.8, color: accent)
                            : null,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 34.w,
                    height: 34.w,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.card(context), width: 2.5),
                    ),
                    child: uploading
                        ? Padding(
                            padding: EdgeInsets.all(8.w),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.photo_camera_rounded, size: 17.sp, color: Colors.white),
                  ),
                ),
                if (onRemove != null && provider != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: uploading ? null : onRemove,
                      child: Container(
                        width: 28.w,
                        height: 28.w,
                        decoration: BoxDecoration(
                          color: AppColors.errorColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.card(context), width: 2),
                        ),
                        child: Icon(Icons.close_rounded, size: 15.sp, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hint != null && hint!.isNotEmpty) ...[
          SizedBox(height: 8.h),
          InterText(
            text: hint!,
            fontSize: 12.sp,
            color: AppColors.textSecondary(context),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ],
    );
  }
}

/// Champ téléphone « Apple » : indicatif (CountryCodePicker) + numéro
/// national. `countryCode` est la RxString du contrôleur (« +33 »). La
/// validation (facultatif ; sinon E.164 7-15 chiffres) est celle des écrans
/// historiques, conservée à l'identique.
class ProfilePhoneField extends StatelessWidget {
  final TextEditingController controller;
  final RxString countryCode;
  final Color accent;
  final String? label;
  final TextInputAction textInputAction;

  const ProfilePhoneField({
    super.key,
    required this.controller,
    required this.countryCode,
    required this.accent,
    this.label,
    this.textInputAction = TextInputAction.next,
  });

  String? _validate() {
    final v = controller.text.trim();
    if (v.isEmpty) return null;
    if (!RegExp(r'^\+?[0-9\s\-\(\)]+$').hasMatch(v)) {
      return 'error_phone_invalid'.tr;
    }
    final countryDigits = countryCode.value.replaceAll(RegExp(r'\D'), '');
    final phoneDigits = v.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\d{7,15}$').hasMatch(countryDigits + phoneDigits)) {
      return 'error_phone_invalid'.tr;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final initial = countryCode.value.isNotEmpty
        ? countryCode.value
        : (Get.deviceLocale?.countryCode ?? 'FR');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: label ?? 'label_mobile_number'.tr,
          fontSize: 12.5.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 6.h),
        FormField<String>(
          validator: (_) => _validate(),
          builder: (field) {
            final hasError = field.hasError;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 52.h,
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: hasError ? AppColors.errorColor : AppColors.divider(context),
                      width: hasError ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CountryCodePicker(
                        onChanged: (country) {
                          countryCode.value = country.dialCode ?? '+1';
                          field.didChange(controller.text);
                        },
                        initialSelection: initial,
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                        padding: EdgeInsets.only(left: 4.w),
                        boxDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.r),
                          color: AppColors.card(context),
                        ),
                        textStyle: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                        dialogTextStyle: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      Container(width: 1, height: 24.h, color: AppColors.divider(context)),
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          keyboardType: TextInputType.phone,
                          textInputAction: textInputAction,
                          onChanged: (_) => field.didChange(controller.text),
                          decoration: InputDecoration(
                            hintText: 'hint_phone'.tr,
                            hintStyle: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.textSecondary(context).withValues(alpha: 0.8),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                          ),
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasError && field.errorText != null)
                  Padding(
                    padding: EdgeInsets.only(left: 12.w, top: 4.h),
                    child: InterText(
                      text: field.errorText!,
                      fontSize: 12.sp,
                      color: AppColors.errorColor,
                      maxLines: 2,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Puces multi-sélection des langues parlées (liste historique conservée).
/// `selected` = RxList source de vérité ; `onChanged` reçoit la liste jointe.
class ProfileLanguageChips extends StatelessWidget {
  final RxList<String> selected;
  final Color accent;
  final ValueChanged<String>? onChanged;

  const ProfileLanguageChips({
    super.key,
    required this.selected,
    required this.accent,
    this.onChanged,
  });

  static const languages = [
    'Français', 'English', 'Deutsch', 'Español',
    'Italiano', 'Português', 'العربية', '中文',
    '日本語', '한국어', 'Русский', 'Türkçe',
    'Nederlands', 'Polski', 'हिन्दी',
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = selected.toList();
      return Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: languages.map((lang) {
          final isSel = current.contains(lang);
          return GestureDetector(
            onTap: () {
              if (isSel) {
                selected.remove(lang);
              } else {
                selected.add(lang);
              }
              onChanged?.call(selected.join(', '));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSel ? accent.withValues(alpha: 0.14) : AppColors.scaffold(context),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSel ? accent : AppColors.divider(context),
                  width: isSel ? 1.5 : 1,
                ),
              ),
              child: InterText(
                text: lang,
                fontSize: 13.sp,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                color: isSel ? accent : AppColors.textPrimary(context),
                maxLines: 1,
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

/// Rangée « interrupteur » (icône teintée + titre + sous-titre + AppSwitch).
class ProfileSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color accent;

  const ProfileSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.accent,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11.r),
          ),
          child: Icon(icon, size: 18.sp, color: accent),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PoppinsText(
                text: title,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                SizedBox(height: 2.h),
                InterText(
                  text: subtitle!,
                  fontSize: 11.5.sp,
                  color: AppColors.textSecondary(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: 8.w),
        AppSwitch(value: value, onChanged: onChanged, accent: accent),
      ],
    );
  }
}

/// Liste déroulante « Apple » (libellé au-dessus, fond carte, coins 14).
class ProfileDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final Color accent;
  final String? hint;
  final Widget? prefix;

  const ProfileDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.accent,
    this.hint,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: c, width: w),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          InterText(
            text: label,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 6.h),
        ],
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          hint: hint == null
              ? null
              : InterText(
                  text: hint!,
                  fontSize: 14.sp,
                  color: AppColors.textSecondary(context),
                  maxLines: 1,
                ),
          icon: Icon(Icons.expand_more_rounded, color: accent),
          // v585 (bug 9) — menu ouvert : blanc chaud (encre en sombre), coins
          // 16, valeur choisie en teinte pâle du rôle avec coche.
          dropdownColor: PawMenuColors.paper(context),
          borderRadius: BorderRadius.circular(16),
          elevation: 6,
          selectedItemBuilder: pawDropdownSelected<T>(items),
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.card(context),
            prefixIcon: prefix,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            border: border(AppColors.divider(context)),
            enabledBorder: border(AppColors.divider(context)),
            focusedBorder: border(accent, 1.6),
          ),
          items: pawDropdownItems<T>(context, items,
              selected: value, accent: accent),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Barre d'action collante des formulaires : bouton principal (+ note).
class ProfileSaveBar extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback? onTap;
  final bool loading;
  final IconData? icon;
  final String? note;

  const ProfileSaveBar({
    super.key,
    required this.label,
    required this.accent,
    required this.onTap,
    this.loading = false,
    this.icon,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (note != null && note!.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 13.sp, color: AppColors.textSecondary(context)),
              SizedBox(width: 5.w),
              Flexible(
                child: InterText(
                  text: note!,
                  fontSize: 11.sp,
                  color: AppColors.textSecondary(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
        ],
        ProfilePrimaryButton(label: label, accent: accent, onTap: onTap, loading: loading, icon: icon),
      ],
    );
  }
}

/// Petite pastille d'état (fond teinté + icône + texte), 1 ligne.
class ProfileStatusPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const ProfileStatusPill({super.key, required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: color),
          SizedBox(width: 5.w),
          Flexible(
            child: InterText(
              text: text,
              fontSize: 11.5.sp,
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
