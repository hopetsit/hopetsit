import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/utils/app_colors.dart';

/// v552 — jetons du redesign PawMap v3 (maquette Claude Design, spec
/// `SPEC-CLAUDE-CODE.md`).
///
/// Décision de Daniel : on suit la maquette pour l'ambiance générale (fond
/// crème, panneaux « verre dépoli », rose des onglets/actifs, police Sora)
/// MAIS on garde les couleurs de rôle et d'abonnement du produit — un
/// propriétaire reste orange, un gardien bleu, un promeneur vert, PawFollow /
/// PawFamily violet, PawSpot ambre. Ces couleurs ont une signification pour
/// les utilisateurs, elles ne sont pas décoratives.
class PawMapTheme {
  PawMapTheme._();

  // ── Maquette ────────────────────────────────────────────────────────────
  static const Color ink = Color(0xFF18100E);
  static const Color sub = Color(0xFF877C71);
  static const Color bg = Color(0xFFFAF7F2);
  static const Color mapBg = Color(0xFFF0EBE1);
  static const Color border = Color(0x1218100E); // rgba(23,19,15,.07)
  static const Color accent = Color(0xFFD83C28); // v559 — orange de l'icône (Daniel), ex-E8551C
  static const Color rose = Color(0xFFE0397F); // agrandir, actif, onglets
  static const Color roseDark = Color(0xFFC72A6C);
  static const Color ok = Color(0xFF26A65B);
  static const Color danger = Color(0xFFCE3B2C);

  // ── Couleurs produit conservées (consigne Daniel) ───────────────────────
  static const Color owner = Color(0xFFC92A12); // propriétaire
  static const Color sitter = Color(0xFF2563EB); // gardien
  static const Color walker = Color(0xFF16A34A); // promeneur
  static const Color pawFollow = Color(0xFF7C3AED); // PawFollow / PawFamily
  static const Color pawSpot = Color(0xFFE8920A); // PawSpot

  /// Couleur officielle d'un rôle (jamais celle de la maquette : c'est un
  /// code de lecture du produit).
  static Color forRole(String role) {
    switch (role.toLowerCase()) {
      case 'walker':
        return walker;
      case 'sitter':
        return sitter;
      default:
        return owner;
    }
  }

  // ── Fonds pastel des puces (maquette) ───────────────────────────────────
  static const Color pastelBlue = Color(0xFFEEF0FB);
  static const Color pastelPeach = Color(0xFFFCEDE4);
  static const Color pastelGreen = Color(0xFFE6F4EB);
  static const Color pastelRed = Color(0xFFFBEAE8);
  static const Color pastelViolet = Color(0xFFF0EDFB);

  // ── Mode sombre des PANNEAUX / FEUILLES ─────────────────────────────────
  // v571 — audit lisibilité. Le FOND DE CARTE Google reste clair en sombre
  // (décision produit : le « mode nuit » de la carte est un réglage à part),
  // et les repères, bitmaps et boutons ronds du rail gardent leurs couleurs.
  // Ce qui suit ne concerne QUE les surfaces posées par-dessus la carte
  // (panneau des filtres, cartes, bandeaux) et les feuilles/écrans annexes :
  // en sombre, un panneau crème avec du texte `ink` était illisible.
  static const Color inkDark = Color(0xFFF5F0EF);
  static const Color subDark = Color(0xFFBBA9A5);
  static const Color bgDark = Color(0xFF1E1512); // fond de feuille / d'écran
  static const Color panelDark = Color(0xFF2E201C); // panneau, carte, pilule
  static const Color borderDarkTone = Color(0x33FFFFFF);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Texte principal d'un panneau (noir en clair, presque blanc en sombre).
  static Color inkOn(BuildContext context) => isDark(context) ? inkDark : ink;

  /// Texte secondaire d'un panneau.
  static Color subOn(BuildContext context) => isDark(context) ? subDark : sub;

  /// Fond d'une feuille / d'un écran annexe de la PawMap.
  static Color bgOn(BuildContext context) => isDark(context) ? bgDark : bg;

  /// Surface d'un panneau, d'une carte ou d'une pilule (blanche en clair).
  static Color panelOn(BuildContext context) =>
      isDark(context) ? panelDark : Colors.white;

  /// Filet de séparation d'un panneau.
  static Color borderOn(BuildContext context) =>
      isDark(context) ? borderDarkTone : border;

  /// Voile discret posé sur une surface de panneau (ex. pastille d'icône) :
  /// `ink` en clair, blanc en sombre, pour rester visible dans les deux cas.
  static Color veilOn(BuildContext context, double alpha, {double? darkAlpha}) =>
      isDark(context)
          ? Colors.white.withValues(alpha: darkAlpha ?? alpha)
          : ink.withValues(alpha: alpha);

  /// Variante éclaircie d'une couleur de rôle / de type, pour rester lisible
  /// sur une surface sombre (le bleu gardien pur passe mal sur anthracite).
  static Color lighten(Color c, [double amount = 0.45]) =>
      Color.lerp(c, Colors.white, amount)!;

