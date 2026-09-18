// v565 — points 19 / 26 : sous-page « Préférences & notifications » des 3
// rôles. Deux onglets : Général (toggles historiques + apparence + langue) et
// Notifications (catégories + son).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/appearance_language_section.dart';
import 'package:hopetsit/views/profile/widgets/notification_prefs_tab.dart';
import 'package:hopetsit/views/profile/widgets/profile_settings_host.dart';
import 'package:hopetsit/views/profile/widgets/profile_settings_tabs.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

class ProfilePreferencesScreen extends StatefulWidget {
  final ProfileSettingsHost host;
  final Color accent;
  /// 0 = Général, 1 = Notifications.
  final int initialTab;

  const ProfilePreferencesScreen({
    super.key,
    required this.host,
    required this.accent,
    this.initialTab = 0,
  });

  @override
  State<ProfilePreferencesScreen> createState() => _ProfilePreferencesScreenState();
}

class _ProfilePreferencesScreenState extends State<ProfilePreferencesScreen> {
  late int _tab = widget.initialTab.clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return ProfileSubPageScaffold(
      title: 'profile_cat_prefs'.tr,
      accent: accent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Segmented(
            accent: accent,
            index: _tab,
            labels: ['prefs_tab_general'.tr, 'prefs_tab_notifications'.tr],
            onChanged: (i) => setState(() => _tab = i),
          ),
          SizedBox(height: 14.h),
          if (_tab == 0)
            Obx(() {
              final p = widget.host.profile.value;
              final saving = widget.host.prefsSaving.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfilePreferencesTab(
                    accent: accent,
                    prefs: p?.preferences ?? const ProfilePreferences(),
                    saving: saving,
                    onSave: (u) => widget.host.savePreferences(u.toJson()),
                    onLanguage: widget.host.showLanguageDialog,
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: AppColors.cardShadow(context),
                    ),
                    child: AppearanceLanguageSection(accent: accent),
                  ),
                ],
              );
            })
          else
            NotificationPrefsTab(accent: accent),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final Color accent;
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  const _Segmented({
    required this.accent,
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.inputFill(context),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: selected ? AppColors.card(context) : Colors.transparent,
                  borderRadius: BorderRadius.circular(11.r),
                  boxShadow: selected ? AppColors.cardShadow(context) : null,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PoppinsText(
                      text: labels[i],
                      fontSize: 13.sp,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? accent : AppColors.textSecondary(context),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
