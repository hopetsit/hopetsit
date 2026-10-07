// 613 (PAM, 06/10/2026) — ALERTES de la PawMap (PROCHAIN_BUILD_613 §4b + §4c,
// propositions de BOB VALIDÉES par Daniel le 06/10 au soir).
//
// 4b — épingle d'alerte « jolie » : rond blanc, ANNEAU à la couleur de la
//      gravité (rouge = danger, orange = attention, bleu = info), l'emoji du
//      type au centre (ou son icône si l'emoji ne se dessine pas, voir
//      pawmap_report_pin613.dart) ; une alerte FRAÎCHE (< 2 h) porte une
//      auréole de sa couleur ; elle PÂLIT en vieillissant (opacité du
//      marqueur : aucune image redessinée, donc aucun clignotement).
//      La « petite pulsation » proposée est rendue par l'auréole FIXE : une
//      épingle qui change d'image à chaque battement fait clignoter la carte
//      et remplit la réserve d'images du SDK iOS (mesuré au 607) — règle
//      n°1 du 612 : la carte reste calme.
// 4c — alerte EN PASSANT : pendant MA balade, à ≤ 50 m d'une alerte, une
//      fois par alerte et par balade : bandeau en haut (« Danger · 40 m
//      devant toi »), petit « ding » (danger : son distinct, vibration plus
//      forte), mode silencieux respecté, réglage on/off dans Calques.

import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/views/map/widgets/pawmap_catch613.dart' show kPawCatchAudioContext613;
import 'package:hopetsit/views/map/widgets/pawmap_signal.dart';

enum PawAlertLevel { danger, attention, info }

/// Gravité d'un type de signalement.
PawAlertLevel pawAlertLevel613(String type) => switch (type) {
      'hazard' || 'poison' || 'trap' || 'aggressive_dog' || 'chemical' || 'fire_smoke' =>
        PawAlertLevel.danger,
      'water_active' || 'vet_open' || 'lost_pet' || 'found_pet' || 'poop' || 'pee' || 'other' =>
        PawAlertLevel.info,
      _ => PawAlertLevel.attention,
    };

/// Couleurs (aucun gris) : rouge danger, orange attention, bleu info.
Color pawAlertColor613(PawAlertLevel l) => switch (l) {
      PawAlertLevel.danger => const Color(0xFFDC2626),
      PawAlertLevel.attention => const Color(0xFFEA580C),
      PawAlertLevel.info => const Color(0xFF2563EB),
    };

/// Alerte « fraîche » : moins de 2 h.
const Duration kPawAlertFresh613 = Duration(hours: 2);
bool pawAlertFresh613(DateTime createdAt, DateTime now) =>
    now.difference(createdAt) < kPawAlertFresh613;

/// Opacité selon l'âge (48 h de vie) : pleine jusqu'à 24 h, puis pâlit.
double pawAlertAlpha613(DateTime createdAt, DateTime now) {
  final h = now.difference(createdAt).inMinutes / 60.0;
  if (h < 24) return 1.0;
  if (h < 36) return 0.78;
  return 0.58;
}

// ─── 4c — en passant ──────────────────────────────────────────────────────

/// Distance d'annonce (m).
const double kPawPassingRadius613 = 50;

/// Réglage (Calques) : activé par défaut.
const String kPawPassingKey613 = 'pawmap_passing_alerts_613';
bool pawPassingEnabled613({GetStorage? box}) {
  try {
    final v = (box ?? GetStorage()).read(kPawPassingKey613);
    return v is bool ? v : true;
  } catch (_) {
    return true;
  }
}

double pawMeters613(LatLng a, LatLng b) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final x = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(x)));
}

