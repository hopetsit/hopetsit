// v585 (lot D du chantier du 24/09) — LE kit de boutons « signature HoPetSit »
// de TOUTE l'app (NORME_DESIGN.md, validée par Daniel le 23/09 : « je valide
// les deux »). Il généralise les boutons de la PawMap du lot C
// (`views/map/widgets/pawmap_buttons.dart`, qui délègue désormais ici) et
// habille `CustomButton`, `ProfilePrimaryButton`, `ProfileSecondaryButton`,
// `ActionPillButton` — donc les ~130 écrans qui passent par eux — SANS
// changer une seule action : habillage seul.
//
//   1. Principal   : dégradé HORIZONTAL du rôle (mêmes teintes que le menu),
//                    reflet verre (moitié haute plus claire), disque blanc à
//                    gauche avec l'icône à la couleur du rôle, texte blanc,
//                    56 px, coins 18, LE PRIX DANS LE BOUTON (« Réserver Léa ·
//                    25 € »). Un seul par écran.
//   2. Secondaire  : fond blanc (surface en sombre), contour 1,5 px couleur du
//                    rôle, petit disque teinté avec l'icône, texte dans le
//                    foncé du rôle, 48 px, coins 16.
//   3. Lien        : texte couleur du rôle, sans cadre.
//   4. Rond icône  : 44 px style « Paw Buttons » (`PawRoundButton`).
//   Produit        : dégradé du produit (PawFollow violet, PawBoost turquoise,
//                    Premium noir + texte or) — `PawButtonKind.product`.
//   Danger         : rouge #D32F2F, seulement supprimer / annuler.
//
// Signature au toucher : une EMPREINTE DE PATTE s'imprime là où le doigt
// touche (plus de vague grise Material), le bouton s'enfonce à 0,97 et vibre
// légèrement. Animation propre à chaque action : patte qui saute (Réserver),
// avion en papier (Envoyer), petits cœurs (succès). Reflet qui passe toutes
// les 6 s sur les boutons qui rapportent (`earns: true`). « Réduire les
// animations » du téléphone → tout est fixe.
//
// États : chargement = petit rond DANS le bouton, libellé conservé, pas de
// double envoi (si `onTap` renvoie un Future, le bouton gère l'attente seul) ;
// désactivé = teinte du rôle PÂLE ET PLEINE (jamais gris) + message qui dit
// pourquoi ; succès = coche ✓ 1 s puis retour. Zone tactile ≥ 44 × 44.
//
// ⛔ Le libellé n'est JAMAIS coupé : 2 lignes coupées à l'espace le plus
// central (`pawTwoLines`), puis réduction douce (FittedBox). Jamais « … ».
// Test automatique : `test/lotd_button_titles_test.dart` (9 langues, 320 et
// 375 px). Garde-fou : `test/lotd_raw_buttons_guard_test.dart`.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/paw_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Couleurs et utilitaires partagés
// ─────────────────────────────────────────────────────────────────────────────

