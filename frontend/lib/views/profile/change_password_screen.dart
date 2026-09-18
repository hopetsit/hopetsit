import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/change_password_controller.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';

class ChangePasswordScreen extends StatelessWidget {
  final String userType;

  const ChangePasswordScreen({super.key, this.userType = 'pet_owner'});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ChangePasswordController(userType: userType));

    final accent = userType == 'pet_sitter'
        ? profileAccentFor('sitter')
        : (userType == 'pet_walker' ? profileAccentFor('walker') : currentRoleAccent());

    // v565 — sous-page modernisée (kit Profil) : bandeau d'aide, champs
    // « Apple », bouton bas collé, états de chargement.
    return ProfileSubPageScaffold(
      title: 'change_password_title'.tr,
      accent: accent,
      body: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileInfoBanner(
              icon: Icons.lock_rounded,
              accent: accent,
              text: 'change_password_help'.tr,
            ),
            SizedBox(height: 20.h),
            ProfileInput(
              label: 'change_password_new_label'.tr,
              hint: 'label_password'.tr,
              controller: controller.newPasswordController,
              accent: accent,
              obscure: true,
              textInputAction: TextInputAction.next,
              validator: controller.validateNewPassword,
            ),
            SizedBox(height: 16.h),
            ProfileInput(
              label: 'change_password_confirm_label'.tr,
              hint: 'change_password_confirm_hint'.tr,
              controller: controller.confirmPasswordController,
              accent: accent,
              obscure: true,
              textInputAction: TextInputAction.done,
              validator: controller.validateConfirmPassword,
            ),
          ],
        ),
      ),
      bottom: Obx(
        () => ProfilePrimaryButton(
          label: controller.isLoading.value ? 'common_saving'.tr : 'common_save'.tr,
          accent: accent,
          loading: controller.isLoading.value,
          onTap: controller.isLoading.value ? null : () => controller.savePassword(),
          icon: Icons.check_rounded,
        ),
      ),
    );
  }
}
