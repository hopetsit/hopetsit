// 614 (PAM, 07/10/2026) — PROCHAIN_BUILD_614 §1 : la carte de fête
// « +20 points · Ourson attrapé ! » se posait SUR la pilule « En balade ·
// 1,6 km · 1/2 attrapée » (capture Android 613, 17_planche_fete.png).
//
// On reconstruit le haut de la PawMap avec les VRAIES pilules
// (PawMapDirectPill + PawNearestPlushPill), on mesure son bas comme la carte
// (`localToGlobal`), on déclenche la vraie fête et on compare les rectangles.
// Le test échoue si la carte de fête touche la pilule, l'en-tête ou un rail.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/map/widgets/pawmap_catch613.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_plush607.dart';

const _headerKey = ValueKey<String>('header');
const _directKey = ValueKey<String>('direct_pill');
const _plushKey = ValueKey<String>('plush_pill');

Future<BuildContext> _map(WidgetTester t, {required bool walking, double statusBar = 24}) async {
  late BuildContext ctx;
  final topKey = GlobalKey();
  await t.pumpWidget(ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(padding: EdgeInsets.only(top: statusBar)),
        child: child!,
      ),
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        // Même branchement que la PawMap (_catchFreeZone614).
        PawCatchCelebration.freeZone614 = () {
          final box = topKey.currentContext?.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize) return null;
          return pawCatchZoneFromTop614(
              box.localToGlobal(Offset(0, box.size.height)).dy, MediaQuery.sizeOf(c).width);
        };
        return Stack(children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFFF3E9DC))),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              minimum: const EdgeInsets.only(top: 28),
              child: Column(
                key: topKey,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // en-tête PawMap (logo + 4 boutons ronds) : 56 dp
                  SizedBox(key: _headerKey, height: 56.h, width: double.infinity),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        PawMapDirectPill(
                          key: _directKey,
                          live: walking,
                          startedAt: walking
                              ? DateTime.now().subtract(const Duration(minutes: 2))
                              : null,
                          onTap: () {},
                        ),
                        if (walking)
                          // comme la PawMap 614 : la pilule se réduit au lieu de déborder
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(left: 6.w),
                                child: PawNearestPlushPill(
                                  key: _plushKey,
                                  type: 'bear',
                                  golden: false,
                                  label: '1,6 km',
                                  progress: '1/2',
                                  arrowDeg: 30,
                                  onTap: () {},
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]);
      })),
    ),
  ));
  await t.pump();
  return ctx;
}

Rect _r(WidgetTester t, Key k) => t.getRect(find.byKey(k));

Future<void> _check(WidgetTester t, Size screen, {required bool walking, double statusBar = 24}) async {
  t.view.physicalSize = screen;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final ctx = await _map(t, walking: walking, statusBar: statusBar);
  PawCatchCelebration.deliver(ctx, const PawPlushWin(points: 20, type: 'bear'),
      lifecycle: AppLifecycleState.resumed);
  await t.pump(const Duration(milliseconds: 600)); // carte entièrement entrée
  final card = _r(t, const ValueKey<String>('catch613_card'));
  final infos = <String, Rect>{
    'en-tête': _r(t, _headerKey),
    'pilule Direct/En balade': _r(t, _directKey),
    if (walking) 'pilule peluche 1,6 km · 1/2': _r(t, _plushKey),
  };
  for (final e in infos.entries) {
    expect(card.overlaps(e.value), isFalse,
        reason: '${screen.width.toInt()} px, balade=$walking : la fête $card couvre ${e.key} ${e.value}');
    expect(card.top, greaterThanOrEqualTo(e.value.bottom),
        reason: 'la fête doit être SOUS ${e.key}');
  }
  // entre les rails (gauche 72 dp, droite 62 dp à l'échelle de l'écran)
  for (final e in infos.entries) {
    expect(e.value.right, lessThanOrEqualTo(screen.width + 0.5), reason: '${e.key} sort de l’écran');
  }
  expect(card.left, greaterThanOrEqualTo(72.w - 0.5), reason: 'rail gauche');
  expect(card.right, lessThanOrEqualTo(screen.width - 62.w + 0.5), reason: 'rail droit');
  expect(find.text('+20 points'), findsOneWidget);
  expect(find.text('Ourson attrapé !'), findsOneWidget);
  await t.pump(const Duration(seconds: 4));
  PawCatchCelebration.freeZone614 = null;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    PawCatchCelebration.silentForTests = true;
  });
  tearDown(() => PawCatchCelebration.freeZone614 = null);

  for (final s in const [Size(375, 812), Size(375, 667), Size(360, 780), Size(412, 915), Size(768, 1024)]) {
    for (final walking in const [true, false]) {
      testWidgets('${s.width.toInt()}×${s.height.toInt()}, ${walking ? 'EN balade' : 'sans balade'} : '
          'la fête ne touche ni la pilule ni l’en-tête ni les rails', (t) async {
        await _check(t, s, walking: walking);
      });
    }
  }

  testWidgets('iPhone à encoche (barre d’état 47) : toujours sous la pilule', (t) async {
    await _check(t, const Size(375, 812), walking: true, statusBar: 47);
  });

  testWidgets('témoin : SANS la zone (comportement 613) la fête couvre bien la pilule '
      '— le test sait voir le bug', (t) async {
    t.view.physicalSize = const Size(375, 812);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final ctx = await _map(t, walking: true);
    PawCatchCelebration.freeZone614 = null; // la PawMap ne déclare rien
    PawCatchCelebration.deliver(ctx, const PawPlushWin(points: 20, type: 'bear'),
        lifecycle: AppLifecycleState.resumed);
    await t.pump(const Duration(milliseconds: 600));
    final card = _r(t, const ValueKey<String>('catch613_card'));
    expect(card.overlaps(_r(t, _directKey)) || card.overlaps(_r(t, _plushKey)), isTrue);
    await t.pump(const Duration(seconds: 4));
  });

  test('hors PawMap (zone absente) : position d’origine inchangée', () {
    final b = pawCatchCardBox614(screen: const Size(375, 812), padTop: 20);
    expect(b.top, 20 + 64.h);
    expect(pawCatchZoneFromTop614(0, 375), isNull);
  });
}
