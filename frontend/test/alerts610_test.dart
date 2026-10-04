// 610 (ZOE, 04/10/2026) — règle B des signalements (REGLES_610.md) côté app :
// plus de cadenas sur les dangers, compteur « 1 par semaine » sur le confort,
// message d'abonnement quand le quota est atteint (côté app ET refus 429 du
// serveur), animal perdu / trouvé inchangé, boutique sans « signalements
// premium », textes en 9 langues.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hopetsit/controllers/map_report_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/alerts610_i18n.dart';
import 'package:hopetsit/localization/v565/pawmap610_i18n.dart';
import 'package:hopetsit/models/map_report_model.dart';
import 'package:hopetsit/views/map/widgets/create_report_sheet.dart';

import 'lotd_harness.dart';

const _point = LatLng(-35, -30); // zone fictive

Map<String, dynamic> _report(String type) => <String, dynamic>{
      '_id': 'r610',
      'type': type,
      'location': <String, dynamic>{
        'coordinates': <double>[-30, -35],
      },
      'expiresAt': DateTime.now().add(const Duration(hours: 48)).toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    };

Future<void> _openSheet(WidgetTester tester) async {
  tester.view.physicalSize = const Size(786, 1704);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(lotdApp(
    const Scaffold(body: Align(
      alignment: Alignment.bottomCenter,
      child: CreateReportSheet(initialPoint: _point, city: 'Zone test'),
    )),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

bool _hasIcon(WidgetTester tester, String type, IconData icon) => find
    .descendant(
      of: find.byKey(ValueKey('alerts610_chip_$type')),
      matching: find.byIcon(icon),
    )
    .evaluate()
    .isNotEmpty;

String _counter(WidgetTester tester) => (tester
        .widget<Text>(find.descendant(
            of: find.byKey(const ValueKey('alerts610_comfort_counter')),
            matching: find.byType(Text)))
        .data ??
    '');

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));

  // 611 (ZOE) — perdu / trouvé ne sont plus verrouillés (PROCHAIN_BUILD_611.md
  // point 1) ; cas complets dans alerts611_test.dart.
  testWidgets('sans abonnement : dangers sans cadenas, compteur confort, perdu/trouvé sans cadenas (611)',
      (tester) async {
    lotdResponder = (req) {
      if (req.url.path.endsWith('/map-reports/quota')) {
        return <String, dynamic>{
          'isPremium': false,
          'comfort': <String, dynamic>{'unlimited': false, 'limit': 1, 'used': 0, 'remaining': 1},
        };
      }
      return const <String, dynamic>{};
    };
    await _openSheet(tester);
    expect(lotdRequests.any((r) => r.path.endsWith('/map-reports/quota')), isTrue);
    for (final t in ReportTypes.dangerTypes) {
      await tester.ensureVisible(find.byKey(ValueKey('alerts610_chip_$t')));
      expect(_hasIcon(tester, t, Icons.lock_rounded), isFalse, reason: t);
    }
    expect(find.text('Dangers'), findsOneWidget);
    expect(find.text('Gratuit pour tous, sans limite'), findsOneWidget);
    expect(_counter(tester), '1 par semaine sans abonnement · disponible');
    expect(_hasIcon(tester, 'poop', Icons.hourglass_bottom_rounded), isFalse);
    expect(_hasIcon(tester, 'lost_pet', Icons.lock_rounded), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('danger choisi : envoyé au serveur + rappel du bon Samaritain', (tester) async {
    lotdResponder = (req) {
      if (req.method == 'POST' && req.url.path.endsWith('/map-reports')) {
        return <String, dynamic>{'report': _report('poison')};
      }
      return const <String, dynamic>{};
    };
    await _openSheet(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('alerts610_chip_poison')));
    await tester.tap(find.byKey(const ValueKey('alerts610_chip_poison')));
    await tester.pump();
    expect(find.textContaining('geste du bon Samaritain'), findsOneWidget);
    await tester.tap(find.text('pawmap_btn_submit'.tr));
    await tester.pump(const Duration(milliseconds: 300));
    final post = lotdRequests.where((r) => r.method == 'POST' && r.path.endsWith('/map-reports'));
    expect(post, hasLength(1));
    expect(post.first.body?['type'], 'poison');
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('quota de confort atteint : sablier, date, message d\'abonnement, rien envoyé',
      (tester) async {
    final next = DateTime(2026, 10, 9, 14, 5);
    lotdResponder = (req) {
      if (req.url.path.endsWith('/map-reports/quota')) {
        return <String, dynamic>{
          'isPremium': false,
          'comfort': <String, dynamic>{
            'unlimited': false, 'limit': 1, 'used': 1, 'remaining': 0,
            'nextAvailableAt': next.toUtc().toIso8601String(),
          },
        };
      }
      return const <String, dynamic>{};
    };
    await _openSheet(tester);
    expect(_counter(tester), startsWith('Utilisé cette semaine · prochain le '));
    expect(_hasIcon(tester, 'poop', Icons.hourglass_bottom_rounded), isTrue);
    await tester.ensureVisible(find.byKey(const ValueKey('alerts610_chip_poop')));
    await tester.tap(find.byKey(const ValueKey('alerts610_chip_poop')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Signalement de confort déjà utilisé'), findsOneWidget);
    expect(find.textContaining('Avec un abonnement, c\'est illimité'), findsOneWidget);
    expect(find.text('Voir les abonnements'), findsOneWidget);
    expect(lotdRequests.where((r) => r.method == 'POST'), isEmpty);
  });

  test('refus 429 du serveur : quota marqué atteint avec la date reçue', () async {
    final api = ApiClient(
      httpClient: MockClient((http.Request req) async => http.Response(
            jsonEncode(<String, dynamic>{
              'code': 'COMFORT_WEEKLY_LIMIT',
              'nextAvailableAt': '2026-10-11T08:00:00.000Z',
              'upgradeUrl': '/subscriptions/plans',
            }),
            429,
            headers: <String, String>{'content-type': 'application/json'},
          )),
      storage: Get.find<GetStorage>(),
    );
    await Get.delete<ApiClient>(force: true);
    Get.put<ApiClient>(api, permanent: true);
    final c = MapReportController();
    final r = await c.createReport(type: 'pee', point: _point);
    expect(r, isNull);
    expect(c.comfortLimitReached.value, isTrue);
    expect(c.comfortQuota.value?.exhausted, isTrue);
    expect(c.comfortQuota.value?.nextAvailableAt?.toUtc(), DateTime.utc(2026, 10, 11, 8));
  });

  test('classement identique au serveur (utils/mapReportRules610.js)', () {
    final js = File('../backend/src/utils/mapReportRules610.js').readAsStringSync();
    List<String> list(String name) {
      final m = RegExp('const $name = \\[([^\\]]*)\\]').firstMatch(js)!;
      return RegExp(r"'([a-z_]+)'").allMatches(m.group(1)!).map((x) => x.group(1)!).toList()
        ..sort();
    }
    List<String> sorted(List<String> l) => [...l]..sort();
    expect(sorted(ReportTypes.dangerTypes), list('DANGER_TYPES'));
    expect(sorted(ReportTypes.usefulFreeTypes), list('USEFUL_FREE_TYPES'));
    expect(sorted(ReportTypes.comfortTypes), list('COMFORT_TYPES'));
    expect(sorted(ReportTypes.premiumCreateTypes), list('PREMIUM_CREATE_TYPES'));
    // 611 — perdu / trouvé : classe à part (gratuits, PET_ALERT_TYPES).
    expect(sorted(ReportTypes.petAlertTypes), list('PET_ALERT_TYPES'));
    final all = <String>{
      ...ReportTypes.dangerTypes, ...ReportTypes.usefulFreeTypes,
      ...ReportTypes.comfortTypes, ...ReportTypes.petAlertTypes,
    };
    expect(all, ReportTypes.all.toSet(), reason: 'chaque type a une classe, une seule');
    expect(all.length, ReportTypes.all.length);
  });

  test('textes : 9 langues, mêmes clés, @date protégé, aucune clé brute', () {
    const langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
    final ref = alerts610I18n['en']!.keys.toSet();
    final tr = AppTranslations().keys;
    const full = {
      'en': 'en_US', 'fr': 'fr_FR', 'es': 'es_ES', 'de': 'de_DE', 'it': 'it_IT',
      'pt': 'pt_PT', 'ko': 'ko_KR', 'ja': 'ja_JP', 'pl': 'pl_PL',
    };
    for (final l in langs) {
      final m = alerts610I18n[l]!;
      expect(m.keys.toSet(), ref, reason: l);
      for (final k in ref) {
        expect(m[k]!.trim(), isNotEmpty, reason: '$l $k');
        expect(m[k]!.contains('@date'), alerts610I18n['en']![k]!.contains('@date'), reason: '$l $k');
        expect(tr[full[l]]![k], m[k], reason: 'branché dans v565 : $l $k');
      }
      expect(pawmap610I18n[l]!['help610_alerts_b'], isNotNull, reason: l);
    }
    expect(tr['fr_FR']!['shop610_comfort_unlimited'], 'Signalements de confort illimités');
    expect(tr['fr_FR']!['shop610_danger_free'], 'Signaler un danger : gratuit pour tous');
    expect(tr['fr_FR']!['help610_alerts_b'], contains('bon Samaritain'));
  });

  test('boutique : plus aucune mention « signalements premium » affichée', () {
    final src = File('lib/views/boost/coin_shop_screen.dart').readAsStringSync();
    for (final k in ['shop_premium_reports_included', 'shop569_follow_b6_title',
      'shop_pp_plus_body', 'shop_ps_plus_body', 'shop_pp_free_body']) {
      expect(src.contains("'$k'.tr"), isFalse, reason: k);
    }
    expect("'shop610_comfort_unlimited'.tr".allMatches(src).length, greaterThanOrEqualTo(4));
    expect("'shop610_danger_free'.tr".allMatches(src).length, greaterThanOrEqualTo(3));
  });
}