/// Dégradé HORIZONTAL validé d'une couleur de rôle (les mêmes que le menu).
LinearGradient pawRoleGradient(Color role) {
  final Color a = Color.lerp(role, Colors.white, 0.10)!;
  final Color b = Color.lerp(role, Colors.black, 0.16)!;
  return LinearGradient(
    colors: [a, b],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

/// Coupe un libellé en deux lignes à l'espace le plus central (jamais au
/// milieu d'un mot). Sans espace : une ligne, réduite par le FittedBox.
String pawTwoLines(String s) {
  final t = s.trim();
  if (t.length < 16) return t;
  final mid = t.length ~/ 2;
  int best = -1;
  for (int i = 0; i < t.length; i++) {
    if (t[i] == ' ' && (best < 0 || (i - mid).abs() < (best - mid).abs())) {
      best = i;
    }
  }
  if (best < 0) return t;
  return '${t.substring(0, best)}\n${t.substring(best + 1)}';
}

/// Couleurs fixes des produits (NORME_DESIGN.md « Couleurs »).
class PawProductColors {
  static const Color pawFollow = Color(0xFF7C3AED);
  static const Color pawBoost = Color(0xFF06B6D4);
  static const Color premiumInk = Color(0xFF17141F);
  static const Color premiumGold = Color(0xFFF4C04A);
  static const Color pawSpotAmber = Color(0xFFE8920A);
}

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

bool pawReduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

enum PawButtonKind { primary, secondary, link, product, danger }

/// Animation propre à chaque action (jouée au tap, sauf « réduire les
/// animations »).
enum PawButtonAction { none, book, send, success, pay }

/// Type accepté par `icon` : une icône maison ([PawIcon]) ou, en transition,
/// une icône Material ([IconData]).
Widget pawIconAny(Object? icon, {required double size, required Color color, Color? fill}) {
  if (icon is PawIcon) {
    return PawIconWidget(icon, size: size, color: color, fill: fill);
  }
  if (icon is IconData) return Icon(icon, size: size, color: color);
  return SizedBox(width: size, height: size);
}

// ─────────────────────────────────────────────────────────────────────────────
// Le bouton
// ─────────────────────────────────────────────────────────────────────────────

class PawButton extends StatefulWidget {
  const PawButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.icon,
    this.kind = PawButtonKind.primary,
    this.price,
    this.loading = false,
    this.enabled = true,
    this.disabledReason,
    this.expand = true,
    this.earns = false,
    this.action = PawButtonAction.none,
    this.compact = false,
    this.height,
    this.textColor,
    this.child,
    this.semanticLabel,
    this.haptic = true,
  });

  final String label;

  /// L'action, inchangée. Si elle renvoie un `Future`, le bouton affiche le
  /// chargement tout seul et ignore les taps suivants (pas de double envoi),
  /// puis la coche ✓ pendant 1 s.
  final FutureOr<void> Function()? onTap;

  /// Couleur du rôle (défaut : rôle actif) ou du produit.
  final Color? color;

  /// [PawIcon] (maison) ou [IconData] (transition).
  final Object? icon;
  final PawButtonKind kind;

  /// « Réserver Léa · 25 € » : le prix vit DANS le bouton.
  final String? price;
  final bool loading;
  final bool enabled;

  /// Message affiché quand on appuie sur un bouton désactivé.
  final String? disabledReason;
  final bool expand;

  /// Reflet qui passe toutes les 6 s (Réserver, Payer).
  final bool earns;
  final PawButtonAction action;

  /// 44 px (bandeaux, cartes) au lieu de 56 / 48.
  final bool compact;
  final double? height;

  /// Texte forcé (Premium : or sur noir).
  final Color? textColor;

  /// Contenu libre (transition `CustomButton(child:)`) : posé DANS la
  /// coque signature, à la place du libellé.
  final Widget? child;
  final String? semanticLabel;
  final bool haptic;

  @override
  State<PawButton> createState() => _PawButtonState();
}

class _PawPrint {
  _PawPrint(this.offset, this.controller);
  final Offset offset;
  final AnimationController controller;
}

class _PawButtonState extends State<PawButton> with TickerProviderStateMixin {
  bool _pressed = false;
  bool _busy = false;
  bool _done = false;
  final List<_PawPrint> _prints = <_PawPrint>[];
  AnimationController? _sheen;
  AnimationController? _fx;
  Timer? _doneTimer;

  /// Accepte un tap (ni chargement, ni désactivé).
  bool get _active => widget.enabled && !widget.loading && !_busy;

  @override
  void initState() {
    super.initState();
    _fx = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool wantSheen = widget.earns &&
        !pawReduceMotion(context) &&
        widget.kind == PawButtonKind.primary;
    if (wantSheen && _sheen == null) {
      _sheen = AnimationController(
          vsync: this, duration: const Duration(seconds: 6))
        ..repeat();
    } else if (!wantSheen && _sheen != null) {
      _sheen!.dispose();
      _sheen = null;
    }
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    _sheen?.dispose();
    _fx?.dispose();
    for (final p in _prints) {
      p.controller.dispose();
    }
    super.dispose();
  }

  void _set(bool v) {
    if (_pressed == v || !mounted) return;
    setState(() => _pressed = v);
  }

