// 631 (PAM-C, 31/10/2026) — BOUTON « BALADE RAPIDE » de la PawMap.
//
// Daniel (31/10) : un gros rond vert en bas de la carte, à portée du pouce, à
// droite (ou à gauche pour les gauchers).
//   · au repos : UN toucher = exactement le flux « Démarrer ma balade » de la
//     carte et du chat (`LiveShareStarter.startWithFeedback` : même service,
//     même permission de position, même partage « jusqu'à l'arrêt ») ;
//   · en balade : il affiche le chrono et UN toucher ouvre la feuille
//     « En direct » existante (sa ligne « Ma balade · Arrêter ») — le bouton
//     n'arrête jamais une balade d'un seul geste ;
//   · appui long : AUCUN mode « balade privée » n'existe dans
//     `LiveMapService` (vérifié 31/10) → rien d'inventé, l'appui long ne fait
//     rien de plus. Qui me voit se règle avec l'œil (Tous / Amis / Masqué).
// Il lit les 2 réglages de Profil › Préférences › Ouverture (`OpenOnPrefs3110`)
// : visible / côté, et suit leur changement tout de suite.
//
// 633 (03/11/2026) — DESIGN DE DANIEL « Bouton Balade en direct » (handoff
// Claude Design, hifi) : rond vert en dégradé radial avec ombre dure verte,
// pastille violette portant un chien stylisé qui se balance, ligne de statut
// (point violet clignotant + « BALADE EN DIRECT » / « HORS LIGNE »), compteur
// minutes (gros) + secondes (petit), anneau pointillé qui tourne, 4 feuilles
// qui flottent et 4 pattes en orbite quand la balade est en direct. Tout est
// dessiné à l'échelle [kQuickWalkScale0311] du prototype (280 × 280 px,
// bouton 172 px) pour tenir à côté des barres de la carte — les petits textes
// ne descendent jamais sous 8 pt. Enfoncé : le rond descend sur son ombre.
// `prefers-reduced-motion` (réglage « Réduire les animations ») coupe les
// animations infinies.
//
// Montage dans l'écran carte (fichier de PAM-A) : voir PROCHAIN_BUILD_631.md,
// section PAM-C — `QuickWalkButton3110.positioned(context)` dans le Stack.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/services/live_share_starter.dart';
import 'package:hopetsit/services/open_on_prefs_3110.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/views/map/widgets/pawmap_live_sheet.dart'
    show showPawLiveSheet;
import 'package:hopetsit/views/map/widgets/pawmap_walk_jewel.dart'
    show PawWalkJewelPainter;
import 'package:hopetsit/widgets/paw_tab_bar.dart'
    show kPawTabBarPillHeight, kPawTabBarBottomMargin;

/// 633 — échelle du prototype (280 × 280 px, bouton 172 px). À 1,0 le rond
/// ferait 172 pt : trop pour une carte où il y en a un de chaque côté.
// 634 (Daniel 03/11, capture : « énorme sur la carte ») — 0,66 → 0,36 :
// rond de 62 pt (la taille de la 631), contenu compact (chien + chrono).
const double kQuickWalkScale0311 = 0.36;

/// 633 — géométrie du prototype (px, avant échelle).
const double kQuickWalkProtoCanvas0311 = 280;
const double kQuickWalkProtoButton0311 = 172;

/// Diamètre du bouton (la partie qui réagit au toucher).
const double kQuickWalkSize3110 =
    kQuickWalkProtoButton0311 * kQuickWalkScale0311;

/// 633 — place prise par les décorations (feuilles, pattes, ombre) autour du
/// bouton, de chaque côté.
const double kQuickWalkHalo0311 =
    (kQuickWalkProtoCanvas0311 - kQuickWalkProtoButton0311) /
    2 *
    kQuickWalkScale0311;

/// 633 — côté du cadre complet (bouton + décorations).
const double kQuickWalkCanvas0311 =
    kQuickWalkProtoCanvas0311 * kQuickWalkScale0311;

/// Marge latérale (comme la barre d'onglets : 16).
const double kQuickWalkSideMargin3110 = 16;

/// Dégagement au-dessus de la barre d'onglets flottante (pilule 70 + marge 6
/// + 46 d'air), hors inset système : le bouton reste à portée du pouce.
/// 633 — 18 → 46 d'air : le rond est plus grand, il reste au-dessus de la
/// patte centrale du menu (± 44 pt autour du centre, test pam631).
// 634 — 46 → 26 : le petit rond se pose juste au-dessus du logo Google.
const double kQuickWalkAboveBar3110 =
    kPawTabBarPillHeight + kPawTabBarBottomMargin + 26;

/// 640 — COUPE-CIRCUIT du nouveau dessin (celui de la 639, partagé avec
/// `PawWalkJewel`). `false` = retour exact au dessin et au code de la 633.
/// Taille, place, clés, toucher et textes sont les mêmes dans les deux cas.
const bool kQuickWalkJewel640 = true;

class QuickWalkButton3110 extends StatefulWidget {
  const QuickWalkButton3110({
    super.key,
    this.onStart,
    this.onStop,
    this.broadcasting,
    this.startedAt,
    this.visible,
    this.side,
    this.now,
    this.onTapOverride,
    this.confirmed,
    this.elsewhere,
    this.elsewhereSince,
  });

  /// 632 (PAM, Daniel 01/11 : « le bouton rajouté ne marche pas comme le
  /// bouton en direct en haut à gauche ») — dans la PawMap, UN toucher fait
  /// exactement ce que fait le bouton Balade de la barre (`_onBaladeTap` :
  /// départ si rien ne tourne, sinon la feuille « En direct »).
  final Future<void> Function()? onTapOverride;

  /// Tests : confirmation serveur / balade sur un autre téléphone (sinon
  /// `LiveMapService.serverConfirmed` / `liveElsewhere`).
  final RxBool? confirmed;
  final RxBool? elsewhere;

  /// 633 — début de la balade qui tourne sur mon autre téléphone (sinon
  /// `LiveMapService.elsewhereSince`) : le compteur l'affiche aussi.
  final Rxn<DateTime>? elsewhereSince;

  /// Démarrage. Par défaut : `LiveShareStarter.startWithFeedback()`.
  final Future<void> Function()? onStart;

  /// Toucher en balade. Par défaut : la feuille « En direct » (Arrêter).
  final Future<void> Function(BuildContext context)? onStop;

  /// Tests / aperçus : état de la balade sans `LiveMapService`.
  final RxBool? broadcasting;
  final Rxn<DateTime>? startedAt;

