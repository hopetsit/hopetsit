// 613 (PAM, 06/10/2026) — LA FÊTE DE LA PELUCHE (PROCHAIN_BUILD_613 §1 + 4d).
//
// Alhama, 22:26 : john a attrapé le Chiot (serveur : 22:26:16,9) et n'a RIEN
// vu ; Cam, 25 s plus tard, a vu « +40 ». Mesuré : la seule trace d'une
// capture était une pastille de 5 s, posée même quand l'app est en arrière-
// plan / l'écran éteint (capture AUTOMATIQUE au GPS, téléphone en poche) —
// la minuterie la retire avant que l'on regarde. Et si la réponse se perdait,
// la demande suivante disait « Trop tard : quelqu'un l'a attrapée ».
//
// Désormais, à CHAQUE capture, sur CHAQUE profil :
//  · confettis aux couleurs de la peluche (~1,5 s, aucun si « Réduire les
//    animations »), une carte « +40 points · Chiot attrapé ! » qui part seule
//    (3,2 s), vibration, petit son « pop + étincelle » (généré, libre) ;
//  · RIEN ne bloque la carte : tout est sous IgnorePointer, la carte est en
//    haut, la fiche de suivi (en bas) n'est jamais couverte ;
//  · app en arrière-plan ou écran éteint au moment de la capture : la fête
//    est GARDÉE (mémoire + disque, 6 h) et jouée au retour dans l'app ;
//  · mode silencieux : iOS = catégorie « ambient » (coupée par l'interrupteur
//    silencieux), Android = flux des notifications (muet en silencieux /
//    vibreur). La vibration suit les réglages du téléphone.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/views/map/widgets/pawmap_plush607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_signal.dart';

/// Couleurs des confettis par peluche (2 tons + or + framboise de la marque).
const Map<String, List<Color>> kPawCatchPalette613 = <String, List<Color>>{
  'teddy': [Color(0xFFB7793F), Color(0xFFE8B884)],
  'bunny': [Color(0xFFF06AA0), Color(0xFFFFC2DA)],
  'kitty': [Color(0xFFF59E0B), Color(0xFFFFD48A)],
  'puppy': [Color(0xFFC98A4B), Color(0xFFF2C894)],
  'fox': [Color(0xFFE8590C), Color(0xFFFFA94D)],
};
const Color _kGold = Color(0xFFF4C04A);
const Color _kRaspberry = Color(0xFFDB2777);

List<Color> pawCatchColors613(String type, {bool golden = false}) => <Color>[
      ...(kPawCatchPalette613[type] ?? kPawCatchPalette613['teddy']!),
      _kGold,
      golden ? const Color(0xFFFFE08A) : _kRaspberry,
    ];

/// Nom traduit de la peluche (« Chiot »).
String pawPlushName613(String type) =>
    'plush607_type_${kPawPlushTypes.contains(type) ? type : 'teddy'}'.tr;

/// Titre de la carte : « +40 points » (rien si les points sont inconnus).
String pawCatchTitle613(PawPlushWin w) =>
    w.points > 0 ? 'catch613_points'.trParams({'points': '${w.points}'}) : '';

/// Sous-titre : « Chiot attrapé ! » / « Peluche dorée · Chiot ! » / collection.
String pawCatchSubtitle613(PawPlushWin w) {
  final name = pawPlushName613(w.type);
  if (w.collector) return 'catch613_collector'.trParams({'name': name});
  if (w.golden) return 'catch613_golden'.trParams({'name': name});
  return 'catch613_caught'.trParams({'name': name});
}

/// La capture se fête-t-elle MAINTENANT (app au premier plan) ?
bool pawCatchCanShowNow613(AppLifecycleState? s) =>
    s == null || s == AppLifecycleState.resumed;

/// Stockage disque de la fête en attente (app tuée avant le retour).
const String kPawCatchPendingKey613 = 'catch613_pending';
const Duration kPawCatchPendingMaxAge613 = Duration(hours: 6);

Map<String, dynamic> pawCatchToJson613(PawPlushWin w, DateTime at) => <String, dynamic>{
      'points': w.points,
      'golden': w.golden,
      'collector': w.collector,
      'type': w.type,
      'already': w.already,
      'at': at.toIso8601String(),
    };

/// Relit une fête en attente ; null si absente, illisible ou trop vieille.
PawPlushWin? pawCatchFromJson613(dynamic j, {DateTime? now}) {
  if (j is! Map) return null;
  final at = DateTime.tryParse((j['at'] ?? '').toString());
  if (at == null) return null;
  if ((now ?? DateTime.now()).difference(at) > kPawCatchPendingMaxAge613) return null;
  return PawPlushWin(
    points: (j['points'] as num?)?.toInt() ?? 0,
    golden: j['golden'] == true,
    collector: j['collector'] == true,
    type: (j['type'] ?? 'teddy').toString(),
    already: j['already'] == true,
  );
}

