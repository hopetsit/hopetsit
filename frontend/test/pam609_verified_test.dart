// 609 (PAM, 02/10/2026) — badge « Identité vérifiée » sur la PawMap
// (Daniel : « que ça leur donne un plus »).
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart'
    show pawIdentityVerified, pawVerifiedFilterKeeps, pawVerifiedFirstAtSamePrice;
import 'package:hopetsit/views/map/widgets/pawmap_focus_card.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('1. vérifié = identityVerified (≥ 609) ou kycVerified ; jamais un e-mail', () {
    expect(pawIdentityVerified({'identityVerified': true}), isTrue);
    expect(pawIdentityVerified({'kycVerified': true}), isTrue);
    expect(pawIdentityVerified({'verified': true, 'emailVerified': true}), isFalse);
    expect(pawIdentityVerified({}), isFalse);
  });

  test('2. coche en bas à droite : ni sous la couronne, ni sous la fusée, ni sur le point en ligne', () {
    const c = Offset(50, 50);
    const r = 23.0;
    final check = pawVerifiedBadgeCenter(c, r);
    expect(check.dx > c.dx && check.dy > c.dy, isTrue, reason: 'bas à droite');
    final crown = PawMapPinPainter.crownCenter(c, r, PawMapLegend.crownMember);
    expect((check - crown).distance, greaterThan(15 / 2 + PawMapLegend.crownMember / 2));
    final rocket = Offset(c.dx - (r + 5 - 9), c.dy + r + 5 - 9);
    expect((check - rocket).distance, greaterThan(15 / 2 + 18 / 2));
    const s = 12.0;
    final dot = pawOnlineDotCenter(c, r, s, verified: true);
    expect((check - dot).distance, greaterThan(15 / 2 + s / 2));
    expect(pawOnlineDotCenter(c, r, s), Offset(c.dx + r - s / 2, c.dy + r - s / 2),
        reason: 'sans coche, le point en ligne reste en bas à droite');
  });

  test('3. l\'épingle vérifiée se dessine (bleu de la coche présent en bas à droite)', () async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    PawMapPinPainter.drawVerifiedBadge(canvas, pawVerifiedBadgeCenter(const Offset(30, 30), 23));
    final img = await rec.endRecording().toImage(70, 70);
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final p = pawVerifiedBadgeCenter(const Offset(30, 30), 23);
    var blue = 0;
    for (var y = (p.dy - 7).round(); y <= (p.dy + 7).round(); y++) {
      for (var x = (p.dx - 7).round(); x <= (p.dx + 7).round(); x++) {
        final i = (y * 70 + x) * 4;
        if (bd!.getUint8(i + 2) > bd.getUint8(i) + 60 && bd.getUint8(i + 3) > 200) blue++;
      }
    }
    final rgb = [blue, 0, blue + 61];
    expect(rgb[2] > rgb[0] + 60, isTrue, reason: 'pixels bleus : $blue');
  });

  test('4. « Autour de moi » : à prix égal et même distance, le vérifié passe avant', () {
    final items = <Map<String, dynamic>>[
      {'id': 'a', 'priceFrom': 12, 'd': 0.30, 'identityVerified': false},
      {'id': 'b', 'priceFrom': 12, 'd': 0.45, 'identityVerified': true},
      {'id': 'c', 'priceFrom': 15, 'd': 0.50, 'identityVerified': true},
      {'id': 'd', 'priceFrom': 9, 'd': 3.0, 'identityVerified': false},
      {'id': 'e', 'priceFrom': 9, 'd': 9.0, 'identityVerified': true},
    ];
    pawVerifiedFirstAtSamePrice(items,
        price: (m) => (m['priceFrom'] as num).toDouble(),
        km: (m) => m['d'] as double,
        verified: (m) => pawIdentityVerified(m));
    expect(items.map((m) => m['id']).toList(), ['b', 'a', 'c', 'd', 'e'],
        reason: 'b passe devant a (même prix, 150 m) ; e ne saute pas 6 km');
  });

  test('5. filtre « Vérifiés seulement » : gardiens/promeneurs non vérifiés retirés, jamais amis ni propriétaires', () {
    bool keep(Map p, {bool friend = false}) => pawVerifiedFilterKeeps(p, on: true, friend: friend);
    expect(keep({'_role': 'sitter', 'identityVerified': true}), isTrue);
    expect(keep({'_role': 'sitter'}), isFalse);
    expect(keep({'_role': 'walker'}), isFalse);
    expect(keep({'_role': 'walker'}, friend: true), isTrue);
    expect(keep({'_role': 'owner'}), isTrue);
    expect(pawVerifiedFilterKeeps({'_role': 'sitter'}, on: false, friend: false), isTrue);
  });

  testWidgets('6. carte focus : pastille « ✓ Vérifié » (9 langues)', (t) async {
    Widget app(bool v, String lang) => ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, __) => GetMaterialApp(
            translations: AppTranslations(),
            locale: Locale(lang),
            home: Scaffold(
              body: Center(
                child: PawFocusCard(
                  info: PawFocusInfo(
                    key: 'x', name: 'Antoine', role: 'sitter', info: '12 € · 300 m',
                    onOpen: () {}, verified: v,
                  ),
                  onClose: () {},
                ),
              ),
            ),
          ),
        );
    await t.pumpWidget(app(true, 'fr'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey<String>('pawmap_focus_verified')), findsOneWidget);
    expect(find.text('Vérifié'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(app(false, 'fr'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey<String>('pawmap_focus_verified')), findsNothing);
    for (final l in ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      final m = AppTranslations().keys[l] ??
          AppTranslations().keys.entries.firstWhere((e) => e.key.startsWith(l)).value;
      for (final k in ['v609_verified_short', 'v609_filter_verified', 'help609_verified_title', 'help609_verified_body']) {
        expect((m[k] ?? '').isNotEmpty, isTrue, reason: '$l/$k');
      }
    }
  });
}
