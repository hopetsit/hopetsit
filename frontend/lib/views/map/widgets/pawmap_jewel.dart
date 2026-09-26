// v590 (26/09) — handoff « Améliorer boutons et profil PawMap » (Daniel).
//
// Le style « BIJOU » des boutons de couleur pleine (README §3.1) :
//   · rond, dégradé 170° en TROIS tons (clair −20 %, moyen 40 %, foncé 100 %) ;
//   · liseré intérieur blanc 1,5 px à 30 %, ombre intérieure en bas, filet
//     sombre 1 px, halo coloré sous le bouton ;
//   · reflet en haut (45 % de la hauteur) ;
//   · icône Material Symbols Rounded PLEINE, blanche, légère ombre portée et
//     dégradé vertical (100 % → 72 %).
// Les palettes sont celles du tableau §3.2 (boutons) et §9 (rôles).
// Rien ici ne décide d'une action : chaque bouton reçoit son `onTap`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PawJewelPalette {
  const PawJewelPalette(this.light, this.mid, this.dark);
  final Color light;
  final Color mid;
  final Color dark;

  LinearGradient get gradient => LinearGradient(
        // 170° CSS ≈ du haut (légèrement à gauche) vers le bas.
        begin: const Alignment(-0.17, -1),
        end: const Alignment(0.17, 1),
        colors: [light, mid, dark],
        // CSS : clair à −20 %, moyen à 40 %, foncé à 100 % → recalé sur 0..1.
        stops: const [0.0, 0.5, 1.0],
      );
}

// §3.2 — code couleur des boutons.
const PawJewelPalette kJewelChat =
    PawJewelPalette(Color(0xFF6B9BFF), Color(0xFF3B6FE0), Color(0xFF2451B8));
const PawJewelPalette kJewelPhoto =
    PawJewelPalette(Color(0xFFFFC06A), Color(0xFFF39A2B), Color(0xFFD97A0E));
const PawJewelPalette kJewelSpots =
    PawJewelPalette(Color(0xFFFFD76A), Color(0xFFF0B323), Color(0xFFCF9208));
const PawJewelPalette kJewelTag =
    PawJewelPalette(Color(0xFF52D6C6), Color(0xFF1FA89A), Color(0xFF0F7F70));
const PawJewelPalette kJewelFeed =
    PawJewelPalette(Color(0xFF6A5C57), Color(0xFF3A2F2C), Color(0xFF1D1715));
const PawJewelPalette kJewelReport =
    PawJewelPalette(Color(0xFFFF806B), Color(0xFFE0402F), Color(0xFFB8261A));
const PawJewelPalette kJewelFriends =
    PawJewelPalette(Color(0xFFFF8CC2), Color(0xFFE8448F), Color(0xFFC12A6E));
const PawJewelPalette kJewelRoute =
    PawJewelPalette(Color(0xFF5FCC79), Color(0xFF2E9E48), Color(0xFF1D7A34));
const PawJewelPalette kJewelAround =
    PawJewelPalette(Color(0xFFB08CFF), Color(0xFF7B4DE0), Color(0xFF5A30BF));
/// Les 4 boutons du haut à droite : rouges pour les 3 rôles.
const PawJewelPalette kJewelHeader =
    PawJewelPalette(Color(0xFFD9442C), Color(0xFFC92A12), Color(0xFF9E1F0B)); // v592 — orange foncé
/// §3.4 — Balade arrêtée (gris) / en direct (vert).
const PawJewelPalette kJewelWalkOff =
    PawJewelPalette(Color(0xFFC4B3AC), Color(0xFF978279), Color(0xFF6F5C55));
const PawJewelPalette kJewelWalkOn =
    PawJewelPalette(Color(0xFF7FE39A), Color(0xFF2E9E48), Color(0xFF1D7A34));

// §9 — couleurs par rôle (viseur, flèches, marqueur Moi, bouton principal).
const PawJewelPalette kJewelOwner =
    PawJewelPalette(Color(0xFFD9442C), Color(0xFFC92A12), Color(0xFF9E1F0B)); // v592 — orange foncé
const PawJewelPalette kJewelSitter =
    PawJewelPalette(Color(0xFF8AB8FF), Color(0xFF3B78E8), Color(0xFF1F4FBF));
const PawJewelPalette kJewelWalker =
    PawJewelPalette(Color(0xFF7FE39A), Color(0xFF2E9E48), Color(0xFF1D7A34));

PawJewelPalette pawJewelForRole(String role) {
  switch (role.toLowerCase()) {
    case 'sitter':
      return kJewelSitter;
    case 'walker':
      return kJewelWalker;
    default:
      return kJewelOwner;
  }
}

/// Couleur « solide » du rôle (§9) : libellés, liserés, chevrons.
Color pawRoleSolid(String role) {
  switch (role.toLowerCase()) {
    case 'sitter':
      return const Color(0xFF2F6FE0);
    case 'walker':
      return const Color(0xFF2A9A48);
    default:
      return const Color(0xFFD8352A);
  }
}

/// Icône Material Symbols Rounded pleine (police figée `PawSymbols`, v591).
class PawSymbol extends StatelessWidget {
  const PawSymbol(this.icon, {super.key, required this.size, this.color = Colors.white});
  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color);
  }
}

/// Bouton rond « bijou ».
class PawJewel extends StatefulWidget {
  const PawJewel({
    super.key,
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 38,
    this.iconSize,
    this.onLongPress,
    this.badge,
    this.active = false,
  });

