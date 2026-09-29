// v599 (29/09/2026) — illustration « La Balade » : se construit dans les
// 9 langues, clair et nuit, et EXPORT des PNG pour LEO (site) :
// ~/hopetsit-social/pawmap_601/balade/balade_ (v601 : badge à droite ; 599 = ancienne)
// balade_{clair,nuit}@{2x,3x}.png (français).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/map/widgets/pawmap_balade_illustration.dart';

Future<void> _loadFonts() async {
  for (final e in {
    'Inter': ['assets/fonts/Inter-Regular.ttf', 'assets/fonts/Inter-Bold.ttf', 'assets/fonts/Inter-ExtraBold.ttf'],
  }.entries) {
    final loader = FontLoader(e.key);
    for (final p in e.value) {
      final f = File(p);
      if (!f.existsSync()) continue;
      final bytes = await f.readAsBytes();
      loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File('${root ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final bytes = await icons.readAsBytes();
    await (FontLoader('MaterialIcons')
          ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer))))
        .load();
  }
}

Widget _app(Locale loc, bool dark, GlobalKey key, {bool full = false}) => GetMaterialApp(
      translations: AppTranslations(),
      locale: loc,
      home: Scaffold(
        backgroundColor: dark ? const Color(0xFF160F0D) : Colors.white,
        body: Center(
          child: SizedBox(
            width: full ? double.infinity : 360,
            child: RepaintBoundary(
              key: key,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: PawMapBaladeIllustration(dark: dark, role: 'walker'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFonts();
  });

  testWidgets('se construit à 320, 360 et 393 dp, clair et nuit, sans débordement',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final width in [320.0, 360.0, 393.0]) {
      tester.view.physicalSize = Size(width, 800);
      for (final dark in [false, true]) {
        await tester.pumpWidget(_app(const Locale('fr'), dark, GlobalKey(), full: true));
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.takeException(), isNull, reason: 'largeur $width dark=$dark');
        final r = tester.getRect(find.byType(PawMapBaladeIllustration));
        expect(r.right, lessThanOrEqualTo(width), reason: 'largeur $width');
        // Aucun mot dans l'image (retour de LEO : même image pour 9 langues).
        expect(find.descendant(of: find.byType(PawMapBaladeIllustration), matching: find.byType(Text)), findsNothing);
      }
    }
  });

  testWidgets('export PNG 2× et 3×, clair et nuit (pour LEO)', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final home = Platform.environment['HOME'] ?? '';
    final dir = Directory('$home/hopetsit-social/pawmap_601/balade');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    for (final dark in [false, true]) {
      final key = GlobalKey();
      await tester.pumpWidget(_app(const Locale('fr'), dark, key));
      await tester.pump(const Duration(milliseconds: 1300)); // point vert au repos
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // Le rendu en image est un vrai travail asynchrone : hors de la
      // boucle simulée du test (sinon il n'aboutit jamais).
      await tester.runAsync(() async {
        for (final scale in [2, 3]) {
          final img = await boundary.toImage(pixelRatio: scale.toDouble());
          final data = await img.toByteData(format: ui.ImageByteFormat.png);
          final f = File('${dir.path}/balade_${dark ? 'nuit' : 'clair'}@${scale}x.png');
          f.writeAsBytesSync(data!.buffer.asUint8List());
          expect(f.lengthSync(), greaterThan(10000), reason: f.path);
        }
      });
    }
  });
}
