// 640 (PAM) — outils communs des tests de l'accueil 640 :
//   · chargement de la police d'icônes Material (absente par défaut en test :
//     les `Icons.*` sortiraient en carrés sur les images de preuve) ;
//   · capture d'un `RepaintBoundary` en PNG. Les images ne sont écrites QUE si
//     la variable d'environnement `HOME640_SHOTS` désigne un dossier : un
//     `flutter test` ordinaire n'écrit rien sur le disque.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/app_translations.dart';

/// Dossier des images de preuve (vide = aucune écriture).
String get home640ShotsDir => Platform.environment['HOME640_SHOTS'] ?? '';

Future<void> home640LoadIconFont() async {
  final String root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final File icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!icons.existsSync()) return;
  final Uint8List bytes = await icons.readAsBytes();
  await (FontLoader('MaterialIcons')
        ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer))))
      .load();
  // Police par défaut du thème en test (plate-forme Android = Roboto) : sans
  // elle, tout `Text` sans famille explicite (ruban « BOOST ACTIF ») sort en
  // carrés sur les images de preuve.
  final FontLoader roboto = FontLoader('Roboto');
  bool any = false;
  for (final String face in <String>['Regular', 'Medium', 'Bold', 'Black']) {
    final File f = File(
      '$root/bin/cache/artifacts/material_fonts/Roboto-$face.ttf',
    );
    if (!f.existsSync()) continue;
    final Uint8List b = f.readAsBytesSync();
    roboto.addFont(Future<ByteData>.value(ByteData.view(b.buffer)));
    any = true;
  }
  if (any) await roboto.load();
}

/// Même montage que `lotdApp` (traductions, langue, thème), avec une hauteur
/// de conception réglable : une fenêtre de test HAUTE (tout l'accueil sur une
/// seule image) garde ainsi l'échelle ScreenUtil d'un vrai téléphone au lieu
/// d'étirer toutes les hauteurs `.h`.
///   · `designHeight == hauteur de la fenêtre`  → échelle verticale 1 ;
///   · fenêtre de 320 dp : `designHeight = hauteur × 852 / 568` → échelles
///     d'un iPhone SE (320 × 568).
Widget home640App(
  Widget home, {
  required double designHeight,
  Locale locale = const Locale('fr', 'FR'),
}) {
  Get.addTranslations(AppTranslations().keys);
  Get.locale = locale;
  Get.fallbackLocale = const Locale('en', 'US');
  return ScreenUtilInit(
    designSize: Size(393, designHeight),
    builder: (_, __) => GetMaterialApp(
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: locale,
      fallbackLocale: const Locale('en', 'US'),
      theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
      home: home,
    ),
  );
}

/// Enveloppe à capturer.
Widget home640Boundary(GlobalKey key, Widget child) =>
    RepaintBoundary(key: key, child: child);

/// Décode les images locales (assets) avant une capture.
Future<void> home640Precache(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final Element el in find.byType(Image).evaluate()) {
      final ImageProvider p = (el.widget as Image).image;
      if (p is AssetImage || p is FileImage || p is MemoryImage) {
        await precacheImage(p, el);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump(const Duration(milliseconds: 50));
}

/// Écrit `<HOME640_SHOTS>/<name>.png` (rien si la variable est absente).
Future<void> home640Shot(
  WidgetTester tester,
  GlobalKey key,
  String name, {
  double pixelRatio = 2.0,
  Rect? crop,
}) async {
  final String dir = home640ShotsDir;
  if (dir.isEmpty) return;
  final RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // En test, Flutter remplace les ombres par des aplats (`debugDisableShadows`)
  // : on les rétablit le temps de la capture, puis on remet l'état d'origine
  // (le cadre de test vérifie qu'il n'a pas changé en fin de test).
  void repaintAll(RenderObject o) {
    o.markNeedsPaint();
    o.visitChildren(repaintAll);
  }

  debugDisableShadows = false;
  repaintAll(boundary);
  await tester.pump();
  try {
    await _home640Capture(tester, boundary, dir, name, pixelRatio, crop);
  } finally {
    debugDisableShadows = true;
    repaintAll(boundary);
    await tester.pump();
  }
}

Future<void> _home640Capture(
  WidgetTester tester,
  RenderRepaintBoundary boundary,
  String dir,
  String name,
  double pixelRatio,
  Rect? crop,
) async {
  await tester.runAsync(() async {
    ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    if (crop != null) {
      // Recadrage (coordonnées logiques de la zone capturée).
      final Rect src = Rect.fromLTRB(
        (crop.left * pixelRatio).clamp(0, image.width.toDouble()),
        (crop.top * pixelRatio).clamp(0, image.height.toDouble()),
        (crop.right * pixelRatio).clamp(0, image.width.toDouble()),
        (crop.bottom * pixelRatio).clamp(0, image.height.toDouble()),
      );
      final ui.PictureRecorder rec = ui.PictureRecorder();
      Canvas(rec).drawImageRect(image, src, Offset.zero & src.size, Paint());
      image = await rec.endRecording().toImage(
        src.width.round(),
        src.height.round(),
      );
    }
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Directory d = Directory(dir);
    if (!d.existsSync()) d.createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}
