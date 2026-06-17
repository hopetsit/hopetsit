import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

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
  // v449 — léger gris neutre (revert du jaune v448 ; le fond de page est
  // désormais teinté par RÔLE, cf scaffold()).
  static const lightGrey = Color(0xFFF1F2F4);
  static const greyText = Color(0xFF707070);
  static const chatFieldColor = Color(0xFFF1F2F4);
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

  /// v449 — accent du rôle COURANT (résolu via user_role / profil / override).
  static Color activeRoleAccent() => roleAccent(_activeRole());

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
  // v449 — Daniel : « au lieu du jaune, couleur PAR RÔLE depuis l'inscription
  // jusqu'aux pages de l'app : owner orange pâle, sitter bleu pâle, walker vert
  // pâle ». Le fond de PAGE (scaffold) + le FILL des champs sont teintés selon
  // le rôle courant. Cartes restent BLANCHES. Mode SOMBRE inchangé.
  static const Color cardLight = Color(0xFFFFFFFF);

  // Fonds de page pâles par rôle.
  static const Color scaffoldOwnerLight = Color(0xFFFFF1EC); // orange pâle
  static const Color scaffoldSitterLight = Color(0xFFEAF2FD); // bleu pâle
  static const Color scaffoldWalkerLight = Color(0xFFEAF7EE); // vert pâle
  // Fill des inputs : un cran plus soutenu que le scaffold (par rôle).
  static const Color inputFillOwnerLight = Color(0xFFFCE4DC);
  static const Color inputFillSitterLight = Color(0xFFDDEAFB);
  static const Color inputFillWalkerLight = Color(0xFFDCEFE3);

  /// v449 — override de rôle posé par le wizard d'inscription (qui connaît le
  /// rôle AVANT toute auth). Sert UNIQUEMENT de fallback : une fois connecté,
  /// le rôle réel (user_role / user_profile.role) gagne, donc pas de fuite.
  /// Effacé au boot, au login (OTP) et au logout.
  static String? activeRoleOverride;

  static String _normalizeRole(String? raw) {
    final r = (raw ?? '').toLowerCase();
    if (r.contains('sitter')) return 'sitter';
    if (r.contains('walker')) return 'walker';
    if (r.contains('owner')) return 'owner';
    return '';
  }

  static String _activeRole() {
    try {
      final box = GetStorage();
      // 1) Rôle canonique mutable (mis à jour à chaque bascule de profil).
      final byRole = _normalizeRole(box.read<String>('user_role'));
      if (byRole.isNotEmpty) return byRole;
      // 2) Rôle embarqué dans le profil stocké.
      final p = box.read<Map>('user_profile');
      final byProfile = _normalizeRole((p?['role'] ?? '').toString());
      if (byProfile.isNotEmpty) return byProfile;
    } catch (_) {/* défensif */}
    // 3) Override d'inscription (avant auth), sinon owner.
    final ov = _normalizeRole(activeRoleOverride);
    if (ov.isNotEmpty) return ov;
    return 'owner';
  }

  // Gradient
  static const LinearGradient linearGradient = LinearGradient(
    colors: [Color(0xFFEF4324), Color(0xFFFF6B4A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Theme-aware helpers ──────────────────────────────────────────
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Fond de page pâle pour le rôle courant (mode clair). Public : sert aussi
  /// de fallback global dans le thème (main.dart).
  static Color scaffoldLightForRole() {
    switch (_activeRole()) {
      case 'sitter':
        return scaffoldSitterLight;
      case 'walker':
        return scaffoldWalkerLight;
      default:
        return scaffoldOwnerLight;
    }
  }

  /// Fill des inputs pâle pour le rôle courant (mode clair).
  static Color inputFillLightForRole() {
    switch (_activeRole()) {
      case 'sitter':
        return inputFillSitterLight;
      case 'walker':
        return inputFillWalkerLight;
      default:
        return inputFillOwnerLight;
    }
  }

  /// Scaffold / page background — teinté par RÔLE en mode clair (v449).
  static Color scaffold(BuildContext context) =>
      _isDark(context) ? backgroundDark : scaffoldLightForRole();

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

  /// Chat field / input background — teinté par RÔLE en mode clair (v449).
  static Color inputFill(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2A2A2A) : inputFillLightForRole();

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
