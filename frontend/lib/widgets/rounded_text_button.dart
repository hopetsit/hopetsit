import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

class CustomButton extends StatelessWidget {
  final Widget? child;
  final String? title;
  final bool isGradient;
  final Color? bgColor;
  final Color? textColor;
  final Color? borderColor;
  final FontWeight? fontWeight;
  final double? fontSize;
  final double? radius;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const CustomButton({
    super.key,
    this.child,
    this.title,
    this.isGradient = false,
    this.bgColor,
    this.textColor,
    this.borderColor,
    this.fontWeight,
    this.fontSize,
    this.radius,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => debugPrint('Button Tapped'),
      child: Container(
        height: height ?? 50.h,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          gradient: isGradient
              ? AppColors.linearGradient
              : LinearGradient(
                  colors: [
                    bgColor ?? AppColors.primaryColor,
                    (bgColor ?? AppColors.primaryColor).withValues(alpha: 0.85),
                  ],
                ),
          border: borderColor != null
              ? Border.all(color: borderColor!)
              : null,
          borderRadius: BorderRadius.circular(radius ?? 16.0.r),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: (bgColor ?? AppColors.primaryColor).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child:
              child ??
              InterText(
                text: title ?? '',
                fontSize: fontSize ?? 16,
                fontWeight: fontWeight ?? FontWeight.w600,
                color: textColor ?? Colors.white,
              ),
        ),
      ),
    );
  }
}
