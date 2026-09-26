// v570 — BARRE D'ONGLETS « PawMap » (variante 12d) + logo PawMap réutilisable.
//
// Handoff hi-fi de Daniel : `docs/design_handoff_pawmap_tab_bar/README.md`
// (prototypes `PawMap Tab Bar.dc.html` et `Splash Screen.dc.html`).
// Toutes les mesures/couleurs/timings viennent de ce document ; les seules
// libertés prises sont documentées ci-dessous (marge basse, hauteur utile).
//
// ⚠️ CE FICHIER NE CONTIENT QUE DU RENDU. Toute la logique de navigation
// (IndexedStack, requestedTab, badges, PromoPopup…) reste dans
// `stacked_navigation_wrapper.dart`.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/widgets/paw_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. COULEURS PAR RÔLE — LE SEUL ENDROIT À MODIFIER
// ─────────────────────────────────────────────────────────────────────────────

enum PawNavRole { owner, sitter, walker }

/// Dégradé vertical de la pilule + couleur de son ombre portée.
class PawTabBarPalette {
  const PawTabBarPalette({
    required this.top,
    required this.bottom,
    required this.shadow,
  });

  /// Haut du dégradé (`linear-gradient(180deg, top, bottom)`).
  final Color top;

  /// Bas du dégradé.
  final Color bottom;

  /// Ombre colorée `0 18px 40px <shadow>` (alpha compris).
  final Color shadow;
}