/// Contexte audio : respecte le mode silencieux (voir en-tête).
final AudioContext kPawCatchAudioContext613 = AudioContext(
  iOS: AudioContextIOS(
    category: AVAudioSessionCategory.ambient,
    options: const {AVAudioSessionOptions.mixWithOthers},
  ),
  android: const AudioContextAndroid(
    isSpeakerphoneOn: false,
    stayAwake: false,
    contentType: AndroidContentType.sonification,
    usageType: AndroidUsageType.notificationEvent,
    audioFocus: AndroidAudioFocus.none,
  ),
);

class PawCatchCelebration {
  PawCatchCelebration._();

  static OverlayEntry? _entry;
  static final List<PawPlushWin> _pending = <PawPlushWin>[];
  static _CatchLifecycle613? _observer;
  static AudioPlayer? _player;

  /// Tests : son et disque coupés.
  @visibleForTesting
  static bool silentForTests = false;
  @visibleForTesting
  static int pendingCountForTests() => _pending.length;
  @visibleForTesting
  static int shownCount = 0;

  /// Point d'entrée : fête maintenant si l'app est visible, sinon la garde.
  static void deliver(BuildContext context, PawPlushWin win,
      {AppLifecycleState? lifecycle}) {
    _ensureObserver();
    final state = lifecycle ?? WidgetsBinding.instance.lifecycleState;
    if (!pawCatchCanShowNow613(state)) {
      _pending.add(win);
      _savePending();
      return;
    }
    show(context, win);
  }

  /// Au retour dans l'app : joue les fêtes gardées (la plus récente, avec le
  /// total des points s'il y en a plusieurs).
  static void flushPending(BuildContext? context) {
    if (_pending.isEmpty) _loadPending();
    if (_pending.isEmpty) return;
    final ctx = context ?? Get.overlayContext;
    if (ctx == null) return;
    final last = _pending.last;
    final total = _pending.fold<int>(0, (s, w) => s + w.points);
    _pending.clear();
    _clearStored();
    show(
      ctx,
      PawPlushWin(
        points: total,
        golden: last.golden,
        collector: last.collector,
        type: last.type,
        already: last.already,
      ),
    );
  }

  static void show(BuildContext context, PawPlushWin win) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    hide();
    // Jamais deux messages l'un sur l'autre : les pastilles attendent.
    PawSignal.holdFor(const Duration(milliseconds: 3600));
    shownCount++;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _haptics();
    _sound();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => PawCatchFx613(
        win: win,
        confetti: !reduce,
        onDone: () {
          if (_entry == entry) hide();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  static void hide() {
    final e = _entry;
    _entry = null;
    if (e != null && e.mounted) e.remove();
  }

  static void _haptics() {
    HapticFeedback.heavyImpact();
    Timer(const Duration(milliseconds: 140), HapticFeedback.lightImpact);
    Timer(const Duration(milliseconds: 280), HapticFeedback.lightImpact);
  }

  static Future<void> _sound() async {
    if (silentForTests) return;
    try {
      final p = _player ??= AudioPlayer();
      await p.setAudioContext(kPawCatchAudioContext613);
      await p.setVolume(0.7);
      await p.play(AssetSource('sounds/plush_pop613.m4a'));
    } catch (_) {/* pas de son : la fête reste visible */}
  }

  static void _ensureObserver() {
    if (_observer != null) return;
    _observer = _CatchLifecycle613();
    WidgetsBinding.instance.addObserver(_observer!);
  }

  static void _savePending() {
    if (silentForTests) return;
    try {
      GetStorage().write(kPawCatchPendingKey613,
          jsonEncode([for (final w in _pending) pawCatchToJson613(w, DateTime.now())]));
    } catch (_) {/* mémoire seule */}
  }

  static void _loadPending() {
    if (silentForTests) return;
    try {
      final raw = GetStorage().read(kPawCatchPendingKey613);
      if (raw is! String || raw.isEmpty) return;
      for (final j in (jsonDecode(raw) as List)) {
        final w = pawCatchFromJson613(j);
        if (w != null) _pending.add(w);
      }
      if (_pending.isEmpty) _clearStored();
    } catch (_) {
      _clearStored();
    }
  }

  static void _clearStored() {
    if (silentForTests) return;
    try {
      GetStorage().remove(kPawCatchPendingKey613);
    } catch (_) {}
  }
}

class _CatchLifecycle613 with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Laisser l'écran se redessiner avant la fête.
    Timer(const Duration(milliseconds: 450), () => PawCatchCelebration.flushPending(null));
  }
}

/// Confettis + carte. Ne capte AUCUN toucher.
class PawCatchFx613 extends StatefulWidget {
  const PawCatchFx613({
    super.key,
    required this.win,
    this.confetti = true,
    this.onDone,
    this.cardFor = const Duration(milliseconds: 3200),
  });