  final PawJewelPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Diamètre en dp logiques (38 barres, 40 en-tête / bouton principal).
  final double size;
  final double? iconSize;

  /// Pastille posée en haut à droite (compteur, point rouge…).
  final Widget? badge;
  final bool active;

  @override
  State<PawJewel> createState() => _PawJewelState();
}

class _PawJewelState extends State<PawJewel> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size.w;
    // Zone tactile ≥ 44 dp (pixels logiques, jamais réduite par ScreenUtil).
    final double tap = s < 44 ? 44 : s;
    final double glyph = widget.iconSize ?? s * 0.52;
    final p = widget.palette;
    return Semantics(
      button: true,
      label: widget.label,
      selected: widget.active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _set(false);
                HapticFeedback.mediumImpact();
                widget.onLongPress!();
              },
        child: SizedBox(
          width: tap,
          height: tap,
          child: Center(
            child: AnimatedScale(
              scale: _pressed ? 0.94 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: SizedBox(
                width: s,
                height: s,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: p.gradient,
                          boxShadow: [
                            // Filet sombre 1 px.
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              spreadRadius: 1,
                            ),
                            // Halo coloré sous le bouton.
                            BoxShadow(
                              color: p.mid.withValues(alpha: widget.active ? 0.75 : 0.55),
                              blurRadius: 12,
                              spreadRadius: -5,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Ombre intérieure en bas (inset 0 −3 5 rgba(0,0,0,.22)).
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.35),
                            radius: 0.95,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.22),
                            ],
                            stops: const [0.0, 0.72, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Liseré intérieur blanc 1,5 px à 30 %.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: widget.active ? 0.85 : 0.30),
                            width: widget.active ? 2.2 : 1.5,
                          ),
                        ),
                      ),
                    ),
                    // Reflet : left/right 5, top 3, hauteur 45 %.
                    Positioned(
                      left: s * 0.13,
                      right: s * 0.13,
                      top: s * 0.08,
                      height: s * 0.45,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.elliptical(s, s * 0.5),
                            bottom: Radius.elliptical(s, s * 0.4),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.55),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Icône : ombre portée légère + dégradé 100 % → 72 %.
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.translate(
                            offset: const Offset(0, 1.5),
                            child: PawSymbol(widget.icon,
                                size: glyph,
                                color: Colors.black.withValues(alpha: 0.28)),
                          ),
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (r) => LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white,
                                Colors.white.withValues(alpha: 0.72),
                              ],
                            ).createShader(r),
                            child: PawSymbol(widget.icon, size: glyph),
                          ),
                        ],
                      ),
                    ),
                    if (widget.badge != null)
                      Positioned(top: -5, right: -6, child: widget.badge!),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille rouge 8 px (« Voir signaux »).
class PawJewelDot extends StatelessWidget {
  const PawJewelDot({super.key, this.color = const Color(0xFFE8402C)});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        margin: const EdgeInsets.only(top: 6, right: 6),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );
}

/// Badge blanc du nombre de suiveurs (§3.4) : 19 px, texte vert 800.
class PawFollowersBadge extends StatelessWidget {
  const PawFollowersBadge({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 19),
        height: 19,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2E9E48), width: 1.5),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Color(0xFF1F7A37),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      );
}

/// Icônes Symbols utilisées par la PawMap (une seule source).
///
/// v591 — Daniel : « 4 boutons sans dessin » + « le bouton fermer n'apparaît
/// pas ». Cause mesurée sur l'AAB et l'IPA 590 : au build release, Flutter
/// réduit la police VARIABLE Material Symbols aux seules icônes utilisées et
/// abîme sa table de variations (gvar) → dessinées pleines/grasses, 16 icônes
/// sur 24 sortaient vides ou fausses (le debug, police complète, ne le montre
/// pas). Correctif : police FIGÉE `PawSymbols` (Material Symbols Rounded
/// instanciée à FILL 1 · wght 600 · GRAD 200 · opsz 48, sans variations),
/// que la réduction du build garde intacte. Mêmes codes que le paquet.
class PawSymbols {
  static const String _family = 'PawSymbols';
  static const IconData chat = IconData(0xe8af, fontFamily: _family);
  static const IconData photo = IconData(0xe412, fontFamily: _family);
  static const IconData spots = IconData(0xf612, fontFamily: _family);
  static const IconData tag = IconData(0xef3a, fontFamily: _family);
  static const IconData feed = IconData(0xef75, fontFamily: _family);
  static const IconData report = IconData(0xf083, fontFamily: _family);
  static const IconData friends = IconData(0xea21, fontFamily: _family);
  static const IconData route = IconData(0xeacd, fontFamily: _family);
  static const IconData around = IconData(0xe538, fontFamily: _family);
  static const IconData help = IconData(0xeb8b, fontFamily: _family);
  static const IconData search = IconData(0xef7a, fontFamily: _family);
  static const IconData refresh = IconData(0xe5d5, fontFamily: _family);
  static const IconData settings = IconData(0xe8b8, fontFamily: _family);
  static const IconData publish = IconData(0xef49, fontFamily: _family);
  static const IconData requests = IconData(0xe85d, fontFamily: _family);
  static const IconData walk = IconData(0xe536, fontFamily: _family);
  static const IconData home = IconData(0xe9b2, fontFamily: _family);
  static const IconData close = IconData(0xe5cd, fontFamily: _family);
  static const IconData chevronRight = IconData(0xe5cc, fontFamily: _family);
}
