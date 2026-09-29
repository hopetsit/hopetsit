// v600 NEO (29/09/2026, GO de Daniel) — « Publier ma demande » :
//   1. SANS fiche animal : puces d'espèce + nombre, « Publier » n'exige plus
//      un animal enregistré, la demande part avec animalTypes / animalCount
//      et petIds vide ;
//   2. formulaire court : heures 8 h – 20 h par défaut pour une garde (jamais
//      pour une promenade), ville du profil pré-remplie, brouillon écrit à
//      chaque changement et proposé au retour (« Reprendre ma demande ? ») ;
//   3. accueil à 0 demande : « Publie ta première demande — N gardiens et
//      promeneurs à <ville> » ; pop-up promo mise en pause après publication.
// 9 langues, sans réseau (harnais lot D).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';

import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/localization/v565/neo600_i18n.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/services/supply_city600.dart';
import 'package:hopetsit/utils/publish_draft600.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/widgets/home_quick_action_bar.dart';

import 'lotd_harness.dart';

Finder _k(String k) => find.byKey(Key(k), skipOffstage: false);

/// Ouvre l'écran EMPILÉ sur une page vide (comme dans l'app), pour que
/// `Get.back()` après « Publier » ait quelque chose à fermer.
Future<PublishReservationRequestController> _open(WidgetTester t,
    {String? service = 'pet_sitting', Locale locale = const Locale('fr', 'FR')}) async {
  lotdPhone(t);
  await t.pumpWidget(lotdApp(const Scaffold(body: SizedBox.shrink()), locale: locale));
  await lotdSettle(t, frames: 1);
  Get.to(() => PublishReservationRequestScreen(initialServiceType: service));
  await lotdSettle(t);
  return Get.find<PublishReservationRequestController>();
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(_k(key));
  await lotdSettle(t, frames: 2);
  await t.tap(_k(key));
  await lotdSettle(t, frames: 2);
}

