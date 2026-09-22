// v569 — DESIGN UNIQUEMENT : l'API publique est inchangée (mêmes paramètres,
// mêmes valeurs par défaut, `onPrimary` / `onSecondary` appelés à l'identique,
// aucun pop ajouté — ce sont toujours les appelants qui ferment le dialogue).
// Nouveau rendu : plus de `BackdropFilter` (coûteux), voile sombre, carte
// coins 24, disque teinté 56 px, titre et sous-titre centrés, champ e-mail au
// style moderne (coins 14, focus couleur de marque), boutons pleine largeur
// empilés.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

class PayPalEmailDialog extends StatelessWidget {
  const PayPalEmailDialog({
    super.key,
    required this.controller,
    this.initialEmail,
    this.title = 'PayPal payout email',
    this.subtitle =
        'Add the email where you want to receive payouts. You can update it anytime.',
    required this.primaryText,
    required this.secondaryText,
    required this.onPrimary,
    required this.onSecondary,
    this.isLoading = false,
  });

  final TextEditingController controller;
  final String? initialEmail;
  final String title;
  final String subtitle;
  final String primaryText;
  final String secondaryText;
  final Future<void> Function() onPrimary;
  final VoidCallback onSecondary;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (initialEmail != null && controller.text.isEmpty) {
      controller.text = initialEmail!;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }

    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = AppColors.activeRoleAccent();

    return Material(
      color: Colors.transparent,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: dark ? 0.62 : 0.38),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              26.w,
              24.h,
              26.w,
              24.h + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 380.w),
              child: Container(
                padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 18.h),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(24.r),
                  border: dark
                      ? Border.all(color: AppColors.dividerDark, width: 1)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.5 : 0.16),
                      blurRadius: 28,
                      spreadRadius: -8,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56.w,
                      height: 56.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: dark ? 0.22 : 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.alternate_email_rounded,
                        color: accent,
                        size: 28.sp,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    PoppinsText(
                      text: title,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8.h),
                    InterText(
                      text: subtitle,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                      color: AppColors.textSecondary(context),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 18.h),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 14.sp,
                      ),
                      decoration: InputDecoration(
                        hintText: 'misc569_email_hint'.tr,
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 13.sp,
                        ),
                        filled: true,
                        fillColor: AppColors.inputFill(context),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                        border: _border(AppColors.divider(context)),
                        enabledBorder: _border(AppColors.divider(context)),
                        focusedBorder: _border(accent, width: 1.5),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    CustomButton(
                      width: double.infinity,
                      height: 50.h,
                      radius: 14.r,
                      title: isLoading ? null : primaryText,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      bgColor: accent,
                      textColor: AppColors.whiteColor,
                      onTap: isLoading
                          ? null
                          : () async {
                              await onPrimary();
                            },
                      child: isLoading
                          ? SizedBox(
                              height: 20.h,
                              width: 20.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.whiteColor,
                                ),
                              ),
                            )
                          : null,
                    ),
                    SizedBox(height: 10.h),
                    CustomButton(
                      width: double.infinity,
                      height: 50.h,
                      radius: 14.r,
                      title: secondaryText,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      bgColor: dark
                          ? const Color(0xFF342420)
                          : const Color(0xFFF6F1EF),
                      textColor: AppColors.textPrimary(context),
                      onTap: isLoading ? null : onSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
