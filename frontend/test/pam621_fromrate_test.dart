// 621 (PAM, 24/10/2026 — serveur 620b de ZOE) :
//   · « à partir de {fromRate} €/{unit} · estimation ~{ownerTotalFrom} € » sur
//     une demande ouverte (formulaire, Mes annonces, détail, PawMap) ;
//   · candidatures « tarif à venir » (`pricing.stale`) : libellé, Choisir
//     verrouillé avec explication, bandeau dédié (jamais « Pose tes dates ») ;
//   · notification `application_service_changed` → écran Tarifs du prestataire ;
//   · i18n 8 clés × 9 langues.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/v565/dates620_i18n.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/models/nearby_request_model.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/dates620.dart';
import 'package:hopetsit/utils/from_rate620.dart';
import 'package:hopetsit/utils/services620.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/dates620_candidates.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_candidates_sheet.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/widgets/dates620_widgets.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_post_card.dart';

import 'lotd_harness.dart';

/// Réponse RÉELLE de `POST /pricing/estimate` sans prestataire (preuve ZOE
/// `preuves/zoe620b/preuve_a3.json`, 24/10) : 3 visites, 1 gardien à 12 €.
const Map<String, dynamic> kMarketDated = <String, dynamic>{
  'serviceType': 'home_visit',
  'dateMode': 'exact',
  'indicative': true,
  'fromRate': 12,
  'unit': 'visit',
  'quantity': 3,
  'ownerTotalFrom': 43.2,
  'basedOn': 1,
  'currency': 'EUR',
  'durationMinutes': 30,
  'radiusKm': 100,
  'rateSource': 'market',
  'unitRate': 12,
  'unitTotal': null,
  'commission': null,
  'ownerTotal': null,
};

const Map<String, dynamic> kMarketTbd = <String, dynamic>{
  'serviceType': 'home_visit',
  'dateMode': 'tbd',
  'indicative': true,
  'fromRate': 12,
  'unit': 'visit',
  'quantity': null,
  'ownerTotalFrom': null,
  'basedOn': 1,
  'currency': 'EUR',
  'rateSource': 'market',
  'unitRate': 12,
};

const Map<String, dynamic> kMarketNobody = <String, dynamic>{
  'serviceType': 'home_visit',
  'dateMode': 'exact',
  'indicative': true,
  'fromRate': null,
  'unit': 'visit',
  'quantity': 3,
  'ownerTotalFrom': null,
  'basedOn': 0,
  'currency': 'EUR',
  'rateSource': 'market',
  'unitRate': null,
};

PostModel _post(Map<String, dynamic> extra) => PostModel.fromJson(<String, dynamic>{
      'id': 'p1',
      'postType': 'request',
      'body': 'x',
      'serviceTypes': ['home_visit'],
      'dateMode': 'exact',
      'startDate': '2026-11-03T00:00:00.000Z',
      'endDate': '2026-11-05T00:00:00.000Z',
      'visitsPerDay': 1,
      'location': {'city': 'Zone test', 'lat': -35.2, 'lng': -30.4},
      'notes': '',
      'images': [],
      'videos': [],
      'likes': [],
      'comments': [],
      'owner': {'id': 'o1', 'name': 'Camille', 'email': '', 'avatar': ''},
      'pets': [],
      ...extra,
    });

Map<String, dynamic> _appJson(String id, String name, Map<String, dynamic> pricing) =>
    <String, dynamic>{
      'id': id,
      'postId': 'p1',
      'status': 'pending',
      'createdAt': '2026-10-24T10:00:00Z',
      'description': 'Je passe nourrir votre chat.',
      'serviceLocation': 'at_owner',
      'sitter': {
        'id': 's-$id',
        'name': name,
        'currency': 'EUR',
        'rating': 4.8,
        'reviewsCount': 3,
        'verified': true,
        'location': {'city': 'Zone test'},
        'avatar': {'url': ''},
      },
      'pricing': pricing,
    };

