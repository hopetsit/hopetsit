// 624 (PAM, 26/10/2026) — page des candidats (parité site de LEO), « Poser
// mes dates » sans code postal, repère ADA, prix du serveur au format de la
// langue.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/v565/cand2610_i18n.dart';
import 'package:hopetsit/localization/v565/dates620_i18n.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_candidates_sheet.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_dates_sheet2610.dart';

import 'lotd_harness.dart';

Map<String, dynamic> _app(String id, String name, Map<String, dynamic> pricing,
        {String role = 'sitter', double? lat, double? lng, bool kyc = false}) =>
    <String, dynamic>{
      'id': id,
      'postId': 'p1',
      'status': 'pending',
      'createdAt': '2026-10-2${id.codeUnitAt(id.length - 1) % 9}T10:00:00Z',
      'description': 'Bonjour, je suis dispo.',
      role: {
        'id': 's-$id',
        'name': name,
        'currency': 'EUR',
        'rating': 0,
        'reviewsCount': 0,
        'verified': true,
        if (kyc) 'identityVerified': true,
        if (lat != null) 'location': {'city': 'Paris', 'lat': lat, 'lng': lng},
      },
      'pricing': pricing,
    };

const _dated = <String, dynamic>{
  'totalPrice': 72, 'appliedRate': 20, 'unit': 'day', 'currency': 'EUR', 'weeklyApplied': true,
};
const _tbd = <String, dynamic>{
  'indicative': true, 'pricingTier': 'indicative', 'unitRate': 10, 'ownerUnitRate': 12,
  'unit': 'walk', 'currency': 'EUR',
};