void main() {
  setUpAll(() async {
    // Comme main.dart : les 9 locales d'intl (dates et heures affichées).
    for (final l in <String>['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      await initializeDateFormatting(l);
    }
  });
  setUp(() async {
    await lotdSetUp(role: 'owner');
    resetSupplyCache600();
    clearPublishDraft600();
  });
  tearDown(() async {
    await Get.deleteAll(force: true);
    Get.reset();
  });

  group('1. publier SANS animal enregistré', () {
    testWidgets('puces espèce + nombre ; « Publier » ne réclame plus un animal', (t) async {
      final c = await _open(t);
      expect(t.takeException(), isNull);
      expect(c.myPets, isEmpty, reason: 'aucune fiche animal (réponse vide)');
      expect(c.usesSpeciesPills, isTrue);
      expect(_k('neo600_species_section'), findsOneWidget);
      expect(find.text('Quel animal ?', skipOffstage: false), findsOneWidget);
      expect(c.firstMissingField, isNot('pet'), reason: 'le mur « ajoute un animal » est tombé');
      expect(c.firstMissingField, 'species');
      expect(c.stepPetsDone, isFalse);

      await _tap(t, 'neo600_species_dog');
      expect(c.animalTypes, <String>['dog']);
      expect(c.stepPetsDone, isTrue);
      expect(c.firstMissingField, isNot('species'));

      expect(c.animalCount.value, 1);
      await _tap(t, 'neo600_count_plus');
      expect(c.animalCount.value, 2);
      expect(find.text('2', skipOffstage: false), findsWidgets);
      await _tap(t, 'neo600_count_minus');
      await _tap(t, 'neo600_count_minus');
      expect(c.animalCount.value, 1, reason: 'jamais moins de 1');

      await _tap(t, 'neo600_species_cat');
      await _tap(t, 'neo600_count_plus');
      expect(c.animalSummary, '2 · Chien, Chat');
      await _tap(t, 'neo600_species_dog');
      expect(c.animalTypes, <String>['cat'], reason: 're-tap = désélection');
    });

    testWidgets('la demande part avec animalTypes / animalCount et petIds VIDE', (t) async {
      final c = await _open(t);
      await _tap(t, 'neo600_species_dog');
      await _tap(t, 'neo600_count_plus');
      c.selectServiceLocation('at_owner');
      c.startDate.value = DateTime(2026, 12, 1);
      c.onDatesChanged();
      expect(c.endDate.value, DateTime(2026, 12, 2), reason: 'garde : fin = lendemain par défaut');
      expect(c.firstMissingField, isNull, reason: 'ville du profil + heures par défaut : tout est prêt');
      await c.submit();
      await lotdSettle(t);
      final sent = lotdRequests.lastWhere((r) => r.method == 'POST' && r.path.endsWith('/posts'));
      expect(sent.body!['petIds'], isEmpty);
      expect(sent.body!['animalTypes'], <String>['dog']);
      expect(sent.body!['animalCount'], 2);
      expect((sent.body!['location'] as Map)['city'], 'Paris');
      expect(sent.body!['startDate'], startsWith('2026-12-01T'));
      expect(find.byType(PublishReservationRequestScreen), findsNothing,
          reason: 'après publication, retour à l\'accueil');
      expect(readPublishDraft600(), isNull, reason: 'brouillon effacé après publication');
      expect(promoPopupSnoozed600(), isTrue, reason: 'pop-up cadeau différée');
    });

    test('Get.back rend kPublishedResult600 ; le serveur muet sur N → repli /supply/city', () {
      expect(PublishReservationRequestController.kPublishedResult600, 'published600');
      expect(PublishReservationRequestController.notifiedCountFromResponse(<String, dynamic>{'post': {}}), isNull);
      expect(PublishReservationRequestController.notifiedCountFromResponse(<String, dynamic>{'notified': 12}), 12);
      expect(PublishReservationRequestController.notifiedCountFromResponse(
          <String, dynamic>{'post': <String, dynamic>{'notifiedCount': 3}}), 3);
    });

    test('PostModel lit animalCount / animalTypes (mode Modifier)', () {
      final p = PostModel.fromJson(<String, dynamic>{
        'id': 'p1', 'postType': 'request', 'body': 'x', 'serviceTypes': <String>['pet_sitting'],
        'notes': '', 'images': const [], 'videos': const [], 'likes': const [], 'comments': const [],
        'createdAt': '2026-09-29T10:00:00Z', 'updatedAt': '2026-09-29T10:00:00Z',
        'owner': <String, dynamic>{'id': 'o1', 'name': 'Camille'},
        'animalCount': 2, 'animalTypes': <String>['dog', ' cat '],
      });
      expect(p.animalCount, 2);
      expect(p.animalTypes, <String>['dog', 'cat']);
      expect(p.copyWith().animalTypes, <String>['dog', 'cat']);
    });
  });

  group('2. formulaire court qui ne perd rien', () {
    testWidgets('garde : heures 8 h / 20 h par défaut, ville du profil ; promenade : aucune heure', (t) async {
      final c = await _open(t);
      expect(c.startTime.value, const TimeOfDay(hour: 8, minute: 0));
      expect(c.endTime.value, const TimeOfDay(hour: 20, minute: 0));
      expect(c.hasDefaultHours, isTrue);
      expect(_k('neo600_hours_hint'), findsOneWidget);
      expect(c.cityController.text, 'Paris');
      expect(c.stepCityDone, isTrue);
      // Garderie : mêmes heures par défaut, fin = même jour.
      c.selectServiceType('day_care');
      expect(c.hasDefaultHours, isTrue);
      c.startDate.value = DateTime(2026, 12, 1);
      c.onDatesChanged();
      expect(c.endDate.value, DateTime(2026, 12, 1));
      // Promenade : l'heure compte, les heures par défaut disparaissent.
      c.selectServiceType('dog_walking');
      expect(c.startTime.value, isNull);
      expect(c.endTime.value, isNull);
      await lotdSettle(t);
      expect(_k('neo600_hours_hint'), findsNothing);
    });

    testWidgets('brouillon écrit à chaque changement, proposé au retour : « Reprendre »', (t) async {
      final c = await _open(t);
      await _tap(t, 'neo600_species_dog');
      c.startDate.value = DateTime(2026, 12, 1);
      c.onDatesChanged();
      c.notesController.text = 'Rex est calme';
      await t.pump(const Duration(milliseconds: 500)); // débounce 350 ms
      final d = readPublishDraft600();
      expect(d, isNotNull);
      expect(d!['animalTypes'], <String>['dog']);
      expect(d['notes'], 'Rex est calme');
      expect(d['startDate'], startsWith('2026-12-01'));
      expect(d['startTime'], '08:00');

      // Retour arrière : l'écran se ferme, le brouillon reste.
      Get.back();
      await lotdSettle(t);
      expect(find.byType(PublishReservationRequestScreen), findsNothing);
      expect(readPublishDraft600(), isNotNull);

      // Réouverture : « Reprendre ma demande ? » → tout revient.
      Get.to(() => const PublishReservationRequestScreen(initialServiceType: 'pet_sitting'));
      await lotdSettle(t);
      expect(find.text('Reprendre ma demande ?'), findsOneWidget);
      await t.tap(find.text('Reprendre'));
      await lotdSettle(t);
      final c2 = Get.find<PublishReservationRequestController>();
      expect(c2.animalTypes, <String>['dog']);
      expect(c2.notesController.text, 'Rex est calme');
      expect(c2.startDate.value, DateTime(2026, 12, 1));
      expect(c2.endDate.value, DateTime(2026, 12, 2));
      expect(c2.startTime.value, const TimeOfDay(hour: 8, minute: 0));
      expect(c2.stepPetsDone, isTrue);
      expect(c2.firstMissingField, 'serviceLocation', reason: 'il ne manque que le lieu');
    });

    testWidgets('« Recommencer » efface le brouillon ; un brouillon sans contenu n\'est pas proposé', (t) async {
      writePublishDraft600(<String, dynamic>{'serviceType': 'pet_sitting', 'notes': 'Rex'});
      await _open(t);
      expect(find.text('Reprendre ma demande ?'), findsOneWidget);
      await t.tap(find.text('Recommencer'));
      await lotdSettle(t);
      expect(readPublishDraft600(), isNull);
      Get.back();
      await lotdSettle(t);
      // Service seul (pré-réglé par la carte de l'accueil) = pas un brouillon.
      writePublishDraft600(<String, dynamic>{'serviceType': 'pet_sitting'});
      expect(publishDraftIsMeaningful600(readPublishDraft600()), isFalse);
      Get.to(() => const PublishReservationRequestScreen(initialServiceType: 'pet_sitting'));
      await lotdSettle(t);
      expect(find.text('Reprendre ma demande ?'), findsNothing);
    });

    test('brouillon trop vieux ou illisible = ignoré', () {
      final box = GetStorage();
      box.write(kPublishDraftKey600, <String, dynamic>{
        'notes': 'vieux',
        'savedAt': DateTime.now().subtract(const Duration(days: 20)).millisecondsSinceEpoch,
      });
      expect(readPublishDraft600(), isNull);
      box.write(kPublishDraftKey600, 'pas une map');
      expect(readPublishDraft600(), isNull);
    });

    test('ville du profil : à plat, ou dans location, jamais une adresse e-mail', () {
      final box = GetStorage();
      expect(profileCity600(storage: box), 'Paris');
      box.write('user_profile', <String, dynamic>{'id': 'u', 'location': <String, dynamic>{'city': 'Lyon'}});
      expect(profileCity600(storage: box), 'Lyon');
      box.write('user_profile', <String, dynamic>{'id': 'u', 'city': 'zach@example.test'});
      expect(profileCity600(storage: box), '');
    });
  });

  group('3. accueil et fin de parcours', () {
    testWidgets('0 demande : « Publie ta première demande — 28 gardiens et promeneurs à Paris »', (t) async {
      // `/posts…` doit répondre une liste (sinon PostsController affiche une
      // bannière d'erreur par-dessus la bande, et le tap tombe dessus).
      lotdResponder = (http.Request req) => req.url.path.endsWith('/supply/city')
          ? <String, dynamic>{'city': 'Paris', 'sitters': 20, 'walkers': 8, 'total': 28}
          : <String, dynamic>{'posts': <Map<String, dynamic>>[]};
      Get.put<PostsController>(PostsController(), permanent: true);
      lotdPhone(t);
      await t.pumpWidget(lotdApp(const Scaffold(body: HomeQuickActionBar(role: 'owner'))));
      await lotdSettle(t, frames: 6);
      expect(t.takeException(), isNull);
      expect(find.text('Publie ta première demande'), findsOneWidget);
      expect(find.text('28 gardiens et promeneurs à Paris seront prévenus'), findsOneWidget);
      final q = lotdRequests.where((r) => r.path.endsWith('/supply/city')).toList();
      expect(q, isNotEmpty);
      expect(q.first.query['city'], 'Paris');
      // Le tap ouvre le formulaire (pas la PawMap).
      await t.tap(find.text('Publie ta première demande'));
      await lotdSettle(t);
      expect(find.byType(PublishReservationRequestScreen), findsOneWidget);
    });

    testWidgets('0 demande mais ville inconnue du serveur : le titre sans chiffre', (t) async {
      lotdResponder = (http.Request req) => <String, dynamic>{'posts': <Map<String, dynamic>>[]};
      Get.put<PostsController>(PostsController(), permanent: true);
      lotdPhone(t);
      await t.pumpWidget(lotdApp(const Scaffold(body: HomeQuickActionBar(role: 'owner'))));
      await lotdSettle(t, frames: 6);
      expect(find.text('Publie ta première demande'), findsOneWidget);
      expect(find.text('Gardiens et promeneurs prévenus dès que tu publies'), findsOneWidget);
      expect(find.textContaining('0 gardiens'), findsNothing);
    });

    testWidgets('avec une demande publiée : bandeau « Tout est à jour » inchangé', (t) async {
      lotdResponder = (http.Request req) => req.url.path.endsWith('/posts')
          ? <String, dynamic>{
              'posts': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'p1', 'postType': 'request', 'body': 'Garde', 'serviceTypes': <String>['pet_sitting'],
                  'notes': '', 'images': const [], 'videos': const [], 'likes': const [], 'comments': const [],
                  'createdAt': '2026-09-29T10:00:00Z', 'updatedAt': '2026-09-29T10:00:00Z',
                  'owner': <String, dynamic>{'id': 'u-test', 'name': 'Camille Durand'},
                },
              ],
            }
          : <String, dynamic>{};
      Get.put<PostsController>(PostsController(), permanent: true);
      await Get.find<PostsController>().loadPostsWithoutMedia();
      lotdPhone(t);
      await t.pumpWidget(lotdApp(const Scaffold(body: HomeQuickActionBar(role: 'owner'))));
      await lotdSettle(t, frames: 6);
      expect(find.text('Publie ta première demande'), findsNothing);
      expect(find.text('Tout est à jour'), findsOneWidget);
    });

    test('supply : total, sinon sitters + walkers, jamais 0 ; cache par ville', () async {
      lotdResponder = (http.Request req) => <String, dynamic>{'sitters': 3, 'walkers': 4};
      expect(await fetchSupplyTotal600('Lyon'), 7);
      lotdResponder = (http.Request req) => <String, dynamic>{'total': 0};
      expect(await fetchSupplyTotal600('Lyon'), 7, reason: 'cache 10 min');
      expect(await fetchSupplyTotal600('Nantes'), isNull);
      expect(await fetchSupplyTotal600(''), isNull);
      expect(await fetchSupplyTotal600('zach@example.test'), isNull);
    });

    test('pop-up promo : en pause 24 h après une publication', () {
      expect(promoPopupSnoozed600(), isFalse);
      snoozePromoPopup600();
      expect(promoPopupSnoozed600(), isTrue);
      snoozePromoPopup600(for_: const Duration(hours: -1));
      expect(promoPopupSnoozed600(), isFalse);
    });
  });

  group('9 langues (375 dp)', () {
    for (final lang in <String>['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      testWidgets('$lang : espèces, nombre, heures par défaut, sans débordement', (t) async {
        lotdPhone(t, width: 375);
        await t.pumpWidget(lotdApp(
          const PublishReservationRequestScreen(initialServiceType: 'pet_sitting'),
          locale: Locale(lang),
        ));
        await lotdSettle(t);
        expect(t.takeException(), isNull);
        final m = neo600I18n[lang]!;
        expect(find.text(m['neo600_species_title']!, skipOffstage: false), findsOneWidget);
        expect(find.text(m['neo600_animal_dog']!, skipOffstage: false), findsOneWidget);
        expect(find.text(m['neo600_animal_other']!, skipOffstage: false), findsOneWidget);
        expect(find.text(m['neo600_count_label']!, skipOffstage: false), findsOneWidget);
        expect(find.text(m['neo600_hours_hint']!, skipOffstage: false), findsOneWidget);
        for (final k in m.keys) {
          expect(find.text(k, skipOffstage: false), findsNothing, reason: 'clé brute $k');
        }
        await Get.deleteAll(force: true);
      });
    }
    test('les 9 langues ont exactement les mêmes clés, {n} et {city} intacts', () {
      final ref = neo600I18n['en']!.keys.toSet();
      for (final e in neo600I18n.entries) {
        expect(e.value.keys.toSet(), ref, reason: e.key);
        expect(e.value['neo600_home_first_sub_count'], contains('{n}'));
        expect(e.value['neo600_home_first_sub_count'], contains('{city}'));
        expect(e.value['neo600_sent_to'], contains('{n}'));
      }
    });
  });
}