double _bearing(LatLng a, LatLng b) {
  double rad(double d) => d * math.pi / 180;
  final y = math.sin(rad(b.longitude - a.longitude)) * math.cos(rad(b.latitude));
  final x = math.cos(rad(a.latitude)) * math.sin(rad(b.latitude)) -
      math.sin(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.cos(rad(b.longitude - a.longitude));
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Une alerte à annoncer.
class PawPassing613 {
  const PawPassing613({required this.id, required this.type, required this.meters, required this.ahead});
  final String id;
  final String type;
  final int meters;
  /// Devant moi (dans le sens de la marche, ±60°) ; sinon « près de toi ».
  final bool ahead;
  PawAlertLevel get level => pawAlertLevel613(type);
}

/// Une alerte candidate (type, position, encore valide).
class PawAlertPoint613 {
  const PawAlertPoint613(this.id, this.type, this.at);
  final String id;
  final String type;
  final LatLng at;
}

/// Mémoire d'UNE balade : chaque alerte n'est annoncée qu'une fois.
class PawPassingAlerts613 {
  final Set<String> _done = <String>{};
  LatLng? _prev;

  void reset() {
    _done.clear();
    _prev = null;
  }

  int get announcedCount => _done.length;

  /// Nouvelle position : l'alerte la plus PROCHE, non annoncée, à ≤ 50 m.
  /// Danger d'abord à distance égale. Null si rien.
  PawPassing613? onPosition(LatLng me, Iterable<PawAlertPoint613> alerts) {
    final prev = _prev;
    // On garde le point de départ du « sens de marche » tant qu'on n'a pas
    // fait 4 m (GPS qui hésite sur place).
    if (prev == null || pawMeters613(prev, me) >= 4) _prev = me;
    PawAlertPoint613? best;
    double bestD = double.infinity;
    for (final a in alerts) {
      if (_done.contains(a.id)) continue;
      final d = pawMeters613(me, a.at);
      if (d > kPawPassingRadius613) continue;
      final better = d < bestD - 0.5 ||
          ((d - bestD).abs() <= 0.5 &&
              best != null &&
              pawAlertLevel613(a.type).index < pawAlertLevel613(best.type).index);
      if (better) {
        best = a;
        bestD = d;
      }
    }
    if (best == null) return null;
    _done.add(best.id);
    var ahead = false;
    if (prev != null && pawMeters613(prev, me) >= 4) {
      final heading = _bearing(prev, me);
      final to = _bearing(me, best.at);
      final diff = ((to - heading + 540) % 360) - 180;
      ahead = diff.abs() <= 60;
    }
    return PawPassing613(id: best.id, type: best.type, meters: bestD.round(), ahead: ahead);
  }
}

/// Texte du bandeau : « 40 m devant toi » / « à 40 m ».
String pawPassingWhere613(PawPassing613 p) => p.ahead
    ? 'alert613_ahead'.trParams({'m': '${math.max(1, p.meters)}'})
    : 'alert613_near'.trParams({'m': '${math.max(1, p.meters)}'});

class PawPassingBanner613 {
  PawPassingBanner613._();
  static OverlayEntry? _entry;
  static AudioPlayer? _player;
  @visibleForTesting
  static bool silentForTests = false;

  static void show(BuildContext context, PawPassing613 p,
      {required String label, required String emoji}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    hide();
    PawSignal.holdFor(const Duration(milliseconds: 4200));
    final danger = p.level == PawAlertLevel.danger;
    if (danger) {
      HapticFeedback.heavyImpact();
      Timer(const Duration(milliseconds: 160), HapticFeedback.heavyImpact);
    } else {
      HapticFeedback.lightImpact();
    }
    unawaited(_ding(danger));
    late final OverlayEntry e;
    e = OverlayEntry(
      builder: (_) => PawPassingCard613(
        passing: p,
        label: label,
        emoji: emoji,
        onDone: () {
          if (_entry == e) hide();
        },
      ),
    );
    _entry = e;
    overlay.insert(e);
  }

  static void hide() {
    final e = _entry;
    _entry = null;
    if (e != null && e.mounted) e.remove();
  }

  static Future<void> _ding(bool danger) async {
    if (silentForTests) return;
    try {
      final pl = _player ??= AudioPlayer();
      await pl.setAudioContext(kPawCatchAudioContext613); // silencieux respecté
      await pl.setVolume(danger ? 0.8 : 0.55);
      await pl.play(AssetSource(danger ? 'sounds/alert_danger613.m4a' : 'sounds/alert_ding613.m4a'));
    } catch (_) {/* pas de son : le bandeau reste */}
  }
}

/// Le bandeau (verre chaud, disque à la couleur de la gravité). Ne capte
/// aucun toucher : la carte reste utilisable dessous.
class PawPassingCard613 extends StatefulWidget {
  const PawPassingCard613({
    super.key,
    required this.passing,
    required this.label,
    required this.emoji,
    this.onDone,
    this.visibleFor = const Duration(seconds: 4),
  });
  final PawPassing613 passing;
  final String label;
  final String emoji;
  final VoidCallback? onDone;
  final Duration visibleFor;

  @override
  State<PawPassingCard613> createState() => _PawPassingCard613State();
}

class _PawPassingCard613State extends State<PawPassingCard613> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _t = Timer(widget.visibleFor, () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = pawAlertColor613(widget.passing.level);
    final where = pawPassingWhere613(widget.passing);
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(children: [
          Positioned(
            left: 16.w,
            right: 16.w,
            top: MediaQuery.of(context).padding.top + 64.h,
            child: Center(
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
                    .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn)),
                child: FadeTransition(
                  opacity: _c,
                  child: Semantics(
                    liveRegion: true,
                    label: '${widget.label} · $where',
                    child: Container(
                      key: const ValueKey<String>('alert613_banner'),
                      constraints: BoxConstraints(maxWidth: 340.w, minHeight: 52.h),
                      padding: EdgeInsets.fromLTRB(7.w, 7.h, 18.w, 7.h),
                      decoration: PawSignalStyle.glass(dark).copyWith(
                        border: Border.all(color: color.withValues(alpha: 0.75), width: 1.6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 40.w,
                          height: 40.w,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: color, width: 3),
                            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10)],
                          ),
                          child: Text(widget.emoji, style: TextStyle(fontSize: 19.sp, decoration: TextDecoration.none)),
                        ),
                        SizedBox(width: 11.w),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w900,
                                    color: color,
                                    decoration: TextDecoration.none,
                                  )),
                              Text(where,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w700,
                                    color: dark ? PawSignalStyle.textInkDark : PawSignalStyle.textInk,
                                    decoration: TextDecoration.none,
                                  )),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
