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
          gradient: isGradient ? AppColors.linearGradient : null,
          color: isGradient ? null : bgColor ?? AppColors.primaryColor,
          border: Border.all(color: borderColor ?? Colors.transparent),
          borderRadius: BorderRadius.circular(radius ?? 48.0.r),
        ),
        child: Center(
          child:
              child ??
              InterText(
                text: title ?? '',
                fontSize: fontSize ?? 16,
                fontWeight: fontWeight ?? FontWeight.w500,
                color: textColor ?? AppColors.whiteColor,
              ),
        ),
      ),
    );
  }
}
