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

Widget _harness(int live) => ScreenUtilInit(
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

  testWidgets('1 ami : le point, sans chiffre, en haut à droite de la patte', (tester) async {
    await tester.pumpWidget(_harness(1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(dot, findsOneWidget);
    expect(find.descendant(of: dot, matching: find.byType(Text)), findsNothing);
    final paw = tester.getRect(find.byKey(const ValueKey<String>('paw_tab_2')));
    final d = tester.getCenter(dot);
    // Sur la tête de l'épingle (coussinet 48 dp, centre à 24 dp du bas de la
    // zone tactile de 67 dp) : à droite du centre, au-dessus du centre.
    expect(d.dx, greaterThan(paw.center.dx + 10), reason: 'à droite du centre de la patte');
    expect(d.dx, lessThan(paw.right), reason: 'dans la boîte de la patte');
    expect(d.dy, lessThan(paw.bottom - 24), reason: 'au-dessus du centre de la tête');
    expect(d.dy, greaterThan(paw.top), reason: 'sur la tête, pas au-dessus des doigts rentrés');
  });

  _exportProofs();

  testWidgets('3 amis : le chiffre en tout petit', (tester) async {
    await tester.pumpWidget(_harness(3));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.descendant(of: dot, matching: find.text('3')), findsOneWidget);
  });
}

/// Preuve visuelle pour BOB : le menu (onglet Accueil actif, doigts rentrés)
/// avec 0, 1 et 3 amis en balade, rendu 3× → pawmap_599/preuves/.
void _exportProofs() {
  testWidgets('export PNG du menu avec et sans point vert (preuve)', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory('${Platform.environment['HOME']}/hopetsit-social/pawmap_599/preuves');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    for (final n in [0, 1, 3]) {
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
                      liveFriends: n,
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
        File('${dir.path}/menu_point_vert_$n.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  });
}
