import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v441 — section partagée par les 3 écrans « Modifier le profil »
/// (owner/sitter/walker) : sélecteur d'apparence (Clair / Sombre / Système) +
/// sélecteur de langue de l'app (6 langues). L'apparence pilote le
/// [ThemeController] (persisté), la langue passe par
/// [LocalizationService.updateLocale] (persiste + Get.updateLocale + sync
/// backend). `accent` = couleur de rôle. Theme-aware (dark/light).
class AppearanceLanguageSection extends StatelessWidget {
  final Color accent;
  const AppearanceLanguageSection({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'pref_appearance'.tr),
        SizedBox(height: 8.h),
        const _AppearanceSelector(),
        SizedBox(height: 20.h),
        _sectionLabel(context, 'pref_app_language'.tr),
        SizedBox(height: 8.h),
        _LanguageTile(accent: accent),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => InterText(
        text: text,
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary(context),
      );
}

/// Sélecteur segmenté Clair / Sombre / Système.
class _AppearanceSelector extends StatelessWidget {
  const _AppearanceSelector();

  @override
  Widget build(BuildContext context) {
    final tc = Get.find<ThemeController>();
    final options = <_AppearanceOption>[
      _AppearanceOption(
          ThemeMode.light, Icons.light_mode_rounded, 'appearance_light'.tr),
      _AppearanceOption(
          ThemeMode.dark, Icons.dark_mode_rounded, 'appearance_dark'.tr),
      _AppearanceOption(ThemeMode.system, Icons.brightness_auto_rounded,
          'appearance_system'.tr),
    ];

    return Obx(() {
      final current = tc.themeMode.value;
      return Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: AppColors.inputFill(context),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.divider(context), width: 1),
        ),
        child: Row(
          children: options.map((o) {
            final selected = o.mode == current;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => tc.setMode(o.mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  decoration: BoxDecoration(
                    // La pastille sélectionnée prend l'orange marque (lisible
                    // en clair comme en sombre).
                    color: selected ? AppColors.primaryColor : null,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        o.icon,
                        size: 18.sp,
                        color: selected
                            ? AppColors.whiteColor
                            : AppColors.textSecondary(context),
                      ),
                      SizedBox(height: 4.h),
                      InterText(
                        text: o.label,
                        fontSize: 12.sp,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                        color: selected
                            ? AppColors.whiteColor
                            : AppColors.textSecondary(context),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }
}

class _AppearanceOption {
  final ThemeMode mode;
  final IconData icon;
  final String label;
  const _AppearanceOption(this.mode, this.icon, this.label);
}

/// Tuile « Langue de l'app » → ouvre un sélecteur 6 langues (bottom sheet).
class _LanguageTile extends StatelessWidget {
  final Color accent;
  const _LanguageTile({required this.accent});

  @override
  Widget build(BuildContext context) {
    final current = LocalizationService.getCurrentLanguageCode();
    final currentLabel =
        LocalizationService.languageLabels[current] ?? current.toUpperCase();
    return GestureDetector(
      onTap: () => showAppLanguagePicker(context, accent),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
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
              child: Icon(Icons.translate_rounded, size: 18.sp, color: accent),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: PoppinsText(
                text: currentLabel,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14.sp, color: AppColors.textSecondary(context)),
          ],
        ),
      ),
    );
  }
}

/// v441 — bottom sheet sélecteur de langue de l'app (6 langues). Met en
/// évidence la langue courante et bascule immédiatement. Réutilisable depuis
/// n'importe où (édition profil, onglet Préférences…).
Future<void> showAppLanguagePicker(BuildContext context, Color accent) {
  final current = LocalizationService.getCurrentLanguageCode();
  final entries = LocalizationService.languageLabels.entries.toList();
  return Get.bottomSheet(
    Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.divider(context),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 14.h),
            PoppinsText(
              text: 'pref_app_language'.tr,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
            SizedBox(height: 8.h),
            ...entries.map((e) {
              final selected = e.key == current;
              return ListTile(
                onTap: () async {
                  await LocalizationService.updateLocale(e.key);
                  Get.back();
                },
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? accent : AppColors.textSecondary(context),
                  size: 20.sp,
                ),
                title: InterText(
                  text: e.value,
                  fontSize: 15.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textPrimary(context),
                ),
              );
            }),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
  );
}
