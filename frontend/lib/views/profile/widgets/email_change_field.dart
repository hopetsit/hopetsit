// v565 — point 2 : champ e-mail des 3 écrans « Modifier le profil ». L'adresse
// reste en lecture seule (elle est vérifiée par code), mais un bouton
// « Modifier » ouvre la feuille « Changer mon e-mail » (§3). Après succès, le
// contrôleur de texte de l'écran est mis à jour.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/change_email_sheet.dart';
import 'package:hopetsit/widgets/app_text.dart';

class EmailChangeField extends StatelessWidget {
  final TextEditingController controller;
  final Color accent;
  const EmailChangeField({super.key, required this.controller, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: 'label_email'.tr,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary(context),
        ),
        SizedBox(height: 8.h),
        Container(
          height: 50.h,
          padding: EdgeInsets.only(left: 16.w, right: 6.w),
          decoration: BoxDecoration(
            color: AppColors.inputFill(context),
            borderRadius: BorderRadius.circular(30.r),
          ),
          child: Row(
            children: [
              Icon(Icons.alternate_email_rounded, size: 18.sp, color: AppColors.textSecondary(context)),
              SizedBox(width: 8.w),
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (_, v, __) => InterText(
                    text: v.text.isEmpty ? 'profile_no_email_added'.tr : v.text,
                    fontSize: 14.sp,
                    color: AppColors.textPrimary(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final newEmail = await showChangeEmailSheet(
                    context,
                    accent: accent,
                    currentEmail: controller.text.trim(),
                  );
                  if (newEmail != null && newEmail.isNotEmpty) {
                    controller.text = newEmail;
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.12),
                  foregroundColor: accent,
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: InterText(
                  text: 'change_email_button'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 6.h),
        InterText(
          text: 'change_email_field_hint'.tr,
          fontSize: 11.sp,
          color: AppColors.textSecondary(context),
          maxLines: 2,
        ),
      ],
    );
  }
}
