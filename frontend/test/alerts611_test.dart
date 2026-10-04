// 611 (ZOE, 04/10/2026) — animal perdu / trouvé GRATUIT pour tous
// (~/hopetsit-social/PROCHAIN_BUILD_611.md, point 1, décision BOB), côté app :
// la feuille « Signaler » n'a plus de cadenas sur perdu / trouvé ; sans
// abonnement, une 2e alerte « animal perdu » pendant que la 1re est active
// ouvre « Tu as déjà une alerte en cours » (rien n'est envoyé) avec la
// clôture de l'alerte en cours ; « trouvé » part toujours.
// Ce fichier ne dépend que de widgets existants : il compile AVANT le
// changement (et y échoue), pour la preuve AVANT / APRÈS.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:hopetsit/views/map/widgets/create_report_sheet.dart';

import 'lotd_harness.dart';

const _point = LatLng(-35, -30); // zone fictive

Map<String, dynamic> _report(String type, [String id = 'r611']) => <String, dynamic>{
      '_id': id,
      'type': type,
      'location': <String, dynamic>{
        'coordinates': <double>[-30, -35],
      },
      'expiresAt': DateTime.now().add(const Duration(hours: 48)).toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    };

Map<String, dynamic> _quota({Map<String, dynamic>? lostPet}) => <String, dynamic>{
      'isPremium': false,
      'comfort': <String, dynamic>{'unlimited': false, 'limit': 1, 'used': 0, 'remaining': 1},
      if (lostPet != null) 'lostPet': lostPet,
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

Future<void> _pick(WidgetTester tester, String type) async {
  await tester.ensureVisible(find.byKey(ValueKey('alerts610_chip_$type')));
  await tester.tap(find.byKey(ValueKey('alerts610_chip_$type')));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.text('pawmap_btn_submit'.tr));
  await tester.pump(const Duration(milliseconds: 400));
}

Iterable<LotdRequest> _posts() =>
    lotdRequests.where((r) => r.method == 'POST' && r.path.endsWith('/map-reports'));

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));

  testWidgets('sans abonnement : plus de cadenas sur perdu / trouvé, règle affichée',
      (tester) async {
    lotdResponder = (req) => req.url.path.endsWith('/map-reports/quota')
        ? _quota(lostPet: <String, dynamic>{
            'unlimited': false, 'limit': 1, 'active': 0, 'remaining': 1,
            'activeReportId': null, 'activeExpiresAt': null,
          })
        : const <String, dynamic>{};
    await _openSheet(tester);
    for (final t in ['lost_pet', 'found_pet']) {
      await tester.ensureVisible(find.byKey(ValueKey('alerts610_chip_$t')));
      expect(_hasIcon(tester, t, Icons.lock_rounded), isFalse, reason: t);
      expect(_hasIcon(tester, t, Icons.hourglass_bottom_rounded), isFalse, reason: t);
    }
    expect(find.text('Gratuit pour tous · 1 animal perdu à la fois'), findsOneWidget);
    expect(find.text('Avec un abonnement'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans abonnement : « animal perdu » part au serveur (aucune fenêtre d\'abonnement)',
      (tester) async {
    lotdResponder = (req) {
      if (req.url.path.endsWith('/map-reports/quota')) {
        return _quota(lostPet: <String, dynamic>{
          'unlimited': false, 'limit': 1, 'active': 0, 'remaining': 1,
        });
      }
      if (req.method == 'POST' && req.url.path.endsWith('/map-reports')) {
        return <String, dynamic>{'report': _report('lost_pet')};
      }
      return const <String, dynamic>{};
    };
    await _openSheet(tester);
    await _pick(tester, 'lost_pet');
    expect(find.text('Réservé aux abonnés'), findsNothing);
    await _submit(tester);
    expect(_posts(), hasLength(1));
    expect(_posts().first.body?['type'], 'lost_pet');
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('sans abonnement : « animal trouvé » part au serveur, même avec une alerte perdue en cours',
      (tester) async {
    lotdResponder = (req) {
      if (req.url.path.endsWith('/map-reports/quota')) {
        return _quota(lostPet: <String, dynamic>{
          'unlimited': false, 'limit': 1, 'active': 1, 'remaining': 0,
          'activeReportId': 'r-active',
        });
      }
      if (req.method == 'POST' && req.url.path.endsWith('/map-reports')) {
        return <String, dynamic>{'report': _report('found_pet')};
      }
      return const <String, dynamic>{};
    };
    await _openSheet(tester);
    await _pick(tester, 'found_pet');
    await _submit(tester);
    expect(_posts(), hasLength(1));
    expect(_posts().first.body?['type'], 'found_pet');
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('alerte perdue déjà en cours : « Tu as déjà une alerte en cours », rien envoyé, clôture possible',
      (tester) async {
    final until = DateTime.now().add(const Duration(hours: 30));
    lotdResponder = (req) {
      if (req.url.path.endsWith('/map-reports/quota')) {
        return _quota(lostPet: <String, dynamic>{
          'unlimited': false, 'limit': 1, 'active': 1, 'remaining': 0,
          'activeReportId': 'r-active',
          'activeExpiresAt': until.toUtc().toIso8601String(),
        });
      }
      return const <String, dynamic>{};
    };
    await _openSheet(tester);
    expect(find.text('Gratuit · ton alerte animal perdu est en cours'), findsOneWidget);
    await _pick(tester, 'lost_pet');
    await _submit(tester);
    expect(find.text('Tu as déjà une alerte en cours'), findsOneWidget);
    expect(find.textContaining('1 alerte animal perdu active à la fois'), findsOneWidget);
    expect(find.textContaining('reste visible jusqu\'au'), findsOneWidget);
    expect(find.text('Voir les abonnements'), findsOneWidget);
    expect(_posts(), isEmpty);

    await tester.tap(find.text('Clôturer mon alerte en cours'));
    await tester.pump(const Duration(milliseconds: 400));
    final del = lotdRequests.where((r) => r.method == 'DELETE');
    expect(del, hasLength(1));
    expect(del.first.path, endsWith('/map-reports/r-active'));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('avec un abonnement (quota illimité) : plusieurs alertes, aucune fenêtre', (tester) async {
    lotdResponder = (req) {
      if (req.url.path.endsWith('/map-reports/quota')) {
        return <String, dynamic>{
          'isPremium': true,
          'comfort': <String, dynamic>{'unlimited': true},
          'lostPet': <String, dynamic>{'unlimited': true, 'limit': null},
        };
      }
      if (req.method == 'POST' && req.url.path.endsWith('/map-reports')) {
        return <String, dynamic>{'report': _report('lost_pet')};
      }
      return const <String, dynamic>{};
    };
    await _openSheet(tester);
    expect(find.text('Gratuit · plusieurs alertes avec ton abonnement'), findsOneWidget);
    await _pick(tester, 'lost_pet');
    await _submit(tester);
    expect(find.text('Tu as déjà une alerte en cours'), findsNothing);
    expect(_posts(), hasLength(1));
    await tester.pump(const Duration(seconds: 4));
  });
}