/// Candidature « tarif à venir » telle que le serveur 620b l'écrit
/// (`applicationRepricing620.js`, branche `stale`).
const Map<String, dynamic> kStalePricing = <String, dynamic>{
  'appliedRate': 0,
  'unit': 'visit',
  'indicative': true,
  'stale': true,
  'totalPrice': null,
  'commission': null,
  'netPayout': null,
  'basePrice': null,
  'quantity': null,
  'currency': 'EUR',
  'pricingTier': 'indicative',
};

const Map<String, dynamic> kPricedPricing = <String, dynamic>{
  'indicative': false,
  'pricingTier': 'visit',
  'unitRate': 12,
  'unit': 'visit',
  'quantity': 6,
  'basePrice': 72,
  'commission': 14.4,
  'totalPrice': 86.4,
  'netPayout': 72,
  'currency': 'EUR',
};

String _eur(double v) => CurrencyHelper.formatCompact('EUR', v);

void main() {
  setUpAll(() {
    Get.testMode = true;
    Get.addTranslations(<String, Map<String, String>>{
      'fr_FR': dates620I18n['fr']!,
      'en_US': dates620I18n['en']!,
    });
    Get.locale = const Locale('fr', 'FR');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  group('i18n 621', () {
    test('8 clés × 9 langues, jamais vides, mêmes jetons', () {
      const langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
      const keys = [
        'dates620_from_rate',
        'dates620_from_rate_total',
        'dates620_from_rate_value_total',
        'dates620_from_rate_field',
        'dates620_stale_label',
        'dates620_stale_explain',
        'dates620_stale_banner',
        'dates620_stale_banner_sub',
        'dates620_rates_from_notif',
      ];
      final tokens = RegExp(r'@[a-z]+');
      for (final l in langs) {
        for (final k in keys) {
          final v = dates620I18n[l]![k];
          expect(v, isNotNull, reason: '$l.$k');
          expect(v!.trim(), isNotEmpty, reason: '$l.$k');
          final en = tokens.allMatches(dates620I18n['en']![k]!).map((m) => m.group(0)).toSet();
          final mine = tokens.allMatches(v).map((m) => m.group(0)).toSet();
          expect(mine, en, reason: '$l.$k jetons');
        }
      }
      expect(dates620I18n['en']!.length, 67);
    });
  });

  group('réponse « market » du moteur de prix', () {
    test('datée : fromRate 12, 3 visites, ownerTotalFrom 43,20, basedOn 1', () {
      final e = PricingEstimate620.tryParse(kMarketDated)!;
      expect(e.market, isTrue);
      expect(e.indicative, isTrue);
      expect(e.fromRate, 12);
      expect(e.ownerTotalFrom, 43.2);
      expect(e.basedOn, 1);
      expect(e.quantity, 3);
      expect(e.unit, ServiceUnit620.visit);
      expect(e.hasFromRate, isTrue);
      expect(e.hasFromTotal, isTrue);
      final t = fromRateText620(e);
      expect(t, contains(_eur(12)));
      expect(t, contains(_eur(43.2)));
      expect(t, startsWith('à partir de'));
      expect(t, contains('/visite'));
      expect(t, contains('estimation'));
      expect(estimateText620(e, tbd: false), t);
      // Case étiquetée « À partir de » : valeur sans le préfixe.
      final v = fromRateValueText620(e);
      expect(v, startsWith(_eur(12)));
      expect(v, contains(_eur(43.2)));
      expect(v, isNot(contains('à partir')));
    });

    test('à prévoir : « à partir de 12 €/visite » seul', () {
      final e = PricingEstimate620.tryParse(kMarketTbd)!;
      expect(e.hasFromRate, isTrue);
      expect(e.hasFromTotal, isFalse);
      final t = fromRateText620(e);
      expect(t, 'à partir de ${_eur(12)}/visite');
      expect(estimateText620(e, tbd: true), t);
      expect(fromRateValueText620(e), '${_eur(12)}/visite');
    });

    test('aucun prestataire (basedOn 0) : rien ; le formulaire garde ses textes', () {
      final e = PricingEstimate620.tryParse(kMarketNobody)!;
      expect(e.market, isTrue);
      expect(e.hasFromRate, isFalse);
      expect(fromRateText620(e), '');
      // formulaire daté : « 3 visites · le total dépend du tarif du candidat »
      expect(estimateText620(e, tbd: false), contains('3 visites'));
      // à prévoir : « Tarif affiché à l'unité… »
      expect(estimateText620(e, tbd: true), 'dates620_estimate_tbd'.tr);
    });

    test('ancien serveur (sans fromRate) : lecture inchangée', () {
      final e = PricingEstimate620.tryParse(<String, dynamic>{
        'indicative': false, 'quantity': 6, 'unit': 'visit', 'unitRate': 12,
        'unitTotal': 72, 'commission': 14.4, 'ownerTotal': 86.4, 'currency': 'EUR',
      })!;
      expect(e.market, isFalse);
      expect(e.hasFromRate, isFalse);
      expect(e.hasTotal, isTrue);
      expect(estimateText620(e, tbd: false), contains(_eur(86.4)));
      expect(fromRateText620(null), '');
    });
  });

  group('corps envoyé pour une demande ouverte', () {
    test('position de la demande, jamais de rate ni de providerId', () {
      final body = fromRateBodyForPost620(_post(const {}))!;
      expect(body.containsKey('rate'), isFalse);
      expect(body.containsKey('providerId'), isFalse);
      expect(body['serviceType'], 'home_visit');
      final post = body['post'] as Map;
      expect(post['dateMode'], 'exact');
      expect(post['visitsPerDay'], 1);
      expect((post['location'] as Map)['lat'], -35.2);
      expect((post['location'] as Map)['lng'], -30.4);
      expect((post['location'] as Map)['city'], 'Zone test');
      expect(post['startDate'], isNotNull);
    });

    test('demande réservée : aucun appel ; à prévoir : dateMode tbd sans dates', () {
      expect(
          fromRateBodyForPost620(_post({
            'reservedBy': {'bookingId': 'b1', 'providerRole': 'sitter', 'providerId': 's1'},
          })),
          isNull);
      final body = fromRateBodyForPost620(_post({'dateMode': 'tbd', 'startDate': null, 'endDate': null}))!;
      expect((body['post'] as Map)['dateMode'], 'tbd');
      expect((body['post'] as Map)['startDate'], isNull);
    });

    test('bulle PawMap : dateMode / visitsPerDay lus, « dates à prévoir »', () {
      final r = NearbyRequestPost.fromJson(<String, dynamic>{
        'id': 'p9', 'ownerId': 'o1', 'ownerName': 'Camille', 'serviceTypes': ['home_visit'],
        'dateMode': 'tbd', 'visitsPerDay': 2,
        'location': {'city': 'Zone test', 'lat': -35.2, 'lng': -30.4},
      });
      expect(r.isDatesTbd, isTrue);
      expect(r.visitsPerDay, 2);
      final body = fromRateBodyForNearby620(r)!;
      expect((body['post'] as Map)['dateMode'], 'tbd');
      expect((body['post'] as Map)['visitsPerDay'], 2);
      expect(body.containsKey('rate'), isFalse);
      // Une bulle 619 (sans dateMode) avec deux dates n'est pas « à prévoir ».
      final old = NearbyRequestPost.fromJson(<String, dynamic>{
        'id': 'p8', 'serviceTypes': ['house_sitting'],
        'startDate': '2026-11-03T00:00:00Z', 'endDate': '2026-11-05T00:00:00Z',
        'location': {'city': 'Zone test', 'lat': -35.2, 'lng': -30.4},
      });
      expect(old.isDatesTbd, isFalse);
    });

    test('empreinte : les dates posées changent la clé de cache', () {
      final a = _post(const {});
      final b = _post({'endDate': '2026-11-06T00:00:00.000Z'});
      final ka = fromRateKey620(a.id, fromRateBodyForPost620(a)!);
      final kb = fromRateKey620(b.id, fromRateBodyForPost620(b)!);
      expect(ka, isNot(kb));
      expect(fromRateKey620(a.id, fromRateBodyForPost620(a)!), ka);
    });
  });

  group('candidatures « tarif à venir »', () {
    test('BookingPricing.stale lu ; helpers', () {
      final p = BookingPricing.fromJson(kStalePricing);
      expect(p.stale, isTrue);
      expect(p.indicative, isTrue);
      expect(p.unitRate, isNull);
      final stale = ApplicationModel.fromJson(_appJson('a1', 'Léa', kStalePricing));
      final priced = ApplicationModel.fromJson(_appJson('a2', 'Tom', kPricedPricing));
      final tbd = ApplicationModel.fromJson(_appJson('a3', 'Ana', const {
        'indicative': true, 'pricingTier': 'indicative', 'unitRate': 14, 'unit': 'visit', 'currency': 'EUR',
      }));
      expect(applicationIsStale620(stale), isTrue);
      expect(applicationIsIndicative620(stale), isTrue);
      expect(applicationNeedsDates620(stale), isFalse, reason: 'stale ≠ dates manquantes');
      expect(applicationNeedsDates620(tbd), isTrue);
      expect(applicationIsStale620(priced), isFalse);
      expect(candidatePriceLabel620(stale), 'Tarif à venir');
      expect(candidatePriceLabel620(priced), _eur(86.4));
      expect(candidatePriceLabel620(tbd), contains('indicatif'));
      expect(BookingPricing.fromJson(kPricedPricing).stale, isFalse);
    });

    // ⚠️ `lotdSetUp` DOIT tourner dans `setUp` (hors de la zone FakeAsync du
    // test) : appelé dans le corps du test, ses lectures de fichiers ne se
    // terminent jamais → délai de 10 min (mesuré le 24/10).
    setUp(() async {
      await lotdSetUp(role: 'owner');
      // `Get.reset()` d'un test précédent a vidé les traductions.
      Get.addTranslations(<String, Map<String, String>>{
        'fr_FR': dates620I18n['fr']!,
        'en_US': dates620I18n['en']!,
      });
      Get.locale = const Locale('fr', 'FR');
    });
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    testWidgets('feuille des candidats : bandeau « Tarif à venir », pas « Pose tes dates », Choisir verrouillé, 0 appel /respond',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      lotdResponder = (req) {
        if (req.url.path.endsWith('/applications/my')) {
          return <String, dynamic>{
            'applications': [
              _appJson('a1', 'Léa Martin', kStalePricing),
              _appJson('a2', 'Tom Petit', kPricedPricing),
            ],
          };
        }
        return <String, dynamic>{};
      };
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(Builder(builder: (ctx) {
        return Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open_sheet'),
              onPressed: () => PostCandidatesSheet.show(context: ctx, postId: 'p1'),
              child: const Text('ouvrir'),
            ),
          ),
        );
      })));
      await lotdSettle(tester);
      await tester.tap(find.byKey(const Key('open_sheet')));
      await lotdSettle(tester, frames: 12);
      expect(find.byKey(const Key('dates620_stale_banner')), findsOneWidget);
      expect(find.byKey(const Key('dates620_set_dates_banner')), findsNothing,
          reason: 'la demande a ses dates : on ne demande pas de les poser');
      expect(find.text('Tarif à venir'), findsWidgets);
      expect(find.text(_eur(86.4)), findsOneWidget, reason: 'Tom garde son total');
      // Choisir du candidat « tarif à venir » : explication, aucun appel serveur.
      final before = lotdRequests.where((r) => r.path.contains('/respond')).length;
      await tester.tap(find.byKey(const Key('dates620_choose_a1')));
      await lotdSettle(tester, frames: 6);
      expect(lotdRequests.where((r) => r.path.contains('/respond')).length, before);
      // Aucun dialogue « Choisir ce gardien » : la candidature n'est pas choisissable.
      expect(find.text('candidates_choose_dialog_title'.tr), findsNothing);
      // La bannière d'explication (Overlay racine) est prouvée à l'écran par la
      // sonde simulateur (`preuves/pam621/05b_…`), le harnais ne la rend pas.
      debugPrint('[621] bannière rendue ici : ${find.textContaining('pas encore de tarif').evaluate().isNotEmpty}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('notifications → écrans', () {
    test('application_service_changed → Tarifs (prestataire) ; pricing_updated → la demande', () {
      const id = '6ac29d319910ac6c3c49da24';
      expect(DeepLinkService.routeForNotification('application_service_changed', {'postId': id}, role: 'sitter'),
          '/rates');
      expect(DeepLinkService.routeForNotification('application_service_changed', {'postId': id}, role: 'walker'),
          '/rates');
      expect(DeepLinkService.routeForNotification('application_service_changed', {'postId': id}, role: 'owner'),
          '/post/$id');
      expect(DeepLinkService.routeForNotification('application_pricing_updated', {'postId': id}, role: 'owner'),
          '/post/$id');
      expect(DeepLinkService.routeForNotification('post_dates_required', {'postId': id}, role: 'owner'),
          '/post/$id');
    });
  });

  group('« à partir de » dans les écrans (harnais lot D)', () {
    setUp(() async {
      await lotdSetUp(role: 'owner');
      FromRateCache620.reset();
    });
    tearDown(() async {
      FromRateCache620.reset();
      await Get.deleteAll(force: true);
      Get.reset();
    });

    testWidgets('carte d\'annonce : case « À partir de » quand le serveur répond, absente sinon',
        (tester) async {
      lotdResponder = (req) => req.url.path.endsWith('/pricing/estimate') ? kMarketDated : <String, dynamic>{};
      lotdPhone(tester);
      final post = _post(const {});
      await tester.pumpWidget(lotdApp(Scaffold(
        body: SingleChildScrollView(
          child: FromRate620Builder(
            future: FromRateCache620.forPost(post),
            builder: (ctx, label) => PetPostCard(
              userName: 'Camille',
              userEmail: '',
              petImages: const <String>[],
              isNetworkImage: false,
              likeCount: 0,
              commentCount: 0,
              // La grille Dates / Lieu / … n'existe qu'avec un contenu de demande.
              dateRange: '03/11/2026 → 05/11/2026',
              serviceTypes: 'home_visit',
              location: 'Zone test',
              fromRateLabel: label,
              ownerViewOfOwnPost: true,
            ),
          ),
        ),
      )));
      await lotdSettle(tester, frames: 8);
      expect(find.text('À partir de'), findsOneWidget);
      expect(find.textContaining(_eur(43.2)), findsOneWidget);
      final calls = lotdRequests.where((r) => r.path.endsWith('/pricing/estimate')).toList();
      expect(calls.length, 1);
      expect(calls.first.body!.containsKey('rate'), isFalse);
      expect(calls.first.body!.containsKey('providerId'), isFalse);
      expect(tester.takeException(), isNull);

      // Même demande, 2e écran : le cache répond, aucun 2e appel.
      await tester.pumpWidget(lotdApp(Scaffold(
        body: FromRateLine620(future: FromRateCache620.forPost(post)),
      )));
      await lotdSettle(tester, frames: 4);
      expect(find.byKey(const Key('dates620_from_rate_line')), findsOneWidget);
      expect(lotdRequests.where((r) => r.path.endsWith('/pricing/estimate')).length, 1);
    });

    testWidgets('aucun prestataire (basedOn 0) : rien n\'est affiché', (tester) async {
      lotdResponder = (req) => req.url.path.endsWith('/pricing/estimate') ? kMarketNobody : <String, dynamic>{};
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(Scaffold(
        body: FromRateLine620(future: FromRateCache620.forPost(_post(const {}))),
      )));
      await lotdSettle(tester, frames: 6);
      expect(find.byKey(const Key('dates620_from_rate_line')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ancien serveur (réponse sans fromRate) : rien, aucune exception', (tester) async {
      lotdResponder = (req) => <String, dynamic>{'message': 'RATE_REQUIRED'};
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(Scaffold(
        body: FromRateLine620(future: FromRateCache620.forPost(_post(const {}))),
      )));
      await lotdSettle(tester, frames: 6);
      expect(find.byKey(const Key('dates620_from_rate_line')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