  /// Tests / aperçus : forcent le réglage (sinon `OpenOnPrefs3110`).
  final RxBool? visible;
  final Rx<QuickWalkSide3110>? side;

  /// Tests : horloge du chrono.
  final DateTime Function()? now;

  /// Le bouton déjà placé dans un `Stack` de la carte (bas droite / gauche,
  /// au-dessus de la barre d'onglets). [extraBottom] = ce que l'écran ajoute
  /// quand une carte ou un bandeau occupe déjà le bas.
  /// [sideInset] (PAM-A, montage dans la PawMap) : distance au bord du côté
  /// choisi — la carte la calcule pour poser le bouton À CÔTÉ du rail de ce
  /// bord (jamais dessus), par défaut la marge de 16.
  /// [side] (633) : force le côté — la carte pose un rond de chaque côté
  /// quand le réglage vaut « Les deux » ; sans [side], « Les deux » = droite.
  /// 633 — les distances valent pour le BOUTON ; les décorations (feuilles,
  /// pattes) débordent autour de lui ([kQuickWalkHalo0311]) et ne prennent
  /// pas le toucher.
  static Widget positioned(
    BuildContext context, {
    double extraBottom = 0,
    double? sideInset,
    Future<void> Function()? onTap,
    QuickWalkSide3110? side,
    double? bottomOverride,
  }) {
    OpenOnPrefs3110.load();
    // 634 — la PawMap pose le rond à la place exacte du bas de ses barres
    // (juste au-dessus du menu) et remonte la barre au-dessus de lui.
    final double bottom = bottomOverride ??
        (appBottomInset(context) + kQuickWalkAboveBar3110 + extraBottom);
    final double inset = sideInset ?? kQuickWalkSideMargin3110;
    Widget at(bool left) => Positioned(
      bottom: bottom - kQuickWalkHalo0311,
      left: left ? inset - kQuickWalkHalo0311 : null,
      right: left ? null : inset - kQuickWalkHalo0311,
      child: QuickWalkButton3110(
        onTapOverride: onTap,
        // 633 — clé propre à chaque côté (quick_walk_3110_left / _right).
        side: Rx<QuickWalkSide3110>(
          left ? QuickWalkSide3110.left : QuickWalkSide3110.right,
        ),
      ),
    );
    // 633 — côté forcé : rien d'observable à suivre, donc pas d'Obx (GetX
    // lève « improper use » sur un Obx qui ne lit aucune variable).
    if (side != null) return at(side == QuickWalkSide3110.left);
    return Obx(
      () => at(OpenOnPrefs3110.quickWalkSide.value == QuickWalkSide3110.left),
    );
  }

  /// Tests seulement : force le dessin (`true` = 640, `false` = 633) sans
  /// toucher à [kQuickWalkJewel640].
  @visibleForTesting
  static bool? debugJewel640;

  // Le coupe-circuit choisit l'état AVANT la création : `false` rend la
  // classe de la 633, intacte.
  @override
  State<QuickWalkButton3110> createState() =>
      // ignore: no_logic_in_create_state
      (debugJewel640 ?? kQuickWalkJewel640)
      ? _QuickWalkJewelState640()
      : _QuickWalkButton3110State();
}

