import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          color: Colors.black.withOpacity(0.15),
          child: Center(
            child: Container(
              width: 1.sw - 64.w,
              padding: EdgeInsets.all(22.w),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: AppColors.cardShadow(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 40.w,
                        width: 40.w,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          Icons.email_outlined,
                          color: AppColors.primaryColor,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: PoppinsText(
                          text: title,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  InterText(
                    text: subtitle,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.grey700Color,
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'sitter-payments@example.com',
                      filled: true,
                      fillColor: AppColors.inputFill(context),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide(color: AppColors.divider(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide(color: AppColors.divider(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide(color: AppColors.primaryColor),
                      ),
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          title: secondaryText,
                          bgColor: AppColors.card(context),
                          textColor: AppColors.textPrimary(context),
                          borderColor: AppColors.divider(context),
                          height: 46.h,
                          radius: 14.r,
                          onTap: isLoading ? null : onSecondary,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: CustomButton(
                          title: isLoading ? null : primaryText,
                          bgColor: AppColors.primaryColor,
                          textColor: AppColors.whiteColor,
                          height: 46.h,
                          radius: 14.r,
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

