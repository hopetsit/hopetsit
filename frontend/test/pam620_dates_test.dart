// 620 (PAM, 24/10/2026 — contrat CONTRAT_620_dates_visites.md §C) :
//   · catalogue des services (4 depuis le serveur, repli sur les 3 actuels) ;
//   · « Publier ma demande » : 3 modes de dates, visites par jour, demande
//     adressée depuis la PawMap, estimation via POST /pricing/estimate ;
//   · candidatures indicatives (tarif unitaire, Choisir verrouillé) ;
//   · prix « à partir de X €/visite » sur la PawMap ;
//   · images réseau : repli, erreur classée non fatale ;
//   · i18n : 9 langues, 0 manquante.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/controllers/sign_up_controller.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/utils/rate_grid620.dart';
import 'package:hopetsit/views/auth/signup_wizard_screen.dart';
import 'package:hopetsit/localization/v565/dates620_i18n.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/dates620.dart';
import 'package:hopetsit/utils/post_date_label.dart';
import 'package:hopetsit/utils/services620.dart';
import 'package:hopetsit/views/map/pawmap_person.dart';
import 'package:hopetsit/views/map/pawmap_rates.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/dates620_candidates.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/widgets/dates620_widgets.dart';
import 'package:hopetsit/widgets/city_location_picker.dart';
import 'package:hopetsit/widgets/net_image620.dart';

import 'lotd_harness.dart';

/// Réponse `GET /app-config/services` du contrat (§A.2), 4 services.
const Map<String, dynamic> kCatalogResponse = <String, dynamic>{
  'services': <Map<String, dynamic>>[
    {'key': 'house_sitting', 'unit': 'day', 'labels': {'fr': 'Garde', 'en': 'Boarding'}},
    {
      'key': 'home_visit',
      'unit': 'visit',
      'durations': [30, 60],
      'visitsPerDay': [1, 2],
      'labels': {'fr': 'Visite à domicile', 'en': 'Home visit'},
    },
    {'key': 'day_care', 'unit': 'day', 'labels': {'fr': 'Garderie', 'en': 'Day care'}},
    {'key': 'dog_walking', 'unit': 'walk', 'labels': {'fr': 'Promenade', 'en': 'Dog walking'}},
  ],
};

PostModel _post(Map<String, dynamic> extra) => PostModel.fromJson(<String, dynamic>{
      'id': 'p1',
      'postType': 'request',
      'body': 'x',
      'serviceTypes': ['home_visit'],
      'notes': '',
      'images': [],
      'videos': [],
      'likes': [],
      'comments': [],
      'owner': {'id': 'o1', 'name': 'Camille', 'email': '', 'avatar': ''},
      'pets': [],
      ...extra,
    });

ApplicationModel _app(Map<String, dynamic> pricing, {String role = 'sitter'}) =>
    ApplicationModel.fromJson(<String, dynamic>{
      'id': 'a1',
      'postId': 'p1',
      'status': 'pending',
      role: {'id': 's1', 'name': 'Léa Martin', 'currency': 'EUR'},
      'pricing': pricing,
    });

String _eur(double v) => CurrencyHelper.formatCompact('EUR', v);