/// ⬅️ LES 3 JEUX DE COULEURS DE LA BARRE. Changer ici suffit.
/// (Décision produit de Daniel : la barre porte la couleur du service ;
/// la patte — noire + 4 doigts colorés — reste IDENTIQUE pour les 3 rôles.)
const Map<PawNavRole, PawTabBarPalette> kPawTabBarPalettes =
    <PawNavRole, PawTabBarPalette>{
  PawNavRole.owner: PawTabBarPalette(
    top: Color(0xFFC92A12), // v592 — orange foncé (ex-D83C28)
    bottom: Color(0xFF9E1F0B),
    shadow: Color(0x66C92A12), // rgba(216,60,40,.4)
  ),
  PawNavRole.sitter: PawTabBarPalette(
    top: Color(0xFF2F6FD6),
    bottom: Color(0xFF1E4FB0),
    shadow: Color(0x662F6FD6), // rgba(47,111,214,.4)
  ),
  PawNavRole.walker: PawTabBarPalette(
    top: Color(0xFF2FAE4E),
    bottom: Color(0xFF15803D),
    shadow: Color(0x662FAE4E), // rgba(47,174,78,.4)
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// 2. MESURES DE LA BARRE
// ─────────────────────────────────────────────────────────────────────────────

/// Hauteur de la pilule (README : 70).
const double kPawTabBarPillHeight = 70;

/// Marges latérales de la pilule (README : 16).
const double kPawTabBarSideMargin = 16;

/// Marge BASSE de la pilule, au-dessus de l'inset système.
///
/// ⚠️ Le README dit 24. On garde **6**, exactement la marge de l'ancien menu
/// (`6 + viewPadding.bottom`) : la barre s'ancre donc au MÊME pixel qu'avant
/// et ne gagne que les 12 px de hauteur de la pilule (70 au lieu de 58). Avec
/// 24 elle serait montée de 30 px et aurait mordu sur les écrans qui réservent
/// un dégagement fixe.
const double kPawTabBarBottomMargin = 6;

/// Zone tactile de la patte (README : 84×84).
const double kPawTabBarPawBox = 84;

/// Écart entre le bas de la pilule et le bas de la zone tactile de la patte
/// (README : barre à `bottom:24`, patte à `bottom:68` → 44).
const double kPawTabBarPawOffset = 44;

/// Montée de la patte quand PawMap est actif (README : translateY(-7px)).
const double kPawTabBarPawLift = 7;

/// Largeur du slot central (README : 84, `flex:none`).
const double kPawTabBarCenterSlot = 84;

/// Hauteur TOTALE du widget (= hauteur rapportée au Scaffold) : elle inclut la
/// saillie de la patte pour que celle-ci reste entièrement cliquable.
double pawTabBarTotalHeight(double systemInset) =>
    kPawTabBarBottomMargin +
    kPawTabBarPawOffset +
    kPawTabBarPawBox +
    kPawTabBarPawLift +
    systemInset;

/// Hauteur UTILE (du bas de l'écran jusqu'au haut de la pilule) : c'est elle
/// qu'on annonce aux écrans-onglets, pour qu'ils gardent le même dégagement
/// qu'avec l'ancien menu (la saillie de la patte est transparente et centrée).
double pawTabBarUsefulHeight(double systemInset) =>
    kPawTabBarBottomMargin + kPawTabBarPillHeight + systemInset;

/// Easing « rebond » du handoff : `cubic-bezier(.3,1.5,.4,1)`.
const Cubic kPawBounce = Cubic(0.3, 1.5, 0.4, 1);

/// Easing « glissement » du point indicateur : `cubic-bezier(.3,1.4,.4,1)`.
const Cubic kPawSlide = Cubic(0.3, 1.4, 0.4, 1);

// ─────────────────────────────────────────────────────────────────────────────
// 3. GÉOMÉTRIE DE LA PATTE (coussinet-épingle + œil + 4 doigts)
// ─────────────────────────────────────────────────────────────────────────────

class PawToeSpec {
  const PawToeSpec({
    required this.left,
    required this.top,
    required this.size,
    required this.light,
    required this.dark,
    required this.tuck,
    required this.out,
  });

  /// Coin haut-gauche du cercle dans la zone de la patte.
  final double left;
  final double top;
  final double size;

  /// `radial-gradient(circle at 35% 30%, light, dark)`.
  final Color light;
  final Color dark;

  /// Transform de départ (rétracté / avant l'animation d'ouverture).
  final Offset tuck;

  /// Transform d'arrivée (doigt sorti).
  final Offset out;
}

class PawGlyphSpec {
  const PawGlyphSpec({
    required this.box,
    required this.pad,
    required this.padBorder,
    required this.eye,
    required this.toeBorder,
    required this.padShadow,
    required this.toeShadow,
    required this.eyeShadow,
    required this.toes,
  });

  final double box;
  final double pad;
  final double padBorder;
  final double eye;
  final double toeBorder;
  final List<BoxShadow> padShadow;
  final List<BoxShadow> toeShadow;
  final List<BoxShadow> eyeShadow;
  final List<PawToeSpec> toes;
}

const Color _kToeRedLight = Color(0xFFFF7A66);
const Color _kToeRedDark = Color(0xFFC92A12);
const Color _kToeBlueLight = Color(0xFF6FA0FF);
const Color _kToeBlueDark = Color(0xFF2F6FD6);
const Color _kToeGreenLight = Color(0xFF7FD66F);
const Color _kToeGreenDark = Color(0xFF3FA33A);
const Color _kToePurpleLight = Color(0xFFB57FE6);
const Color _kToePurpleDark = Color(0xFF7A3FB0);

/// Noir du coussinet (`linear-gradient(135deg,#3A363F,#17151A)`).
const Color kPawPadLight = Color(0xFF443531);
const Color kPawPadDark = Color(0xFF1D1412);

/// Patte de la BARRE (zone 84×84).
const PawGlyphSpec kPawGlyphBar = PawGlyphSpec(
  box: kPawTabBarPawBox,
  pad: 48,
  padBorder: 3,
  eye: 32,
  toeBorder: 2.5,
  padShadow: <BoxShadow>[
    BoxShadow(
      color: Color(0x801D1412), // rgba(23,21,26,.5)
      blurRadius: 30,
      offset: Offset(0, 14),
    ),
  ],
  toeShadow: <BoxShadow>[
    BoxShadow(
      color: Color(0x661D1412), // rgba(23,21,26,.4)
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ],
  eyeShadow: <BoxShadow>[
    BoxShadow(
      color: Color(0x597A2A16), // rgba(0,0,0,.35)
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ],
  // v570 — Daniel : « les petits ronds de la patte devraient être plus proches »
  // quand PawMap est sélectionné. La maquette les écartait de 4 px vers
  // l'extérieur (≈ 8 px de vide avec le coussinet) ; on les ramène de 6 px vers
  // le coussinet (`out` pointe désormais de 2 px VERS le centre) → ≈ 2 px de vide.
  toes: <PawToeSpec>[
    PawToeSpec(
      left: 4.1,
      top: 33.9,
      size: 13,
      light: _kToeRedLight,
      dark: _kToeRedDark,
      tuck: Offset(31.4, 19.6),
      out: Offset(1.7, 1.1),
    ),
    PawToeSpec(
      left: 22,
      top: 17,
      size: 16,
      light: _kToeBlueLight,
      dark: _kToeBlueDark,
      tuck: Offset(12, 35),
      out: Offset(0.65, 1.9),
    ),
    PawToeSpec(
      left: 46,
      top: 17,
      size: 16,
      light: _kToeGreenLight,
      dark: _kToeGreenDark,
      tuck: Offset(-12, 35),
      out: Offset(-0.65, 1.9),
    ),
    PawToeSpec(
      left: 66.9,
      top: 33.9,
      size: 13,
      light: _kToePurpleLight,
      dark: _kToePurpleDark,
      tuck: Offset(-31.4, 19.6),
      out: Offset(-1.7, 1.1),
    ),
  ],
);

/// Patte du SPLASH (zone 210×210 — table dédiée du README).
const PawGlyphSpec kPawGlyphSplash = PawGlyphSpec(
  box: 210,
  pad: 120,
  padBorder: 6,
  eye: 80,
  toeBorder: 5,
  padShadow: <BoxShadow>[
    BoxShadow(
      color: Color(0x805A0F08), // rgba(90,15,8,.5)
      blurRadius: 60,
      offset: Offset(0, 30),
    ),
  ],
  toeShadow: <BoxShadow>[
    BoxShadow(
      color: Color(0x59781408), // rgba(120,20,10,.35)
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ],
  eyeShadow: <BoxShadow>[
    BoxShadow(
      color: Color(0x667A2A16), // rgba(0,0,0,.4)
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ],
  toes: <PawToeSpec>[
    PawToeSpec(
      left: 10,
      top: 84.2,
      size: 34,
      light: _kToeRedLight,
      dark: _kToeRedDark,
      tuck: Offset(78, 48.8),
      out: Offset.zero,
    ),
    PawToeSpec(
      left: 55,
      top: 43,
      size: 40,
      light: _kToeBlueLight,
      dark: _kToeBlueDark,
      tuck: Offset(30, 87),
      out: Offset.zero,
    ),
    PawToeSpec(
      left: 115,
      top: 43,
      size: 40,
      light: _kToeGreenLight,
      dark: _kToeGreenDark,
      tuck: Offset(-30, 87),
      out: Offset.zero,
    ),
    PawToeSpec(
      left: 166,
      top: 84.2,
      size: 34,
      light: _kToePurpleLight,
      dark: _kToePurpleDark,
      tuck: Offset(-78, 48.8),
      out: Offset.zero,
    ),
  ],
);

/// Icône app recadrée à 40 % AUTOUR DE L'ŒIL.
///
/// ⚠️ Dans `HoPetSit_logo.png` (512×512) l'œil n'est PAS au centre de l'image :
/// son disque est centré en (256, 285.5). Un recadrage « 40 % centré sur
/// l'image » remonterait donc l'œil dans le coussinet. On embarque directement
/// le recadrage 40 % centré sur l'œil (256×256), affiché plein cercle.
const String kPawEyeAsset = 'assets/images/pawmap_eye.png';

// ─────────────────────────────────────────────────────────────────────────────
// 4. LA PATTE (rendu pur, sans geste ni animation propre)
// ─────────────────────────────────────────────────────────────────────────────

/// Coussinet-épingle noir + œil du logo + 4 doigts.
///
/// [toeProgress] : 0 = doigt rentré dans le coussinet, 1 = doigt sorti.
/// [toeOpacity] : opacité de chaque doigt. `null` ⇒ patte complète (logo).
class PawGlyph extends StatelessWidget {
  const PawGlyph({
    super.key,
    this.spec = kPawGlyphBar,
    required this.size,
    this.toeProgress,
    this.toeOpacity,
  });

  final PawGlyphSpec spec;
  final double size;
  final List<double>? toeProgress;
  final List<double>? toeOpacity;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < spec.toes.length; i++) {
      final PawToeSpec t = spec.toes[i];
      final double p = toeProgress == null ? 1.0 : toeProgress![i];
      final double o =
          (toeOpacity == null ? 1.0 : toeOpacity![i]).clamp(0.0, 1.0);
      final Offset off = Offset(
        t.tuck.dx + (t.out.dx - t.tuck.dx) * p,
        t.tuck.dy + (t.out.dy - t.tuck.dy) * p,
      );
      children.add(Positioned(
        left: t.left,
        top: t.top,
        width: t.size,
        height: t.size,
        child: Opacity(
          key: ValueKey<String>('paw_toe_$i'),
          opacity: o,
          child: Transform.translate(
            offset: off,
            child: Transform.scale(
              scale: 0.25 + 0.75 * p,
              child: _toe(t),
            ),
          ),
        ),
      ));
    }

    // Coussinet ancré en bas-centre de la zone.
    children.add(Positioned(
      left: (spec.box - spec.pad) / 2,
      bottom: 0,
      width: spec.pad,
      height: spec.pad,
      child: _pad(),
    ));

    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: spec.box,
          height: spec.box,
          child: Stack(clipBehavior: Clip.none, children: children),
        ),
      ),
    );
  }

  Widget _toe(PawToeSpec t) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4), // circle at 35% 30%
          radius: 0.95, // farthest-corner
          colors: <Color>[t.light, t.dark],
        ),
        border: Border.all(color: Colors.white, width: spec.toeBorder),
        boxShadow: spec.toeShadow,
      ),
    );
  }

  Widget _pad() {
    final double r = spec.pad / 2;
    return Transform.rotate(
      angle: -0.7853981633974483, // -45°
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, // 135deg
            end: Alignment.bottomRight,
            colors: <Color>[kPawPadLight, kPawPadDark],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(r),
            topRight: Radius.circular(r),
            bottomRight: Radius.circular(r),
            bottomLeft: Radius.zero,
          ),
          border: Border.all(color: Colors.white, width: spec.padBorder),
          boxShadow: spec.padShadow,
        ),
        child: Center(
          child: Transform.rotate(
            angle: 0.7853981633974483, // contre-rotation +45°
            child: Container(
              width: spec.eye,
              height: spec.eye,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPawPadDark,
                boxShadow: spec.eyeShadow,
              ),
              child: ClipOval(
                child: Image.asset(
                  kPawEyeAsset,
                  width: spec.eye,
                  height: spec.eye,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo PawMap réutilisable : la patte-épingle, doigts SORTIS, sans animation.
/// Remplace `assets/images/pawmap_logo*.svg` / `pawmap_nav.svg`.
class PawMapLogo extends StatelessWidget {
  const PawMapLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => PawGlyph(size: size);
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. LA BARRE
// ─────────────────────────────────────────────────────────────────────────────


TextStyle _manrope({
  required double size,
  required FontWeight weight,
  required Color color,
  double? letterSpacing,
}) {
  // Manrope vient de google_fonts (déjà au pubspec) ; hors réseau la police
  // par défaut prend le relais — aucune dépendance ajoutée.
  return GoogleFonts.manrope(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: 1.15,
  );
}

class PawTabBar extends StatefulWidget {
  const PawTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.role,
    required this.systemInset,
    required this.labels,
    this.badges = const <int, WidgetBuilder>{},
  });

  /// 0 Accueil · 1 Chat · 2 PawMap · 3 Réservations · 4 Profil.
  final int currentIndex;
  final ValueChanged<int> onTap;
  final PawNavRole role;

  /// Inset système (viewPadding.bottom) à ajouter sous la pilule.
  final double systemInset;

  /// 5 libellés déjà traduits (aucun texte en dur ici).
  final List<String> labels;

  /// Pastilles de non-lus par index d'onglet.
  final Map<int, WidgetBuilder> badges;

  @override
  State<PawTabBar> createState() => _PawTabBarState();
}

class _PawTabBarState extends State<PawTabBar>
    with SingleTickerProviderStateMixin {
  // 500 ms de transition + 120 ms de délai en cascade sur le 4e doigt.
  static const int _toeTotalMs = 620;
  static const int _toeMoveMs = 500;
  static const int _toeFadeMs = 300;
  static const List<int> _toeDelaysMs = <int>[0, 40, 80, 120];

  late final AnimationController _toeCtl;
  late bool _toesOpen;
  bool _pawDown = false;

  bool get _isPawMap => widget.currentIndex == 2;

  @override
  void initState() {
    super.initState();
    _toesOpen = _isPawMap;
    _toeCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _toeTotalMs),
      value: 1, // état stable au montage (pas d'animation d'entrée)
    );
  }

  @override
  void didUpdateWidget(covariant PawTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isPawMap != _toesOpen) {
      _toesOpen = _isPawMap;
      _toeCtl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _toeCtl.dispose();
    super.dispose();
  }

  /// Progression du doigt [i] : le délai en cascade s'applique dans les DEUX
  /// sens (comme les `transition-delay` CSS du prototype).
  double _toeProgress(int i, double v) {
    final double t =
        ((v * _toeTotalMs - _toeDelaysMs[i]) / _toeMoveMs).clamp(0.0, 1.0);
    final double c = kPawBounce.transform(t);
    return _toesOpen ? c : 1 - c;
  }

  double _toeOpacity(double v) {
    final double t = (v * _toeTotalMs / _toeFadeMs).clamp(0.0, 1.0);
    return _toesOpen ? t : 1 - t;
  }

  void _tap(int index) {
    HapticFeedback.selectionClick();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final PawTabBarPalette palette =
        kPawTabBarPalettes[widget.role] ?? kPawTabBarPalettes[PawNavRole.owner]!;

    return SizedBox(
      height: pawTabBarTotalHeight(widget.systemInset),
      // ⚠️ Rien d'opaque ici : la bande transparente au-dessus de la pilule
      // (de part et d'autre de la patte) doit laisser passer les taps vers
      // l'écran qui est dessous (Stack ne s'auto-hit-teste pas).
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: kPawTabBarSideMargin,
            right: kPawTabBarSideMargin,
            bottom: kPawTabBarBottomMargin + widget.systemInset,
            height: kPawTabBarPillHeight,
            child: RepaintBoundary(child: _pill(palette)),
          ),
          // Patte : sa zone tactile fait 84×84 et ne déborde jamais de cette
          // boîte (aucun tap intercepté ailleurs).
          AnimatedPositioned(
            duration: const Duration(milliseconds: 450),
            curve: kPawBounce,
            left: 0,
            right: 0,
            height: kPawTabBarPawBox,
            bottom: kPawTabBarBottomMargin +
                kPawTabBarPawOffset +
                widget.systemInset +
                (_isPawMap ? kPawTabBarPawLift : 0),
            child: Center(
              child: RepaintBoundary(child: _pawButton()),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pilule ────────────────────────────────────────────────────────────────
  Widget _pill(PawTabBarPalette palette) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kPawTabBarPillHeight / 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.top, palette.bottom],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow,
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kPawTabBarPillHeight / 2),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final double w = c.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // Liseré haut : inset 0 1px 0 rgba(255,255,255,.3).
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 1,
                  child: Container(color: Colors.white.withValues(alpha: 0.3)),
                ),
                _dot(w),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: <Widget>[
                      _tab(0, PawIcon.paw),
                      _tab(1, PawIcon.chat),
                      _centerSlot(),
                      _tab(3, PawIcon.calendar),
                      _tab(4, PawIcon.user),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Point blanc 6×6 sous l'onglet actif (formule du README).
  Widget _dot(double barWidth) {
    const List<int> lateral = <int>[0, 1, 3, 4];
    final int i = lateral.indexOf(widget.currentIndex);
    final double cell = (barWidth - 16 - kPawTabBarCenterSlot) / 4;
    final double left = i < 0
        ? barWidth / 2 - 3
        : 8 + i * cell + (i >= 2 ? kPawTabBarCenterSlot : 0) + cell / 2 - 3;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 450),
      curve: kPawSlide,
      left: left,
      bottom: 6,
      width: 6,
      height: 6,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: _isPawMap ? 0 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.8),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(int index, PawIcon path) {
    final bool active = widget.currentIndex == index;
    final Color color =
        active ? Colors.white : Colors.white.withValues(alpha: 0.7);
    final WidgetBuilder? badge = widget.badges[index];
    return Expanded(
      child: _PressScale(
        key: ValueKey<String>('paw_tab_$index'),
        onTap: () => _tap(index),
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  SvgPicture.string(
                    _strokeIcon(path, active),
                    width: 23,
                    height: 23,
                  ),
                  if (badge != null)
                    Positioned(top: -7, right: -10, child: badge(context)),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.labels[index].toUpperCase(),
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: _manrope(
                      size: 8.5,
                      weight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// v585 (lot D) — icône de la FAMILLE MAISON (`paw_icons.dart`), bicolore :
  /// trait blanc 100 % (actif) / 70 % (inactif) + aplat blanc 30 % (actif) /
  /// 14 % (inactif). Mêmes tracés que le reste de l'app et le site.
  String _strokeIcon(PawIcon icon, bool active) {
    return pawIconSvg(
      icon,
      color: Colors.white.withValues(alpha: active ? 1 : 0.7),
      fill: Colors.white.withValues(alpha: active ? 0.30 : 0.14),
    );
  }

  /// Slot central : uniquement l'étiquette « PawMap » (la patte est au-dessus).
  Widget _centerSlot() {
    final bool active = _isPawMap;
    return SizedBox(
      width: kPawTabBarCenterSlot,
      height: 60,
      child: _PressScale(
        key: const ValueKey<String>('paw_tab_chip'),
        onTap: () => _tap(2),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 450),
              curve: kPawBounce,
              tween: Tween<double>(begin: 0, end: active ? -2 : 0),
              builder: (BuildContext context, double dy, Widget? child) =>
                  Transform.translate(offset: Offset(0, dy), child: child),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: active ? kPawPadDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: active
                      ? <BoxShadow>[
                          const BoxShadow(
                            color: Color(0x597A2A16),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.labels[2].toUpperCase(),
                    maxLines: 1,
                    softWrap: false,
                    style: _manrope(
                      size: 8,
                      weight: FontWeight.w800,
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 0.48, // .06em
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Patte ────────────────────────────────────────────────────────────────
  Widget _pawButton() {
    return SizedBox(
      width: kPawTabBarPawBox,
      height: kPawTabBarPawBox,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Dessin (non tactile) : la patte occupe bien les 84×84 du handoff.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedScale(
                scale: _pawDown ? 0.96 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: AnimatedBuilder(
                  animation: _toeCtl,
                  builder: (BuildContext context, Widget? _) {
                    final double v = _toeCtl.value;
                    return PawGlyph(
                      size: kPawTabBarPawBox,
                      toeProgress: <double>[
                        _toeProgress(0, v),
                        _toeProgress(1, v),
                        _toeProgress(2, v),
                        _toeProgress(3, v),
                      ],
                      toeOpacity: List<double>.filled(4, _toeOpacity(v)),
                    );
                  },
                ),
              ),
            ),
          ),
          // Zone tactile : 84 × 67, ancrée en bas. Les 17 px du haut de la
          // boîte sont VIDES par construction (les doigts commencent à y=17) :
          // les y laisser tactiles volerait des taps à l'écran qui est
          // dessous (consigne de Daniel : ne gêner AUCUN bouton).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: kPawTabBarPawBox - 17,
            child: GestureDetector(
              key: const ValueKey<String>('paw_tab_2'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pawDown = true),
              onTapUp: (_) => setState(() => _pawDown = false),
              onTapCancel: () => setState(() => _pawDown = false),
              onTap: () => _tap(2),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Feedback d'appui : scale .96 (aucun hover sur mobile).
class _PressScale extends StatefulWidget {
  const _PressScale({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