void main() {
  setUpAll(() {
    Get.testMode = true;
    Get.locale = const Locale('fr', 'FR');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  group('i18n 2610', () {
    test('mêmes clés dans les 9 langues, jamais vides, jetons gardés', () {
      final fr = cand2610I18n['fr']!;
      for (final l in const ['en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
        final m = cand2610I18n[l]!;
        expect(m.keys.toSet(), fr.keys.toSet(), reason: l);
        for (final e in m.entries) {
          expect(e.value.trim(), isNotEmpty, reason: '$l ${e.key}');
          for (final tok in const ['{name}', '{km}']) {
            if (fr[e.key]!.contains(tok)) expect(e.value, contains(tok), reason: '$l ${e.key}');
          }
        }
      }
    });
  });

  group('prix', () {
    test('total du serveur au format de la langue, jamais incohérent', () {
      Get.locale = const Locale('fr', 'FR');
      final a = ApplicationModel.fromJson(_app('a1', 'Léa', const {
        'totalPrice': 14.4, 'appliedRate': 12, 'currency': 'EUR',
      }));
      expect(candidateTotal2610(a), '14,40 €');
      final bad = ApplicationModel.fromJson(_app('a2', 'Tom', const {
        'totalPrice': 2.7, 'appliedRate': 18, 'currency': 'EUR',
      }));
      expect(candidateTotal2610(bad), '', reason: 'total < tarif = masqué (règle ZOE)');
      final tbd = ApplicationModel.fromJson(_app('a3', 'Ana', _tbd));
      expect(candidateTotal2610(tbd), '');
      expect(tbd.pricing!.ownerUnitRate, 12);
      expect(ApplicationModel.fromJson(_app('a4', 'Zoé', _dated)).pricing!.weeklyApplied, isTrue);
      Get.locale = const Locale('en', 'US');
      expect(candidateTotal2610(a), '€14.40');
      Get.locale = const Locale('fr', 'FR');
    });
    test('nombre seul au format de la langue', () {
      Get.locale = const Locale('fr', 'FR');
      expect(CurrencyHelper.number(14.4), '14,40');
      Get.locale = const Locale('en', 'US');
      expect(CurrencyHelper.number(14.4), '14.40');
      Get.locale = const Locale('fr', 'FR');
    });
    test('distance arrondie, jamais 0', () {
      expect(candidateKm2610(48.8566, 2.3522, 48.8566, 2.3522), 1);
      expect(candidateKm2610(48.8566, 2.3522, 48.9, 2.3522), 5);
      expect(candidateKm2610(null, 2, 3, 4), isNull);
    });
    test('position et identité vérifiée lues', () {
      final a = ApplicationModel.fromJson(_app('a1', 'Léa', _dated, lat: 48.9, lng: 2.35, kyc: true));
      expect(a.sitter.lat, 48.9);
      expect(a.sitter.identityVerified, isTrue);
      final b = ApplicationModel.fromJson(<String, dynamic>{
        ..._app('b1', 'Max', _dated),
        'sitter': {'id': 's', 'name': 'Max', 'location': {'coordinates': [2.35, 48.85]}},
      });
      expect(b.sitter.lat, 48.85);
      expect(b.sitter.lng, 2.35);
      expect(b.sitter.identityVerified, isFalse, reason: 'e-mail vérifié ≠ identité');
    });
  });

  group('Poser mes dates', () {
    test('balade : un jour + une heure, fin = début + durée', () {
      final p = postDatesPayload2610(
          walk: true, mode: 'exact', startDay: DateTime(2026, 11, 5), endDay: null,
          time: const TimeOfDay(hour: 9, minute: 30), walkMinutes: 45)!;
      expect(p.start, DateTime(2026, 11, 5, 9, 30));
      expect(p.end, DateTime(2026, 11, 5, 10, 15));
      expect(p.dateMode, 'exact');
    });
    test('garde : début / fin, ordre vérifié, approximatif gardé', () {
      expect(postDatesPayload2610(
          walk: false, mode: 'exact', startDay: DateTime(2026, 11, 7), endDay: DateTime(2026, 11, 5)), isNull);
      expect(postDatesPayload2610(walk: false, mode: 'exact', startDay: null, endDay: null), isNull);
      final p = postDatesPayload2610(
          walk: false, mode: 'approx', startDay: DateTime(2026, 11, 5), endDay: DateTime(2026, 11, 9))!;
      expect(p.dateMode, 'approx');
      expect(p.end.difference(p.start).inDays, 4);
    });
  });

  group('page des candidats', () {
    setUp(() async {
      await lotdSetUp(role: 'owner');
      Get.addTranslations(<String, Map<String, String>>{
        'fr_FR': {...dates620I18n['fr']!, ...cand2610I18n['fr']!},
      });
      Get.locale = const Locale('fr', 'FR');
    });
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    Future<void> open(WidgetTester tester, List<Map<String, dynamic>> apps,
        {String dateMode = 'exact', String? highlight}) async {
      lotdResponder = (req) {
        if (req.url.path.endsWith('/applications/my')) {
          return <String, dynamic>{'applications': apps};
        }
        if (req.url.path.contains('/posts/by-id/')) {
          return <String, dynamic>{
            'post': {
              'id': 'p1', '_id': 'p1', 'dateMode': dateMode, 'serviceTypes': ['dog_walking'],
              'location': {'city': 'Paris', 'lat': 48.8566, 'lng': 2.3522},
              'owner': {'id': 'o1', 'name': 'Camille'},
              'createdAt': '2026-10-26T10:00:00Z', 'updatedAt': '2026-10-26T10:00:00Z',
            },
          };
        }
        return <String, dynamic>{};
      };
      lotdPhone(tester, width: 375, height: 667);
      await tester.pumpWidget(lotdApp(Builder(builder: (ctx) {
        return Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open_sheet'),
              onPressed: () => PostCandidatesSheet.show(
                  context: ctx, postId: 'p1', highlightApplicationId: highlight, source: 'push'),
              child: const Text('ouvrir'),
            ),
          ),
        );
      })));
      await lotdSettle(tester);
      await tester.tap(find.byKey(const Key('open_sheet')));
      await lotdSettle(tester, frames: 14);
    }

    testWidgets('titre (N), Écrire en principal, Choisir · total, repère ADA, candidat de la notification en premier',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [
        _app('a1', 'Léa Martin', _dated, lat: 48.86, lng: 2.35, kyc: true),
        _app('a2', 'Tom Petit', _dated, role: 'walker'),
      ], highlight: 'a2');
      expect(find.text('Tes candidats (2)'), findsOneWidget);
      expect(find.text('Écrire à Léa'), findsOneWidget);
      expect(find.text('Écrire à Tom'), findsOneWidget);
      expect(find.textContaining('72,00'), findsWidgets);
      expect(find.text('tarif semaine appliqué'), findsWidgets);
      // Le candidat de la notification (Tom) est posé en premier.
      final yTom = tester.getTopLeft(find.byKey(const Key('cand2610_card_a2'))).dy;
      final yLea = tester.getTopLeft(find.byKey(const Key('cand2610_card_a1'))).dy;
      expect(yTom, lessThan(yLea));
      // Repère ADA envoyé à l'ouverture.
      final sig = lotdRequests.where((r) => r.path.endsWith('/owner-signals/candidates-view')).toList();
      expect(sig, hasLength(1));
      expect(sig.first.body, {'postId': 'p1', 'source': 'push'});
      // Écrire et Choisir du 1er candidat visibles sans défiler (375 × 667).
      final h = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(tester.getBottomLeft(find.byKey(const Key('cand2610_write_a2'))).dy, lessThan(h));
      expect(tester.getBottomLeft(find.byKey(const Key('dates620_choose_a2'))).dy, lessThan(h));
      // Écrire → POST /conversations/start avec le PROMENEUR.
      await tester.tap(find.byKey(const Key('cand2610_write_a2')));
      await lotdSettle(tester, frames: 8);
      final start = lotdRequests.where((r) => r.path.contains('/conversations')).toList();
      expect(start, isNotEmpty);
      expect(start.last.query['walkerId'], 's-a2');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('dates à prévoir : encart + « Choisir mes dates » ouvre la feuille des dates seules (sans code postal)',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [_app('a1', 'Léa Martin', _tbd, role: 'walker')], dateMode: 'tbd');
      expect(find.text('Indique tes dates pour voir le prix total et choisir'), findsOneWidget);
      expect(find.textContaining('12'), findsWidgets, reason: 'tarif frais compris (ownerUnitRate)');
      await tester.tap(find.byKey(const Key('dates620_set_dates_button')));
      await lotdSettle(tester, frames: 10);
      expect(find.byKey(const Key('dates2610_sheet')), findsOneWidget);
      expect(find.byKey(const Key('dates2610_time')), findsOneWidget, reason: 'balade = date + heure');
      expect(find.textContaining('postal'), findsNothing);
      // Enregistrer sans date : message, aucun envoi.
      final before = lotdRequests.where((r) => r.method == 'PATCH').length;
      await tester.tap(find.byKey(const Key('dates2610_save')));
      await lotdSettle(tester, frames: 6);
      expect(lotdRequests.where((r) => r.method == 'PATCH').length, before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