/// Fait défiler jusqu'à la clé puis l'appuie (le formulaire est long).
Future<void> _tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await t.scrollUntilVisible(f, 160, scrollable: find.byType(Scrollable).first);
  await lotdSettle(t);
  await t.tap(f);
  await lotdSettle(t);
}

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

  group('i18n 620', () {
    test('58 clés, 9 langues, jamais vides, mêmes jetons', () {
      const langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
      final keys = dates620I18n['en']!.keys.toSet();
      expect(keys.length, 58);
      final ph = RegExp(r'@\w+');
      for (final l in langs) {
        expect(dates620I18n[l]?.keys.toSet(), keys, reason: l);
        for (final k in keys) {
          final v = dates620I18n[l]![k]!;
          expect(v.trim().isNotEmpty, isTrue, reason: '$l $k');
          expect(ph.allMatches(v).map((m) => m.group(0)).toSet(),
              ph.allMatches(dates620I18n['en']![k]!).map((m) => m.group(0)).toSet(),
              reason: '$l $k');
        }
      }
    });
  });

  group('catalogue des services', () {
    test('réponse RÉELLE du serveur (liste `all`, label/desc 9 langues) → langue du téléphone', () {
      // Extrait de GET /app-config/services relevé le 24/10/2026 (banc).
      final live = <String, dynamic>{
        'services': [
          {'key': 'house_sitting', 'unit': 'day'},
          {'key': 'home_visit', 'unit': 'visit', 'durations': [30, 60], 'visitsPerDay': [1, 2]},
          {'key': 'day_care', 'unit': 'day'},
          {'key': 'dog_walking', 'unit': 'walk'},
        ],
        'all': [
          {'key': 'house_sitting', 'unit': 'day', 'active': true, 'label': {'fr': 'Garde à domicile', 'en': 'House sitting', 'de': 'Betreuung zu Hause', 'pt': 'Cuidado ao domicílio', 'ja': '在宅ペットシッティング'}, 'desc': {'fr': 'Un gardien chez vous ou chez lui.'}},
          {'key': 'home_visit', 'unit': 'visit', 'active': true, 'durations': [30, 60], 'visitsPerDay': [1, 2], 'label': {'fr': 'Visite à domicile', 'en': 'Home visit', 'de': 'Hausbesuch', 'pt': 'Visita ao domicílio', 'ko': '방문 돌봄'}, 'desc': {'fr': 'Le gardien passe chez vous, 1 ou 2 fois par jour, 30 ou 60 min. Prix par visite.', 'de': 'Der Sitter kommt zu Ihnen.'}},
          {'key': 'day_care', 'unit': 'day', 'active': true, 'label': {'fr': 'Garderie', 'en': 'Day care', 'de': 'Tagesbetreuung'}},
          {'key': 'dog_walking', 'unit': 'walk', 'active': true, 'label': {'fr': 'Promenade', 'en': 'Dog walking', 'de': 'Gassi gehen'}},
          {'key': 'grooming', 'unit': 'day', 'active': false, 'label': {'fr': 'Toilettage'}},
        ],
        'dateModes': ['exact', 'approx', 'tbd'],
      };
      final list = ServiceCatalog620.parse(live)!;
      expect(list.map((s) => s.key).toList(), ['dog_walking', 'day_care', 'house_sitting', 'home_visit'],
          reason: 'service inactif écarté, ordre du contrat');
      ServiceCatalog620.apply(list);
      expect(ServiceCatalog620.label('home_visit', lang: 'de'), 'Hausbesuch');
      expect(ServiceCatalog620.label('home_visit', lang: 'pt'), 'Visita ao domicílio');
      expect(ServiceCatalog620.label('home_visit', lang: 'ko'), '방문 돌봄');
      expect(ServiceCatalog620.label('pet_sitting', lang: 'ja'), '在宅ペットシッティング');
      expect(ServiceCatalog620.label('home_visit', lang: 'pl'), 'Home visit', reason: 'langue absente → anglais');
      expect(ServiceCatalog620.description('home_visit', lang: 'de'), 'Der Sitter kommt zu Ihnen.');
      expect(ServiceCatalog620.byKey('home_visit')!.visitsPerDay, [1, 2]);
      ServiceCatalog620.reset();
    });

    setUp(ServiceCatalog620.reset);
    tearDown(ServiceCatalog620.reset);

    test('repli = les 3 services actuels, sans visite à domicile', () {
      expect(ServiceCatalog620.services.map((s) => s.key).toList(),
          ['dog_walking', 'day_care', 'house_sitting']);
      expect(ServiceCatalog620.hasHomeVisit, isFalse);
      expect(ServiceCatalog620.fromServer.value, isFalse);
    });

    test('réponse serveur : 4 services dans l\'ordre du contrat, unités', () {
      final list = ServiceCatalog620.parse(kCatalogResponse)!;
      expect(list.map((s) => s.key).toList(),
          ['dog_walking', 'day_care', 'house_sitting', 'home_visit']);
      ServiceCatalog620.apply(list);
      expect(ServiceCatalog620.hasHomeVisit, isTrue);
      expect(ServiceCatalog620.unitFor('home_visit'), ServiceUnit620.visit);
      expect(ServiceCatalog620.unitFor('pet_sitting'), ServiceUnit620.day);
      expect(ServiceCatalog620.unitFor('dog_walking'), ServiceUnit620.walk);
      expect(ServiceCatalog620.byKey('home_visit')!.visitsPerDay, [1, 2]);
      expect(ServiceCatalog620.byKey('home_visit')!.durations, [30, 60]);
      // Libellé du serveur dans la langue de l'app.
      expect(ServiceCatalog620.label('home_visit', lang: 'fr'), 'Visite à domicile');
      expect(ServiceCatalog620.label('pet_sitting', lang: 'en'), 'Boarding');
    });

    test('réponse inexploitable (404, vide, inconnue) → null = repli gardé', () {
      expect(ServiceCatalog620.parse(null), isNull);
      expect(ServiceCatalog620.parse(<String, dynamic>{}), isNull);
      expect(ServiceCatalog620.parse({'services': [{'key': 'grooming', 'unit': 'day'}]}), isNull);
    });

    test('clés : pet_sitting (app) ↔ house_sitting (catalogue)', () {
      expect(ServiceCatalog620.appValueFor('house_sitting'), 'pet_sitting');
      expect(ServiceCatalog620.catalogKeyFor('pet_sitting'), 'house_sitting');
      expect(ServiceCatalog620.catalogKeyFor('home_visit'), 'home_visit');
    });

    test('« 12 €/visite », « 1 visite » / « 5 visites », suffixes serveur', () {
      expect(priceWithUnit620('12 €', ServiceUnit620.visit), '12 €/visite');
      expect(priceWithUnit620('18 €', ServiceUnit620.day), '18 €/jour');
      expect(priceWithUnit620('20 €', ServiceUnit620.day, night: true), '20 €/nuit');
      expect(quantityLabel620(1, ServiceUnit620.visit), '1 visite');
      expect(quantityLabel620(5, ServiceUnit620.visit), '5 visites');
      expect(quantityLabel620(2, ServiceUnit620.day, night: true), '2 nuits');
      expect(quantityLabel620(1, ServiceUnit620.walk), '1 balade');
      expect(priceUnitSuffix620('visit'), '/visite');
      expect(priceUnitSuffix620('walk'), '/balade');
      expect(priceUnitSuffix620('day'), '/jour');
      expect(priceUnitSuffix620(''), '');
    });
  });

  group('dates à prévoir — modèle et moteur', () {
    test('dateMode : défaut exact avec 2 dates, tbd sans', () {
      expect(dateMode620Parse(null, start: DateTime(2026), end: DateTime(2026)), DateMode620.exact);
      expect(dateMode620Parse(null), DateMode620.tbd);
      expect(dateMode620Parse('approx'), DateMode620.approx);
      final p = _post({'startDate': '2026-11-03T08:00:00Z', 'endDate': '2026-11-05T20:00:00Z'});
      expect(p.dateMode, 'exact');
      expect(_post({}).isDatesTbd, isTrue);
      expect(_post({'dateMode': 'tbd', 'visitsPerDay': 2}).visitsPerDay, 2);
    });

    test('libellés de carte : « Dates à prévoir », « Environ du … au … »', () {
      expect(PostDateLabel.dateOnly(_post({})), 'Dates à prévoir');
      expect(PostDateLabel.timeLabel(_post({})), '');
      final a = _post({'dateMode': 'approx', 'startDate': '2026-11-03T08:00:00Z', 'endDate': '2026-11-05T20:00:00Z'});
      expect(PostDateLabel.dateOnly(a), startsWith('Environ du 03/11/2026 au 05/11/2026'));
      expect(PostDateLabel.timeLabel(a), '');
    });

    test('corps de POST /pricing/estimate : tbd sans dates, visites par jour', () {
      final b = estimateBody620(
        serviceType: 'home_visit',
        dateMode: DateMode620.tbd,
        startDate: DateTime(2026, 11, 3),
        endDate: DateTime(2026, 11, 5),
        visitsPerDay: 2,
        rate: 12,
      );
      expect(b['serviceType'], 'home_visit');
      expect(b.containsKey('unit'), isFalse, reason: 'le moteur choisit l\'unité');
      expect(b['rate'], 12);
      expect(b['dateMode'], 'tbd');
      expect(b['startDate'], isNull);
      expect((b['post'] as Map)['visitsPerDay'], 2);
      final e = estimateBody620(
        serviceType: 'pet_sitting',
        dateMode: DateMode620.exact,
        startDate: DateTime(2026, 11, 3, 8),
        endDate: DateTime(2026, 11, 5, 20),
      );
      expect(e['serviceType'], 'house_sitting');
      expect(e.containsKey('rate'), isFalse);
      expect(e['startDate'], isNotNull);
      expect((e['post'] as Map).containsKey('visitsPerDay'), isFalse);
    });

    test('réponse du moteur : total réel, ou indicatif en tbd', () {
      final e = PricingEstimate620.tryParse({
        'quantity': 5, 'unitTotal': 60, 'commission': 12, 'ownerTotal': 72,
        'indicative': false, 'currency': 'EUR', 'unit': 'visit',
      })!;
      expect(e.hasTotal, isTrue);
      expect(estimateText620(e, tbd: false), 'Environ ${_eur(72)} pour 5 visites');
      final i = PricingEstimate620.tryParse({'indicative': true, 'quantity': null, 'ownerTotal': null})!;
      expect(i.indicative, isTrue);
      expect(estimateText620(i, tbd: true), 'Tarif affiché à l\'unité, total une fois tes dates posées');
      final q = PricingEstimate620.tryParse({'quantity': 3, 'unit': 'night', 'indicative': false})!;
      expect(estimateText620(q, tbd: false), '3 nuits · le total dépend du tarif du candidat');
      expect(PricingEstimate620.tryParse('nope'), isNull);
    });

    test('prestataire visé : un service sans tarif n\'est pas proposé', () {
      const s = TargetProvider620(id: 's1', role: 'sitter', name: 'Léa Martin', rateVisit: 12);
      expect(s.offers('home_visit'), isTrue);
      expect(s.offers('pet_sitting'), isFalse, reason: 'aucun tarif jour');
      expect(s.offers('dog_walking'), isFalse, reason: 'un gardien ne promène pas');
      expect(s.rateFor('home_visit'), 12);
      expect(s.firstName, 'Léa');
      expect(s.wire, {'role': 'sitter', 'id': 's1'});
      const w = TargetProvider620(id: 'w1', role: 'walker', rateWalk: 10);
      expect(w.offers('dog_walking'), isTrue);
      expect(w.offers('home_visit'), isFalse);
      expect(targetRateLabel620(w, 'dog_walking'), '${_eur(10)}/balade');
    });
  });

  group('candidatures indicatives', () {
    test('« 12 €/visite · indicatif », total réel sinon, Choisir verrouillé', () {
      final ind = _app({'indicative': true, 'appliedRate': 12, 'unit': 'visit', 'currency': 'EUR', 'totalPrice': null});
      expect(applicationIsIndicative620(ind), isTrue);
      expect(candidatePriceLabel620(ind), '${_eur(12)}/visite · indicatif');
      final tier = _app({'pricingTier': 'indicative', 'basePrice': 18, 'currency': 'EUR'});
      expect(applicationIsIndicative620(tier), isTrue);
      expect(candidatePriceLabel620(tier), '${_eur(18)}/jour · indicatif');
      final real = _app({'totalPrice': 72, 'basePrice': 60, 'currency': 'EUR', 'pricingTier': 'visit', 'quantity': 5});
      expect(applicationIsIndicative620(real), isFalse);
      expect(candidatePriceLabel620(real), _eur(72));
      expect(isDatesRequiredError620('ApiException(statusCode: 409, message: DATES_REQUIRED)'), isTrue);
    });
  });

  group('PawMap — prix selon le service', () {
    test('« dès 12 €/visite » (priceUnit serveur), fiche : ligne Visite', () {
      String suffix(String u) => priceUnitSuffix620(u);
      expect(pawMapRolePriceText({'priceFrom': 12, 'priceUnit': 'visit', 'currency': 'EUR'},
          format: CurrencyHelper.formatCompact, unitSuffix: suffix), '${_eur(12)}/visite');
      expect(pawMapRolePriceText({'priceFrom': 18, 'priceUnit': 'day', 'currency': 'EUR'},
          format: CurrencyHelper.formatCompact, unitSuffix: suffix), '${_eur(18)}/jour');
      // Sans unité (ancien serveur) : le montant seul, comme avant.
      expect(pawMapRolePriceText({'priceFrom': 18, 'currency': 'EUR'},
          format: CurrencyHelper.formatCompact, unitSuffix: suffix), _eur(18));
      const r = PawProviderRates(currency: 'EUR', role: 'sitter', visit: 12, visitDurationMinutes: 30);
      expect(r.fromLabel, '${_eur(12)}/visite');
      expect(r.lines.single.label, 'Visite à domicile (30 min)');
      expect(r.lines.single.value, CurrencyHelper.format('EUR', 12));
      const none = PawProviderRates(currency: 'EUR', role: 'sitter');
      expect(none.fromLabel, isNull);
    });
  });

  group('images réseau', () {
    test('erreur d\'image = non fatale', () {
      expect(isNetworkImageError620(NetworkImageLoadException(statusCode: 404, uri: Uri.parse('https://x/y.jpg'))), isTrue);
      expect(isNetworkImageError620(Exception('HTTP request failed, statusCode: 401')), isTrue);
      expect(isNetworkImageError620(StateError('autre')), isFalse);
      expect(netImageProvider620(''), isNull);
      expect(netImageProvider620('https://x/y.jpg'), isNotNull);
    });

    testWidgets('photo morte → patte, aucune exception', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: SizedBox(width: 80, height: 80, child: NetImage620('https://127.0.0.1:9/dead.jpg'))));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(NetImageFallback620), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const MaterialApp(home: NetImage620('')));
      expect(find.byType(NetImageFallback620), findsOneWidget);
    });
  });

  group('« Publier ma demande » — contrôleur (harnais lot D)', () {
    setUp(() async {
      await lotdSetUp(role: 'owner');
      ServiceCatalog620.reset();
    });
    tearDown(() async {
      ServiceCatalog620.reset();
      await Get.deleteAll(force: true);
      Get.reset();
    });

    Future<PublishReservationRequestController> openForm(
      WidgetTester tester, {
      String? initial,
      TargetProvider620? target,
    }) async {
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(
        PublishReservationRequestScreen(initialServiceType: initial, targetProvider: target),
      ));
      await lotdSettle(tester);
      final c = Get.find<PublishReservationRequestController>();
      // Ville choisie (zone fictive), GPS précis : pas de code postal demandé.
      c.cityController.text = 'Zone test';
      markCityPicked610(c.cityController, 'Zone test');
      c.userLat.value = -35.2;
      c.userLng.value = -30.4;
      c.gpsPrecise.value = true;
      c.animalTypes.add('dog');
      return c;
    }

    testWidgets('sans catalogue serveur : 3 services, pas de visite', (tester) async {
      final c = await openForm(tester, initial: 'pet_sitting');
      expect(c.serviceTypes.map((t) => t['value']).toList(), ['dog_walking', 'day_care', 'pet_sitting']);
      expect(find.byKey(const Key('dates620_service_home_visit')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« dates à prévoir » : aucune date exigée, POST /posts sans dates + dateMode tbd',
        (tester) async {
      final c = await openForm(tester, initial: 'pet_sitting');
      c.serviceLocation.value = 'at_owner';
      expect(c.firstMissingField, 'startDate', reason: 'mode précis : la date manque');
      await _tapKey(tester, 'dates620_mode_tbd');
      expect(c.isDatesTbd, isTrue);
      expect(c.stepDatesDone, isTrue);
      expect(c.firstMissingField, isNull);
      expect(find.byKey(const Key('dates620_tbd_hint')), findsOneWidget);
      expect(c.datesSummaryLabel, 'À prévoir');
      await c.submit();
      await lotdSettle(tester);
      final req = lotdRequests.firstWhere((r) => r.method == 'POST' && r.path.endsWith('/posts'));
      expect(req.body!['dateMode'], 'tbd');
      expect(req.body!.containsKey('startDate'), isFalse);
      expect(req.body!.containsKey('endDate'), isFalse);
      expect(req.body!['serviceTypes'], ['pet_sitting']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('période approximative : 2 dates sans heure, heures par défaut envoyées', (tester) async {
      final c = await openForm(tester, initial: 'pet_sitting');
      c.serviceLocation.value = 'at_owner';
      await _tapKey(tester, 'dates620_mode_approx');
      expect(find.byKey(const Key('dates620_approx_start')), findsOneWidget);
      expect(c.firstMissingField, 'startDate');
      c.startDate.value = DateTime(2026, 11, 3);
      c.endDate.value = DateTime(2026, 11, 5);
      c.startTime.value = null;
      c.endTime.value = null;
      expect(c.firstMissingField, isNull, reason: 'pas d\'heure en approximatif');
      await c.submit();
      await lotdSettle(tester);
      final req = lotdRequests.firstWhere((r) => r.method == 'POST' && r.path.endsWith('/posts'));
      expect(req.body!['dateMode'], 'approx');
      expect(DateTime.parse(req.body!['startDate'] as String).toLocal().hour, 8);
      expect(DateTime.parse(req.body!['endDate'] as String).toLocal().hour, 20);
      expect(tester.takeException(), isNull);
    });

    testWidgets('catalogue serveur : visite à domicile, 1|2 visites par jour, estimation', (tester) async {
      Map<String, dynamic>? estimateBody;
      lotdResponder = (req) {
        if (req.url.path.endsWith('/app-config/services')) return kCatalogResponse;
        if (req.url.path.endsWith('/pricing/estimate')) {
          estimateBody = Map<String, dynamic>.from(
              (lotdRequests.last.body ?? const <String, dynamic>{}));
          return {'quantity': 6, 'unitTotal': 72, 'commission': 14.4, 'ownerTotal': 86.4,
                  'indicative': false, 'currency': 'EUR', 'unit': 'visit'};
        }
        return <String, dynamic>{};
      };
      final c = await openForm(tester);
      await ServiceCatalog620.load(force: true);
      await lotdSettle(tester);
      expect(ServiceCatalog620.hasHomeVisit, isTrue);
      expect(c.serviceTypes.map((t) => t['value']).toList(),
          ['dog_walking', 'day_care', 'pet_sitting', 'home_visit']);
      expect(find.byKey(const Key('dates620_service_home_visit')), findsOneWidget);
      await _tapKey(tester, 'dates620_service_home_visit');
      expect(c.isHomeVisit, isTrue);
      expect(c.serviceLocationDone, isTrue, reason: 'visites = chez moi, fixé');
      expect(find.byKey(const Key('dates620_visits_2')), findsOneWidget);
      await _tapKey(tester, 'dates620_visits_2');
      expect(c.visitsPerDay.value, 2);
      c.startDate.value = DateTime(2026, 11, 3);
      c.onDatesChanged();
      expect(c.endDate.value, DateTime(2026, 11, 3), reason: 'fin = début par défaut');
      c.endDate.value = DateTime(2026, 11, 5);
      await c.refreshEstimate();
      await lotdSettle(tester);
      expect(estimateBody, isNotNull);
      expect(estimateBody!['serviceType'], 'home_visit');
      expect((estimateBody!['post'] as Map)['visitsPerDay'], 2);
      expect(c.estimate.value?.ownerTotal, 86.4);
      expect(find.text('Environ ${_eur(86.4)} pour 6 visites'), findsWidgets);
      await c.submit();
      await lotdSettle(tester);
      final req = lotdRequests.firstWhere((r) => r.method == 'POST' && r.path.endsWith('/posts'));
      expect(req.body!['serviceTypes'], ['home_visit']);
      expect(req.body!['visitsPerDay'], 2);
      expect(req.body!['dateMode'], 'exact');
      expect(req.body!['serviceLocation'], 'at_owner');
      expect(tester.takeException(), isNull);
    });

    testWidgets('PawMap → « Demander à Léa » : même formulaire, services selon SES tarifs, targetProvider envoyé',
        (tester) async {
      lotdResponder = (req) {
        if (req.url.path.endsWith('/app-config/services')) return kCatalogResponse;
        if (req.url.path.endsWith('/pricing/estimate')) {
          return {'indicative': true};
        }
        return <String, dynamic>{};
      };
      const target = TargetProvider620(
          id: 's1', role: 'sitter', name: 'Léa Martin', currency: 'EUR',
          rateVisit: 12, visitDurationMinutes: 30);
      final c = await openForm(tester, initial: 'home_visit', target: target);
      await ServiceCatalog620.load(force: true);
      await lotdSettle(tester);
      expect(find.byKey(const Key('dates620_target_banner')), findsOneWidget);
      expect(find.textContaining('Léa'), findsWidgets);
      expect(c.serviceOffered('home_visit'), isTrue);
      expect(c.serviceOffered('pet_sitting'), isFalse);
      expect(c.serviceOffered('dog_walking'), isFalse);
      // Une carte non proposée ne se sélectionne pas.
      await _tapKey(tester, 'dates620_service_dog_walking');
      expect(c.selectedServiceType.value, 'home_visit');
      await _tapKey(tester, 'dates620_mode_tbd');
      expect(c.knownRate, 12);
      final body = c.estimateBodyForTest();
      expect(body['rate'], 12);
      expect(body['providerId'], 's1');
      expect(body['dateMode'], 'tbd');
      await c.submit();
      await lotdSettle(tester);
      final req = lotdRequests.firstWhere((r) => r.method == 'POST' && r.path.endsWith('/posts'));
      expect(req.body!['targetProvider'], {'role': 'sitter', 'id': 's1'});
      expect(req.body!['dateMode'], 'tbd');
      expect(req.body!['visitsPerDay'], 1);
      expect(req.body!['visitDurationMinutes'], 30);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« Modifier » une demande à prévoir → poser des dates : PATCH dateMode exact + dates',
        (tester) async {
      final post = _post({'dateMode': 'tbd', 'serviceTypes': ['pet_sitting'], 'location': {'city': 'Zone test', 'lat': -35.2, 'lng': -30.4}});
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(PublishReservationRequestScreen(editPost: post)));
      await lotdSettle(tester);
      final c = Get.find<PublishReservationRequestController>();
      expect(c.isDatesTbd, isTrue, reason: 'pré-rempli depuis l\'annonce');
      markCityPicked610(c.cityController, 'Zone test');
      c.gpsPrecise.value = true;
      c.animalTypes.add('dog');
      c.serviceLocation.value = 'at_owner';
      await _tapKey(tester, 'dates620_mode_exact');
      expect(c.isDatesTbd, isFalse);
      c.startDate.value = DateTime(2026, 11, 3);
      c.endDate.value = DateTime(2026, 11, 5);
      c.startTime.value = const TimeOfDay(hour: 9, minute: 0);
      c.endTime.value = const TimeOfDay(hour: 18, minute: 0);
      expect(c.firstMissingField, isNull);
      await c.submit();
      await lotdSettle(tester);
      final req = lotdRequests.firstWhere((r) => r.method == 'PATCH' && r.path.endsWith('/posts/p1'));
      expect(req.body!['dateMode'], 'exact');
      expect(req.body!['startDate'], isNotNull);
      expect(req.body!['endDate'], isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('inscription gardien — grille de tarifs par service (620)', () {
    setUp(() async => lotdSetUp(role: 'sitter'));
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    SignUpController ctrl() => SignUpController(
        userType: 'pet_sitter', authRepository: Get.find<AuthRepository>());

    test('defaultRateType et grille envoyée', () {
      expect(defaultRateType620(visit: 12), 'visit');
      expect(defaultRateType620(daily: 18, visit: 12), 'day');
      expect(defaultRateType620(hourly: 10), 'hour');
      final g = rateGridPayload620(daily: 18, visit: 12, visitDurationMinutes: 60);
      expect(g['visitRate'], 12);
      expect(g['visitDurationMinutes'], 60);
      expect(g['dailyRate'], 18);
      expect(g['defaultRateType'], 'day');
      final v = rateGridPayload620(visit: 12);
      expect(v.containsKey('dailyRate'), isFalse);
      expect(v['defaultRateType'], 'visit');
    });

    test('services cochés → cartes affichées, au moins un tarif parmi elles', () {
      final c = ctrl();
      expect(c.sitterOffersSitting, isTrue, reason: 'rien de coché : garde proposée');
      expect(c.sitterOffersVisit, isFalse);
      c.selectedServices.add('home_visit');
      expect(c.sitterOffersVisit, isTrue);
      expect(c.sitterOffersSitting, isFalse, reason: 'visite seule : pas de carte garde');
      c.selectedServices.add('sit_owner');
      expect(c.sitterOffersSitting, isTrue);
      // Étape tarifs : visite seule cochée → le tarif par visite suffit.
      c.selectedServices.remove('sit_owner');
      expect(c.validateStep(3), 'signup_error_rate_required');
      c.visitRateController.text = '12';
      expect(c.validateStep(3), isNull);
    });

    testWidgets('wizard : étape Tarifs = grille par service ; POST /auth/signup porte visitRate/visitDurationMinutes/defaultRateType',
        (tester) async {
      lotdPhone(tester);
      final c = Get.put(ctrl(), tag: 'pet_sitter', permanent: true);
      c.selectedServices.addAll(['home_visit', 'sit_owner']);
      c.currentStep.value = 3;
      await tester.pumpWidget(lotdApp(const SignupWizardScreen(userType: 'pet_sitter')));
      await lotdSettle(tester);
      expect(find.byKey(const Key('dates620_signup_visit_field')), findsOneWidget);
      expect(find.text('Tarif par visite'), findsOneWidget);
      expect(find.text('Garde — par jour ou par nuit'), findsOneWidget);
      c.selectedServices.remove('sit_owner');
      await lotdSettle(tester);
      expect(find.text('Garde — par jour ou par nuit'), findsNothing, reason: 'service non coché = carte absente');
      c.visitRateController.text = '12';
      c.selectVisitDuration(60);
      c.ratePerDayController.text = '18';
      // Données d'inscription (mêmes clés que le profil).
      c.firstNameController.text = 'Test';
      c.lastNameController.text = 'Gardien';
      c.emailController.text = 'dadaciao84+testgrille@gmail.com';
      c.passwordController.text = 'Hopetsit2026!';
      c.confirmPasswordController.text = 'Hopetsit2026!';
      c.cityController.text = 'Zone test';
      markCityPicked610(c.cityController, 'Zone test');
      c.postalCodeController.text = '97500';
      c.acceptedAnimals.add('cat');
      c.agreeToTerms.value = true;
      expect(c.validateStep1(), isNull, reason: 'étape 1 valide');
      expect(c.validateStep(3), isNull, reason: 'étape tarifs valide');
      // Données telles qu'envoyées à POST /auth/signup (même construction que
      // handleWizardSignUp, sans la navigation vers l'écran du code).
      final user = c.buildSignupPayload620();
      expect(user['visitRate'], 12);
      expect(user['visitDurationMinutes'], 60);
      expect(user['defaultRateType'], 'visit');
      expect(user.containsKey('dailyRate'), isFalse, reason: 'garde non cochée : pas de tarif jour');
      expect(user['service'], contains('home_visit'));
      await savePendingRateGrid620(c.pendingRateGrid620!);
      // Grille en attente → PUT /users/me/profile + PUT /sitters/me/rates dès qu'un jeton existe.
      final pushed = await pushPendingRateGrid620();
      expect(pushed, isTrue);
      final put = lotdRequests.firstWhere((r) => r.method == 'PUT' && r.path.endsWith('/users/me/profile'));
      expect(put.body!['visitRate'], 12);
      expect(put.body!['defaultRateType'], 'visit');
      expect(lotdRequests.any((r) => r.method == 'PUT' && r.path.endsWith('/sitters/me/rates')), isTrue);
      expect(await pushPendingRateGrid620(), isFalse, reason: 'envoyée une seule fois');
      expect(tester.takeException(), isNull);
    });
  });
}
