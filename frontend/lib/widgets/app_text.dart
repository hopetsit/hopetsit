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
      ).copyWith(fontFamilyFallback: cjkFontFallback),
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
      ).copyWith(fontFamilyFallback: cjkFontFallback),
    );
  }
}

/// v532 — polices de secours pour le coréen et le japonais.
///
/// Poppins et Inter ne contiennent NI hangul NI kana : sans repli explicite,
/// un texte coréen ou japonais risque de s'afficher en carrés vides (« tofu »),
/// surtout sur les Android d'entrée de gamme. On liste les polices système
/// présentes sur iOS et Android ; Flutter prend la première qui possède le
/// glyphe, et ignore silencieusement celles qui n'existent pas sur l'appareil.
const List<String> cjkFontFallback = <String>[
  'Apple SD Gothic Neo', // iOS — coréen
  'Hiragino Sans',       // iOS — japonais
  'Noto Sans KR',        // Android — coréen
  'Noto Sans JP',        // Android — japonais
  'Noto Sans CJK KR',
  'Noto Sans CJK JP',
];


/// v540 — titres du design "handoff LAP" (Fredoka 500-700).
class FredokaText extends StatelessWidget {
  final String text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final double? letterSpacing;
  final double? height;
  const FredokaText({
    super.key,
    required this.text,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.textAlign,
    this.maxLines,
    this.letterSpacing,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      style: GoogleFonts.fredoka(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      ),
    );
  }
}
