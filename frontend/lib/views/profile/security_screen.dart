// v565 — point 26 : sous-page « Sécurité » des 3 rôles (mot de passe, e-mail,
// 2FA, vérifications, bloqués, suppression du compte).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/views/profile/widgets/change_email_sheet.dart';
import 'package:hopetsit/views/profile/widgets/profile_settings_host.dart';
import 'package:hopetsit/views/profile/widgets/profile_settings_tabs.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';

class ProfileSecurityScreen extends StatelessWidget {
  final ProfileSettingsHost host;
  final Color accent;
  const ProfileSecurityScreen({super.key, required this.host, required this.accent});

  @override
  Widget build(BuildContext context) {
    return ProfileSubPageScaffold(
      title: 'profile_cat_security'.tr,
      accent: accent,
      body: Obx(() {
        final p = host.profile.value;
        final saving = host.prefsSaving.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileGroupCard(
              margin: EdgeInsets.only(bottom: 10.h),
              children: [
                ProfileRow(
                  icon: Icons.alternate_email_rounded,
                  title: 'change_email_title'.tr,
                  subtitle: (p?.email ?? '').isNotEmpty ? p!.email : 'profile_no_email_added'.tr,
                  color: accent,
                  onTap: () => showChangeEmailSheet(
                    context,
                    accent: accent,
                    currentEmail: p?.email ?? '',
                  ),
                ),
              ],
            ),
            ProfileSecurityTab(
              accent: accent,
              twoFactorEnabled: p?.twoFactorEnabled ?? false,
              emailVerified: p?.verified ?? false,
              phoneVerified: (p?.mobile.isNotEmpty ?? false),
              saving: saving,
              onToggle2FA: host.setTwoFactor,
              onChangePassword: host.navigateToChangePassword,
              onBlockedUsers: host.navigateToBlockedUsers,
              onDeleteAccount: () => host.showDeleteAccountDialog(context),
            ),
          ],
        );
      }),
    );
  }
}
