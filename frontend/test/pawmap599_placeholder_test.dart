// v599 (29/09/2026) — fond de remplacement SOUS la carte (Oppo A40 : 5 s de
// zone vide) et APK de test A/B « composition hybride ».
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/map/widgets/pawmap_placeholder.dart';

void main() {
  testWidgets('le fond affiche « Carte en préparation… », clair et nuit', (tester) async {
    for (final night in [false, true]) {
      await tester.pumpWidget(GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        home: PawMapPlaceholder(night: night),
      ));
      await tester.pump();
      expect(find.text('Carte en préparation…'), findsOneWidget, reason: 'nuit=$night');
      expect(tester.takeException(), isNull);
    }
  });

  test('le fond est posé SOUS la carte (avant elle dans la pile), jamais par-dessus', () {
    final s = File('lib/views/map/paw_map_screen.dart').readAsStringSync();
    final ph = s.indexOf("ValueKey<String>('pawmap_placeholder')");
    final map = s.indexOf("ValueKey<String>('pawmap_google_map')");
    expect(ph, greaterThan(0));
    expect(map, greaterThan(ph));
  });

  test('HPS_MAP_SURFACE=1 → composition hybride (jamais par défaut)', () {
    final s = File('lib/main.dart').readAsStringSync();
    expect(s, contains("String.fromEnvironment('HPS_MAP_SURFACE', defaultValue: '0') == '1'"));
    expect(s, contains('if (kHpsMapSurface) impl.useAndroidViewSurface = true;'));
  });
}
