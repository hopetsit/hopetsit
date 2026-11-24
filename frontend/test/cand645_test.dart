// 645 (PAM, 24/11/2026) — page des candidats du propriétaire, parité avec le
// site du 24/11 (`OwnerCandidatesPay3110.tsx`) :
//   1. pastilles « Le plus proche » / « Le moins cher » : deux candidats → les
//      deux pastilles ; un seul → aucune ; deux ex æquo → aucune ;
//   2. détail du total « 11 jours × 16,80 € » (entier > 1, « ≈ » si la
//      division ne tombe pas juste, rien si indicatif / tarif à venir) ;
//   3. textes 9 langues, paquet branché ;
//   4. notification « … a regardé ta proposition » (type application_new reçu
//      par un PRESTATAIRE) → la demande, pas la page des candidats.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/cand645_i18n.dart';
import 'package:hopetsit/localization/v565/v565_i18n.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/cand644.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/cand645.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_candidates_sheet.dart';

import 'lotd_harness.dart';

const _langs = <String>['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

// Point de la demande : zone fictive (jamais une vraie ville).
const double _pLat = -35, _pLng = -30;

Map<String, dynamic> _app(
  String id, {
  String name = 'Imane Benali',
  double? dlat,
  double total = 120,
  String status = 'pending',
  String? serviceType,
  Map<String, dynamic>? pricing,
}) =>
    <String, dynamic>{
      'id': id,
      'postId': 'p1',
      'status': status,
      'createdAt': '2026-11-20T10:00:00Z',
      'description': '',
      if (serviceType != null) 'serviceType': serviceType,
      'sitter': <String, dynamic>{
        'id': 's-$id',
        'name': name,
        'currency': 'EUR',
        'rating': 0,
        'reviewsCount': 0,
        if (dlat != null) 'location': {'lat': _pLat + dlat, 'lng': _pLng},
      },
      'pricing': pricing ?? <String, dynamic>{'totalPrice': total, 'appliedRate': 10, 'unit': 'day', 'currency': 'EUR'},
    };

ApplicationModel _m(Map<String, dynamic> j) => ApplicationModel.fromJson(j);
int? _km(ApplicationModel a) => candidateKm2610(_pLat, _pLng, a.sitter.lat, a.sitter.lng);
String _eur(double v) => CurrencyHelper.format('EUR', v);

void main() {
  setUpAll(() {
    Get.testMode = true;
    Get.locale = const Locale('fr', 'FR');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  group('i18n 645', () {
    test('9 langues, mêmes clés, jamais vides, paquet branché, mot pour mot le site (fr, en)', () {
      final fr = cand645I18n['fr']!;
      expect(fr.length, 2);
      expect(cand645I18n.keys.toSet(), _langs.toSet());
      for (final l in _langs) {
        final m = cand645I18n[l]!;
        expect(m.keys.toSet(), fr.keys.toSet(), reason: l);
        for (final e in m.entries) {
          expect(e.value.trim(), isNotEmpty, reason: '$l ${e.key}');
          expect(v565For(l)[e.key], e.value, reason: 'paquet branché ($l ${e.key})');
        }
      }
      expect(fr['cand645_badge_closest'], 'Le plus proche');
      expect(fr['cand645_badge_cheapest'], 'Le moins cher');
      expect(cand645I18n['en']!['cand645_badge_closest'], 'Closest to you');
      expect(cand645I18n['en']!['cand645_badge_cheapest'], 'Lowest price');
    });
  });

  group('règle des pastilles (logique pure)', () {
    test('deux candidats, un seul en tête → distance et total retenus', () {
      final a = _m(_app('a', dlat: 0.02, total: 150)), b = _m(_app('b', dlat: 0.2, total: 120));
      final r = badges645([a, b], kmOf: _km);
      expect(r.km, _km(a));
      expect(r.total, 120);
      expect(r.closest(a, _km(a)), isTrue);
      expect(r.closest(b, _km(b)), isFalse);
      expect(r.cheapest(b), isTrue);
      expect(r.cheapest(a), isFalse);
    });
    test('un seul candidat → rien', () {
      final a = _m(_app('a', dlat: 0.02));
      final r = badges645([a], kmOf: _km);
      expect(r.km, isNull);
      expect(r.total, isNull);
      expect(r.closest(a, _km(a)), isFalse);
      expect(r.cheapest(a), isFalse);
    });
    test('ex æquo en tête → rien (distance comme prix)', () {
      final r = badges645([
        _m(_app('a', dlat: 0.05, total: 120)),
        _m(_app('b', dlat: 0.05, total: 120)),
        _m(_app('c', dlat: 0.3, total: 200)),
      ], kmOf: _km);
      expect(r.km, isNull);
      expect(r.total, isNull);
    });
    test('seulement les candidats EN ATTENTE et sans « tarif à venir »', () {
      final near = _m(_app('ok', dlat: 0.02, total: 90, status: 'accepted'));
      final stale = _m(_app('st', dlat: 0.01, pricing: {'stale': true, 'unit': 'day', 'currency': 'EUR'}));
      final a = _m(_app('a', dlat: 0.1, total: 150)), b = _m(_app('b', dlat: 0.2, total: 120));
      final r = badges645([near, stale, a, b], kmOf: _km);
      expect(r.km, _km(a), reason: 'accepté et « tarif à venir » ne comptent pas');
      expect(r.total, 120);
      expect(r.cheapest(near), isFalse);
      expect(r.closest(stale, _km(stale)), isFalse);
    });
    test('distance inconnue ou total indicatif : il faut DEUX valeurs connues', () {
      final a = _m(_app('a', dlat: 0.1, total: 150));
      final b = _m(_app('b', pricing: {'indicative': true, 'unitRate': 12, 'unit': 'day', 'currency': 'EUR'}));
      final r = badges645([a, b], kmOf: _km);
      expect(r.km, isNull);
      expect(r.total, isNull);
    });
  });

  group('détail du total (logique pure)', () {
    setUp(() async {
      await lotdSetUp(role: 'owner');
      Get.clearTranslations();
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr', 'FR');
    });
    String d(Map<String, dynamic> pricing, {String? service, List<String>? post}) =>
        candidateDetail645(_m(_app('a', pricing: pricing, serviceType: service)), postServices: post);

    test('« 11 jours × 16,80 € » : total ÷ quantité, au format du total', () {
      expect(d({'totalPrice': 184.8, 'appliedRate': 14, 'quantity': 11, 'unit': 'day', 'currency': 'EUR'}),
          '11 jours × ${_eur(16.8)}');
    });
    test('nuits, visites, balades', () {
      expect(d({'totalPrice': 60, 'quantity': 3, 'unit': 'night', 'currency': 'EUR'}), '3 nuits × ${_eur(20)}');
      expect(d({'totalPrice': 60, 'quantity': 4, 'unit': 'visit', 'currency': 'EUR'}), startsWith('4 visites × '));
      expect(d({'totalPrice': 60, 'quantity': 5, 'currency': 'EUR'}, service: 'dog_walking'), startsWith('5 balades × '));
      expect(d({'totalPrice': 60, 'quantity': 5, 'currency': 'EUR'}, post: const ['home_visit']), startsWith('5 visites × '));
    });
    test('« ≈ » quand la division ne tombe pas juste', () {
      expect(d({'totalPrice': 100, 'quantity': 3, 'unit': 'day', 'currency': 'EUR'}), '≈ 3 jours × ${_eur(33.33)}');
    });
    test('rien : une seule unité, quantité absente ou non entière, indicatif, tarif à venir, total absent', () {
      expect(d({'totalPrice': 30, 'quantity': 1, 'unit': 'day', 'currency': 'EUR'}), '');
      expect(d({'totalPrice': 30, 'unit': 'day', 'currency': 'EUR'}), '');
      expect(d({'totalPrice': 30, 'quantity': 2.5, 'unit': 'day', 'currency': 'EUR'}), '');
      expect(d({'totalPrice': 30, 'quantity': 3, 'indicative': true, 'unit': 'day', 'currency': 'EUR'}), '');
      expect(d({'totalPrice': 30, 'quantity': 3, 'stale': true, 'unit': 'day', 'currency': 'EUR'}), '');
      expect(d({'quantity': 3, 'unitRate': 10, 'unit': 'day', 'currency': 'EUR'}), '');
    });
  });

  group('notification « a regardé ta proposition » (owner_viewed_2411, type application_new)', () {
    const id = '6ae3b1bee86658cbe6d9e34c', app = '6ae3b1bee86658cbe6d9e34d';
    String r(String role) => DeepLinkService.routeForNotification(
        'application_new', {'postId': id, 'applicationId': app, 'ownerName': 'Camille'}, role: role);
    test('gardien et promeneur → la demande', () {
      expect(r('sitter'), '/post/$id');
      expect(r('walker'), '/post/$id');
    });
    test('le gabarit reçu comme type → la demande aussi, jamais la simple liste', () {
      for (final role in const ['sitter', 'walker']) {
        expect(
            DeepLinkService.routeForNotification(
                'owner_viewed_2411', {'postId': id, 'applicationId': app}, role: role),
            '/post/$id');
      }
    });
    test('propriétaire → la candidature (inchangé)', () => expect(r('owner'), '/application/$app'));
    test('push : le rôle voyage dans data.recipientRole', () {
      expect(
          DeepLinkService.resolvePushRoute('application_new',
              {'postId': id, 'applicationId': app, 'recipientRole': 'walker', 'route': '/posts?application=$app'},
              role: 'walker'),
          '/post/$id');
    });
  });

  group('feuille des candidats — pastilles et détail à l\'écran', () {
    setUp(() async {
      await lotdSetUp(role: 'owner');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall c) async => null);
      Get.locale = const Locale('fr', 'FR');
      Flags644.reset();
    });
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    Future<void> open(WidgetTester tester, List<Map<String, dynamic>> list,
        {double width = 375, double height = 2400, double textScale = 1.0}) async {
      lotdResponder = (req) {
        final path = req.url.path;
        if (path.endsWith('/applications/my')) return <String, dynamic>{'applications': list};
        if (path.contains('/posts/by-id/')) {
          return <String, dynamic>{
            'post': {
              'id': 'p1', '_id': 'p1', 'dateMode': 'exact', 'serviceTypes': ['house_sitting'],
              'animalTypes': ['dog'],
              'location': {'city': 'Zone test', 'lat': _pLat, 'lng': _pLng},
              'owner': {'id': 'o1', 'name': 'Camille'},
              'createdAt': '2026-11-20T10:00:00Z', 'updatedAt': '2026-11-20T10:00:00Z',
            },
          };
        }
        return <String, dynamic>{};
      };
      lotdPhone(tester, width: width, height: height);
      if (textScale != 1.0) {
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
      await tester.pumpWidget(lotdApp(Builder(builder: (ctx) {
        return Scaffold(
          body: Center(
            child: GestureDetector(
              key: const Key('open_sheet'),
              onTap: () => PostCandidatesSheet.show(context: ctx, postId: 'p1', source: 'direct'),
              child: const Text('ouvrir'),
            ),
          ),
        );
      })));
      await lotdSettle(tester);
      await tester.tap(find.byKey(const Key('open_sheet')));
      await lotdSettle(tester, frames: 14);
    }

    Finder k(String key) => find.byKey(Key(key), skipOffstage: false);

    testWidgets('deux candidats → les deux pastilles, chacune sur la bonne carte, et le détail sous le total',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [
        _app('pres', name: 'Paula Près', dlat: 0.02,
            pricing: {'totalPrice': 184.8, 'appliedRate': 14, 'quantity': 11, 'unit': 'day', 'currency': 'EUR'}),
        _app('eco', name: 'Éric Éco', dlat: 0.2,
            pricing: {'totalPrice': 100, 'appliedRate': 10, 'quantity': 3, 'unit': 'day', 'currency': 'EUR'}),
      ]);
      expect(find.text('Tes candidats (2)'), findsOneWidget);
      expect(k('cand645_closest_pres'), findsOneWidget);
      expect(k('cand645_cheapest_eco'), findsOneWidget);
      expect(k('cand645_closest_eco'), findsNothing);
      expect(k('cand645_cheapest_pres'), findsNothing);
      expect(find.text('📍 Le plus proche'), findsOneWidget);
      expect(find.text('💶 Le moins cher'), findsOneWidget);
      // mêmes couleurs que le site
      Color bg(String key) =>
          ((tester.widget<Container>(find.descendant(of: k(key), matching: find.byType(Container)).first).decoration)
                  as BoxDecoration)
              .color!;
      expect(bg('cand645_closest_pres'), const Color(0xFFEAF6EE));
      expect(bg('cand645_cheapest_eco'), const Color(0xFFFFF4D6));
      expect(tester.widget<Text>(find.text('📍 Le plus proche')).style?.color, const Color(0xFF15803D));
      expect(tester.widget<Text>(find.text('💶 Le moins cher')).style?.color, const Color(0xFF7A4B00));
      // détail sous le total
      expect(tester.widget<Text>(find.descendant(of: k('cand645_detail_pres'), matching: find.byType(Text))).data,
          '11 jours × ${_eur(16.8)}');
      expect(tester.widget<Text>(find.descendant(of: k('cand645_detail_eco'), matching: find.byType(Text))).data,
          '≈ 3 jours × ${_eur(33.33)}');
      final price = tester.getRect(k('cand2610_price_pres'));
      final detail = tester.getRect(k('cand645_detail_pres'));
      expect(price.contains(detail.topLeft) && price.contains(detail.bottomRight), isTrue,
          reason: 'le détail est DANS l\'encadré du prix, sous le total');
      // le total et le bouton Choisir ne changent pas
      expect(find.textContaining('Choisir · ${_eur(184.8)}'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('un seul candidat → aucune pastille (le détail reste)',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [
        _app('seul', dlat: 0.02,
            pricing: {'totalPrice': 184.8, 'appliedRate': 14, 'quantity': 11, 'unit': 'day', 'currency': 'EUR'}),
      ]);
      expect(k('cand2610_card_seul'), findsOneWidget);
      expect(find.byType(CandBadge645, skipOffstage: false), findsNothing);
      expect(k('cand645_detail_seul'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('deux ex æquo (même distance, même prix) → aucune pastille',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [
        _app('a1', name: 'Ana Un', dlat: 0.05, total: 120),
        _app('a2', name: 'Bob Deux', dlat: 0.05, total: 120),
      ]);
      expect(k('cand2610_card_a1'), findsOneWidget);
      expect(k('cand2610_card_a2'), findsOneWidget);
      expect(find.byType(CandBadge645, skipOffstage: false), findsNothing);
      expect(k('cand645_detail_a1'), findsNothing, reason: 'pas de quantité → pas de détail');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final size in const <Size>[Size(375, 667), Size(320, 568), Size(768, 1024)]) {
      for (final scale in const <double>[1.0, 1.5]) {
        testWidgets('${size.width.toInt()}×${size.height.toInt()}, caractères ×$scale : aucun débordement avec les deux pastilles sur la même carte',
            timeout: const Timeout(Duration(minutes: 2)), (tester) async {
          await open(tester, [
            _app('top', name: 'Maximilienne Dupont-Lefebvre', dlat: 0.02,
                pricing: {'totalPrice': 1184.85, 'appliedRate': 14, 'quantity': 11, 'unit': 'night', 'currency': 'EUR', 'weeklyApplied': true}),
            _app('autre', name: 'Tom Petit', dlat: 0.2, total: 2000),
          ], width: size.width, height: size.height, textScale: scale);
          expect(k('cand645_closest_top'), findsOneWidget);
          expect(k('cand645_cheapest_top'), findsOneWidget);
          expect(k('cand645_detail_top'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  });
}
