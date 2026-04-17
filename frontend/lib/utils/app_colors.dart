import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryColor = Color(0xFFEF4324);
  static const Color blackColor = Color(0xFF000000);
  static const Color whiteColor = Color(0xFFFFFFFF);
  static const Color white38Color = Color(0x3EFFFFFF);
  static const Color greyColor = Color(0xFFA1A1A1);
  static const Color grey300Color = Color(0xFFD5D7DA);
  static const Color grey500Color = Color(0xFF717680);
  static const Color grey700Color = Color(0xFF414651);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color hintColor = Color(0xFF535862);
  static const lightGreyColor = Color(0xFFD9D9D9);
  static const textFieldBorder = Color(0xFFD5D7DA);
  static const lightGrey = Color(0xFFF4F3EE);
  static const greyText = Color(0xFF707070);
  static const chatFieldColor = Color(0xFFF3F2EF);
  static const greenColor = Color(0xFF008000);
  // Role accents — used on SignUp cards and per-role profile screens.
  // Sitter accent = blue (matches the blue palette already used in
  // sitter_profile_screen). Walker accent = the existing greenColor above.
  static const sitterAccent = Color(0xFF1A73E8);

  // Detail box color
  static const detailBoxColor = Color(0x1AFFBC11); // #FFBC11 with 0.1 opacity
  static const purpleLineNavigation = Color(0xFFBF32C1);

  // Sprint 6 step 1 — dark mode palette.
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF242424);
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color dividerDark = Color(0xFF333333);

  // ── Modern light palette ──
  static const Color scaffoldLight = Color(0xFFF7F7F8);
  static const Color cardLight = Color(0xFFFFFFFF);

  // Gradient
  static const LinearGradient linearGradient = LinearGradient(
    colors: [Color(0xFFEF4324), Color(0xFFFF6B4A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Theme-aware helpers ──────────────────────────────────────────
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Scaffold / page background
  static Color scaffold(BuildContext context) =>
      _isDark(context) ? backgroundDark : scaffoldLight;

  /// AppBar background
  static Color appBar(BuildContext context) =>
      _isDark(context) ? surfaceDark : whiteColor;

  /// Card / container surface
  static Color card(BuildContext context) =>
      _isDark(context) ? cardDark : cardLight;

  /// Primary text (titles, body)
  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? textPrimaryDark : blackColor;

  /// Secondary text (subtitles, hints)
  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? textSecondaryDark : greyText;

  /// Divider / border
  static Color divider(BuildContext context) =>
      _isDark(context) ? dividerDark : grey300Color;

  /// Chat field / input background
  static Color inputFill(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2A2A2A) : scaffoldLight;

  /// Subtle shadow that works in dark mode (invisible) and light mode
  static List<BoxShadow> cardShadow(BuildContext context) =>
      _isDark(context)
          ? []  // no shadow in dark mode — use border or elevation
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ];
}