  void _addPrint(Offset local) {
    if (pawReduceMotion(context)) return;
    final c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    final p = _PawPrint(local, c);
    setState(() => _prints.add(p));
    c.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _prints.remove(p));
      c.dispose();
    });
  }

  Future<void> _handleTap() async {
    if (widget.loading || _busy) return;
    if (!widget.enabled) {
      final why = widget.disabledReason;
      if (why != null && why.isNotEmpty) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(why)),
        );
      }
      return;
    }
    if (widget.haptic) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {/* pas de moteur haptique */}
    }
    if (widget.action != PawButtonAction.none && !pawReduceMotion(context)) {
      _fx?.forward(from: 0);
    }
    final result = widget.onTap?.call();
    if (result is Future) {
      if (mounted) setState(() => _busy = true);
      try {
        await result;
        if (mounted) {
          setState(() {
            _busy = false;
            _done = true;
          });
          _doneTimer?.cancel();
          _doneTimer = Timer(const Duration(seconds: 1), () {
            if (mounted) setState(() => _done = false);
          });
        }
      } catch (_) {
        if (mounted) setState(() => _busy = false);
        rethrow;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDark(context);
    final bool reduce = pawReduceMotion(context);
    final Color role = widget.color ?? AppColors.activeRoleAccent();
    final bool danger = widget.kind == PawButtonKind.danger;
    final Color base = danger ? AppColors.errorColor : role;
    final Color dark = Color.lerp(base, Colors.black, 0.30)!;
    // Aspect : seul `enabled` pâlit le bouton ; en chargement il garde son
    // dégradé (petit rond DANS le bouton, libellé conservé).
    final bool active = widget.enabled;
    final bool link = widget.kind == PawButtonKind.link;
    final bool primary = widget.kind == PawButtonKind.primary ||
        widget.kind == PawButtonKind.product ||
        danger;
    final bool loading = widget.loading || _busy;
    final String text = (widget.price == null || widget.price!.isEmpty)
        ? widget.label
        : '${widget.label} · ${widget.price}';

    final double h = widget.height ??
        (link
            ? 40.h
            : widget.compact
                ? 44.h
                : (primary ? 56.h : 48.h));
    final double radius = widget.compact ? 14.r : (primary ? 18.r : 16.r);
    // Désactivé : teinte du rôle PÂLE et PLEINE, texte dans le foncé.
    final Color paleFill = Color.lerp(base, Colors.white, 0.82)!;
    final Color lightOnDark = Color.lerp(base, Colors.white, 0.28)!;
    final Color fg = widget.textColor ??
        (link
            ? (isDark ? lightOnDark : dark)
            : primary
                ? (active ? Colors.white : dark)
                : (isDark ? lightOnDark : dark));
    final Color discIconColor =
        widget.textColor != null && widget.kind == PawButtonKind.product
            ? widget.textColor!
            : (active ? base : dark);

    final double discSize = widget.compact ? 28.w : (primary ? 34.w : 28.w);
    final double iconSize = widget.compact ? 15.sp : (primary ? 19.sp : 16.sp);

    Widget disc() {
      if (widget.icon == null && !loading && !_done) return const SizedBox.shrink();
      final Widget inner = loading
          ? Padding(
              padding: EdgeInsets.all(primary ? 8.w : 6.w),
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: primary ? discIconColor : fg,
              ),
            )
          : _done
              ? PawIconWidget(PawIcon.check,
                  size: iconSize + 3,
                  color: primary ? discIconColor : fg,
                  fill: Colors.transparent)
              : Center(
                  child: pawIconAny(widget.icon,
                      size: iconSize,
                      color: primary ? discIconColor : fg,
                      fill: primary
                          ? discIconColor.withValues(alpha: 0.18)
                          : fg.withValues(alpha: 0.18)),
                );
      if (link) {
        return Padding(
          padding: EdgeInsets.only(right: 6.w),
          child: SizedBox(width: iconSize + 2, height: iconSize + 2, child: inner),
        );
      }
      return Padding(
        padding: EdgeInsets.only(right: 10.w),
        child: Container(
          width: discSize,
          height: discSize,
          decoration: BoxDecoration(
            color: primary
                ? (active ? Colors.white : Colors.white.withValues(alpha: 0.6))
                : base.withValues(alpha: isDark ? 0.24 : 0.12),
            shape: BoxShape.circle,
          ),
          child: inner,
        ),
      );
    }

    final TextStyle style = GoogleFonts.poppins(
      fontSize: widget.compact ? 13.5.sp : (primary ? 15.sp : 14.sp),
      fontWeight: FontWeight.w700,
      height: 1.1,
      color: fg,
    );

    final Widget label = widget.child ??
        Flexible(child: PawButtonLabel(text: text, style: style));

    final Widget content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        disc(),
        if (widget.child != null) Flexible(child: widget.child!) else label,
      ],
    );

    final Gradient? gradient = !primary || !active
        ? null
        : widget.kind == PawButtonKind.product && base == PawProductColors.premiumInk
            ? const LinearGradient(
                colors: [Color(0xFF2B2140), Color(0xFF15120D)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : pawRoleGradient(base);

    final Decoration deco = link
        ? const BoxDecoration()
        : primary
            ? BoxDecoration(
                gradient: gradient,
                color: active ? null : paleFill,
                borderRadius: BorderRadius.circular(radius),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: base.withValues(alpha: _pressed ? 0.18 : 0.30),
                          blurRadius: _pressed ? 8 : 16,
                          offset: Offset(0, _pressed ? 3 : 6),
                        ),
                      ]
                    : null,
              )
            : BoxDecoration(
                color: active
                    ? (isDark ? AppColors.cardDark : Colors.white)
                    : paleFill.withValues(alpha: isDark ? 0.35 : 1),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: active ? (isDark ? lightOnDark : base) : paleFill,
                  width: 1.5,
                ),
              );

    Widget box = Container(
      height: h,
      width: widget.expand ? double.infinity : null,
      constraints: BoxConstraints(minWidth: link ? 0 : 44, minHeight: link ? 40 : 44),
      padding: EdgeInsets.symmetric(
          horizontal: link ? 6.w : (widget.compact ? 12.w : 14.w)),
      decoration: deco,
      clipBehavior: link ? Clip.none : Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Reflet verre : moitié haute plus claire (principal actif).
          if (primary && active)
            Positioned(
              left: -14.w,
              right: -14.w,
              top: 0,
              height: h / 2,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Reflet qui passe (boutons qui rapportent).
          if (_sheen != null && active)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _sheen!,
                  builder: (_, __) => CustomPaint(
                    painter: _SheenPainter(_sheen!.value),
                  ),
                ),
              ),
            ),
          Center(child: content),
          // Empreintes de patte au toucher.
          for (final p in _prints)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: p.controller,
                  builder: (_, __) => CustomPaint(
                    painter: _PawPrintPainter(
                      p.offset,
                      p.controller.value,
                      primary ? Colors.white : base,
                    ),
                  ),
                ),
              ),
            ),
          // Animation propre à l'action.
          if (widget.action != PawButtonAction.none && _fx != null && !reduce)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _fx!,
                  builder: (_, __) => _fx!.value == 0 || _fx!.isCompleted
                      ? const SizedBox.shrink()
                      : CustomPaint(
                          painter: _ActionFxPainter(
                            widget.action,
                            _fx!.value,
                            primary ? Colors.white : base,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: _active,
      label: widget.semanticLabel ?? text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _active
            ? (d) {
                _set(true);
                _addPrint(d.localPosition);
              }
            : null,
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: _handleTap,
        child: AnimatedScale(
          scale: _pressed && !reduce ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: box,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Libellé JAMAIS coupé
// ─────────────────────────────────────────────────────────────────────────────

/// Le libellé d'un bouton, jamais coupé (NORME_DESIGN.md) :
///   1. il tient sur une ligne → une ligne, texte intact ;
///   2. sinon, si chaque mot tient dans la largeur → 2 lignes, coupées à un
///      espace par Flutter (jamais au milieu d'un mot), texte intact ;
///   3. sinon (un mot plus large que le bouton, ex. un composé allemand) →
///      coupure à l'espace le plus central + réduction douce (FittedBox).
/// Jamais « … ». Le texte reste celui de la traduction dans les cas 1 et 2
/// (les tests `find.text(...)` le retrouvent tel quel).
class PawButtonLabel extends StatelessWidget {
  const PawButtonLabel({super.key, required this.text, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    // Le même style que `Text` rendra (thème fusionné : interlettrage…).
    final TextStyle style = DefaultTextStyle.of(context).style.merge(this.style);
    return LayoutBuilder(builder: (context, c) {
      final double w = c.maxWidth;
      if (!w.isFinite || w <= 0) {
        return Text(text, maxLines: 1, softWrap: false, style: style);
      }
      final TextPainter one = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        textScaler: scaler,
      )..layout(maxWidth: w);
      final bool fitsOne = !one.didExceedMaxLines && one.width <= w + 0.5;
      one.dispose();
      if (fitsOne) {
        return Text(text,
            maxLines: 1, softWrap: false, textAlign: TextAlign.center, style: style);
      }
      // Chaque mot tient-il seul ? Alors Flutter coupe à un espace.
      bool wordsFit = true;
      for (final String word in text.split(RegExp(r'\s+'))) {
        if (word.isEmpty) continue;
        final TextPainter tp = TextPainter(
          text: TextSpan(text: word, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          textScaler: scaler,
        )..layout(maxWidth: double.infinity);
        if (tp.width > w) wordsFit = false;
        tp.dispose();
        if (!wordsFit) break;
      }
      if (wordsFit) {
        final TextPainter two = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 2,
          textScaler: scaler,
        )..layout(maxWidth: w);
        final bool fitsTwo = !two.didExceedMaxLines;
        two.dispose();
        if (fitsTwo) {
          return Text(text,
              maxLines: 2, softWrap: true, textAlign: TextAlign.center, style: style);
        }
      }
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          pawTwoLines(text),
          textAlign: TextAlign.center,
          maxLines: 2,
          softWrap: true,
          style: style,
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Peintres : empreinte, reflet, animations d'action
// ─────────────────────────────────────────────────────────────────────────────

/// Dessine une patte centrée sur l'origine (coussinet + 4 doigts), rayon ~12.
void paintPawShape(Canvas canvas, Paint paint, {double scale = 1.0}) {
  canvas.save();
  canvas.scale(scale);
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(0, 5.2), width: 17, height: 14),
    paint,
  );
  const List<List<double>> toes = <List<double>>[
    <double>[-8.6, -3.6, 4.0, 5.2, -0.42],
    <double>[-3.0, -9.0, 4.0, 5.4, -0.14],
    <double>[3.0, -9.0, 4.0, 5.4, 0.14],
    <double>[8.6, -3.6, 4.0, 5.2, 0.42],
  ];
  for (final List<double> t in toes) {
    canvas.save();
    canvas.translate(t[0], t[1]);
    canvas.rotate(t[4]);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: t[2] * 2, height: t[3] * 2),
      paint,
    );
    canvas.restore();
  }
  canvas.restore();
}

class _PawPrintPainter extends CustomPainter {
  _PawPrintPainter(this.at, this.t, this.color);
  final Offset at;
  final double t; // 0 → 1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double eased = Curves.easeOut.transform(t);
    final double alpha = (1 - t) * 0.55;
    final Paint p = Paint()
      ..color = color.withValues(alpha: alpha)
      ..isAntiAlias = true;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    paintPawShape(canvas, p, scale: 0.9 + eased * 1.3);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PawPrintPainter old) =>
      old.t != t || old.at != at || old.color != color;
}

class _SheenPainter extends CustomPainter {
  _SheenPainter(this.t);
  final double t; // 0 → 1 sur 6 s ; le reflet ne passe que sur les 14 % premiers

  @override
  void paint(Canvas canvas, Size size) {
    if (t > 0.14) return;
    final double k = t / 0.14; // 0 → 1
    final double x = -size.width * 0.35 + (size.width * 1.7) * k;
    final Rect r = Rect.fromLTWH(x, 0, size.width * 0.28, size.height);
    final Paint p = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(r);
    canvas.save();
    canvas.transform(Matrix4.skewX(-0.35).storage);
    canvas.drawRect(r, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SheenPainter old) => old.t != t;
}

class _ActionFxPainter extends CustomPainter {
  _ActionFxPainter(this.action, this.t, this.color);
  final PawButtonAction action;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color.withValues(alpha: (1 - t) * 0.9)
      ..isAntiAlias = true;
    final Offset c = Offset(size.width / 2, size.height / 2);
    switch (action) {
      case PawButtonAction.book:
      case PawButtonAction.pay:
        // Patte qui saute : monte, tourne un peu, s'efface.
        final double y = c.dy - Curves.easeOut.transform(t) * size.height * 0.9;
        canvas.save();
        canvas.translate(c.dx + size.width * 0.28, y);
        canvas.rotate(math.sin(t * math.pi) * 0.4);
        paintPawShape(canvas, p, scale: 0.7 + t * 0.4);
        canvas.restore();
        break;
      case PawButtonAction.send:
        // Avion en papier qui file vers la droite en montant.
        final double x = c.dx + Curves.easeIn.transform(t) * size.width * 0.6;
        final double y = c.dy - t * size.height * 0.7;
        final Path plane = Path()
          ..moveTo(-9, 4)
          ..lineTo(9, -3)
          ..lineTo(-2, 8)
          ..lineTo(-3, 2)
          ..close();
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-0.35);
        canvas.drawPath(plane, p);
        canvas.restore();
        break;
      case PawButtonAction.success:
        // Trois petits cœurs qui montent.
        for (int i = 0; i < 3; i++) {
          final double dx = c.dx + (i - 1) * size.width * 0.18;
          final double dy = c.dy - Curves.easeOut.transform(t) * (28 + i * 10);
          _heart(canvas, Offset(dx, dy), 5 + i.toDouble(), p);
        }
        break;
      case PawButtonAction.none:
        break;
    }
  }

  void _heart(Canvas canvas, Offset o, double r, Paint p) {
    final Path h = Path()
      ..moveTo(o.dx, o.dy + r)
      ..cubicTo(o.dx - r * 1.6, o.dy - r * 0.3, o.dx - r * 0.6, o.dy - r * 1.3,
          o.dx, o.dy - r * 0.4)
      ..cubicTo(o.dx + r * 0.6, o.dy - r * 1.3, o.dx + r * 1.6, o.dy - r * 0.3,
          o.dx, o.dy + r)
      ..close();
    canvas.drawPath(h, p);
  }

  @override
  bool shouldRepaint(covariant _ActionFxPainter old) =>
      old.t != t || old.action != action;
}

// ─────────────────────────────────────────────────────────────────────────────
// Rond icône 44 px « Paw Buttons » et pilule de choix
// ─────────────────────────────────────────────────────────────────────────────

class PawRoundButton extends StatefulWidget {
  const PawRoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color,
    this.size = 44,
    this.badge,
  });

  final Object icon; // PawIcon ou IconData
  final VoidCallback? onTap;
  final String tooltip;
  final Color? color;
  final double size;
  final Widget? badge;

  @override
  State<PawRoundButton> createState() => _PawRoundButtonState();
}

