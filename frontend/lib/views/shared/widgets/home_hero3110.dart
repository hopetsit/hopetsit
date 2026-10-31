// PAM-B 31/10/2026 — HERO des 3 accueils (maquettes Daniel
// `~/hopetsit-social/design_handoff_accueil_3110/`, README = valeurs exactes).
//
// DESIGN UNIQUEMENT : ce fichier ne connaît aucun contrôleur, aucune route.
// Tout passe par callbacks ; l'écran hôte branche exactement les mêmes actions
// qu'avant (fusée → boutique, cloche → notifications, champ → publier,
// « Changer » → feuille de ville).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/widgets/app_text.dart' show cjkFontFallback;
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/role_chip.dart'
    show roleIconData, roleLabelKey;

/// Jetons de couleur par rôle (README « Couleurs par rôle »).
class HomeTokens3110 {
  const HomeTokens3110._({
    required this.primary,
    required this.heroStart,
    required this.heroEnd,
    required this.pageBg,
    required this.tint,
    required this.tintDeco,
    required this.shadowColor,
  });

  final Color primary;
  final Color heroStart;
  final Color heroEnd;
  final Color pageBg;
  final Color tint;
  final Color tintDeco;
  final Color shadowColor;

  static const HomeTokens3110 owner = HomeTokens3110._(
    primary: Color(0xFFC62817),
    heroStart: Color(0xFFD63A22),
    heroEnd: Color(0xFFB8220F),
    pageBg: Color(0xFFFAF6F3),
    tint: Color(0xFFF6DED8),
    tintDeco: Color(0xFFFBEAE6),
    shadowColor: Color(0x47C62817), // rgba(198,40,23,0.28)
  );
  static const HomeTokens3110 sitter = HomeTokens3110._(
    primary: Color(0xFF2457C5),
    heroStart: Color(0xFF3B6FE0),
    heroEnd: Color(0xFF2050B8),
    pageBg: Color(0xFFF4F7FC),
    tint: Color(0xFFE6EEFB),
    tintDeco: Color(0xFFEEF3FC),
    shadowColor: Color(0x402457C5), // 0.25
  );
  static const HomeTokens3110 walker = HomeTokens3110._(
    primary: Color(0xFF1F9A4B),
    heroStart: Color(0xFF2BB35E),
    heroEnd: Color(0xFF188A42),
    pageBg: Color(0xFFF3F9F4),
    tint: Color(0xFFE3F4E8),
    tintDeco: Color(0xFFEAF6ED),
    shadowColor: Color(0x401F9A4B),
  );

  static HomeTokens3110 forRole(String? role) {
    switch ((role ?? '').toLowerCase()) {
      case 'walker':
        return walker;
      case 'sitter':
        return sitter;
      default:
        return owner;
    }
  }

  /// Couleurs communes (README « Couleurs communes »), adaptées au mode sombre.
  static const Color ink = Color(0xFF1C1917);
  static const Color muted = Color(0xFF8A7F7B);
  static const Color tertiary = Color(0xFFA39791);
  static const Color chevron = Color(0xFFB5A9A4);
  static const Color chipInk = Color(0xFF6B615D);
  static const Color notifDot = Color(0xFFFFD166);
  static const Color availableDot = Color(0xFF7CE58A);

  static bool isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;
  Color pageBackground(BuildContext c) =>
      isDark(c) ? AppColors.scaffold(c) : pageBg;
  static Color card(BuildContext c) =>
      isDark(c) ? AppColors.card(c) : Colors.white;
  static Color text(BuildContext c) =>
      isDark(c) ? AppColors.textPrimary(c) : ink;
  static Color text2(BuildContext c) =>
      isDark(c) ? AppColors.textSecondary(c) : muted;
  static Color text3(BuildContext c) =>
      isDark(c) ? AppColors.textSecondary(c) : tertiary;

  /// Teinte claire : en sombre, la couleur primaire très transparente lirait
  /// gris → on garde une teinte PLEINE sombre dérivée du primaire.
  Color tintOn(BuildContext c) => isDark(c)
      ? Color.alphaBlend(primary.withValues(alpha: 0.22), AppColors.card(c))
      : tint;
  Color tintDecoOn(BuildContext c) => isDark(c)
      ? Color.alphaBlend(primary.withValues(alpha: 0.12), AppColors.card(c))
      : tintDeco;

  /// Ombre de carte : `0 2px 12px rgba(…,0.05), 0 0 0 1px rgba(28,25,23,0.04)`.
  List<BoxShadow> cardShadow(BuildContext c) => isDark(c)
      ? const <BoxShadow>[]
      : <BoxShadow>[
          BoxShadow(
            color: _cardShadowInk.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
          const BoxShadow(color: Color(0x0A1C1917), spreadRadius: 1),
        ];

  Color get _cardShadowInk {
    if (identical(this, sitter)) return const Color(0xFF14285A);
    if (identical(this, walker)) return const Color(0xFF0A3C1E);
    return const Color(0xFF3C140A);
  }
}

/// Bloc pleine largeur en dégradé 160°, coins bas 32, cercle décoratif.
class HomeHero3110 extends StatelessWidget {
  const HomeHero3110({
    super.key,
    required this.role,
    required this.name,
    required this.avatarUrl,
    required this.onRocket,
    required this.onBell,
    required this.unreadCount,
    required this.child,
    this.bottomPadding = 22,
  });

  final String role;
  final String name;
  final String avatarUrl;
  final VoidCallback onRocket;
  final VoidCallback onBell;
  final int unreadCount;

