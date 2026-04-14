import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/utils/app_colors.dart';

class PoppinsText extends StatelessWidget {
  final String text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextOverflow? overflow;
  final TextDecoration? textDecoration;
  final int? maxLines;
  final double? letterSpacing;
  final double? height;
  final FontStyle? fontStyle;
  final TextAlign? textAlign;
  const PoppinsText({
    required this.text,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.letterSpacing,
    this.overflow,
    this.textDecoration,
    this.maxLines,
    this.fontStyle,
    this.height,
    this.textAlign,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,

      style: GoogleFonts.poppins(
        fontSize: (fontSize ?? 14).sp,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
        decoration: textDecoration,
        fontWeight: fontWeight,
        color: color ?? AppColors.blackColor,
        height: height,
      ),
    );
  }
}

class InterText extends StatelessWidget {
  final String text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextOverflow? overflow;
  final TextDecoration? textDecoration;
  final int? maxLines;
  final double? letterSpacing;
  final double? height;
  final FontStyle? fontStyle;
  final TextAlign? textAlign;
  const InterText({
    required this.text,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.letterSpacing,
    this.overflow,
    this.textDecoration,
    this.maxLines,
    this.fontStyle,
    this.height,
    this.textAlign,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,

      style: GoogleFonts.inter(
        fontSize: (fontSize ?? 14).sp,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
        decoration: textDecoration,
        fontWeight: fontWeight,
        color: color ?? AppColors.blackColor,
        height: height,
      ),
    );
  }
}