class _PawRoundButtonState extends State<PawRoundButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color base = widget.color ?? AppColors.activeRoleAccent();
    final bool enabled = widget.onTap != null;
    final bool reduce = pawReduceMotion(context);
    final Widget btn = AnimatedScale(
      scale: _pressed && !reduce ? 0.94 : 1.0,
      duration: const Duration(milliseconds: 110),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(base, Colors.white, 0.14)!,
              Color.lerp(base, Colors.black, 0.18)!,
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: base.withValues(alpha: 0.32),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: pawIconAny(widget.icon,
                  size: widget.size * 0.5,
                  color: Colors.white,
                  fill: Colors.white.withValues(alpha: 0.3)),
            ),
            if (widget.badge != null)
              Positioned(top: -3, right: -3, child: widget.badge!),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: enabled
              ? () {
                  try {
                    HapticFeedback.selectionClick();
                  } catch (_) {}
                  widget.onTap!();
                }
              : null,
          child: Opacity(opacity: enabled ? 1 : 0.7, child: btn),
        ),
      ),
    );
  }
}

/// Pilule de choix : 34 px, coins 12, pleine = sélectionnée.
class PawChoicePill extends StatelessWidget {
  const PawChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;
  final Object? icon;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDark(context);
    final Color base = color ?? AppColors.activeRoleAccent();
    final Color fg = selected
        ? Colors.white
        : (isDark ? Color.lerp(base, Colors.white, 0.3)! : Color.lerp(base, Colors.black, 0.25)!);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                try {
                  HapticFeedback.selectionClick();
                } catch (_) {}
                onTap!();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 34.h,
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            gradient: selected ? pawRoleGradient(base) : null,
            color: selected ? null : base.withValues(alpha: isDark ? 0.2 : 0.10),
            borderRadius: BorderRadius.circular(12.r),
            border: selected ? null : Border.all(color: base.withValues(alpha: 0.35), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                pawIconAny(icon, size: 14.sp, color: fg, fill: fg.withValues(alpha: 0.2)),
                SizedBox(width: 5.w),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: fg,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Thèmes des boutons Material BRUTS encore présents (108 dans des dialogues et
// sous-pages, listés par le garde-fou) : le même langage, sans un seul gris.
// ─────────────────────────────────────────────────────────────────────────────

/// Les 4 thèmes de boutons Material de l'app (clair ou sombre), à poser dans
/// `ThemeData` : couleur d'accent pleine, DÉSACTIVÉ = teinte pâle PLEINE
/// (jamais gris, jamais d'opacité), ondulation teintée (plus de vague grise),
/// contour couleur, coins 14/16, hauteur tactile 44.
class PawMaterialButtonThemes {
  PawMaterialButtonThemes({required Color accent, required bool dark})
      : _accent = accent,
        _dark = dark;

  final Color _accent;
  final bool _dark;

  Color get _pale => Color.lerp(_accent, _dark ? const Color(0xFF241916) : Colors.white, _dark ? 0.55 : 0.82)!;
  Color get _ink => _dark ? Color.lerp(_accent, Colors.white, 0.30)! : Color.lerp(_accent, Colors.black, 0.30)!;

  static const TextStyle _text = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

  WidgetStateProperty<Color?> _bg() => WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.disabled) ? _pale : _accent);
  WidgetStateProperty<Color?> _fgOnAccent() => WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.disabled) ? _ink : Colors.white);
  WidgetStateProperty<Color?> _fgAccent() => WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.disabled) ? Color.lerp(_ink, _pale, 0.45) : _ink);
  WidgetStateProperty<Color?> _overlayWhite() => WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.pressed) ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.08));
  WidgetStateProperty<Color?> _overlayAccent() => WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.pressed) ? _accent.withValues(alpha: 0.14) : _accent.withValues(alpha: 0.07));

  ElevatedButtonThemeData get elevated => ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          textStyle: const WidgetStatePropertyAll(_text),
          backgroundColor: _bg(),
          foregroundColor: _fgOnAccent(),
          iconColor: _fgOnAccent(),
          overlayColor: _overlayWhite(),
          shadowColor: WidgetStatePropertyAll(_accent.withValues(alpha: 0.3)),
        ),
      );

  FilledButtonThemeData get filled => FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          textStyle: const WidgetStatePropertyAll(_text),
          backgroundColor: _bg(),
          foregroundColor: _fgOnAccent(),
          iconColor: _fgOnAccent(),
          overlayColor: _overlayWhite(),
        ),
      );

  OutlinedButtonThemeData get outlined => OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          textStyle: const WidgetStatePropertyAll(_text),
          foregroundColor: _fgAccent(),
          iconColor: _fgAccent(),
          overlayColor: _overlayAccent(),
          side: WidgetStateProperty.resolveWith((s) => BorderSide(
              color: s.contains(WidgetState.disabled) ? _pale : _accent, width: 1.5)),
        ),
      );

  TextButtonThemeData get text => TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 40)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          foregroundColor: _fgAccent(),
          iconColor: _fgAccent(),
          overlayColor: _overlayAccent(),
        ),
      );
}