  final PawPlushWin win;
  final bool confetti;
  final VoidCallback? onDone;
  final Duration cardFor;

  @override
  State<PawCatchFx613> createState() => _PawCatchFx613State();
}

class _PawCatchFx613State extends State<PawCatchFx613> with TickerProviderStateMixin {
  late final AnimationController _burst =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _card = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 240),
  );
  Timer? _t;
  late final List<_Bit> _bits = _Bit.make(
      pawCatchColors613(widget.win.type, golden: widget.win.golden),
      seed: widget.win.type.hashCode ^ widget.win.points);

  @override
  void initState() {
    super.initState();
    if (widget.confetti) _burst.forward();
    _card.forward();
    _t = Timer(widget.cardFor, () async {
      if (!mounted) return;
      await _card.reverse();
      widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _burst.dispose();
    _card.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 64.h;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final title = pawCatchTitle613(widget.win);
    final sub = pawCatchSubtitle613(widget.win);
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            if (widget.confetti)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _burst,
                  builder: (_, __) => CustomPaint(
                    painter: _ConfettiPainter(_bits, _burst.value,
                        origin: Offset(0.5, (top + 40.h) / MediaQuery.of(context).size.height)),
                  ),
                ),
              ),
            Positioned(
              left: 16.w,
              right: 16.w,
              top: top,
              child: Center(
                child: FadeTransition(
                  opacity: CurvedAnimation(parent: _card, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.8, end: 1).animate(
                        CurvedAnimation(parent: _card, curve: Curves.elasticOut, reverseCurve: Curves.easeIn)),
                    child: Semantics(
                      liveRegion: true,
                      label: [title, sub].where((s) => s.isNotEmpty).join(' · '),
                      child: Container(
                        key: const ValueKey<String>('catch613_card'),
                        constraints: BoxConstraints(maxWidth: 340.w),
                        padding: EdgeInsets.fromLTRB(8.w, 8.h, 18.w, 8.h),
                        decoration: PawSignalStyle.glass(dark).copyWith(
                          border: Border.all(
                              color: widget.win.golden ? _kGold : _kRaspberry.withValues(alpha: 0.55),
                              width: 1.4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 48.w,
                              height: 48.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  Colors.white,
                                  (widget.win.golden ? _kGold : _kRaspberry).withValues(alpha: 0.18),
                                ]),
                              ),
                              padding: EdgeInsets.all(4.w),
                              child: Image.asset(
                                pawPlushAsset(widget.win.type, golden: widget.win.golden),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    Icon(Icons.toys_rounded, color: _kRaspberry, size: 28.w),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (title.isNotEmpty)
                                    Text(title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 20.sp,
                                          height: 1.1,
                                          fontWeight: FontWeight.w900,
                                          color: widget.win.golden ? const Color(0xFFB7791F) : _kRaspberry,
                                          decoration: TextDecoration.none,
                                        )),
                                  Text(sub,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5.sp,
                                        height: 1.25,
                                        fontWeight: FontWeight.w700,
                                        color: dark ? PawSignalStyle.textInkDark : PawSignalStyle.textInk,
                                        decoration: TextDecoration.none,
                                      )),
                                ],
                              ),
                            ),
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
      ),
    );
  }
}

class _Bit {
  _Bit(this.angle, this.speed, this.color, this.size, this.spin, this.round);
  final double angle;
  final double speed;
  final Color color;
  final double size;
  final double spin;
  final bool round;

  static List<_Bit> make(List<Color> colors, {int seed = 7, int n = 64}) {
    final r = math.Random(seed);
    return List<_Bit>.generate(n, (i) {
      // Gerbe vers le haut et les côtés (−200° → 20°), retombe par gravité.
      final a = (-200 + r.nextDouble() * 220) * math.pi / 180;
      return _Bit(a, 260 + r.nextDouble() * 380, colors[i % colors.length],
          4 + r.nextDouble() * 5, (r.nextDouble() - 0.5) * 14, i % 3 == 0);
    });
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t, {required this.origin});
  final List<_Bit> bits;
  final double t; // 0..1 sur 1,5 s
  final Offset origin; // fraction de l'écran

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final o = Offset(origin.dx * size.width, origin.dy * size.height);
    final s = t * 1.5; // secondes
    final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
    final p = Paint();
    for (final b in bits) {
      final x = o.dx + math.cos(b.angle) * b.speed * s * (1 - 0.35 * s);
      final y = o.dy + math.sin(b.angle) * b.speed * s * (1 - 0.35 * s) + 520 * s * s;
      p.color = b.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * s);
      if (b.round) {
        canvas.drawCircle(Offset.zero, b.size / 2, p);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * 0.55),
                const Radius.circular(1.2)),
            p);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
