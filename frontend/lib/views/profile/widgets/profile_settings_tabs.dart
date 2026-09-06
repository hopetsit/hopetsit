import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_switch.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v406 refonte — contenu de l'onglet « Préférences » du profil (maquette).
/// Partagé owner/sitter/walker. API par callbacks → découplé du contrôleur.
class ProfilePreferencesTab extends StatelessWidget {
  final Color accent;
  final ProfilePreferences prefs;
  final bool saving;
  final Future<void> Function(ProfilePreferences updated) onSave;
  final VoidCallback onLanguage;

  const ProfilePreferencesTab({
    super.key,
    required this.accent,
    required this.prefs,
    required this.onSave,
    required this.onLanguage,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header('profile_prefs_title'.tr),
        _toggle(
          context,
          icon: Icons.notifications_active_rounded,
          label: 'profile_pref_notifications'.tr,
          sub: 'profile_pref_notifications_sub'.tr,
          value: prefs.notifications,
          onChanged: (v) => onSave(prefs.copyWith(notifications: v)),
        ),
        _toggle(
          context,
          icon: Icons.bolt_rounded,
          label: 'profile_pref_quick_replies'.tr,
          sub: 'profile_pref_quick_replies_sub'.tr,
          value: prefs.quickReplies,
          onChanged: (v) => onSave(prefs.copyWith(quickReplies: v)),
        ),
        _toggle(
          context,
          icon: Icons.photo_camera_rounded,
          label: 'profile_pref_photos'.tr,
          sub: 'profile_pref_photos_sub'.tr,
          value: prefs.sendPhotosVideos,
          onChanged: (v) => onSave(prefs.copyWith(sendPhotosVideos: v)),
        ),
        // v444 — Daniel : « Assurance PawMap » retiré des Préférences (n'existe
        // pas). Le champ prefs.pawMapInsurance reste dans le modèle (inoffensif).
        _toggle(
          context,
          icon: Icons.event_available_rounded,
          label: 'profile_pref_flexible_cancellation'.tr,
          sub: 'profile_pref_flexible_cancellation_sub'.tr,
          value: prefs.flexibleCancellation,
          onChanged: (v) => onSave(prefs.copyWith(flexibleCancellation: v)),
        ),
        SizedBox(height: 18.h),
        // v551 — Daniel : « rajouter une ligne dans le profil : masquer mon
        // profil sur la carte (on/off), pour quelqu'un qui ne veut pas être
        // vu par les autres sauf ses amis ».
        _header('profile_pref_privacy'.tr),
        _toggle(
          context,
          icon: Icons.visibility_off_rounded,
          label: 'profile_pref_hide_map'.tr,
          sub: 'profile_pref_hide_map_sub'.tr,
          value: prefs.hideFromMap,
          onChanged: (v) => onSave(prefs.copyWith(hideFromMap: v)),
        ),
        SizedBox(height: 18.h),
        _header('profile_pref_language'.tr),
        _navTile(
          context,
          icon: Icons.translate_rounded,
          label: 'profile_pref_language'.tr,
          onTap: onLanguage,
        ),
      ],
    );
  }

  Widget _header(String label) => Padding(
        padding: EdgeInsets.only(top: 8.h, bottom: 8.h, left: 4.w),
        child: PoppinsText(
          text: label.toUpperCase(),
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.greyText,
        ),
      );

  Widget _toggle(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: AppColors.cardShadow(context),
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
            child: Icon(icon, size: 18.sp, color: accent),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PoppinsText(
                  text: label,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
                if (sub.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  InterText(
                    text: sub,
                    fontSize: 11.sp,
                    color: AppColors.textSecondary(context),
                  ),
                ],
              ],
            ),
          ),
          AppSwitch(
            value: value,
            onChanged: saving ? null : onChanged,
            accent: accent,
          ),
        ],
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: AppColors.cardShadow(context),
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
              child: Icon(icon, size: 18.sp, color: accent),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: PoppinsText(
                text: label,
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

/// v406 refonte — contenu de l'onglet « Sécurité » du profil (maquette).
class ProfileSecurityTab extends StatelessWidget {
  final Color accent;
  final bool twoFactorEnabled;
  final bool emailVerified;
  final bool phoneVerified;
  final bool saving;
  final ValueChanged<bool> onToggle2FA;
  final VoidCallback onChangePassword;
  final VoidCallback onBlockedUsers;
  final VoidCallback onDeleteAccount;

  const ProfileSecurityTab({
    super.key,
    required this.accent,
    required this.twoFactorEnabled,
    required this.onToggle2FA,
    required this.onChangePassword,
    required this.onBlockedUsers,
    required this.onDeleteAccount,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header('profile_section_account'.tr),
        _navTile(context,
            icon: Icons.lock_outline_rounded,
            label: 'profile_change_password'.tr,
            sub: 'profile_change_password_subtitle'.tr,
            color: accent,
            onTap: onChangePassword),
        // 2FA toggle
        Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: AppColors.cardShadow(context),
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
                child: Icon(Icons.verified_user_rounded,
                    size: 18.sp, color: accent),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: 'profile_2fa'.tr,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                    SizedBox(height: 2.h),
                    InterText(
                      text: 'profile_2fa_sub'.tr,
                      fontSize: 11.sp,
                      color: AppColors.textSecondary(context),
                    ),
                  ],
                ),
              ),
              AppSwitch(
                value: twoFactorEnabled,
                onChanged: saving ? null : onToggle2FA,
                accent: accent,
              ),
            ],
          ),
        ),
        SizedBox(height: 18.h),
        _header('profile_verifications'.tr),
        _verifRow(context, 'profile_phone'.tr, phoneVerified),
        _verifRow(context, 'profile_email'.tr, emailVerified),
        SizedBox(height: 18.h),
        _navTile(context,
            icon: Icons.block_rounded,
            label: 'profile_blocked_users'.tr,
            sub: 'profile_blocked_users_subtitle'.tr,
            color: AppColors.errorColor,
            onTap: onBlockedUsers),
        SizedBox(height: 8.h),
        // Danger — delete account
        GestureDetector(
          onTap: onDeleteAccount,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                  color: AppColors.errorColor.withValues(alpha: 0.4), width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded,
                    size: 20.sp, color: AppColors.errorColor),
                SizedBox(width: 12.w),
                Expanded(
                  child: PoppinsText(
                    text: 'profile_delete_account'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.errorColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(String label) => Padding(
        padding: EdgeInsets.only(top: 8.h, bottom: 8.h, left: 4.w),
        child: PoppinsText(
          text: label.toUpperCase(),
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.greyText,
        ),
      );

  Widget _verifRow(BuildContext context, String label, bool verified) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: PoppinsText(
              text: label,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
            ),
          ),
          Icon(
            verified ? Icons.verified_rounded : Icons.error_outline_rounded,
            size: 18.sp,
            color: verified ? const Color(0xFF16A34A) : AppColors.greyColor,
          ),
          SizedBox(width: 6.w),
          InterText(
            text: verified ? 'profile_verified'.tr : 'profile_not_verified'.tr,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: verified ? const Color(0xFF16A34A) : AppColors.greyColor,
          ),
        ],
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, size: 18.sp, color: color),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PoppinsText(
                    text: label,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                  SizedBox(height: 2.h),
                  InterText(
                    text: sub,
                    fontSize: 11.sp,
                    color: AppColors.textSecondary(context),
                  ),
                ],
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

/// v406 — barre d'onglets segmentée (Profil / Préférences / Sécurité), style
/// maquette : libellés soulignés, couleur de rôle. `index` piloté par un RxInt.
class ProfileTabBar extends StatelessWidget {
  final int index;
  final Color accent;
  final ValueChanged<int> onChanged;
  const ProfileTabBar({
    super.key,
    required this.index,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = [
      'profile_tab_profile'.tr,
      'profile_tab_preferences'.tr,
      'profile_tab_security'.tr,
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.greyColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Column(
                  children: [
                    PoppinsText(
                      text: labels[i],
                      fontSize: 14.sp,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? accent
                          : AppColors.textSecondary(context),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      height: 2.5.h,
                      width: 40.w,
                      decoration: BoxDecoration(
                        color: selected ? accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
