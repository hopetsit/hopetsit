import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

class CustomConfirmationDialog extends StatelessWidget {
  final String message;
  final String yesText;
  final String cancelText;
  final VoidCallback onYes;
  final VoidCallback? onCancel;
  final Color? yesButtonColor;
  final Color? cancelButtonColor;

  const CustomConfirmationDialog({
    super.key,
    required this.message,
    this.yesText = 'Yes',
    this.cancelText = 'Cancel',
    required this.onYes,
    this.onCancel,
    this.yesButtonColor,
    this.cancelButtonColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          color: Colors.white.withOpacity(0.1),
          child: Center(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 40.w),
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: AppColors.cardShadow(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Message
                  PoppinsText(
                    text: message,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary(context),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 24.h),

                  // Buttons
                  Column(
                    children: [
                      // Yes Button
                      CustomButton(
                        width: double.infinity,
                        height: 48.h,
                        radius: 48.r,
                        title: yesText,
                        bgColor: yesButtonColor ?? AppColors.primaryColor,
                        textColor: AppColors.whiteColor,
                        onTap: () {
                          Navigator.of(context).pop();
                          onYes();
                        },
                      ),

                      SizedBox(height: 12.h),

                      // Cancel Button
                      CustomButton(
                        width: double.infinity,
                        height: 48.h,
                        radius: 48.r,
                        title: cancelText,
                        bgColor: cancelButtonColor ?? AppColors.card(context),
                        textColor: AppColors.textPrimary(context),
                        borderColor: AppColors.divider(context),
                        onTap: () {
                          Navigator.of(context).pop();
                          onCancel?.call();
                        },
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

  static void show({
    required BuildContext context,
    required String message,
    String yesText = 'Yes',
    String cancelText = 'Cancel',
    required VoidCallback onYes,
    VoidCallback? onCancel,
    Color? yesButtonColor,
    Color? cancelButtonColor,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomConfirmationDialog(
        message: message,
        yesText: yesText,
        cancelText: cancelText,
        onYes: onYes,
        onCancel: onCancel,
        yesButtonColor: yesButtonColor,
        cancelButtonColor: cancelButtonColor,
      ),
    );
  }
}