  /// Contenu sous l'en-tête : champ + ligne dispo (propriétaire) ou bloc
  /// statut + ligne lieu (prestataire).
  final Widget child;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final t = HomeTokens3110.forRole(role);
    // Maquette : padding haut 60 « status bar comprise » → encoche réelle + 4.
    final double top = math.max(MediaQuery.paddingOf(context).top, 44) + 4;
    return Container(
      key: const ValueKey<String>('home_hero_3110'),
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.34, -1),
          end: const Alignment(0.34, 1),
          colors: <Color>[t.heroStart, t.heroEnd],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top, 20, bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[_header(context, t), child],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, HomeTokens3110 t) {
    return Row(
      children: <Widget>[
        HeroAvatar3110(url: avatarUrl, name: name),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'pamb3110_hello'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: pop3110(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 1),
              // 631 (ZOE) : le badge passe sous le nom quand les deux ne
              // tiennent pas sur la ligne (« Camill… » coupé sur iPhone 16).
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 3,
                children: <Widget>[
                  Text(
                    name,
                    key: const ValueKey<String>('home_hero_name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pop3110(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  _roleBadge(),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        HeroRoundButton3110(
          key: const ValueKey<String>('home_hero_rocket'),
          icon: Icons.rocket_launch_outlined,
          onTap: onRocket,
          semanticLabel: 'home571_card_boost_title'.tr,
        ),
        const SizedBox(width: 8),
        HeroRoundButton3110(
          key: const ValueKey<String>('home_hero_bell'),
          icon: Icons.notifications_none_rounded,
          onTap: onBell,
          dot: unreadCount > 0,
          heroColor: t.heroStart,
          semanticLabel: 'notifications_title'.tr,
        ),
      ],
    );
  }

  Widget _roleBadge() {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 3, 9, 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(roleIconData(role), size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            roleLabelKey(role).tr,
            maxLines: 1,
            style: pop3110(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar rond 44 px, anneau 2,5 px blanc 70 %.
class HeroAvatar3110 extends StatelessWidget {
  const HeroAvatar3110({super.key, required this.url, required this.name});
  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final String initial = name.trim().isEmpty
        ? ''
        : name.trim().characters.first.toUpperCase();
    final Widget fallback = Container(
      color: const Color(0xFF6F8FB4),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: pop3110(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 2.5,
        ),
      ),
      child: ClipOval(
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

/// Bouton rond 40 px, fond blanc 16 %, icône blanche 18 px, point optionnel.
class HeroRoundButton3110 extends StatelessWidget {
  const HeroRoundButton3110({
    super.key,
    required this.icon,
    required this.onTap,
    this.dot = false,
    this.heroColor,
    this.semanticLabel,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool dot;
  final Color? heroColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Center(child: Icon(icon, size: 18, color: Colors.white)),
                if (dot)
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HomeTokens3110.notifDot,
                        border: Border.all(
                          color: heroColor ?? const Color(0xFFD63A22),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Propriétaire — champ « Écris ta demande ici… » (pill blanc + bouton noir →).
class HeroRequestField3110 extends StatelessWidget {
  const HeroRequestField3110({super.key, required this.onTap, this.hint});
  final VoidCallback onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey<String>('home_hero_field'),
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 5, 5, 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x405A0A00), // rgba(90,10,0,0.25)
                  blurRadius: 26,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    hint ?? 'post_input_hint'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pop3110(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: HomeTokens3110.tertiary,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: HomeTokens3110.ink,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Propriétaire — ligne « ● N gardien disponible à Ville ».
class HeroAvailableLine3110 extends StatelessWidget {
  const HeroAvailableLine3110({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: HomeTokens3110.availableDot,
              boxShadow: <BoxShadow>[
                BoxShadow(color: Color(0x407CE58A), spreadRadius: 3),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              key: const ValueKey<String>('home_hero_available'),
              // 631 (ZOE) : 2 lignes — coupée en anglais (« …as soon as y… »).
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: pop3110(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prestataire — bloc statut (rond blanc + check, titre, sous-titre).
class HeroStatusBlock3110 extends StatelessWidget {
  const HeroStatusBlock3110({
    super.key,
    required this.primary,
    required this.title,
    required this.subtitle,
  });
  final Color primary;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('home_hero_status'),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(Icons.check_rounded, size: 20, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: pop3110(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: pop3110(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Prestataire — ligne lieu « 📍 Ville · 50 km … Changer ».
class HeroLocationLine3110 extends StatelessWidget {
  const HeroLocationLine3110({
    super.key,
    required this.city,
    required this.radiusKm,
    required this.onChange,
  });
  final String city;
  final int radiusKm;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: <Widget>[
          const Icon(Icons.location_on_outlined, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: pop3110(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.3,
                ),
                children: <InlineSpan>[
                  TextSpan(text: city),
                  TextSpan(
                    text: ' · $radiusKm km',
                    style: pop3110(
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            key: const ValueKey<String>('home_hero_change_city'),
            borderRadius: BorderRadius.circular(8),
            onTap: onChange,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                'home571_change'.tr,
                style: pop3110(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.3,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Poppins (police des maquettes) avec le repli CJK de l'app.
TextStyle pop3110({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
  double? height,
  TextDecoration? decoration,
  Color? decorationColor,
}) => GoogleFonts.poppins(
  fontSize: fontSize,
  fontWeight: fontWeight,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
  decoration: decoration,
  decorationColor: decorationColor,
).copyWith(fontFamilyFallback: cjkFontFallback);
