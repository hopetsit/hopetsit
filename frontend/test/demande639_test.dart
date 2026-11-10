// 639 (lot D) — demande : « Je fournis la nourriture », ordre des sections,
// suggestions de races. Contrat `CONTRATS.md` §1, §2, §3 :
//   · `foodProvided` : true / false / absent (non précisé) — lu, envoyé
//     (création + modification) seulement quand il est précisé, affiché sur
//     les cartes seulement quand il est précisé ;
//   · formulaire : Animaux → Service → Dates et horaires → Ville → Budget →
//     Infos pratiques (nourriture + sans voiture) → Détails → Photos ;
//   · race : champ libre facultatif + suggestions chien / chat ;
//   · 9 langues.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/edit_pet_controller.dart';
import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/demande639_i18n.dart';
import 'package:hopetsit/localization/v565/v565_i18n.dart';
import 'package:hopetsit/models/nearby_request_model.dart';
import 'package:hopetsit/models/owner_active_request.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/repositories/post_repository.dart';
import 'package:hopetsit/services/propose_services_service.dart';
import 'package:hopetsit/utils/breeds639.dart';
import 'package:hopetsit/utils/conclure1011.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_post_card.dart';
import 'package:hopetsit/views/profile/edit_pet_screen.dart';
import 'package:hopetsit/views/profile/widgets/breed_suggestions639.dart';
import 'package:hopetsit/views/service_provider/widgets/owner_requests_card.dart';

import 'lotd_harness.dart';

