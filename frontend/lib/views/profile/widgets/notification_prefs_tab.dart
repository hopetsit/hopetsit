// v565 — point 19 : onglet « Notifications » des Préférences (3 rôles).
// Interrupteurs par catégorie + choix du son avec bouton d'écoute.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/notification_prefs_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_switch.dart';
import 'package:hopetsit/widgets/app_text.dart';

class NotificationPrefsTab extends StatelessWidget {
  final Color accent;
  const NotificationPrefsTab({super.key, required this.accent});

  static const Map<String, IconData> _categoryIcons = {
    'messages': Icons.chat_bubble_rounded,
    'bookings': Icons.event_available_rounded,
    'payments': Icons.payments_rounded,
    'friends': Icons.group_rounded,
    'pawmap': Icons.map_rounded,
    'live': Icons.share_location_rounded,
    'reviews': Icons.star_rounded,
    'subscriptions': Icons.workspace_premium_rounded,
  };

  static const Map<String, IconData> _soundIcons = {
    'default': Icons.notifications_rounded,
    'bark': Icons.pets_rounded,
    'meow': Icons.pets_rounded,
    'tweet': Icons.flutter_dash_rounded,
    'vibrate': Icons.vibration_rounded,
    'silent': Icons.notifications_off_rounded,
  };

  static const Map<String, String> _soundEmoji = {
    'default': '🔔',
    'bark': '🐶',
    'meow': '🐱',
    'tweet': '🐦',
    'vibrate': '📳',
    'silent': '🔕',
  };

  @override
  Widget build(BuildContext context) {
    final c = Get.isRegistered<NotificationPrefsController>()
        ? Get.find<NotificationPrefsController>()
        : Get.put(NotificationPrefsController());

    return Obx(() {
      final loading = c.loading.value;
      final saving = c.saving.value;
      final err = c.error.value;
      final currentSound = c.sound.value;
      final previewing = c.previewing.value;
      final cats = Map<String, bool>.from(c.categories);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileInfoBanner(
            icon: Icons.notifications_active_rounded,
            accent: accent,
            text: 'notif_prefs_intro'.tr,
          ),
          if (err.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 10.h),
              child: ProfileEmptyState(
                icon: Icons.cloud_off_rounded,
                title: err,
                accent: accent,
                error: true,
                actionLabel: 'common_retry'.tr,
                onAction: c.load,
              ),
            ),
          ProfileSectionTitle('notif_prefs_categories'.tr, icon: Icons.tune_rounded),
          Stack(
            children: [
              ProfileGroupCard(
                children: [
                  for (final key in NotificationPrefsController.categoryKeys)
                    ProfileRow(
                      icon: _categoryIcons[key] ?? Icons.notifications_rounded,
                      title: 'notif_cat_$key'.tr,
                      subtitle: 'notif_cat_${key}_sub'.tr,
                      color: accent,
                      showChevron: false,
                      trailing: AppSwitch(
                        value: cats[key] ?? true,
                        accent: accent,
                        onChanged: saving ? null : (v) => c.setCategory(key, v),
                      ),
                    ),
                ],
              ),
              if (loading)
                Positioned(
                  top: 8.h,
                  right: 12.w,
                  child: SizedBox(
                    width: 14.w,
                    height: 14.w,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                  ),
                ),
            ],
          ),
          ProfileSectionTitle('notif_prefs_sound'.tr, icon: Icons.volume_up_rounded),
          ProfileGroupCard(
            children: [
              for (final s in NotificationPrefsController.sounds)
                _SoundRow(
                  accent: accent,
                  label: 'notif_sound_$s'.tr,
                  emoji: _soundEmoji[s] ?? '🔔',
                  icon: _soundIcons[s] ?? Icons.notifications_rounded,
                  selected: currentSound == s,
                  playing: previewing == s,
                  canPreview: s != 'silent',
                  onSelect: saving ? null : () => c.setSound(s),
                  onPreview: () => c.preview(s),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            child: InterText(
              text: 'notif_prefs_footer'.tr,
              fontSize: 11.5.sp,
              color: AppColors.textSecondary(context),
              maxLines: 4,
              height: 1.35,
            ),
          ),
        ],
      );
    });
  }
}

class _SoundRow extends StatelessWidget {
  final Color accent;
  final String label;
  final String emoji;
  final IconData icon;
  final bool selected;
  final bool playing;
  final bool canPreview;
  final VoidCallback? onSelect;
  final VoidCallback onPreview;

  const _SoundRow({
    required this.accent,
    required this.label,
    required this.emoji,
    required this.icon,
    required this.selected,
    required this.playing,
    required this.canPreview,
    required this.onSelect,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? accent : accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Text(emoji, style: TextStyle(fontSize: 18.sp)),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: PoppinsText(
                text: label,
                fontSize: 14.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? accent : AppColors.textPrimary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (canPreview)
              IconButton(
                onPressed: onPreview,
                tooltip: 'notif_prefs_listen'.tr,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  playing ? Icons.graphic_eq_rounded : Icons.play_circle_fill_rounded,
                  size: 26.sp,
                  color: playing ? accent : AppColors.textSecondary(context),
                ),
              ),
            SizedBox(width: 4.w),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 22.sp,
              color: selected ? accent : AppColors.greyColor,
            ),
          ],
        ),
      ),
    );
  }
}
