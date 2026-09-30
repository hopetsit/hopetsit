// v599 (29/09/2026) — point vert « un ami est en balade » sur la patte du
// menu (Daniel : discret, sans texte, le nombre en tout petit si plusieurs).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';

const List<String> _labels = ['Accueil', 'Chat', 'PawMap', 'Réservations', 'Profil'];

Widget _harness(int live, {bool lost = false}) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        home: Scaffold(
          extendBody: true,
          bottomNavigationBar: PawTabBar(
            currentIndex: 0,
            onTap: (_) {},
            role: PawNavRole.owner,
            systemInset: 0,
            labels: _labels,
            liveFriends: live,
            myLiveLost: lost,
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final dot = find.byKey(const ValueKey<String>('paw_tab_live_dot'));

  testWidgets('0 ami en balade : aucun point', (tester) async {
    await tester.pumpWidget(_harness(0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(dot, findsNothing);
  });

  // v604 — Daniel (30/09) : le point vert est remplacé par le CONTOUR de la
  // patte (coussinet + 4 doigts) qui passe du blanc au vert ; rouge quand
  // MON direct ne part plus. Fondu doux (250 ms).
  Color rim(WidgetTester t) => t.widget<PawGlyph>(find.byType(PawGlyph)).rimColor;

  testWidgets('1 ami : plus de point, contour vert (coussinet + doigts)', (tester) async {
    await tester.pumpWidget(_harness(1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(dot, findsNothing);
    expect(rim(tester), PawLiveDot.green);
    // Les 4 doigts ET le coussinet portent la bordure verte.
    final borders = tester
        .widgetList<Container>(find.descendant(
            of: find.byType(PawGlyph), matching: find.byType(Container)))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.border != null)
        .map((d) => (d.border as Border).top.color)
        .toList();
    expect(borders.length, 5);
    expect(borders.every((c) => c == PawLiveDot.green), isTrue);
  });

  testWidgets('transition animée blanc → vert (≈ 250 ms)', (tester) async {
    await tester.pumpWidget(_harness(0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(rim(tester), Colors.white);
    await tester.pumpWidget(_harness(2));
    await tester.pump(const Duration(milliseconds: 100));
    final mid = rim(tester);
    expect(mid, isNot(Colors.white));
    expect(mid, isNot(PawLiveDot.green));
    await tester.pump(const Duration(milliseconds: 300));
    expect(rim(tester), PawLiveDot.green);
  });

  test('couleur du contour : blanc / vert / rouge (mon direct perdu prime)', () {
    expect(pawTabRimColor(liveFriends: 0), Colors.white);
    expect(pawTabRimColor(liveFriends: 3), PawLiveDot.green);
    expect(pawTabRimColor(liveFriends: 0, myLiveLost: true), kPawRimLost);
    expect(pawTabRimColor(liveFriends: 2, myLiveLost: true), kPawRimLost);
  });

  _exportProofs();

  testWidgets('0 ami : contour blanc', (tester) async {
    await tester.pumpWidget(_harness(0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(rim(tester), Colors.white);
  });
}

/// Preuve visuelle pour BOB : le menu (onglet Accueil actif, doigts rentrés)
/// avec 0, 1 et 3 amis en balade, rendu 3× → pawmap_599/preuves/.
void _exportProofs() {
  testWidgets('export PNG du menu : contour blanc / vert / rouge (preuve v604)', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory('${Platform.environment['HOME']}/hopetsit-social/pawmap_604/preuves');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    for (final n in [0, 1, 3, -1]) {
      final key = GlobalKey();
      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, __) => GetMaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFFFFF1EC),
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 393,
                  height: 150,
                  child: Scaffold(
                    backgroundColor: const Color(0xFFFFF1EC),
                    extendBody: true,
                    bottomNavigationBar: PawTabBar(
                      currentIndex: 0,
                      onTap: (_) {},
                      role: PawNavRole.owner,
                      systemInset: 0,
                      labels: _labels,
                      liveFriends: n < 0 ? 0 : n,
                      myLiveLost: n < 0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 700));
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 3);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/menu_contour_${n < 0 ? 'rouge_direct_perdu' : '${n}_ami'}.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  });
}