const _langs = <String>['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

const _keys = <String>[
  'f639_dates_hours_title',
  'f639_hours_title',
  'f639_practical_title',
  'f639_food',
  'f639_food_sub',
  'f639_food_label',
  'f639_food_short_yes',
  'f639_food_short_no',
  'f639_food_yes',
  'f639_food_no',
  'f639_breed_suggest',
];

Map<String, dynamic> _postJson(Map<String, dynamic> extra) => <String, dynamic>{
      'id': 'p1', 'postType': 'request', 'body': 'x', 'serviceTypes': <String>['day_care'],
      'notes': '', 'images': const [], 'videos': const [], 'likes': const [], 'comments': const [],
      'createdAt': '2026-11-09T10:00:00Z', 'updatedAt': '2026-11-09T10:00:00Z',
      'owner': <String, dynamic>{'id': 'o1', 'name': 'Camille'},
      ...extra,
    };

Map<String, dynamic> _nearby(Map<String, dynamic> extra) => <String, dynamic>{
      'id': 'p1', 'ownerId': 'o1', 'serviceTypes': <String>['day_care'],
      'location': <String, dynamic>{'city': 'Zone test', 'lat': -35, 'lng': -30},
      ...extra,
    };

OwnerActiveRequest _req(bool? food) => OwnerActiveRequest(
      id: 'p1',
      ownerId: 'o-test',
      serviceTypes: const <String>['pet_sitting'],
      startDate: DateTime(2026, 12, 1, 9),
      endDate: DateTime(2026, 12, 3, 18),
      city: 'Zone test',
      foodProvided: food,
    );

double _top(WidgetTester t, Finder f) => t.getTopLeft(f.first).dy;

void main() {
  setUpAll(() {
    Get.testMode = true;
    Get.locale = const Locale('fr', 'FR');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  group('i18n 639', () {
    test('9 langues, mêmes 11 clés partout, aucune valeur vide', () {
      expect(demande639I18n.keys.toSet(), _langs.toSet());
      for (final lang in _langs) {
        final m = demande639I18n[lang]!;
        expect(m.keys.toSet(), _keys.toSet(), reason: 'clés de $lang');
        for (final k in _keys) {
          expect(m[k]!.trim(), isNotEmpty, reason: '$lang / $k');
        }
      }
    });

    test('paquet branché dans le registre et dans AppTranslations', () {
      expect(v565Packs.contains(demande639I18n), isTrue);
      final all = AppTranslations().keys;
      for (final lang in _langs) {
        final merged = v565For(lang);
        for (final k in _keys) {
          expect(merged[k], demande639I18n[lang]![k], reason: 'v565For($lang) / $k');
        }
        final locale = all.keys.firstWhere((l) => l == lang || l.startsWith('${lang}_'),
            orElse: () => '');
        expect(locale, isNotEmpty, reason: 'langue $lang absente de AppTranslations');
        expect(all[locale]!['f639_food'], demande639I18n[lang]!['f639_food'], reason: locale);
      }
    });

    test('libellés figés du contrat (français)', () {
      final fr = demande639I18n['fr']!;
      expect(fr['f639_dates_hours_title'], 'Dates et horaires');
      expect(fr['f639_practical_title'], 'Infos pratiques');
      expect(fr['f639_food'], 'Je fournis la nourriture');
      expect(fr['f639_food_yes'], 'Nourriture fournie');
      expect(fr['f639_food_no'], 'Nourriture à prévoir');
    });
  });

  group('outils', () {
    test('requestExtras1011 : nourriture absente si non précisée, envoyée si true ou false', () {
      final none = requestExtras1011(timeFrom: '09:00', timeTo: '18:00', ownerNoCar: true);
      expect(none.containsKey('foodProvided'), isFalse);
      final yes = requestExtras1011(timeFrom: '', timeTo: '', ownerNoCar: false, foodProvided: true);
      expect(yes['foodProvided'], isTrue);
      final no = requestExtras1011(timeFrom: '', timeTo: '', ownerNoCar: false, foodProvided: false);
      expect(no['foodProvided'], isFalse);
      final upd = requestExtras1011(
          timeFrom: '', timeTo: '', ownerNoCar: false, foodProvided: false, forUpdate: true);
      expect(upd['foodProvided'], isFalse);
      final updNone = requestExtras1011(timeFrom: '', timeTo: '', ownerNoCar: false, forUpdate: true);
      expect(updNone.containsKey('foodProvided'), isFalse);
    });

    test('foodLabel639 : vide si non précisé, sinon la phrase du contrat', () {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr', 'FR');
      expect(foodLabel639(null), '');
      expect(foodLabel639(true), 'Nourriture fournie');
      expect(foodLabel639(false), 'Nourriture à prévoir');
      Get.locale = const Locale('en', 'US');
      expect(foodLabel639(true), 'Food provided');
      expect(foodLabel639(false), 'Food to bring');
      Get.locale = const Locale('fr', 'FR');
    });
  });

  group('lecture du serveur', () {
    test('PostModel : true, false, absent (ancien serveur), null', () {
      expect(PostModel.fromJson(_postJson(<String, dynamic>{'foodProvided': true})).foodProvided, isTrue);
      expect(PostModel.fromJson(_postJson(<String, dynamic>{'foodProvided': false})).foodProvided, isFalse);
      expect(PostModel.fromJson(_postJson(const <String, dynamic>{})).foodProvided, isNull);
      expect(PostModel.fromJson(_postJson(<String, dynamic>{'foodProvided': null})).foodProvided, isNull);
    });

    test('NearbyRequestPost : true, false, absent', () {
      expect(NearbyRequestPost.fromJson(_nearby(<String, dynamic>{'foodProvided': true})).foodProvided, isTrue);
      expect(NearbyRequestPost.fromJson(_nearby(<String, dynamic>{'foodProvided': false})).foodProvided, isFalse);
      expect(NearbyRequestPost.fromJson(_nearby(const <String, dynamic>{})).foodProvided, isNull);
    });

    test('OwnerActiveRequest : true, false, absent', () {
      Map<String, dynamic> j(Map<String, dynamic> extra) =>
          <String, dynamic>{'id': 'p1', 'ownerId': 'o1', 'serviceTypes': <String>['day_care'], ...extra};
      expect(OwnerActiveRequest.fromJson(j(<String, dynamic>{'foodProvided': true})).foodProvided, isTrue);
      expect(OwnerActiveRequest.fromJson(j(<String, dynamic>{'foodProvided': false})).foodProvided, isFalse);
      expect(OwnerActiveRequest.fromJson(j(const <String, dynamic>{})).foodProvided, isNull);
    });
  });

  group('envoi au serveur', () {
    setUp(() async => lotdSetUp(role: 'owner'));
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    Future<Map<String, dynamic>> create({bool? food}) async {
      final repo = Get.find<OwnerRepository>();
      await repo.createReservationRequest(
        body: 'Garde',
        startDate: DateTime(2026, 12, 1, 9),
        endDate: DateTime(2026, 12, 1, 18),
        serviceTypes: const <String>['day_care'],
        city: 'Zone test',
        timeFrom: '09:00',
        timeTo: '18:00',
        ownerNoCar: false,
        foodProvided: food,
      );
      return lotdRequests.lastWhere((r) => r.method == 'POST').body!;
    }

    test('création : champ absent si non précisé (rien ne change pour une demande sans réponse)', () async {
      final sent = await create();
      expect(sent.containsKey('foodProvided'), isFalse);
      expect(sent['timeFrom'], '09:00', reason: 'les champs 1011 gardent leur nom');
    });

    test('création : true envoyé', () async {
      expect((await create(food: true))['foodProvided'], isTrue);
    });

    test('création : false envoyé (« à prévoir » est une vraie réponse)', () async {
      final sent = await create(food: false);
      expect(sent.containsKey('foodProvided'), isTrue);
      expect(sent['foodProvided'], isFalse);
    });

    test('modification : envoyé seulement si précisé', () async {
      final repo = Get.find<PostRepository>();
      await repo.updatePost('p1', body: 'x', timeFrom: '10:00', timeTo: '', ownerNoCar: false);
      var sent = lotdRequests.lastWhere((r) => r.path.contains('p1') && r.body != null).body!;
      expect(sent.containsKey('foodProvided'), isFalse);
      await repo.updatePost('p1', body: 'x', foodProvided: true);
      sent = lotdRequests.lastWhere((r) => r.path.contains('p1') && r.body != null).body!;
      expect(sent['foodProvided'], isTrue);
      await repo.updatePost('p1', body: 'x', foodProvided: false);
      sent = lotdRequests.lastWhere((r) => r.path.contains('p1') && r.body != null).body!;
      expect(sent['foodProvided'], isFalse);
    });
  });

  group('formulaire « Publier ma demande »', () {
    setUp(() async => lotdSetUp(role: 'owner'));
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    for (final width in const <double>[320, 375]) {
      testWidgets('ordre des sections du contrat ($width px)', (t) async {
        lotdPhone(t, width: width, height: 812);
        await t.pumpWidget(lotdApp(
          const PublishReservationRequestScreen(initialServiceType: 'house_sitting'),
        ));
        await lotdSettle(t);
        expect(t.takeException(), isNull);
        Finder txt(String key) => find.text(key.tr, skipOffstage: false);
        Finder k(String key) => find.byKey(Key(key), skipOffstage: false);

        final pets = _top(t, txt('label_pets'));
        final service = _top(t, txt('send_request_service_type_label'));
        final dates = _top(t, txt('f639_dates_hours_title'));
        final hours = _top(t, k('f639_hours_block'));
        final city = _top(t, txt('publish_request_city_label'));
        final budget = _top(t, k('budget587_section'));
        final practical = _top(t, k('c1011_section'));
        final food = _top(t, k('f639_food_switch'));
        final noCar = _top(t, k('c1011_no_car_switch'));
        final details = _top(t, txt('post_field_details'));
        final photos = _top(t, txt('publish_request_images_label'));

        expect(find.text('Dates et horaires', skipOffstage: false), findsWidgets);
        expect(find.text('Infos pratiques', skipOffstage: false), findsWidgets);
        expect(pets, lessThan(service), reason: 'Animaux avant Service');
        expect(service, lessThan(dates), reason: 'Service avant Dates et horaires');
        expect(dates, lessThan(hours), reason: 'heures dans la section des dates');
        expect(hours, lessThan(city), reason: 'heures juste sous les dates, avant la Ville');
        expect(city, lessThan(budget), reason: 'Ville avant Budget');
        expect(budget, lessThan(practical), reason: 'Budget avant Infos pratiques');
        expect(practical, lessThan(food));
        expect(food, lessThan(noCar), reason: 'nourriture puis « sans voiture »');
        expect(noCar, lessThan(details), reason: 'Infos pratiques avant Détails');
        expect(details, lessThan(photos), reason: 'Détails avant Photos');

        // Les cases d'heure sont bien DANS le bloc sous les dates.
        expect(
          find.descendant(of: k('f639_hours_block'), matching: k('c1011_time_from'), skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.descendant(of: k('f639_hours_block'), matching: k('c1011_time_to'), skipOffstage: false),
          findsOneWidget,
        );
        // Les deux interrupteurs sont DANS « Infos pratiques ».
        expect(
          find.descendant(of: k('c1011_section'), matching: k('f639_food_switch'), skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.descendant(of: k('c1011_section'), matching: k('c1011_no_car_switch'), skipOffstage: false),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      });
    }

    for (final lang in _langs) {
      testWidgets('$lang : interrupteur nourriture à 3 états, sans débordement à 320 px', (t) async {
        lotdPhone(t, width: 320, height: 800);
        await t.pumpWidget(lotdApp(
          const PublishReservationRequestScreen(initialServiceType: 'house_sitting'),
          locale: Locale(lang),
        ));
        await lotdSettle(t);
        expect(t.takeException(), isNull);
        final c = Get.find<PublishReservationRequestController>();

        // Non touché : rien de précisé, rien à envoyer, rien au récapitulatif.
        expect(c.foodProvided.value, isNull);
        expect(c.foodProvidedWire, isNull);
        expect(c.practicalDone639, isFalse);
        expect(find.byKey(const Key('f639_food_summary'), skipOffstage: false), findsNothing);
        expect(find.text(demande639I18n[lang]!['f639_food']!, skipOffstage: false), findsOneWidget);

        final sw = find.byKey(const Key('f639_food_switch'), skipOffstage: false);
        expect(sw, findsOneWidget);
        await t.ensureVisible(sw);
        await lotdSettle(t, frames: 2);
        await t.tap(sw);
        await lotdSettle(t, frames: 4);
        expect(c.foodProvided.value, isTrue);
        expect(c.foodProvidedWire, isTrue);
        expect(c.practicalDone639, isTrue);
        final row = find.byKey(const Key('f639_food_summary'), skipOffstage: false);
        expect(row, findsOneWidget);
        expect(
          find.descendant(
              of: row,
              matching: find.text(demande639I18n[lang]!['f639_food_short_yes']!, skipOffstage: false),
              skipOffstage: false),
          findsOneWidget,
        );

        // Décoché après avoir été touché : « à prévoir » est envoyé (false).
        await t.ensureVisible(sw);
        await lotdSettle(t, frames: 2);
        await t.tap(sw);
        await lotdSettle(t, frames: 4);
        expect(c.foodProvided.value, isFalse);
        expect(c.foodProvidedWire, isFalse);
        expect(c.practicalDone639, isTrue);
        expect(
          find.descendant(
              of: find.byKey(const Key('f639_food_summary'), skipOffstage: false),
              matching: find.text(demande639I18n[lang]!['f639_food_short_no']!, skipOffstage: false),
              skipOffstage: false),
          findsOneWidget,
        );

        // « Je n'ai pas de voiture » garde son comportement.
        final car = find.byKey(const Key('c1011_no_car_switch'), skipOffstage: false);
        expect(c.ownerNoCar.value, isFalse);
        await t.ensureVisible(car);
        await lotdSettle(t, frames: 2);
        await t.tap(car);
        await lotdSettle(t, frames: 4);
        expect(c.ownerNoCar.value, isTrue);
        expect(c.foodProvidedWire, isFalse, reason: 'les deux interrupteurs sont indépendants');
        expect(t.takeException(), isNull);
      });
    }
  });

  group('affichage côté gardien / promeneur', () {
    setUp(() async => lotdSetUp(role: 'sitter'));
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    Widget card({bool? food}) => lotdApp(Scaffold(
          body: SingleChildScrollView(
            child: PetPostCard(
              userName: 'Camille',
              userEmail: '',
              petImages: const <String>[],
              isNetworkImage: false,
              likeCount: 0,
              commentCount: 0,
              dateRange: '01/12/2026 → 03/12/2026',
              serviceTypes: 'day_care',
              location: 'Zone test',
              foodProvided: food,
              viewerRole: 'sitter',
            ),
          ),
        ));

    for (final width in const <double>[320, 375]) {
      testWidgets('carte d\'annonce ($width px) : « Nourriture » Fournie / À prévoir, absente si non précisé',
          (t) async {
        lotdPhone(t, width: width, height: 812);
        await t.pumpWidget(card(food: true));
        await lotdSettle(t, frames: 8);
        expect(t.takeException(), isNull);
        expect(find.text('Nourriture'), findsOneWidget);
        expect(find.text('Fournie'), findsOneWidget);
        expect(find.text('À prévoir'), findsNothing);

        await t.pumpWidget(card(food: false));
        await lotdSettle(t, frames: 8);
        expect(t.takeException(), isNull);
        expect(find.text('Nourriture'), findsOneWidget);
        expect(find.text('À prévoir'), findsOneWidget);
        expect(find.text('Fournie'), findsNothing);

        await t.pumpWidget(card());
        await lotdSettle(t, frames: 8);
        expect(t.takeException(), isNull);
        expect(find.text('Nourriture'), findsNothing);
        expect(find.text('Fournie'), findsNothing);
        expect(find.text('À prévoir'), findsNothing);
      });
    }

    Widget requests(bool? food) => lotdApp(Scaffold(
          body: SingleChildScrollView(
            child: OwnerRequestsCard(
              requests: <OwnerActiveRequest>[_req(food)],
              viewerRole: 'sitter',
              states: const <String, OwnerRequestApplyState>{},
              onPropose: (_) {},
            ),
          ),
        ));

    testWidgets('fiche du propriétaire (demandes en cours) : phrase du contrat, masquée si non précisé',
        (t) async {
      lotdPhone(t, width: 320, height: 812);
      await t.pumpWidget(requests(true));
      await lotdSettle(t, frames: 8);
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>('owner_requests_card')), findsOneWidget);
      expect(find.text('Nourriture fournie'), findsOneWidget);
      expect(find.text('Nourriture à prévoir'), findsNothing);

      await t.pumpWidget(requests(false));
      await lotdSettle(t, frames: 8);
      expect(t.takeException(), isNull);
      expect(find.text('Nourriture à prévoir'), findsOneWidget);
      expect(find.text('Nourriture fournie'), findsNothing);

      await t.pumpWidget(requests(null));
      await lotdSettle(t, frames: 8);
      expect(t.takeException(), isNull);
      expect(find.textContaining('Nourriture'), findsNothing);
    });
  });

  group('races suggérées (outil)', () {
    test('chien et chat : listes distinctes, « Croisé » en dernier, autre espèce = rien', () {
      final dogs = breedSuggestions639('Dog', '', 'fr');
      final cats = breedSuggestions639('Cat', '', 'fr');
      expect(dogs.length, dogBreeds639.length);
      expect(cats.length, catBreeds639.length);
      expect(dogs, contains('Labrador'));
      expect(dogs, contains('Berger allemand'));
      expect(dogs, isNot(contains('Maine Coon')));
      expect(cats, contains('Maine Coon'));
      expect(cats, isNot(contains('Labrador')));
      expect(dogs.last, 'Croisé');
      expect(cats.last, 'Croisé');
      expect(dogs.toSet().length, dogs.length, reason: 'pas de doublon');
      expect(cats.toSet().length, cats.length, reason: 'pas de doublon');
      for (final other in const <String?>['Bird', 'Rabbit', 'Other', '', null]) {
        expect(breedSuggestions639(other, '', 'fr'), isEmpty, reason: '$other');
      }
      expect(breedSuggestions639('dog', '', 'fr').length, dogs.length, reason: 'casse du jeton ignorée');
    });

    test('français en français, anglais dans les autres langues', () {
      expect(breedSuggestions639('Dog', '', 'fr'), contains('Caniche'));
      for (final lang in const <String>['en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
        final l = breedSuggestions639('Dog', '', lang);
        expect(l, contains('Poodle'), reason: lang);
        expect(l, isNot(contains('Caniche')), reason: lang);
        expect(l.last, 'Mixed breed', reason: lang);
      }
    });

    test('filtre : accents et casse ignorés, saisie libre sans correspondance = rien', () {
      expect(breedSuggestions639('Dog', 'berg', 'fr'),
          <String>['Berger allemand', 'Berger australien', 'Berger belge malinois']);
      expect(breedSuggestions639('Dog', 'SIBERIEN', 'fr'), <String>['Husky sibérien']);
      // Le nom anglais trouve aussi la race en français.
      expect(breedSuggestions639('Dog', 'pood', 'fr'), <String>['Caniche']);
      // Race d'une AUTRE espèce restée dans le champ après un changement
      // d'espèce : on propose la liste de la nouvelle espèce.
      expect(breedSuggestions639('Cat', 'Labrador', 'fr').length, catBreeds639.length);
      expect(breedSuggestions639('Dog', 'maine coon', 'en').length, dogBreeds639.length);
      expect(breedSuggestions639('Bird', 'Labrador', 'fr'), isEmpty);
      // Une race de la liste déjà choisie : on garde toute la liste (pour en changer).
      expect(breedSuggestions639('Dog', 'labrador', 'fr').length, dogBreeds639.length);
      // Saisie libre inconnue : aucune suggestion, la saisie reste permise.
      expect(breedSuggestions639('Dog', 'Chien de mon voisin', 'fr'), isEmpty);
      expect(normBreed639('  Bérger   ALLEMAND '), 'berger allemand');
      expect(sameBreed639('berger allemand', 'Berger allemand'), isTrue);
      expect(sameBreed639('', 'Berger allemand'), isFalse);
    });

    test('toutes les races tiennent dans la limite serveur de 60 caractères', () {
      for (final b in <Breed639>[...dogBreeds639, ...catBreeds639]) {
        expect(b.en.length, lessThanOrEqualTo(60));
        expect(b.fr.length, lessThanOrEqualTo(60));
        expect(b.en.trim(), isNotEmpty);
        expect(b.fr.trim(), isNotEmpty);
      }
    });
  });

  group('races suggérées (fiche animal)', () {
    setUp(() async => lotdSetUp(role: 'owner'));
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    testWidgets('pastilles : remplir, vider, masquées pour une saisie libre et pour un oiseau', (t) async {
      lotdPhone(t, width: 320, height: 812);
      final ctl = TextEditingController();
      final species = 'Dog'.obs;
      await t.pumpWidget(lotdApp(Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            TextField(key: const Key('champ_race'), controller: ctl),
            Obx(() => BreedSuggestions639(
                  species: species.value,
                  controller: ctl,
                  accent: const Color(0xFFC92A12),
                )),
          ]),
        ),
      )));
      await lotdSettle(t, frames: 4);
      expect(t.takeException(), isNull);
      final block = find.byKey(const Key('f639_breed_suggestions'));
      expect(block, findsOneWidget);
      expect(find.text('Races courantes — saisie libre possible'), findsOneWidget);
      final labrador = find.byKey(const ValueKey<String>('f639_breed_Labrador'), skipOffstage: false);
      expect(labrador, findsOneWidget);

      await t.tap(labrador);
      await lotdSettle(t, frames: 4);
      expect(ctl.text, 'Labrador');
      expect(block, findsOneWidget, reason: 'la liste reste, pour pouvoir changer');

      // Retoucher la pastille choisie vide le champ : rien d'obligatoire.
      await t.tap(labrador);
      await lotdSettle(t, frames: 4);
      expect(ctl.text, '');

      // Saisie libre qui ne correspond à rien : gardée, plus de pastilles.
      await t.enterText(find.byKey(const Key('champ_race')), 'Chien de mon voisin');
      await lotdSettle(t, frames: 4);
      expect(ctl.text, 'Chien de mon voisin');
      expect(block, findsNothing);

      // Saisie partielle : liste filtrée.
      await t.enterText(find.byKey(const Key('champ_race')), 'berg');
      await lotdSettle(t, frames: 4);
      expect(find.byKey(const ValueKey<String>('f639_breed_Berger allemand'), skipOffstage: false),
          findsOneWidget);
      expect(find.byKey(const ValueKey<String>('f639_breed_Labrador'), skipOffstage: false), findsNothing);

      // Chat : la liste change.
      await t.enterText(find.byKey(const Key('champ_race')), '');
      species.value = 'Cat';
      await lotdSettle(t, frames: 4);
      expect(find.byKey(const ValueKey<String>('f639_breed_Maine Coon'), skipOffstage: false),
          findsOneWidget);
      expect(find.byKey(const ValueKey<String>('f639_breed_Labrador'), skipOffstage: false), findsNothing);

      // Oiseau : pas de suggestion.
      species.value = 'Bird';
      await lotdSettle(t, frames: 4);
      expect(block, findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('écran « Ajouter un animal » : suggestions sous le champ Race, la race reste facultative',
        (t) async {
      lotdPhone(t, width: 320, height: 812);
      await t.pumpWidget(lotdApp(const EditPetScreen()));
      await lotdSettle(t);
      expect(t.takeException(), isNull);
      final c = Get.find<EditPetController>();
      expect(c.breedController.text, '', reason: 'rien de pré-rempli');
      final block = find.byKey(const Key('f639_breed_suggestions'), skipOffstage: false);
      expect(block, findsOneWidget, reason: 'espèce par défaut : chien');
      final chip = find.byKey(const ValueKey<String>('f639_breed_Labrador'), skipOffstage: false);
      expect(chip, findsOneWidget);
      // Les pastilles sont sous le libellé du champ « Race ».
      expect(_top(t, find.text('edit_pet_breed_label'.tr, skipOffstage: false)), lessThan(_top(t, block)));

      await t.ensureVisible(chip);
      await lotdSettle(t, frames: 2);
      await t.tap(chip);
      await lotdSettle(t, frames: 4);
      expect(c.breedController.text, 'Labrador');

      // Passage à « chat » avec « Labrador » encore dans le champ : les races
      // de chat sont proposées, la saisie n'est pas effacée.
      c.setCategory('Cat');
      await lotdSettle(t, frames: 4);
      expect(c.breedController.text, 'Labrador');
      final coon = find.byKey(const ValueKey<String>('f639_breed_Maine Coon'), skipOffstage: false);
      expect(coon, findsOneWidget);
      expect(find.byKey(const ValueKey<String>('f639_breed_Labrador'), skipOffstage: false), findsNothing);
      await t.ensureVisible(coon);
      await lotdSettle(t, frames: 2);
      await t.tap(coon);
      await lotdSettle(t, frames: 4);
      expect(c.breedController.text, 'Maine Coon');

      c.setCategory('Bird');
      await lotdSettle(t, frames: 4);
      expect(find.byKey(const Key('f639_breed_suggestions'), skipOffstage: false), findsNothing);
      expect(c.breedController.text, 'Maine Coon', reason: 'la saisie n\'est jamais effacée d\'office');
      expect(t.takeException(), isNull);
    });
  });
}