class _QuickWalkButton3110State extends State<QuickWalkButton3110>
    with SingleTickerProviderStateMixin {
  Timer? _tick;
  bool _busy = false;
  bool _pressed = false;

  /// 633 — horloge des animations (secondes écoulées), tournée par un Ticker
  /// seulement quand la balade est en direct et que les animations sont
  /// permises.
  Ticker? _anim;
  double _t = 0;

  LiveMapService? get _live =>
      Get.isRegistered<LiveMapService>() ? Get.find<LiveMapService>() : null;

  RxBool get _broadcasting =>
      widget.broadcasting ?? _live?.broadcasting ?? _never;
  static final RxBool _never = false.obs;

  Rxn<DateTime> get _startedAt =>
      widget.startedAt ?? _live?.sessionStartedAt ?? _noStart;
  static final Rxn<DateTime> _noStart = Rxn<DateTime>();
  Rxn<DateTime> get _elsewhereSince =>
      widget.elsewhereSince ?? _live?.elsewhereSince ?? _noStart;

  // 632 — même vérité que la pilule du haut et le bouton Balade de la barre.
  RxBool get _confirmed => widget.confirmed ?? _live?.serverConfirmed ?? _yes;
  static final RxBool _yes = true.obs;
  RxBool get _elsewhere => widget.elsewhere ?? _live?.liveElsewhere ?? _never;
  DateTime _clock() =>
      widget.now?.call() ?? _live?.liveNow.value ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    OpenOnPrefs3110.load();
    // Le chrono se met à jour toutes les secondes (633 : les secondes
    // s'affichent) — seulement en balade, sinon rien à redessiner.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (_broadcasting.value || _elsewhere.value)) {
        setState(() {});
      }
    });
    _anim = createTicker((elapsed) {
      _t = elapsed.inMicroseconds / 1e6;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _anim?.dispose();
    super.dispose();
  }

  void _syncAnim({required bool on, required bool reduced}) {
    final t = _anim;
    if (t == null) return;
    final bool run = on && !reduced;
    if (run && !t.isActive) {
      t.start();
    } else if (!run && t.isActive) {
      t.stop();
      _t = 0;
    }
  }

  Future<void> _onTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      HapticFeedback.mediumImpact();
      if (widget.onTapOverride != null) {
        await widget.onTapOverride!();
      } else if (_broadcasting.value || _elsewhere.value) {
        if (widget.onStop != null) {
          await widget.onStop!(context);
        } else if (mounted) {
          await showPawLiveSheet(context);
        }
      } else {
        if (widget.onStart != null) {
          await widget.onStart!();
        } else {
          await LiveShareStarter.startWithFeedback();
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool visible =
          (widget.visible ?? OpenOnPrefs3110.quickWalkVisible).value;
      final QuickWalkSide3110 side =
          (widget.side ?? OpenOnPrefs3110.quickWalkSide).value;
      if (!visible) {
        _syncAnim(on: false, reduced: true);
        return const SizedBox.shrink();
      }
      final bool live = _broadcasting.value;
      // 632 — « en direct » aussi quand ma balade tourne sur mon autre
      // téléphone, comme la pilule et le bouton de la barre.
      final bool elsewhere = _elsewhere.value;
      final bool on = live || elsewhere;
      // 632 — tant que le serveur n'a pas confirmé : « Connexion… », comme
      // la pilule (avant : « 0 min » pendant que la pilule disait Connexion).
      final bool connecting = live && !_confirmed.value;
      final DateTime now = _clock();
      final DateTime? start = live
          ? _startedAt.value
          : (elsewhere ? _elsewhereSince.value : null);
      final Duration? elapsed = (on && !connecting && start != null)
          ? (now.isAfter(start) ? now.difference(start) : Duration.zero)
          : null;
      final String label = on
          ? 'pamc3110_qw_stop_hint'.tr
          : 'pm605_live_start'.tr;
      final bool reduced =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      _syncAnim(on: on, reduced: reduced);

      // 633 — la clé de côté, la sémantique et l'info-bulle portent sur le
      // ROND (la zone touchable), pas sur les décorations autour.
      return _LiveWalkCanvas0311(
        scale: kQuickWalkScale0311,
        buttonKey: ValueKey<String>('quick_walk_3110_${side.code}'),
        label: label,
        on: on,
        connecting: connecting,
        busy: _busy,
        pressed: _pressed,
        elapsed: elapsed,
        t: _t,
        animate: on && !reduced,
        onTap: _onTap,
        onPressChanged: (v) {
          if (_pressed != v && mounted) setState(() => _pressed = v);
        },
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 640 — le même bouton, au dessin de la 639 (celui de `PawWalkJewel`).
//
// Daniel (10/11, build 639) : « le bouton balade qd il apparaît à gauche ou
// droite n'a pas été changé par le nouveau ». Ce rond reprend donc le peintre
// partagé `PawWalkJewelPainter` : disque vert en relief, pastille violette,
// nouvelle tête de chien, 4 feuilles et 4 pattes en direct, plus d'anneau en
// pointillés.
//
// RÈGLE DE LA MAQUETTE : on ne change QUE l'apparence. Même cadre
// ([kQuickWalkCanvas0311]), même rond touchable ([kQuickWalkSize3110]), mêmes
// clés, même logique de toucher, mêmes textes. Les décorations sont peintes
// en surcouche (`IgnorePointer`) à l'intérieur du halo de la 633.
//
// FLUIDITÉ : avant, une balade en direct reconstruisait tout le bouton à
// chaque image (`setState` dans un `Ticker`). Ici, les animations passent par
// un peintre (`repaint:`) derrière un `RepaintBoundary` : aucune
// reconstruction par image. Seuls les deux petits textes du chrono sont
// reconstruits, une fois par seconde.
// ─────────────────────────────────────────────────────────────────────────

class _QuickWalkJewelState640 extends State<QuickWalkButton3110>
    with TickerProviderStateMixin {
  // ── Géométrie ─────────────────────────────────────────────────────────
  /// Part du relief dans le diamètre du dessin (celle du peintre partagé).
  static const double _reliefRatio = 0.055;

  /// Diamètre donné au peintre : sa FACE (diamètre − relief) fait exactement
  /// [kQuickWalkSize3110], le rond touchable. Le relief (3,6 dp) dépasse
  /// dessous, comme l'ombre dure de la 633.
  static const double _diameter = kQuickWalkSize3110 / (1 - _reliefRatio);
  static const double _relief = _diameter * _reliefRatio;

  /// Pastille violette : 26 dp, comme en 633 (la maquette réduit le chien
  /// plutôt que le texte quand la place manque).
  static const double _pastilleR = 13;
  static const double _pastilleRatio = _pastilleR / (kQuickWalkSize3110 / 2);
  // 1 px de la maquette de la pastille (dessinée pour 50 px).
  static const double _u = _pastilleR * 2 / 50;
  // Du haut du liseré (3 px maquette) au bas du petit relief (4 px).
  static const double _pastilleBlock = _pastilleR * 2 + 3 * _u + 4 * _u;
  static const double _pastilleTop = _pastilleR + 3 * _u + 2 * _u;
  static const double _rowH = 16;
  static const double _secsH = 9;
  static const double _gapRest = 3;
  static const double _gapLive = 1;

  // Hors ligne / connexion : pastille + ligne des minutes.
  static const double _restTop = -(_pastilleBlock + _gapRest + _rowH) / 2;
  static const double _restPastilleDy = _restTop + _pastilleTop;
  static const double _restRowCy =
      _restTop + _pastilleBlock + _gapRest + _rowH / 2;
  // En direct : pastille + minutes + secondes.
  static const double _liveTop =
      -(_pastilleBlock + _gapLive + _rowH + _secsH) / 2;
  static const double _livePastilleDy = _liveTop + _pastilleTop;
  static const double _liveRowCy =
      _liveTop + _pastilleBlock + _gapLive + _rowH / 2;
  static const double _liveSecsCy = _liveRowCy + _rowH / 2 + _secsH / 2;

  /// Feuilles : aux angles de la maquette (225°, 315°, 45°, 135°), sur un
  /// cercle de 0,79 D en haut et 0,72 D en bas pour rester dans le halo.
  static const List<double> _leafAngles = <double>[225, 315, 45, 135];
  static const List<double> _leafRadii = <double>[0.74, 0.74, 0.70, 0.70];

  /// Pattes : orbite à 0,64 D (0,71 D dans la maquette dépasserait le halo
  /// et le bord de l'écran).
  static const double _pawRadius = 0.64;

  /// Marge de peinture autour du cadre (flou de l'ombre portée).
  static const double _bleed = 8;

  // ── Horloges ──────────────────────────────────────────────────────────
  /// Appui : le disque descend sur son relief (150 ms).
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  )..addStatusListener(_onPressStatus);

  /// Chien, feuilles, pattes, point d'état : une seule horloge, qui ne
  /// tourne que pendant une balade.
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(seconds: PawWalkJewelPainter.loopSeconds),
  );

  /// Le chrono : seuls ses deux textes écoutent ce compteur.
  final ValueNotifier<int> _second = ValueNotifier<int>(0);
  Timer? _tick;
  StreamSubscription<DateTime>? _clockSub;

  bool _busy = false;
  bool _held = false;

  LiveMapService? get _live =>
      Get.isRegistered<LiveMapService>() ? Get.find<LiveMapService>() : null;

  RxBool get _broadcasting =>
      widget.broadcasting ??
      _live?.broadcasting ??
      _QuickWalkButton3110State._never;
  Rxn<DateTime> get _startedAt =>
      widget.startedAt ??
      _live?.sessionStartedAt ??
      _QuickWalkButton3110State._noStart;
  Rxn<DateTime> get _elsewhereSince =>
      widget.elsewhereSince ??
      _live?.elsewhereSince ??
      _QuickWalkButton3110State._noStart;
  RxBool get _confirmed =>
      widget.confirmed ??
      _live?.serverConfirmed ??
      _QuickWalkButton3110State._yes;
  RxBool get _elsewhere =>
      widget.elsewhere ??
      _live?.liveElsewhere ??
      _QuickWalkButton3110State._never;

  /// 632 — l'horloge commune (pilule, barre, rond) : `LiveMapService.liveNow`.
  DateTime _clock() =>
      widget.now?.call() ?? _live?.liveNow.value ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    OpenOnPrefs3110.load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _clockSub?.cancel();
    _press.dispose();
    _life.dispose();
    _second.dispose();
    super.dispose();
  }

  /// Met en route ou arrête ce qui bouge. [on] : une balade tourne (le
  /// chrono avance) ; [moving] : les animations sont permises.
  void _sync({required bool on, required bool moving}) {
    if (moving) {
      if (!_life.isAnimating) _life.repeat();
    } else {
      if (_life.isAnimating) _life.stop();
      if (_life.value != 0) _life.value = 0;
    }
    if (!on) {
      _tick?.cancel();
      _tick = null;
      _clockSub?.cancel();
      _clockSub = null;
      return;
    }
    // En balade : le chrono suit l'horloge commune du service (une mise à
    // jour par seconde) ; sans service (tests, aperçus), une minuterie.
    final LiveMapService? live = widget.now == null ? _live : null;
    if (live != null) {
      _tick?.cancel();
      _tick = null;
      _clockSub ??= live.liveNow.listen((_) {
        if (mounted) _second.value++;
      });
    } else {
      _clockSub?.cancel();
      _clockSub = null;
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _second.value++;
      });
    }
  }

  void _onPressStatus(AnimationStatus status) {
    // Appui bref : le disque finit de descendre avant de remonter.
    if (status == AnimationStatus.completed && !_held) _press.reverse();
  }

  void _down() {
    _held = true;
    _press.forward();
  }

  void _up() {
    _held = false;
    if (_press.status == AnimationStatus.forward) return;
    _press.reverse();
  }

  // Même logique de toucher que la 633, mot pour mot.
  Future<void> _onTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      HapticFeedback.mediumImpact();
      if (widget.onTapOverride != null) {
        await widget.onTapOverride!();
      } else if (_broadcasting.value || _elsewhere.value) {
        if (widget.onStop != null) {
          await widget.onStop!(context);
        } else if (mounted) {
          await showPawLiveSheet(context);
        }
      } else {
        if (widget.onStart != null) {
          await widget.onStart!();
        } else {
          await LiveShareStarter.startWithFeedback();
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Obx(() {
      final bool visible =
          (widget.visible ?? OpenOnPrefs3110.quickWalkVisible).value;
      final QuickWalkSide3110 side =
          (widget.side ?? OpenOnPrefs3110.quickWalkSide).value;
      if (!visible) {
        _sync(on: false, moving: false);
        return const SizedBox.shrink();
      }
      final bool live = _broadcasting.value;
      // 632 — « en direct » aussi quand ma balade tourne sur mon autre
      // téléphone, comme la pilule et le bouton de la barre.
      final bool elsewhere = _elsewhere.value;
      final bool on = live || elsewhere;
      // 632 — tant que le serveur n'a pas confirmé : « Connexion… ».
      final bool connecting = live && !_confirmed.value;
      final DateTime? start = live
          ? _startedAt.value
          : (elsewhere ? _elsewhereSince.value : null);
      final bool timed = on && !connecting && start != null;
      final String label = on
          ? 'pamc3110_qw_stop_hint'.tr
          : 'pm605_live_start'.tr;
      final String status = connecting
          ? 'live607_connecting'.tr
          : (on ? 'pamc3110_qw_live'.tr : 'pamc3110_qw_offline'.tr);
      final bool moving = on && !reduced;
      _sync(on: on, moving: moving);

      const double canvas = kQuickWalkCanvas0311;
      const double button = kQuickWalkSize3110;
      final double pastilleDy = timed ? _livePastilleDy : _restPastilleDy;

      return SizedBox(
        width: canvas,
        height: canvas,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Tout le dessin : hors appuis, repeint seul. Son centre est
            // posé un demi-relief sous celui du rond touchable : au repos,
            // la face du disque recouvre exactement ce rond.
            Positioned(
              left: -_bleed,
              right: -_bleed,
              top: -_bleed + _relief / 2,
              bottom: -_bleed - _relief / 2,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: PawWalkJewelPainter(
                      diameter: _diameter,
                      live: on,
                      moving: moving,
                      badge: false,
                      press: _press,
                      life: _life,
                      pastilleRatio: _pastilleRatio,
                      pastilleDy: pastilleDy,
                      leafRadiusRatios: _leafRadii,
                      leafAngles: _leafAngles,
                      pawRadiusRatio: _pawRadius,
                      pawsFadeAtBottom: false,
                      dog: !_busy,
                    ),
                  ),
                ),
              ),
            ),
            // Le rond touchable : clé de côté, sémantique et info-bulle,
            // comme en 633. Il ne bouge pas à l'appui (seul le dessin
            // descend).
            Semantics(
              key: ValueKey<String>('quick_walk_3110_${side.code}'),
              button: true,
              label: '$status · $label',
              child: Tooltip(
                message: label,
                child: GestureDetector(
                  key: const ValueKey<String>('quick_walk_3110_tap'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _down(),
                  onTapUp: (_) => _up(),
                  onTapCancel: _up,
                  onTap: _onTap,
                  child: SizedBox(
                    width: button,
                    height: button,
                    // Le texte suit le disque quand il s'enfonce.
                    child: AnimatedBuilder(
                      animation: _press,
                      builder: (BuildContext context, Widget? child) =>
                          Transform.translate(
                            offset: Offset(
                              0,
                              Curves.easeOut.transform(
                                    _press.value.clamp(0.0, 1.0),
                                  ) *
                                  _relief,
                            ),
                            child: child,
                          ),
                      child: _content(
                        on: on,
                        moving: moving,
                        timed: timed,
                        start: start,
                        pastilleDy: pastilleDy,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // Couleurs de texte de la maquette 639 (aucun gris).
  static const Color _dotOffline = Color(0xFFECFFE4);
  static const Color _txtSmall = Color(0xFFE3FBDA);

  /// Ce qui s'écrit sur le disque : le point d'état, les minutes, les
  /// secondes. Mêmes clés et mêmes tailles de texte que la 633.
  Widget _content({
    required bool on,
    required bool moving,
    required bool timed,
    required DateTime? start,
    required double pastilleDy,
  }) {
    const double half = kQuickWalkSize3110 / 2;
    final TextStyle minStyle = GoogleFonts.nunito(
      fontSize: 15,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: .2),
          offset: const Offset(0, 1),
        ),
      ],
    );
    final TextStyle smallStyle = GoogleFonts.nunito(
      fontSize: 8,
      fontWeight: FontWeight.w800,
      color: _txtSmall,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final double rowCy = timed ? _liveRowCy : _restRowCy;

    Duration elapsed() {
      final DateTime now = _clock();
      return now.isAfter(start!) ? now.difference(start) : Duration.zero;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Attente d'une action : l'indicateur remplace le chien.
        if (_busy)
          Positioned(
            left: half - 8,
            top: half + pastilleDy - 2 * _u - 8,
            width: 16,
            height: 16,
            child: const CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Colors.white,
            ),
          ),
        // Point d'état + minutes.
        Positioned(
          left: 7,
          right: 7,
          top: half + rowCy - _rowH / 2,
          height: _rowH,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      size: const Size(9, 9),
                      painter: _StatusDotPainter640(
                        on: on,
                        moving: moving,
                        life: _life,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  if (!timed)
                    Text(
                      '—',
                      key: const ValueKey<String>('quick_walk_3110_chrono'),
                      style: minStyle,
                    )
                  else ...[
                    ValueListenableBuilder<int>(
                      valueListenable: _second,
                      builder: (BuildContext context, int _, Widget? _) =>
                          Text(
                            '${elapsed().inMinutes}',
                            key: const ValueKey<String>(
                              'quick_walk_3110_chrono',
                            ),
                            style: minStyle,
                          ),
                    ),
                    const SizedBox(width: 2),
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text('pamc3110_qw_min'.tr, style: smallStyle),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Secondes (en direct seulement).
        if (timed)
          Positioned(
            left: 12,
            right: 12,
            top: half + _liveSecsCy - _secsH / 2,
            height: _secsH,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ValueListenableBuilder<int>(
                  valueListenable: _second,
                  builder: (BuildContext context, int _, Widget? _) => Text(
                    '${(elapsed().inSeconds % 60).toString().padLeft(2, '0')} '
                    '${'pamc3110_qw_sec'.tr}',
                    key: const ValueKey<String>('quick_walk_3110_secs'),
                    style: smallStyle,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 640 — le point d'état devant les minutes. Hors ligne : point clair fixe.
/// En balade : point violet clair qui bat, avec son halo. La maquette fait
/// aussi baisser l'opacité du point à 0,5 ; sur le vert, un violet à moitié
/// transparent tire sur le gris : le point reste donc plein, seul le halo
/// s'estompe. Repeint par l'horloge, sans reconstruction.
class _StatusDotPainter640 extends CustomPainter {
  _StatusDotPainter640({
    required this.on,
    required this.moving,
    required this.life,
  }) : super(repaint: life);

  final bool on;
  final bool moving;
  final Animation<double> life;

  static const Color _liveDot = Color(0xFFC9A8FF);

  /// Période du battement : 1,05 s (1,1 s dans la maquette) pour que la
  /// boucle de 1 260 s reprenne sans à-coup.
  static const double _period = 1.05;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    if (!on) {
      canvas.drawCircle(
        c,
        2.5,
        Paint()..color = _QuickWalkJewelState640._dotOffline,
      );
      return;
    }
    final double beat = moving
        ? 1 -
              0.5 *
                  PawWalkJewelPainter.yoyo(
                    life.value * PawWalkJewelPainter.loopSeconds / _period,
                  )
        : 1;
    // beat : 1 (gros) → 0,5 (petit).
    final double scale = 0.3 + 0.7 * beat;
    canvas.drawCircle(
      c,
      4.2 * scale,
      Paint()..color = _liveDot.withValues(alpha: 0.7 * beat - 0.3),
    );
    canvas.drawCircle(c, 2.6 * scale, Paint()..color = _liveDot);
  }

  @override
  bool shouldRepaint(covariant _StatusDotPainter640 old) =>
      old.on != on || old.moving != moving || old.life != life;
}

// ─────────────────────────────────────────────────────────────────────────
// 633 — rendu du design « Bouton Balade en direct » (prototype 280 × 280).
// ─────────────────────────────────────────────────────────────────────────

class _LiveWalkCanvas0311 extends StatelessWidget {
  const _LiveWalkCanvas0311({
    required this.scale,
    required this.buttonKey,
    required this.label,
    required this.on,
    required this.connecting,
    required this.busy,
    required this.pressed,
    required this.elapsed,
    required this.t,
    required this.animate,
    required this.onTap,
    required this.onPressChanged,
  });

  final double scale;
  final Key buttonKey;
  final String label;
  final bool on;
  final bool connecting;
  final bool busy;
  final bool pressed;
  final Duration? elapsed;
  final double t;
  final bool animate;
  final VoidCallback onTap;
  final ValueChanged<bool> onPressChanged;

  // Couleurs du prototype.
  static const Color _gLight = Color(0xFF95F0A4);
  static const Color _gMid = Color(0xFF48CB68);
  static const Color _gDark = Color(0xFF28A04A);
  static const Color _hardShadow = Color(0xFF1E7A38);
  static const Color _softShadow = Color(0xFF2AA04B);
  static const Color _violet = Color(0xFF9B5CF6);
  static const Color _violetLight = Color(0xFFE9D5FF);
  static const Color _violetDark = Color(0xFF7C3AED);
  static const Color _violetShadow = Color(0xFF5B21B6);
  static const Color _lavender = Color(0xFFB388FF);
  static const Color _leafA = Color(0xFF6FD98A);
  static const Color _leafB = Color(0xFF8EEB9E);
  static const Color _txtStatus = Color(0xFFECFFE4);
  static const Color _txtUnit = Color(0xFFD8F7CD);
  static const Color _txtSecs = Color(0xFFB9EDAD);

  double _px(double v) => v * scale;

  /// Les petits textes ne descendent jamais sous 8 pt (lisibilité).
  double _font(double px) => math.max(8.0, px * scale);

  @override
  Widget build(BuildContext context) {
    final double canvas = _px(kQuickWalkProtoCanvas0311);
    final double button = _px(kQuickWalkProtoButton0311);
    final double center = canvas / 2;
    final double pressDy = pressed ? _px(10) : 0;

    return SizedBox(
      width: canvas,
      height: canvas,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Pattes en orbite + feuilles (en direct seulement, derrière le rond).
          if (on)
            IgnorePointer(
              child: SizedBox(
                width: canvas,
                height: canvas,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [..._paws(center), ..._leaves(center)],
                ),
              ),
            ),
          // Ombre dure verte (le socle) + ombre portée colorée.
          IgnorePointer(
            child: Transform.translate(
              offset: Offset(0, _px(10)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: button,
                height: button,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hardShadow,
                  boxShadow: [
                    pressed
                        ? BoxShadow(
                            color: _softShadow.withValues(alpha: .30),
                            blurRadius: _px(12),
                            offset: Offset(0, _px(4) - _px(10)),
                          )
                        : BoxShadow(
                            color: _softShadow.withValues(alpha: .45),
                            blurRadius: _px(44),
                            offset: Offset(0, _px(26) - _px(10)),
                          ),
                  ],
                ),
              ),
            ),
          ),
          // Le rond lui-même (seule zone qui réagit au toucher).
          Semantics(
            key: buttonKey,
            button: true,
            label: '${_statusText()} · $label',
            child: Tooltip(
              message: label,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(0, pressDy, 0),
                child: GestureDetector(
                  key: const ValueKey<String>('quick_walk_3110_tap'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => onPressChanged(true),
                  onTapUp: (_) => onPressChanged(false),
                  onTapCancel: () => onPressChanged(false),
                  onTap: onTap,
                  child: SizedBox(
                    width: button,
                    height: button,
                    child: ClipOval(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Fond : dégradé radial centré à 35 % / 25 %.
                          Container(
                            width: button,
                            height: button,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: Alignment(-0.3, -0.5),
                                radius: 0.99,
                                colors: [_gLight, _gMid, _gDark],
                                stops: [0, .4, 1],
                              ),
                            ),
                          ),
                          // Ombres internes : bande claire en haut (3 px),
                          // bande sombre en bas (8 px, 4 px enfoncé).
                          IgnorePointer(
                            child: CustomPaint(
                              size: Size(button, button),
                              painter: _InsetBandsPainter0311(
                                topBand: _px(3),
                                topColor: Colors.white.withValues(
                                  alpha: pressed ? .30 : .45,
                                ),
                                bottomBand: _px(pressed ? 4 : 8),
                                bottomColor: Colors.black.withValues(
                                  alpha: .14,
                                ),
                              ),
                            ),
                          ),
                          // Anneau pointillé qui tourne (en direct).
                          if (on)
                            IgnorePointer(
                              child: Transform.rotate(
                                angle: animate ? 2 * math.pi * (t / 14) : 0,
                                child: CustomPaint(
                                  size: Size(button, button),
                                  painter: _DashedRingPainter0311(
                                    inset: _px(7),
                                    stroke: _px(2),
                                    dash: _px(6),
                                    gap: _px(5),
                                    color: Colors.white.withValues(alpha: .5),
                                  ),
                                ),
                              ),
                            ),
                          _content(button),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText() => connecting
      ? 'live607_connecting'.tr
      : (on ? 'pamc3110_qw_live'.tr : 'pamc3110_qw_offline'.tr);

  /// 634 — rond de 62 pt : chien, point d'état + minutes, secondes. Le texte
  /// d'état (« BALADE EN DIRECT ») n'y tiendrait qu'en 4 pt : il passe dans
  /// la sémantique et l'info-bulle, le point violet qui bat dit « en direct ».
  Widget _compactContent(double button) {
    final bool showMin = on && !connecting && elapsed != null;
    final int minutes = showMin ? elapsed!.inMinutes : 0;
    final int seconds = showMin ? elapsed!.inSeconds % 60 : 0;
    final double dotScale = animate
        ? 0.75 + 0.25 * math.cos(2 * math.pi * t / 1.1)
        : 1;
    final TextStyle minStyle = GoogleFonts.nunito(
      fontSize: 15,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: [
        Shadow(color: Colors.black.withValues(alpha: .2), offset: const Offset(0, 1)),
      ],
    );
    final TextStyle smallStyle = GoogleFonts.nunito(
      fontSize: 8,
      fontWeight: FontWeight.w800,
      color: _txtUnit,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return SizedBox(
      width: button * .8,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dogDisc(proto: 72),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Transform.scale(
                  scale: on ? dotScale : 1,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? _violet : _txtStatus.withValues(alpha: .8),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  showMin ? '$minutes' : '—',
                  key: const ValueKey<String>('quick_walk_3110_chrono'),
                  style: minStyle,
                ),
                if (showMin) ...[
                  const SizedBox(width: 2),
                  Text('pamc3110_qw_min'.tr, style: smallStyle),
                ],
              ],
            ),
            if (showMin) ...[
              const SizedBox(height: 1),
              Text(
                '${seconds.toString().padLeft(2, '0')} ${'pamc3110_qw_sec'.tr}',
                key: const ValueKey<String>('quick_walk_3110_secs'),
                style: smallStyle.copyWith(color: _txtSecs),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _content(double button) {
    if (scale < 0.5) return _compactContent(button);
    final bool showMin = on && !connecting && elapsed != null;
    final int minutes = showMin ? elapsed!.inMinutes : 0;
    final int seconds = showMin ? elapsed!.inSeconds % 60 : 0;
    final String status = connecting
        ? 'live607_connecting'.tr
        : (on ? 'pamc3110_qw_live'.tr : 'pamc3110_qw_offline'.tr);
    final TextStyle statusStyle = GoogleFonts.nunito(
      fontSize: _font(9.5),
      fontWeight: FontWeight.w900,
      letterSpacing: _px(2.4),
      color: _txtStatus,
      height: 1.1,
    );
    final TextStyle minStyle = GoogleFonts.nunito(
      fontSize: _px(32),
      fontWeight: FontWeight.w900,
      letterSpacing: _px(-1),
      color: Colors.white,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: .2),
          offset: Offset(0, _px(2)),
        ),
      ],
    );
    final TextStyle unitStyle = GoogleFonts.nunito(
      fontSize: _font(11),
      fontWeight: FontWeight.w800,
      letterSpacing: _px(.8),
      color: _txtUnit,
      height: 1,
    );
    final TextStyle secStyle = GoogleFonts.nunito(
      fontSize: _font(11),
      fontWeight: FontWeight.w800,
      letterSpacing: _px(.6),
      color: _txtSecs,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final double dotScale = animate
        ? 0.75 + 0.25 * math.cos(2 * math.pi * t / 1.1)
        : 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dogDisc(),
        SizedBox(height: _px(8 + 2)),
        // Ligne statut : point + texte en capitales.
        SizedBox(
          width: button - _px(20),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: on ? dotScale : 1,
                  child: Transform.scale(
                    scale: on ? dotScale : 1,
                    child: Container(
                      width: _px(7),
                      height: _px(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? _violet : _txtStatus,
                        boxShadow: on
                            ? [
                                BoxShadow(
                                  color: _violet.withValues(alpha: .35),
                                  spreadRadius: _px(3),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: _px(6)),
                Text(
                  status.toUpperCase(),
                  key: const ValueKey<String>('quick_walk_3110_status'),
                  style: statusStyle,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: _px(2)),
        // Compteur : minutes (gros) + unité, alignés sur la ligne de base.
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              showMin ? '$minutes' : '—',
              key: const ValueKey<String>('quick_walk_3110_chrono'),
              style: minStyle,
            ),
            if (showMin) ...[
              SizedBox(width: _px(4)),
              Text('pamc3110_qw_min'.tr.toUpperCase(), style: unitStyle),
            ],
          ],
        ),
        SizedBox(height: _px(2 + 2)),
        // Secondes « 07 s » (vide hors ligne, hauteur réservée).
        SizedBox(
          height: secStyle.fontSize! * 1.1,
          child: showMin
              ? Text(
                  '${seconds.toString().padLeft(2, '0')} ${'pamc3110_qw_sec'.tr}',
                  key: const ValueKey<String>('quick_walk_3110_secs'),
                  style: secStyle,
                )
              : null,
        ),
      ],
    );
  }

  /// Pastille violette 58 px + chien 46 px qui se balance (± 8°, 0,9 s).
  Widget _dogDisc({double proto = 58}) {
    final double d = _px(proto);
    final double wobble = animate
        ? -8 * math.cos(2 * math.pi * t / 0.9) * math.pi / 180
        : 0;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.2, -0.4),
          radius: 0.95,
          colors: [_violetLight, _violet, _violetDark],
          stops: [0, .58, 1],
        ),
        boxShadow: [
          BoxShadow(color: _violetShadow, offset: Offset(0, _px(4))),
          BoxShadow(
            color: Colors.black.withValues(alpha: .2),
            blurRadius: _px(16),
            offset: Offset(0, _px(10)),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Reflet interne (inset 0 2px 0 blanc .75).
          CustomPaint(
            size: Size(d, d),
            painter: _InsetBandsPainter0311(
              topBand: _px(2),
              topColor: Colors.white.withValues(alpha: .75),
              bottomBand: 0,
              bottomColor: Colors.transparent,
            ),
          ),
          if (busy)
            SizedBox(
              width: d * .55,
              height: d * .55,
              child: const CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          else
            Transform.rotate(
              angle: wobble,
              alignment: const Alignment(0, 0.7), // origine 50 % / 85 %
              child: SvgPicture.string(
                _dogSvg0311,
                width: d * 46 / 58,
                height: d * 46 / 58,
              ),
            ),
        ],
      ),
    );
  }

  /// 4 pattes en orbite (rayon 104 px) : 0°, 90°, 180°, 270° ; 18 s les
  /// grandes, 21 s les petites.
  List<Widget> _paws(double center) {
    const specs = <(double, double, Color, double)>[
      (0, 18, _leafA, 18),
      (90, 14, _violet, 21),
      (180, 18, _leafB, 18),
      (270, 14, _lavender, 21),
    ];
    final double r = _px(104);
    return [
      for (final (a0, sz, c, period) in specs)
        () {
          final double deg = a0 + (animate ? 360 * t / period : 0);
          final double rad = deg * math.pi / 180;
          final double size = _px(sz);
          final double x = center + r * math.sin(rad) - size / 2;
          final double y = center - r * math.cos(rad) - size / 2;
          return Positioned(
            left: x,
            top: y,
            child: Transform.rotate(
              angle: (a0 * math.pi / 180) + rad,
              child: Opacity(
                opacity: .9,
                child: SvgPicture.string(
                  _pawSvg0311(c),
                  width: size,
                  height: size,
                ),
              ),
            ),
          );
        }(),
    ];
  }

  /// 4 feuilles sur un cercle de rayon 118 px (225°, 315°, 45°, 135°), qui
  /// flottent de 6 px (3 à 5 s, décalées).
  List<Widget> _leaves(double center) {
    const specs = <(double, double, double, Color, double)>[
      (225, -25, 30, _leafA, 0),
      (315, 40, 26, _violet, 1),
      (45, 120, 24, _leafB, 2),
      (135, -110, 22, _lavender, 1.5),
    ];
    final double r = _px(118);
    return [
      for (final (deg, rot, sz, c, d) in specs)
        () {
          final double rad = deg * math.pi / 180;
          final double size = _px(sz);
          final double x = center + r * math.cos(rad) - size / 2;
          final double y = center + r * math.sin(rad) - size / 2;
          final double dur = 3 + d;
          final double dy = animate
              ? -_px(6) *
                    (0.5 - 0.5 * math.cos(2 * math.pi * (t - d * 0.5) / dur))
              : 0;
          return Positioned(
            left: x,
            top: y + dy,
            child: Transform.rotate(
              angle: rot * math.pi / 180,
              child: SvgPicture.string(
                _leafSvg0311(c),
                width: size,
                height: size,
              ),
            ),
          );
        }(),
    ];
  }
}

/// Bandes « inset » d'un cercle : croissant clair en haut, croissant sombre
/// en bas (équivalent des `inset box-shadow` du prototype).
class _InsetBandsPainter0311 extends CustomPainter {
  const _InsetBandsPainter0311({
    required this.topBand,
    required this.topColor,
    required this.bottomBand,
    required this.bottomColor,
  });
  final double topBand;
  final Color topColor;
  final double bottomBand;
  final Color bottomColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = Offset.zero & size;
    final Path circle = Path()..addOval(r);
    if (topBand > 0) {
      final Path shifted = Path()..addOval(r.shift(Offset(0, topBand)));
      canvas.drawPath(
        Path.combine(PathOperation.difference, circle, shifted),
        Paint()..color = topColor,
      );
    }
    if (bottomBand > 0) {
      final Path shifted = Path()..addOval(r.shift(Offset(0, -bottomBand)));
      canvas.drawPath(
        Path.combine(PathOperation.difference, circle, shifted),
        Paint()..color = bottomColor,
      );
    }
  }

  @override
  bool shouldRepaint(_InsetBandsPainter0311 o) =>
      o.topBand != topBand ||
      o.topColor != topColor ||
      o.bottomBand != bottomBand ||
      o.bottomColor != bottomColor;
}

/// Anneau pointillé (border 2px dashed, inset 7).
class _DashedRingPainter0311 extends CustomPainter {
  const _DashedRingPainter0311({
    required this.inset,
    required this.stroke,
    required this.dash,
    required this.gap,
    required this.color,
  });
  final double inset;
  final double stroke;
  final double dash;
  final double gap;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2 - inset - stroke / 2;
    if (radius <= 0) return;
    final Offset c = Offset(size.width / 2, size.height / 2);
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final double circ = 2 * math.pi * radius;
    // Nombre entier de motifs pour que l'anneau se referme proprement.
    final int n = math.max(8, (circ / (dash + gap)).round());
    final double step = 2 * math.pi / n;
    final double dashAngle = step * (dash / (dash + gap));
    final Rect rect = Rect.fromCircle(center: c, radius: radius);
    for (int i = 0; i < n; i++) {
      canvas.drawArc(rect, i * step, dashAngle, false, p);
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter0311 o) =>
      o.inset != inset || o.stroke != stroke || o.color != color;
}

// ── Pictos du prototype (SVG inline, paths exacts) ──────────────────────────

const String _dogSvg0311 = '''
<svg xmlns="http://www.w3.org/2000/svg" width="46" height="46" viewBox="0 0 48 48">
  <defs>
    <radialGradient id="dogHead" cx="40%" cy="30%" r="75%">
      <stop offset="0" stop-color="#2F9A4C"/><stop offset="1" stop-color="#176B30"/>
    </radialGradient>
    <radialGradient id="dogEar" cx="40%" cy="25%" r="80%">
      <stop offset="0" stop-color="#1E7A38"/><stop offset="1" stop-color="#0E4F22"/>
    </radialGradient>
    <radialGradient id="dogMuzzle" cx="45%" cy="25%" r="80%">
      <stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#D9F5D1"/>
    </radialGradient>
  </defs>
  <path d="M14 13c-5-1.5-9 2.5-9 8.5 0 5.5 2.5 11 6 12 2.5.7 5-1 5-4.5V17c0-2-.8-3.4-2-4z" fill="url(#dogEar)"/>
  <path d="M34 13c5-1.5 9 2.5 9 8.5 0 5.5-2.5 11-6 12-2.5.7-5-1-5-4.5V17c0-2 .8-3.4 2-4z" fill="url(#dogEar)"/>
  <path d="M11 18c-.5 3 0 7 1.5 10" stroke="rgba(255,255,255,0.18)" stroke-width="1.4" stroke-linecap="round" fill="none"/>
  <path d="M24 8c-8.5 0-13.5 6-13.5 14.5 0 7 4.8 13.5 13.5 13.5s13.5-6.5 13.5-13.5C37.5 14 32.5 8 24 8z" fill="url(#dogHead)"/>
  <ellipse cx="19.5" cy="13" rx="4.5" ry="2.2" fill="rgba(255,255,255,0.18)" transform="rotate(-20 19.5 13)"/>
  <path d="M16 16.5c1.2-.9 2.8-1 4-.3M28 16.2c1.2-.7 2.8-.6 4 .3" stroke="#0E3B1B" stroke-width="1.3" stroke-linecap="round" fill="none" opacity="0.8"/>
  <path d="M24 21.5c-4.6 0-7.8 3-7.8 6.6 0 3.9 3.2 7.2 7.8 7.2s7.8-3.3 7.8-7.2c0-3.6-3.2-6.6-7.8-6.6z" fill="url(#dogMuzzle)"/>
  <ellipse cx="18.8" cy="20.6" rx="2.3" ry="2.6" fill="#0E3B1B"/>
  <ellipse cx="29.2" cy="20.6" rx="2.3" ry="2.6" fill="#0E3B1B"/>
  <circle cx="19.7" cy="19.5" r="0.8" fill="#fff"/>
  <circle cx="30.1" cy="19.5" r="0.8" fill="#fff"/>
  <circle cx="18.2" cy="21.6" r="0.4" fill="#fff" opacity="0.6"/>
  <circle cx="28.6" cy="21.6" r="0.4" fill="#fff" opacity="0.6"/>
  <ellipse cx="15.5" cy="25.5" rx="1.8" ry="1.1" fill="#FF8FA8" opacity="0.55"/>
  <ellipse cx="32.5" cy="25.5" rx="1.8" ry="1.1" fill="#FF8FA8" opacity="0.55"/>
  <path d="M24 24.8c-2.1 0-3.5 1.1-3.5 2.5 0 1.1 1 2 2.2 2.5l1.3.7 1.3-.7c1.2-.5 2.2-1.4 2.2-2.5 0-1.4-1.4-2.5-3.5-2.5z" fill="#0E3B1B"/>
  <ellipse cx="22.9" cy="26.1" rx="0.8" ry="0.5" fill="#fff" opacity="0.75"/>
  <path d="M24 30.5v1.5M24 32c-1.5 1.8-3.3 1.8-4.4.6M24 32c1.5 1.8 3.3 1.8 4.4.6" stroke="#0E3B1B" stroke-width="1.4" stroke-linecap="round" fill="none"/>
  <path d="M22.1 32.9c0 2.3.9 4.1 1.9 4.1s1.9-1.8 1.9-4.1c-.6-.5-3.2-.5-3.8 0z" fill="#FF6B8A"/>
  <path d="M24 33.4v2.6" stroke="#E04A6C" stroke-width="0.7" stroke-linecap="round"/>
</svg>
''';

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String _pawSvg0311(Color c) =>
    '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="${_hex(c)}">
  <ellipse cx="12" cy="14" rx="3.2" ry="3.6"/>
  <circle cx="7" cy="9.5" r="1.9"/><circle cx="17" cy="9.5" r="1.9"/>
  <circle cx="9.5" cy="5.5" r="1.8"/><circle cx="14.5" cy="5.5" r="1.8"/>
</svg>
''';

String _leafSvg0311(Color c) =>
    '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path d="M3 21c0-9 7-16 18-18-1 11-8 18-18 18z" fill="${_hex(c)}"/>
  <path d="M4 20L19 5" stroke="rgba(255,255,255,0.6)" stroke-width="1.3" stroke-linecap="round"/>
</svg>
''';