  /// Couleur de texte d'une puce teintée : la couleur du type en clair, sa
  /// variante éclaircie en sombre.
  static Color toneOn(BuildContext context, Color tone) =>
      isDark(context) ? lighten(tone) : tone;

  /// Surface « verre dépoli » de la maquette : blanc translucide + flou.
  static BoxDecoration glass({double radius = 26, double opacity = 0.88}) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: ink.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      );

  /// Même surface, adaptée au mode sombre (panneau anthracite opaque).
  static BoxDecoration glassOn(BuildContext context,
      {double radius = 26, double opacity = 0.88}) {
    if (!isDark(context)) return glass(radius: radius, opacity: opacity);
    return BoxDecoration(
      color: panelDark.withValues(alpha: opacity < 1 ? 0.94 : 1.0),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderDarkTone),
      boxShadow: const [
        BoxShadow(
          color: Color(0x667A2A16),
          blurRadius: 32,
          offset: Offset(0, 12),
        ),
      ],
    );
  }

  /// Ombre douce des pilules flottantes (0 4px 14px rgba(23,19,15,.14)).
  static List<BoxShadow> get pillShadow => [
        BoxShadow(
          color: ink.withValues(alpha: 0.14),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  // ── v573 — jetons communs aux BOUTONS de la PawMap ──────────────────────
  // Daniel : « peaufine les boutons de la PawMap ». Le rail gauche, la capsule
  // droite, les trois pilules du haut et le bandeau d'itinéraire tiraient
  // chacun leurs tailles, rayons et ombres de valeurs écrites en dur : d'où
  // des hauteurs et des épaisseurs de bord qui ne tombaient pas juste. Tout
  // part désormais d'ici. Ce sont des dp de maquette : les appelants passent
  // par `.w` / `.h` / `.r` comme partout ailleurs.

  /// Diamètre d'un bouton rond du rail gauche.
  static const double railButtonSize = 44; // v585 — 44 (bug 8)

  /// Écart vertical entre deux boutons du rail (identique partout).
  static const double railGap = 10; // v585 — 10 (bug 8)

  /// Part du diamètre occupée par le glyphe d'un bouton du rail — la même pour
  /// une icône Material et pour un SVG, sinon les poids optiques divergent.
  static const double railIconRatio = 0.48;

  /// Zone tactile minimale d'un bouton (recommandation Apple ; Material dit
  /// 48, mais le rail en compte huit et doit tenir au-dessus du menu).
  static const double minTapTarget = 44;

  /// Hauteur commune des pilules de la rangée du haut.
  static const double pillHeight = 46;

  /// Rayon commun des pilules (capsule pleine).
  static const double pillRadius = 999;

  /// Épaisseur de bord commune des pilules et de la capsule.
  static const double pillBorderWidth = 1.4;

  /// Dégradé subtil d'un bouton du rail : la couleur légèrement éclaircie en
  /// haut, assombrie en bas. Jamais un aplat — mais jamais un effet « bille »
  /// non plus : 16 % vers le blanc, 18 % vers le noir.
  static LinearGradient railGradient(Color c, {Color? top, Color? bottom}) =>
      LinearGradient(
        colors: [
          top ?? lighten(c, 0.16),
          bottom ?? Color.lerp(c, Colors.black, 0.18)!,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  /// Ombre portée COLORÉE d'un bouton du rail (jamais du noir dur) : une
  /// nappe à la teinte du bouton, plus une assise très fine pour le détacher
  /// d'un fond de carte clair. [active] ajoute le halo de l'état sélectionné.
  static List<BoxShadow> railShadow(
    Color tone, {
    bool pressed = false,
    bool active = false,
  }) =>
      [
        if (active)
          BoxShadow(
            color: tone.withValues(alpha: 0.42),
            blurRadius: 16,
            spreadRadius: 1.5,
          ),
        BoxShadow(
          color: tone.withValues(alpha: pressed ? 0.20 : 0.34),
          blurRadius: 14,
          spreadRadius: -2,
          offset: Offset(0, pressed ? 3 : 6),
        ),
        BoxShadow(
          color: AppColors.shadow(0.07),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  /// Ombre d'une pilule / de la capsule, thémée : `pillShadow` en clair (la
  /// maquette), une ombre plus dense en sombre où un halo clair ne se voit pas.
  static List<BoxShadow> pillShadowOn(BuildContext context) => isDark(context)
      ? const [
          BoxShadow(
            color: Color(0x737A2A16),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ]
      : pillShadow;

  /// Police de la PawMap et de ses sous-pages (Sora, comme la maquette).
  /// Le reste de l'app garde ses polices existantes.
  static TextStyle font({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color color = ink,
    double? height,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.sora(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Même police, mais la couleur par défaut suit le thème (`inkOn`).
  /// À utiliser dans les panneaux et feuilles, pas sur la carte elle-même.
  static TextStyle fontOn(
    BuildContext context, {
    required double size,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double? height,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.sora(
        fontSize: size,
        fontWeight: weight,
        color: color ?? inkOn(context),
        height: height,
        letterSpacing: letterSpacing,
      );
}
