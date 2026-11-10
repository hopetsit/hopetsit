// 640 — le gros bouton vert « Balade » de la PawMap (QuickWalkButton3110)
// passe au dessin de la 639, celui du bouton du rail (PawWalkJewel).
//
// Ce que ces tests prouvent :
//   • coupe-circuit à true : même taille, même place, mêmes clés qu'en 633 ;
//   • les 4 états : repos, connexion, en direct, « ailleurs » ;
//   • le toucher fait la même chose qu'avant ;
//   • fluidité : en direct, le bouton n'est plus reconstruit à chaque image
//     (mesure 633 / 640 imprimée) ;
//   • rien ne tourne au repos ni quand les animations sont réduites ;
//   • coupe-circuit à false : le dessin 633 revient ;
//   • aucun gris dans le dessin.
//
// Images de preuve (à la demande) :
//   flutter test test/pam640_quick_walk_jewel_test.dart \
//     --dart-define=QW640_RENDUS=/chemin/du/dossier
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/services/open_on_prefs_3110.dart';
import 'package:hopetsit/views/map/widgets/pawmap_walk_jewel.dart';
import 'package:hopetsit/widgets/quick_walk_button_3110.dart';

import 'lotd_harness.dart';

const String _rendus = String.fromEnvironment('QW640_RENDUS');

const ValueKey<String> _kLeft = ValueKey<String>('quick_walk_3110_left');
const ValueKey<String> _kRight = ValueKey<String>('quick_walk_3110_right');
const ValueKey<String> _kTap = ValueKey<String>('quick_walk_3110_tap');
const ValueKey<String> _kChrono = ValueKey<String>('quick_walk_3110_chrono');
const ValueKey<String> _kSecs = ValueKey<String>('quick_walk_3110_secs');

final DateTime _t0 = DateTime(2026, 11, 10, 14, 0);

Widget _host(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool reduced = false,
}) => lotdApp(
  Scaffold(
    body: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Center(child: child),
      ),
    ),
  ),
  brightness: brightness,
);

/// Le bouton dans un état donné, sans service (tout est injecté).
Widget _button({
  bool live = false,
  bool confirmed = true,
  bool elsewhere = false,
  DateTime? startedAt,
  DateTime? elsewhereSince,
  DateTime Function()? now,
  QuickWalkSide3110 side = QuickWalkSide3110.left,
  Future<void> Function()? onStart,
  Future<void> Function(BuildContext)? onStop,
  Future<void> Function()? onTapOverride,
}) => QuickWalkButton3110(
  visible: true.obs,
  side: side.obs,
  broadcasting: live.obs,
  confirmed: confirmed.obs,
  elsewhere: elsewhere.obs,
  startedAt: Rxn<DateTime>(startedAt),
  elsewhereSince: Rxn<DateTime>(elsewhereSince),
  now: now ?? () => _t0,
  onStart: onStart,
  onStop: onStop,
  onTapOverride: onTapOverride,
);

PawWalkJewelPainter _painter(WidgetTester t) => t
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((CustomPaint c) => c.painter)
    .whereType<PawWalkJewelPainter>()
    .single;

String _text(WidgetTester t, Key key) => t.widget<Text>(find.byKey(key)).data!;

String _label(WidgetTester t, Key key) =>
    t.widget<Semantics>(find.byKey(key)).properties.label!;

