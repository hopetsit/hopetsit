import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/services/map_prefs_service.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_switch.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';
import 'package:hopetsit/widgets/paw_icons.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';
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
        _header(context, 'profile_prefs_title'.tr),
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
        _header(context, 'profile_pref_privacy'.tr),
        // v586 — Daniel : « masquer / visible par tous n'est pas synchro avec
        // le menu de la PawMap ». UNE vérité à 3 états (Tous · Amis seulement
        // · Masqué), lue et écrite au MÊME endroit que le bouton œil de la
        // carte et le site (`MapPrefsService.mapVisibility`, route
        // /users/me/map-prefs, les 3 profils).
        _visibilityRow(context),
        // v585 (lot D) — « Mon fond » (NORME_DESIGN.md) : auto selon mon animal /
        // pattes seules / aucun, enregistré sur le compte ET copié en local
        // (le fond change tout de suite, même hors réseau).
        SizedBox(height: 18.h),
        _header(context, 'pref_wallpaper_title'.tr),
        _wallpaperRow(context),
        // v575 — Daniel : « il y a 2 fois "Langue préférée" ». C'ÉTAIT un vrai
        // doublon : ce bloc ouvrait le même sélecteur de LANGUE DE L'APP que
        // la section « Apparence & langue » affichée juste en dessous sur le
        // MÊME écran (`preferences_screen.dart`). Une seule entrée est
        // conservée : « Langue de l'app », dans la section Apparence & langue.
        // `onLanguage` reste dans l'API du widget (appelé par d'autres écrans).
      ],
    );
  }

  Widget _visibilityRow(BuildContext context) {
    final svc = MapPrefsService.instance;
    return Container(
      key: const ValueKey<String>('pref_map_visibility'),
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Obx(() {
        final current = svc.mapVisibility.value;
        Widget pill(String value, PawIcon icon, String label) => PawChoicePill(
              key: ValueKey<String>('pref_vis_$value'),
              label: label,
              icon: icon,
              color: accent,
              selected: current == value,
              onTap: current == value
                  ? null
                  : () async {
                      final ok = await svc.setMapVisibility(value);
                      if (!ok) {
                        CustomSnackbar.showError(
                          title: 'common_error'.tr,
                          message: 'pawmap_visibility_failed'.tr,
                        );
                      }
                    },
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PoppinsText(
              text: 'pawmap586_pref_vis_title'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                pill('all', PawIcon.eye, 'vis587_all_t'.tr),
                pill('friends', PawIcon.heart, 'vis587_friends_t'.tr),
                pill('hidden', PawIcon.eyeOff, 'vis587_hidden_t'.tr),
              ],
            ),
            // v587 — Daniel : « ces options doivent être claires » : chaque
            // option avec son titre ET sa phrase ; celle choisie est en avant.
            SizedBox(height: 10.h),
            for (final o in const <List<String>>[
              <String>['all', 'vis587_all_t', 'vis587_all_d'],
              <String>['friends', 'vis587_friends_t', 'vis587_friends_d'],
              <String>['hidden', 'vis587_hidden_t', 'vis587_hidden_d'],
            ])
              Padding(
                key: ValueKey<String>('pref_vis_explain_${o[0]}'),
                padding: EdgeInsets.only(bottom: 6.h),
                child: Text.rich(
                  TextSpan(children: <InlineSpan>[
                    TextSpan(
                      text: '${o[1].tr} — ',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: current == o[0]
                            ? accent
                            : AppColors.textPrimary(context),
                      ),
                    ),
                    TextSpan(text: o[2].tr),
                  ]),
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    height: 1.35,
                    color: current == o[0]
                        ? AppColors.textPrimary(context)
                        : AppColors.textSecondary(context),
                  ),
                ),
              ),
            InterText(
              text: 'vis587_live'.tr,
              fontSize: 11.sp,
              color: AppColors.textSecondary(context),
            ),
          ],
        );
      }),
    );
  }

  Widget _wallpaperRow(BuildContext context) {
    // v586 — le choix s'affiche TOUT DE SUITE (copie locale, qui redessine
    // aussi tous les fonds), puis part sur le compte. Avant, la pilule restait
    // sur l'ancienne valeur pendant l'enregistrement et tout appui pendant
    // celui-ci était ignoré.
    return ValueListenableBuilder<int>(
      valueListenable: PawWallpaperPrefs.revision,
      builder: (ctx, _, __) => _wallpaperCard(ctx, PawWallpaperPrefs.mode()),
    );
  }

  Widget _wallpaperCard(BuildContext context, String current) {
    Widget pill(String value, PawIcon icon, String label) => PawChoicePill(
          key: ValueKey<String>('pref_wallpaper_$value'),
          label: label,
          icon: icon,
          color: accent,
          selected: current == value,
          onTap: current == value
              ? null
              : () {
                  // v587 — choix protégé des relectures périmées du compte.
                  PawWallpaperPrefs.choose(value);
                  onSave(prefs.copyWith(wallpaper: value));
                },
        );
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InterText(
            text: 'pref_wallpaper_sub'.tr,
            fontSize: 11.5.sp,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              pill('auto', PawIcon.paw, 'pref_wallpaper_auto'.tr),
              pill('paws', PawIcon.heart, 'pref_wallpaper_paws'.tr),
              pill('none', PawIcon.close, 'pref_wallpaper_none'.tr),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String label) => Padding(
        padding: EdgeInsets.only(top: 10.h, bottom: 8.h, left: 6.w),
        child: PoppinsText(
          text: label.toUpperCase(),
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          color: AppColors.textSecondary(context),
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
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
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
        _header(context, 'profile_section_account'.tr),
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
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
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
        _header(context, 'profile_verifications'.tr),
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
              borderRadius: BorderRadius.circular(16.r),
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

  Widget _header(BuildContext context, String label) => Padding(
        padding: EdgeInsets.only(top: 10.h, bottom: 8.h, left: 6.w),
        child: PoppinsText(
          text: label.toUpperCase(),
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          color: AppColors.textSecondary(context),
        ),
      );

  Widget _verifRow(BuildContext context, String label, bool verified) {
    final Color stateColor =
        verified ? const Color(0xFF16A34A) : AppColors.greyColor;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: PoppinsText(
              text: label,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              color: AppColors.textPrimary(context),
            ),
          ),
          SizedBox(width: 8.w),
          // v569 — pastille d'état colorée (au lieu d'une icône + texte nus).
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            constraints: BoxConstraints(maxWidth: 150.w),
            decoration: BoxDecoration(
              color: stateColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  verified
                      ? Icons.verified_rounded
                      : Icons.error_outline_rounded,
                  size: 14.sp,
                  color: stateColor,
                ),
                SizedBox(width: 5.w),
                Flexible(
                  child: InterText(
                    text: verified
                        ? 'profile_verified'.tr
                        : 'profile_not_verified'.tr,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    color: stateColor,
                  ),
                ),
              ],
            ),
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
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.r),
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
            Icon(Icons.chevron_right_rounded,
                size: 20.sp, color: AppColors.textSecondary(context)),
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
    // v569 — DESIGN UNIQUEMENT : même `index`, même `onChanged`. Le
    // soulignement devient un sélecteur en pilules (façon iOS) : plus lisible
    // et les libellés longs (allemand / polonais) s'ellipsent au lieu de
    // déborder.
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2B1E1B) : const Color(0xFFF6F1EF),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(vertical: 9.h, horizontal: 6.w),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.card(context) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999.r),
                  boxShadow: selected ? AppColors.cardShadow(context) : null,
                ),
                child: PoppinsText(
                  text: labels[i],
                  fontSize: 13.sp,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      selected ? accent : AppColors.textSecondary(context),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
