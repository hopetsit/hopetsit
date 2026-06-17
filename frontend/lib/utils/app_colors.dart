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
  // v448 — Daniel : « tous les fonds gris CLAIR → jaune clair, toute l'app en
  // profondeur ». Ces 2 fonds gris clair passent en jaune doux.
  static const lightGrey = Color(0xFFFFF8E1); // jaune doux (ex 0xFFF4F3EE gris)
  static const greyText = Color(0xFF707070);
  static const chatFieldColor = Color(0xFFFFF3D2); // jaune doux (ex 0xFFF3F2EF)
  static const greenColor = Color(0xFF008000);
  // Role accents — used on SignUp cards and per-role profile screens.
  // v23.1.346 — audit codes couleur (Daniel) : canon = sitter 0xFF2563EB.
  // L'ancien 0xFF1A73E8 (bleu Google) fragmentait la charte : marqueurs map,
  // bande d'accueil et boutons service utilisaient déjà 2563EB.
  static const sitterAccent = Color(0xFF2563EB);

  // v18.9.8 — constantes rôle centralisées. Remplacer progressivement les
  // const Color(0xFF1A73E8) / Color(0xFF2563EB) / greenColor éparpillés
  // par ces références. Toujours passer par `roleAccent(role)` pour les
  // widgets qui s'adaptent au rôle courant.
  static const Color ownerAccent = primaryColor; // #EF4324 orange
  static const Color walkerAccent = Color(0xFF16A34A); // vert walker

  /// Retourne la couleur d'accent du rôle fourni.
  /// Valeurs acceptées : 'owner' | 'sitter' | 'walker'.
  /// Fallback : `primaryColor` (orange owner) si rôle inconnu.
  static Color roleAccent(String? role) {
    switch ((role ?? '').toLowerCase()) {
      case 'walker':
        return walkerAccent;
      case 'sitter':
        return sitterAccent;
      case 'owner':
        return ownerAccent;
      default:
        return primaryColor;
    }
  }

  // Session v15-4 — Map Boost theme palette. Distinct from Boost (red) and
  // Premium (orange) so the user immediately sees Map Boost = "carte".
  // Blue for the entry tiers + gold for the premium tiers.
  // v354 — refonte PawSpot : l'identité produit passe du bleu au DORÉ.
  static const Color mapBoostBlue = Color(0xFFE8A00A);
  static const Color mapBoostGold = Color(0xFFF59E0B);
  static const Color mapBoostGoldDeep = Color(0xFFD97706);

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
  // v448 — Daniel : « tous les fonds gris clair de l'app → jaune clair, en
  // profondeur ». Le fond de PAGE (scaffold) et le FILL des champs/zones
  // internes passent en jaune doux. Les CARTES restent BLANCHES (cardLight) →
  // page jaune pâle + cartes blanches = chaleureux ET lisible. Comme
  // scaffold()/inputFill() routent par ces constantes, le changement est
  // app-wide (1 source = toutes les pages). Le mode SOMBRE est inchangé.
  static const Color scaffoldLight = Color(0xFFFFF8E1); // jaune doux (ex gris F7F7F8)
  static const Color cardLight = Color(0xFFFFFFFF);
  // Fill des inputs / zones internes : un cran plus soutenu que le scaffold
  // pour rester distinct sur une page jaune comme sur une carte blanche.
  static const Color inputFillLight = Color(0xFFFFF3D2);

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
      _isDark(context) ? const Color(0xFF2A2A2A) : inputFillLight;

  /// Subtle shadow that works in dark mode (invisible) and light mode.
  ///
  /// v23.1 part 232 — Daniel : "sa surrame le scroll est au ralenti".
  /// blurRadius reduit de 10 → 3 : un shadow blur de 10 est tres
  /// couteux GPU-side (chaque pixel doit echantilloner 10x10 voisins).
  /// 3 reste visuellement subtle mais 11x moins de samples = scroll
  /// fluide sur Oppo / low-end GPU. Aussi on retourne const list pour
  /// permettre Flutter d'identifier les cards qui partagent ce shadow.
  static const List<BoxShadow> _lightCardShadow = [
    BoxShadow(
      color: Color(0x0A000000), // alpha 0.04
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];
  static const List<BoxShadow> _emptyCardShadow = [];
  static List<BoxShadow> cardShadow(BuildContext context) =>
      _isDark(context) ? _emptyCardShadow : _lightCardShadow;
}