/// Reconstructions pendant 60 images (1 s d'écran à 60 images/s).
Future<({int button, int all})> _rebuilds(WidgetTester t) async {
  int all = 0, button = 0;
  debugOnRebuildDirtyWidget = (Element e, bool builtOnce) {
    all++;
    if (e.widget is QuickWalkButton3110) button++;
  };
  for (int i = 0; i < 60; i++) {
    await t.pump(const Duration(microseconds: 16667));
  }
  debugOnRebuildDirtyWidget = null;
  return (button: button, all: all);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Les vraies polices du bouton (sinon le texte sort en carrés).
    const Map<String, String> fonts = <String, String>{
      'Nunito_900': 'Nunito-Black.ttf',
      'Nunito_800': 'Nunito-ExtraBold.ttf',
    };
    for (final MapEntry<String, String> f in fonts.entries) {
      final Uint8List bytes = File('assets/fonts/${f.value}').readAsBytesSync();
      final FontLoader loader = FontLoader(f.key)
        ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
  });

  setUp(() async {
    await lotdSetUp(role: 'owner');
    OpenOnPrefs3110.resetForTest();
    QuickWalkButton3110.debugJewel640 = null;
  });

  tearDown(() {
    QuickWalkButton3110.debugJewel640 = null;
    debugOnRebuildDirtyWidget = null;
  });

  test('le coupe-circuit est allumé', () {
    expect(kQuickWalkJewel640, isTrue);
  });

  group('640 — même taille, même place, mêmes clés', () {
    testWidgets('rond touchable et cadre : identiques au dessin 633', (
      t,
    ) async {
      lotdPhone(t);
      // Dessin 633.
      QuickWalkButton3110.debugJewel640 = false;
      await t.pumpWidget(_host(_button()));
      await t.pump();
      final Rect tap633 = t.getRect(find.byKey(_kTap));
      final Rect frame633 = t.getRect(find.byType(QuickWalkButton3110));
      await t.pumpWidget(const SizedBox.shrink());

      // Dessin 640.
      QuickWalkButton3110.debugJewel640 = null;
      await t.pumpWidget(_host(_button()));
      await t.pump();
      final Rect tap640 = t.getRect(find.byKey(_kTap));
      final Rect frame640 = t.getRect(find.byType(QuickWalkButton3110));

      expect(tap640.width, closeTo(kQuickWalkSize3110, 0.001));
      expect(tap640.height, closeTo(kQuickWalkSize3110, 0.001));
      expect(frame640.width, closeTo(kQuickWalkCanvas0311, 0.001));
      expect(frame640.height, closeTo(kQuickWalkCanvas0311, 0.001));
      expect(tap640, tap633);
      expect(frame640, frame633);
      expect(find.byKey(_kLeft), findsOneWidget);
      expect(find.byKey(_kChrono), findsOneWidget);
    });

    testWidgets('positioned : même place à gauche et à droite', (t) async {
      lotdPhone(t);
      Future<Rect> place(QuickWalkSide3110 side, {required bool jewel}) async {
        QuickWalkButton3110.debugJewel640 = jewel;
        await t.pumpWidget(
          lotdApp(
            Scaffold(
              body: Builder(
                builder: (BuildContext ctx) => Stack(
                  children: [
                    QuickWalkButton3110.positioned(
                      ctx,
                      side: side,
                      bottomOverride: 120,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await t.pump();
        final Rect r = t.getRect(find.byKey(_kTap));
        expect(
          find.byKey(side == QuickWalkSide3110.left ? _kLeft : _kRight),
          findsOneWidget,
        );
        await t.pumpWidget(const SizedBox.shrink());
        return r;
      }

      for (final QuickWalkSide3110 side in const <QuickWalkSide3110>[
        QuickWalkSide3110.left,
        QuickWalkSide3110.right,
      ]) {
        final Rect avant = await place(side, jewel: false);
        final Rect apres = await place(side, jewel: true);
        expect(apres, avant, reason: 'côté ${side.code}');
        expect(apres.width, closeTo(kQuickWalkSize3110, 0.001));
        // Bord du rond à 16 du bord de l'écran, bas du rond à 120 du bas.
        final double gap = side == QuickWalkSide3110.left
            ? apres.left
            : 393 - apres.right;
        expect(gap, closeTo(kQuickWalkSideMargin3110, 0.001));
        expect(852 - apres.bottom, closeTo(120, 0.001));
      }
    });

    testWidgets('décorations : hors toucher, dans le halo de la 633', (
      t,
    ) async {
      lotdPhone(t);
      await t.pumpWidget(
        _host(
          _button(
            live: true,
            startedAt: _t0.subtract(const Duration(minutes: 3)),
          ),
        ),
      );
      await t.pump();
      final PawWalkJewelPainter p = _painter(t);
      // La face du disque = le rond touchable.
      expect(
        p.diameter * (1 - 0.055),
        closeTo(kQuickWalkSize3110, 0.001),
      );
      // Feuilles et pattes restent dans le halo réservé par la carte.
      const double reach = kQuickWalkSize3110 / 2 + kQuickWalkHalo0311;
      final double relief = p.diameter * 0.055;
      final double k = p.diameter / 144; // 1 px de la maquette
      // Pattes (16 px maquette) : orbite + demi-patte + demi-relief.
      final double pawReach =
          p.diameter * p.pawRadiusRatio + 8 * k + relief / 2;
      expect(pawReach, lessThan(reach));
      // … et jamais hors de l'écran (rond à 16 dp du bord).
      expect(
        pawReach - relief / 2,
        lessThan(kQuickWalkSize3110 / 2 + kQuickWalkSideMargin3110),
      );
      // Feuilles (26 px maquette au plus, posées en diagonale) : centre +
      // demi-diagonale + flottement (6 px) + demi-relief.
      for (final double r in p.leafRadiusRatios) {
        expect(
          p.diameter * r * 0.7072 + 0.53 * 26 * k + 6 * k + relief / 2,
          lessThan(reach),
        );
      }
      for (final double a in p.leafAngles) {
        expect(a % 90, 45, reason: 'feuilles aux 4 diagonales');
      }
      // Le dessin ne prend aucun toucher : un tap au bord du cadre, hors du
      // rond, ne déclenche rien.
      final Rect frame = t.getRect(find.byType(QuickWalkButton3110));
      final RenderBox tap = t.renderObject<RenderBox>(find.byKey(_kTap));
      final BoxHitTestResult hit = BoxHitTestResult();
      t.binding.hitTestInView(hit, frame.topLeft + const Offset(4, 4), t.view.viewId);
      expect(hit.path.any((HitTestEntry e) => e.target == tap), isFalse);
      // Plus d'anneau en pointillés.
      expect(
        t
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .where(
              (CustomPaint c) =>
                  '${c.painter.runtimeType}'.contains('DashedRing'),
            ),
        isEmpty,
      );
    });
  });

  group('640 — les 4 états', () {
    testWidgets('repos : « — », pas de secondes, disque hors ligne', (t) async {
      lotdPhone(t);
      await t.pumpWidget(_host(_button()));
      await t.pump();
      expect(_text(t, _kChrono), '—');
      expect(find.byKey(_kSecs), findsNothing);
      expect(find.text('pamc3110_qw_min'.tr), findsNothing);
      final PawWalkJewelPainter p = _painter(t);
      expect(p.live, isFalse);
      expect(p.moving, isFalse);
      expect(p.dog, isTrue);
      expect(
        _label(t, _kLeft),
        '${'pamc3110_qw_offline'.tr} · ${'pm605_live_start'.tr}',
      );
      expect(find.byTooltip('pm605_live_start'.tr), findsOneWidget);
    });

    testWidgets('connexion : « Connexion… », chrono « — », disque allumé', (
      t,
    ) async {
      lotdPhone(t);
      await t.pumpWidget(
        _host(
          _button(
            live: true,
            confirmed: false,
            startedAt: _t0.subtract(const Duration(seconds: 40)),
          ),
        ),
      );
      await t.pump();
      expect(_text(t, _kChrono), '—');
      expect(find.byKey(_kSecs), findsNothing);
      expect(_label(t, _kLeft), startsWith('live607_connecting'.tr));
      expect(_painter(t).live, isTrue);
    });

    testWidgets('en direct : minutes + secondes, qui avancent', (t) async {
      lotdPhone(t);
      DateTime now = _t0;
      await t.pumpWidget(
        _host(
          _button(
            live: true,
            startedAt: _t0.subtract(const Duration(minutes: 12, seconds: 7)),
            now: () => now,
          ),
        ),
      );
      await t.pump();
      expect(_text(t, _kChrono), '12');
      expect(_text(t, _kSecs), '07 ${'pamc3110_qw_sec'.tr}');
      expect(find.text('pamc3110_qw_min'.tr), findsOneWidget);
      expect(
        _label(t, _kLeft),
        '${'pamc3110_qw_live'.tr} · ${'pamc3110_qw_stop_hint'.tr}',
      );
      final PawWalkJewelPainter p = _painter(t);
      expect(p.live, isTrue);
      expect(p.moving, isTrue);

      // Le chrono suit l'horloge, seconde par seconde.
      now = now.add(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(_text(t, _kSecs), startsWith('08'));
      now = now.add(const Duration(seconds: 53));
      await t.pump(const Duration(seconds: 1));
      expect(_text(t, _kChrono), '13');
      expect(_text(t, _kSecs), startsWith('01'));
    });

    testWidgets('« ailleurs » : en direct, chrono de l\'autre téléphone', (
      t,
    ) async {
      lotdPhone(t);
      int taps = 0;
      await t.pumpWidget(
        _host(
          _button(
            elsewhere: true,
            elsewhereSince: _t0.subtract(const Duration(minutes: 4, seconds: 9)),
            onTapOverride: () async => taps++,
          ),
        ),
      );
      await t.pump();
      expect(_text(t, _kChrono), '4');
      expect(_text(t, _kSecs), startsWith('09'));
      expect(_label(t, _kLeft), startsWith('pamc3110_qw_live'.tr));
      expect(_painter(t).live, isTrue);
      await t.tap(find.byKey(_kTap));
      await t.pump(const Duration(milliseconds: 300));
      expect(taps, 1);
    });

    testWidgets('masqué : rien à l\'écran', (t) async {
      lotdPhone(t);
      await t.pumpWidget(
        _host(
          QuickWalkButton3110(
            visible: false.obs,
            broadcasting: true.obs,
            elsewhere: false.obs,
          ),
        ),
      );
      await t.pump();
      expect(find.byKey(_kTap), findsNothing);
      expect(t.binding.transientCallbackCount, 0);
    });
  });

  group('640 — le toucher fait la même chose', () {
    testWidgets('repos → onStart ; en direct → onStop', (t) async {
      lotdPhone(t);
      int starts = 0, stops = 0;
      await t.pumpWidget(
        _host(
          _button(
            onStart: () async => starts++,
            onStop: (_) async => stops++,
          ),
        ),
      );
      await t.pump();
      await t.tap(find.byKey(_kTap));
      await t.pump(const Duration(milliseconds: 400));
      expect((starts, stops), (1, 0));
      await t.pumpWidget(const SizedBox.shrink());

      await t.pumpWidget(
        _host(
          _button(
            live: true,
            startedAt: _t0,
            onStart: () async => starts++,
            onStop: (_) async => stops++,
          ),
        ),
      );
      await t.pump();
      await t.tap(find.byKey(_kTap));
      await t.pump(const Duration(milliseconds: 400));
      expect((starts, stops), (1, 1));
    });

    testWidgets('pendant l\'action : indicateur, 2e toucher ignoré', (t) async {
      lotdPhone(t);
      int starts = 0;
      final Completer<void> gate = Completer<void>();
      await t.pumpWidget(
        _host(
          _button(
            onStart: () {
              starts++;
              return gate.future;
            },
          ),
        ),
      );
      await t.pump();
      await t.tap(find.byKey(_kTap));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_painter(t).dog, isFalse);
      await t.tap(find.byKey(_kTap));
      await t.pump(const Duration(milliseconds: 50));
      expect(starts, 1);
      gate.complete();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_painter(t).dog, isTrue);
    });

    testWidgets('appui : le dessin descend, le rond touchable ne bouge pas', (
      t,
    ) async {
      lotdPhone(t);
      await t.pumpWidget(_host(_button(onStart: () async {})));
      await t.pump();
      final Rect before = t.getRect(find.byKey(_kTap));
      final TestGesture g = await t.startGesture(before.center);
      await t.pump(const Duration(milliseconds: 150)); // délai d'appui
      await t.pump(const Duration(milliseconds: 16));
      await t.pump(const Duration(milliseconds: 200));
      expect(_painter(t).press.value, 1.0);
      expect(t.getRect(find.byKey(_kTap)), before);
      await g.up();
      await t.pump(const Duration(milliseconds: 16));
      await t.pump(const Duration(milliseconds: 400));
      expect(_painter(t).press.value, 0.0);
    });
  });

  group('640 — fluidité', () {
    testWidgets('mesure : reconstructions par seconde, 633 puis 640', (
      t,
    ) async {
      lotdPhone(t);
      Future<({int button, int all})> run({required bool jewel}) async {
        QuickWalkButton3110.debugJewel640 = jewel;
        await t.pumpWidget(
          _host(
            _button(
              live: true,
              startedAt: _t0.subtract(const Duration(minutes: 12, seconds: 7)),
            ),
          ),
        );
        await t.pump(const Duration(milliseconds: 500));
        final ({int button, int all}) r = await _rebuilds(t);
        await t.pumpWidget(const SizedBox.shrink());
        return r;
      }

      final ({int button, int all}) avant = await run(jewel: false);
      final ({int button, int all}) apres = await run(jewel: true);
      // ignore: avoid_print
      print(
        '[QW640] MESURE en direct, 60 images (1 s) — '
        'dessin 633 : bouton=${avant.button}, tous widgets=${avant.all} ; '
        'dessin 640 : bouton=${apres.button}, tous widgets=${apres.all}',
      );
      // 640 : le bouton n'est jamais reconstruit par l'animation ; seuls les
      // deux textes du chrono le sont, une fois par seconde.
      expect(apres.button, 0);
      expect(apres.all, lessThanOrEqualTo(4));
      expect(avant.button, greaterThanOrEqualTo(55));
    });

    testWidgets('au repos : aucune animation ne tourne', (t) async {
      lotdPhone(t);
      await t.pumpWidget(_host(_button()));
      await t.pump(const Duration(milliseconds: 500));
      expect(t.binding.transientCallbackCount, 0);
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('en direct : une horloge tourne, sans reconstruire', (t) async {
      lotdPhone(t);
      await t.pumpWidget(_host(_button(live: true, startedAt: _t0)));
      await t.pump(const Duration(milliseconds: 500));
      expect(t.binding.transientCallbackCount, greaterThan(0));
      final double a = _painter(t).life.value;
      await t.pump(const Duration(milliseconds: 500));
      expect(_painter(t).life.value, greaterThan(a));
    });

    testWidgets('animations réduites : en direct, rien ne tourne', (t) async {
      lotdPhone(t);
      await t.pumpWidget(
        _host(_button(live: true, startedAt: _t0), reduced: true),
      );
      await t.pump(const Duration(milliseconds: 500));
      expect(t.binding.transientCallbackCount, 0);
      final PawWalkJewelPainter p = _painter(t);
      expect(p.live, isTrue);
      expect(p.moving, isFalse);
      expect(_text(t, _kChrono), '0');
    });
  });

  group('640 — coupe-circuit', () {
    testWidgets('false : retour au dessin 633 (anneau, pas de joyau)', (
      t,
    ) async {
      lotdPhone(t);
      QuickWalkButton3110.debugJewel640 = false;
      await t.pumpWidget(
        _host(
          _button(
            live: true,
            startedAt: _t0.subtract(const Duration(minutes: 2)),
          ),
        ),
      );
      await t.pump();
      final List<String> painters = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((CustomPaint c) => '${c.painter.runtimeType}')
          .toList();
      expect(painters.any((String s) => s.contains('PawWalkJewel')), isFalse);
      expect(painters.any((String s) => s.contains('DashedRing')), isTrue);
      expect(_text(t, _kChrono), '2');
      expect(find.byKey(_kLeft), findsOneWidget);
    });
  });

  test('zéro gris : toutes les couleurs du dessin 640 sont saturées', () {
    final String src = File(
      'lib/widgets/quick_walk_button_3110.dart',
    ).readAsStringSync();
    final int a = src.indexOf('// 640 — le même bouton');
    final int b = src.indexOf('// 633 — rendu du design');
    expect(a, greaterThan(0));
    expect(b, greaterThan(a));
    final Iterable<RegExpMatch> colors = RegExp(
      r'Color\(0x([0-9A-Fa-f]{8})\)',
    ).allMatches(src.substring(a, b));
    expect(colors, isNotEmpty);
    for (final RegExpMatch m in colors) {
      final Color c = Color(int.parse(m.group(1)!, radix: 16));
      final HSLColor hsl = HSLColor.fromColor(c);
      final bool warm = hsl.hue >= 340 || hsl.hue <= 45;
      expect(
        hsl.saturation >= 0.25 || warm,
        isTrue,
        reason: 'gris : #${m.group(1)} (saturation ${hsl.saturation})',
      );
    }
  });

  // ── Images de preuve ────────────────────────────────────────────────────
  group('rendus', () {
    Future<void> shot(
      WidgetTester t,
      String name, {
      required Brightness brightness,
      required Widget button,
      Duration settle = const Duration(milliseconds: 1500),
      bool outline = false,
    }) async {
      lotdPhone(t);
      final GlobalKey key = GlobalKey();
      // Fonds proches de la carte : clair (OpenStreetMap) et sombre.
      final Color bg = brightness == Brightness.light
          ? const Color(0xFFF2EFE9)
          : const Color(0xFF14233A);
      await t.pumpWidget(
        _host(
          RepaintBoundary(
            key: key,
            child: Container(
              width: 150,
              height: 150,
              color: bg,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  button,
                  if (outline)
                    IgnorePointer(
                      child: Container(
                        width: kQuickWalkSize3110,
                        height: kQuickWalkSize3110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF2D55),
                            width: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          brightness: brightness,
        ),
      );
      await t.pump(settle);
      final RenderRepaintBoundary boundary = t
          .renderObject<RenderRepaintBoundary>(find.byKey(key));
      await t.runAsync(() async {
        final ui.Image image = await boundary.toImage(pixelRatio: 6);
        final ByteData? data = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        Directory(_rendus).createSync(recursive: true);
        File('$_rendus/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
      await t.pumpWidget(const SizedBox.shrink());
    }

    Widget live() => _button(
      live: true,
      startedAt: _t0.subtract(const Duration(minutes: 12, seconds: 7)),
    );

    for (final Brightness b in Brightness.values) {
      final String mode = b == Brightness.light ? 'clair' : 'sombre';
      testWidgets('repos $mode', (t) async {
        await shot(t, 'qw640_repos_$mode', brightness: b, button: _button());
      });
      testWidgets('en direct $mode', (t) async {
        await shot(t, 'qw640_en_direct_$mode', brightness: b, button: live());
      });
    }
    testWidgets('connexion', (t) async {
      await shot(
        t,
        'qw640_connexion_clair',
        brightness: Brightness.light,
        button: _button(live: true, confirmed: false, startedAt: _t0),
      );
    });
    testWidgets('ailleurs', (t) async {
      await shot(
        t,
        'qw640_ailleurs_clair',
        brightness: Brightness.light,
        button: _button(
          elsewhere: true,
          elsewhereSince: _t0.subtract(const Duration(minutes: 104, seconds: 59)),
        ),
      );
    });
    testWidgets('zone tactile (trait rouge) sur le dessin', (t) async {
      await shot(
        t,
        'qw640_zone_tactile_en_direct',
        brightness: Brightness.light,
        button: live(),
        outline: true,
      );
    });
    testWidgets('dessin 633 (avant), pour comparer', (t) async {
      QuickWalkButton3110.debugJewel640 = false;
      await shot(
        t,
        'avant_633_repos_clair',
        brightness: Brightness.light,
        button: _button(),
      );
      await shot(
        t,
        'avant_633_en_direct_clair',
        brightness: Brightness.light,
        button: live(),
      );
    });
  }, skip: _rendus.isEmpty ? 'rendus à la demande (QW640_RENDUS)' : false);
}
