// 631 (PAM-C, 31/10/2026) — BOUTON « BALADE RAPIDE » de la PawMap.
//
// Daniel (31/10) : un gros rond vert (60-64 pt, icône marcheur) en bas de la
// carte, à portée du pouce, à droite (ou à gauche pour les gauchers).
//   · au repos : UN toucher = exactement le flux « Démarrer ma balade » de la
//     carte et du chat (`LiveShareStarter.startWithFeedback` : même service,
//     même permission de position, même partage « jusqu'à l'arrêt ») ;
//   · en balade : il affiche le chrono (« 12 min ») et UN toucher ouvre la
//     feuille « En direct » existante (sa ligne « Ma balade · Arrêter ») — le
//     bouton n'arrête jamais une balade d'un seul geste ;
//   · appui long : AUCUN mode « balade privée » n'existe dans
//     `LiveMapService` (vérifié 31/10) → rien d'inventé, l'appui long ne fait
//     rien de plus. Qui me voit se règle avec l'œil (Tous / Amis / Masqué).
// Il lit les 2 réglages de Profil › Préférences › Ouverture (`OpenOnPrefs3110`)
// : visible / côté, et suit leur changement tout de suite.
//
// Montage dans l'écran carte (fichier de PAM-A) : voir PROCHAIN_BUILD_631.md,
// section PAM-C — `QuickWalkButton3110.positioned(context)` dans le Stack.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/services/live_share_starter.dart';
import 'package:hopetsit/services/open_on_prefs_3110.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/views/map/widgets/pawmap_live_sheet.dart'
    show pawLiveDurationLabel, showPawLiveSheet;
import 'package:hopetsit/widgets/paw_icons.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart'
    show kPawTabBarPillHeight, kPawTabBarBottomMargin;

/// Diamètre du bouton (Daniel : 60-64 pt).
const double kQuickWalkSize3110 = 62;

/// Marge latérale (comme la barre d'onglets : 16).
const double kQuickWalkSideMargin3110 = 16;

/// Dégagement au-dessus de la barre d'onglets flottante (pilule 70 + marge 6
/// + 18 d'air), hors inset système : le bouton reste à portée du pouce.
const double kQuickWalkAboveBar3110 =
    kPawTabBarPillHeight + kPawTabBarBottomMargin + 18;

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
  });

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
  static Widget positioned(BuildContext context,
      {double extraBottom = 0, double? sideInset}) {
    OpenOnPrefs3110.load();
    final double bottom =
        appBottomInset(context) + kQuickWalkAboveBar3110 + extraBottom;
    final double inset = sideInset ?? kQuickWalkSideMargin3110;
    return Obx(() {
      final side = OpenOnPrefs3110.quickWalkSide.value;
      return Positioned(
        bottom: bottom,
        left: side == QuickWalkSide3110.left ? inset : null,
        right: side == QuickWalkSide3110.right ? inset : null,
        child: const QuickWalkButton3110(),
      );
    });
  }

  @override
  State<QuickWalkButton3110> createState() => _QuickWalkButton3110State();
}

class _QuickWalkButton3110State extends State<QuickWalkButton3110> {
  Timer? _tick;
  bool _busy = false;

  LiveMapService? get _live =>
      Get.isRegistered<LiveMapService>() ? Get.find<LiveMapService>() : null;

  RxBool get _broadcasting =>
      widget.broadcasting ?? _live?.broadcasting ?? _never;
  static final RxBool _never = false.obs;

  Rxn<DateTime> get _startedAt =>
      widget.startedAt ?? _live?.sessionStartedAt ?? _noStart;
  static final Rxn<DateTime> _noStart = Rxn<DateTime>();

  @override
  void initState() {
    super.initState();
    OpenOnPrefs3110.load();
    // Le chrono se met à jour toutes les 20 s (affichage à la minute).
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && _broadcasting.value) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      HapticFeedback.mediumImpact();
      if (_broadcasting.value) {
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
      if (!visible) return const SizedBox.shrink();
      final bool on = _broadcasting.value;
      final DateTime? start = _startedAt.value;
      final String chrono = on
          ? pawLiveDurationLabel(start ?? (widget.now?.call() ?? DateTime.now()),
              widget.now?.call() ?? DateTime.now())
          : '';
      final String label =
          on ? 'pamc3110_qw_stop_hint'.tr : 'pm605_live_start'.tr;
      const Color green = AppColors.walkerAccent; // vert promeneur #16A34A
      final Color top = Color.lerp(green, Colors.white, 0.18)!;
      final Color bottom = Color.lerp(green, Colors.black, 0.18)!;
      return Semantics(
        key: ValueKey<String>('quick_walk_3110_${side.code}'),
        button: true,
        label: label,
        child: Tooltip(
          message: label,
          child: GestureDetector(
            key: const ValueKey<String>('quick_walk_3110_tap'),
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: kQuickWalkSize3110,
              height: kQuickWalkSize3110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: on ? [bottom, green] : [top, bottom],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: on ? 0.95 : 0.75),
                  width: on ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: green.withValues(alpha: 0.42),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  : on
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const PawIconWidget(PawIcon.walker,
                                size: 22, color: Colors.white),
                            const SizedBox(height: 1),
                            FittedBox(
                              child: Text(
                                chrono,
                                key: const ValueKey<String>(
                                    'quick_walk_3110_chrono'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Center(
                          child: PawIconWidget(PawIcon.walker,
                              size: 30, color: Colors.white),
                        ),
            ),
          ),
        ),
      );
    });
  }
}
