// 1011 « conclure » (PAM, 09/11/2026) — partie C du plan, contrat
// `CONTRAT_1011.md` :
//   · demande : horaires `timeFrom` / `timeTo` (« HH:MM ») et `ownerNoCar`,
//     lus, envoyés (création + modification) et affichés ;
//   · profil gardien / promeneur : `hasVehicle` envoyé sur la mise à jour ;
//   · candidats côté propriétaire : pastille « Véhiculé » seulement à `true` ;
//   · 9 langues, « Garde en journée » lisible.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/controllers/edit_sitter_profile_controller.dart';
import 'package:hopetsit/controllers/edit_walker_profile_controller.dart';
import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/conclure1011_i18n.dart';
import 'package:hopetsit/localization/v565/v565_i18n.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/models/nearby_request_model.dart';
import 'package:hopetsit/models/owner_active_request.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/models/sitter_model.dart';
import 'package:hopetsit/models/walker_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/repositories/post_repository.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/utils/conclure1011.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_candidates_sheet.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/edit_sitter_profile_screen.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_post_card.dart';
import 'package:hopetsit/views/pet_walker/profile/edit_walker_profile_screen.dart';
import 'package:hopetsit/views/service_provider/widgets/service_provider_card.dart';
import 'package:hopetsit/widgets/vehicle_badge1011.dart';

import 'lotd_harness.dart';

const _langs = <String>['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

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

/// Candidature telle que le serveur la renvoie ; `vehicle` absent = champ non
/// envoyé (ancien serveur ou profil jamais renseigné).
Map<String, dynamic> _app(String id, String name, {String role = 'sitter', Object? vehicle = _absent}) =>
    <String, dynamic>{
      'id': id,
      'postId': 'p1',
      'status': 'pending',
      'createdAt': '2026-11-0${id.codeUnitAt(id.length - 1) % 9 + 1}T10:00:00Z',
      'description': 'Bonjour, je suis dispo.',
      role: <String, dynamic>{
        'id': 's-$id',
        'name': name,
        'currency': 'EUR',
        'rating': 0,
        'reviewsCount': 0,
        'verified': true,
        if (!identical(vehicle, _absent)) 'hasVehicle': vehicle,
      },
      'pricing': const <String, dynamic>{
        'totalPrice': 72, 'appliedRate': 20, 'unit': 'day', 'currency': 'EUR',
      },
    };
const Object _absent = Object();

void main() {
  setUpAll(() {
    Get.testMode = true;
    Get.locale = const Locale('fr', 'FR');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  group('outils', () {
    test('cleanHm1011 : « HH:MM » sur 24 h, sinon vide', () {
      expect(cleanHm1011('09:00'), '09:00');
      expect(cleanHm1011('9:5'), '09:05');
      expect(cleanHm1011(' 18h30 '), '18:30');
      expect(cleanHm1011('23:59'), '23:59');
      expect(cleanHm1011('24:00'), '');
      expect(cleanHm1011('12:60'), '');
      expect(cleanHm1011('matin'), '');
      expect(cleanHm1011(''), '');
      expect(cleanHm1011(null), '');
    });

    test('parseTriBool1011 garde le « pas dit » (null)', () {
      expect(parseTriBool1011(true), isTrue);
      expect(parseTriBool1011('true'), isTrue);
      expect(parseTriBool1011(1), isTrue);
      expect(parseTriBool1011(false), isFalse);
      expect(parseTriBool1011('false'), isFalse);
      expect(parseTriBool1011(0), isFalse);
      expect(parseTriBool1011(null), isNull);
      expect(parseTriBool1011('peut-être'), isNull);
      expect(parseBool1011(null), isFalse);
      expect(parseBool1011('true'), isTrue);
    });

    test('requestExtras1011 : création = seulement ce qui est rempli', () {
      expect(requestExtras1011(), isEmpty);
      expect(requestExtras1011(timeFrom: '', timeTo: '', ownerNoCar: false), isEmpty);
      expect(requestExtras1011(timeFrom: '9:00', timeTo: '18:00', ownerNoCar: true),
          <String, Object>{'timeFrom': '09:00', 'timeTo': '18:00', 'ownerNoCar': true});
      expect(requestExtras1011(timeFrom: '25:00'), isEmpty, reason: 'heure invalide jamais envoyée');
    });

    test('requestExtras1011 : modification = null inchangé, vide = effacé, faux envoyé', () {
      expect(requestExtras1011(forUpdate: true), isEmpty);
      expect(requestExtras1011(timeFrom: '', timeTo: '', ownerNoCar: false, forUpdate: true),
          <String, Object>{'timeFrom': '', 'timeTo': '', 'ownerNoCar': false});
      expect(requestExtras1011(timeFrom: '08:30', forUpdate: true), <String, Object>{'timeFrom': '08:30'});
    });
  });

  group('i18n 1011', () {
    test('mêmes clés dans les 9 langues, jamais vides, jeton @time gardé', () {
      expect(conclure1011I18n.keys.toSet(), _langs.toSet());
      final fr = conclure1011I18n['fr']!;
      for (final l in _langs) {
        final m = conclure1011I18n[l]!;
        expect(m.keys.toSet(), fr.keys.toSet(), reason: l);
        for (final e in m.entries) {
          expect(e.value.trim(), isNotEmpty, reason: '$l ${e.key}');
        }
        expect(m['c1011_hours_from'], contains('@time'), reason: l);
        expect(m['c1011_hours_until'], contains('@time'), reason: l);
      }
    });

    test('le lot est branché dans l\'app, et « Garde en journée » remplace « Garderie »', () {
      for (final l in _langs) {
        final all = v565For(l);
        expect(all['c1011_vehicle_badge'], conclure1011I18n[l]!['c1011_vehicle_badge'], reason: l);
        expect(all['publish_request_service_daycare'], conclure1011I18n[l]!['publish_request_service_daycare'],
            reason: l);
      }
      final fr = v565For('fr');
      expect(fr['c1011_vehicle_badge'], 'Véhiculé');
      expect(fr['c1011_no_car'], 'Je n\'ai pas de voiture');
      expect(fr['c1011_has_vehicle'], 'J\'ai un véhicule');
      expect(fr['publish_request_service_daycare'], 'Garde en journée');
      expect(fr['publish_request_service_daycare_desc'], contains('rentre le soir'));
      expect(fr['publish_request_service_daycare_desc'], contains('Prix au jour'));
    });
  });

  group('lecture du serveur', () {
    setUp(() async {
      await lotdSetUp(role: 'owner');
      Get.addTranslations(<String, Map<String, String>>{'fr_FR': v565For('fr')});
      Get.locale = const Locale('fr', 'FR');
    });

    test('annonce, demande proche, demande d\'un propriétaire : heures + sans voiture', () {
      const filled = <String, dynamic>{'timeFrom': '09:00', 'timeTo': '18:00', 'ownerNoCar': true};
      final p = PostModel.fromJson(_postJson(filled));
      expect(p.timeFrom, '09:00');
      expect(p.timeTo, '18:00');
      expect(p.ownerNoCar, isTrue);
      expect(p.hoursLabel, '09:00 – 18:00');

      final n = NearbyRequestPost.fromJson(_nearby(filled));
      expect(n.hoursLabel, '09:00 – 18:00');
      expect(n.ownerNoCar, isTrue);

      final o = OwnerActiveRequest.fromJson(<String, dynamic>{'id': 'p1', 'ownerId': 'o1', ...filled});
      expect(o.hoursLabel, '09:00 – 18:00');
      expect(o.ownerNoCar, isTrue);
    });

    test('ancien serveur (champs absents) ou valeurs vides : rien, sans erreur', () {
      for (final extra in const <Map<String, dynamic>>[
        <String, dynamic>{},
        <String, dynamic>{'timeFrom': '', 'timeTo': '', 'ownerNoCar': false},
        <String, dynamic>{'timeFrom': null, 'timeTo': null, 'ownerNoCar': null},
        <String, dynamic>{'timeFrom': 'n\'importe quoi', 'timeTo': 99},
      ]) {
        final p = PostModel.fromJson(_postJson(extra));
        expect(p.hoursLabel, isEmpty);
        expect(p.ownerNoCar, isFalse);
        final n = NearbyRequestPost.fromJson(_nearby(extra));
        expect(n.hoursLabel, isEmpty);
        expect(n.ownerNoCar, isFalse);
        final o = OwnerActiveRequest.fromJson(<String, dynamic>{'id': 'p1', 'ownerId': 'o1', ...extra});
        expect(o.hoursLabel, isEmpty);
        expect(o.ownerNoCar, isFalse);
      }
    });

    test('une seule heure : « à partir de » / « jusqu\'à »', () {
      expect(PostModel.fromJson(_postJson(const {'timeFrom': '08:30'})).hoursLabel, 'à partir de 08:30');
      expect(PostModel.fromJson(_postJson(const {'timeTo': '19:00'})).hoursLabel, 'jusqu\'à 19:00');
    });

    test('hasVehicle : candidature (gardien ET promeneur), profils — vrai, faux, pas dit', () {
      expect(ApplicationModel.fromJson(_app('a1', 'Léa', vehicle: true)).sitter.hasVehicle, isTrue);
      expect(ApplicationModel.fromJson(_app('a2', 'Tom', role: 'walker', vehicle: true)).sitter.hasVehicle, isTrue);
      expect(ApplicationModel.fromJson(_app('a3', 'Zoé', vehicle: false)).sitter.hasVehicle, isFalse);
      expect(ApplicationModel.fromJson(_app('a4', 'Max', vehicle: null)).sitter.hasVehicle, isNull);
      expect(ApplicationModel.fromJson(_app('a5', 'Lou')).sitter.hasVehicle, isNull);
      expect(ApplicationModel.fromJson(_app('a6', 'Sam', role: 'walker')).sitter.hasVehicle, isNull);

      expect(WalkerModel.fromJson(const <String, dynamic>{'id': 'w1', 'name': 'Tom', 'hasVehicle': true}).hasVehicle,
          isTrue);
      expect(WalkerModel.fromJson(const <String, dynamic>{'id': 'w1', 'name': 'Tom', 'hasVehicle': false}).hasVehicle,
          isFalse);
      expect(WalkerModel.fromJson(const <String, dynamic>{'id': 'w1', 'name': 'Tom'}).hasVehicle, isNull);
      expect(SitterModel.fromJson(const <String, dynamic>{'id': 's1', 'name': 'Léa', 'hasVehicle': true}).hasVehicle,
          isTrue);
      expect(SitterModel.fromJson(const <String, dynamic>{'id': 's1', 'name': 'Léa'}).hasVehicle, isNull);
    });
  });

  group('envoi au serveur', () {
    setUp(() async => lotdSetUp(role: 'owner'));

    test('création : timeFrom / timeTo / ownerNoCar partent ; vides = absents de la requête', () async {
      final repo = Get.find<OwnerRepository>();
      await repo.createReservationRequest(
        body: 'Garde', startDate: DateTime(2026, 12, 1, 9), endDate: DateTime(2026, 12, 1, 18),
        serviceTypes: const <String>['day_care'], city: 'Zone test',
        timeFrom: '09:00', timeTo: '18:00', ownerNoCar: true,
      );
      final full = lotdRequests.lastWhere((r) => r.method == 'POST').body!;
      expect(full['timeFrom'], '09:00');
      expect(full['timeTo'], '18:00');
      expect(full['ownerNoCar'], true);
      expect(full['serviceTypes'], <String>['day_care']);

      await repo.createReservationRequest(
        body: 'Garde', startDate: DateTime(2026, 12, 1, 9), endDate: DateTime(2026, 12, 1, 18),
        serviceTypes: const <String>['day_care'], city: 'Zone test',
        timeFrom: '', timeTo: '', ownerNoCar: false,
      );
      final empty = lotdRequests.lastWhere((r) => r.method == 'POST').body!;
      expect(empty.containsKey('timeFrom'), isFalse);
      expect(empty.containsKey('timeTo'), isFalse);
      expect(empty.containsKey('ownerNoCar'), isFalse);
    });

    test('modification : valeurs envoyées, vide = effacé, null = pas touché', () async {
      final repo = Get.find<PostRepository>();
      await repo.updatePost('p1', body: 'x', timeFrom: '10:00', timeTo: '', ownerNoCar: false);
      final sent = lotdRequests.lastWhere((r) => r.path.contains('p1') && r.body != null).body!;
      expect(sent['timeFrom'], '10:00');
      expect(sent['timeTo'], '', reason: 'heure de fin effacée');
      expect(sent['ownerNoCar'], false, reason: 'case décochée');

      lotdRequests.clear();
      await repo.updatePost('p1', body: 'y');
      final untouched = lotdRequests.lastWhere((r) => r.path.contains('p1') && r.body != null).body!;
      expect(untouched.containsKey('timeFrom'), isFalse);
      expect(untouched.containsKey('timeTo'), isFalse);
      expect(untouched.containsKey('ownerNoCar'), isFalse);
    });

    test('profil gardien : hasVehicle sur la mise à jour, absent quand il n\'est pas dit', () async {
      final repo = Get.find<SitterRepository>();
      await repo.updateSitterProfileMe(name: 'Léa Martin', mobile: '', hasVehicle: true);
      expect(lotdRequests.last.path, endsWith('/me/profile'));
      expect(lotdRequests.last.body!['hasVehicle'], true);
      await repo.updateSitterProfileMe(name: 'Léa Martin', mobile: '', hasVehicle: false);
      expect(lotdRequests.last.body!['hasVehicle'], false);
      await repo.updateSitterProfileMe(name: 'Léa Martin', mobile: '');
      expect(lotdRequests.last.body!.containsKey('hasVehicle'), isFalse);
    });

    test('contrôleurs de profil : jamais envoyé tant que personne n\'a rien dit', () {
      final s = EditSitterProfileController();
      expect(s.hasVehicleWire1011, isNull);
      s.setHasVehicle1011(true);
      expect(s.hasVehicleWire1011, isTrue);
      s.setHasVehicle1011(false);
      expect(s.hasVehicleWire1011, isFalse, reason: 'décoché à la main = « non » envoyé');

      final w = EditWalkerProfileController();
      expect(w.hasVehicleWire1011, isNull);
      w.hasVehicleServer1011 = false;
      expect(w.hasVehicleWire1011, isFalse, reason: 'valeur déjà connue du serveur : renvoyée telle quelle');
      w.setHasVehicle1011(true);
      expect(w.hasVehicleWire1011, isTrue);
    });
  });

  group('formulaire « Publier ma demande »', () {
    setUp(() async => lotdSetUp(role: 'owner'));
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    for (final lang in const <String>['fr', 'ja']) {
      testWidgets('$lang : bloc facultatif en bas, « sans voiture » décoché, heures vides (320 px)', (t) async {
        lotdPhone(t, width: 320, height: 800);
        await t.pumpWidget(lotdApp(
          const PublishReservationRequestScreen(initialServiceType: 'house_sitting'),
          locale: lang == 'fr' ? const Locale('fr', 'FR') : const Locale('ja', 'JP'),
        ));
        await lotdSettle(t);
        expect(t.takeException(), isNull);
        final c = Get.find<PublishReservationRequestController>();
        expect(find.byKey(const Key('c1011_section'), skipOffstage: false), findsOneWidget);
        expect(c.ownerNoCar.value, isFalse);
        expect(c.timeFromWire, '');
        expect(c.timeToWire, '');
        expect(c.extrasDone1011, isFalse, reason: 'facultatif : rien de rempli par défaut');

        final sw = find.byKey(const Key('c1011_no_car_switch'), skipOffstage: false);
        expect(sw, findsOneWidget);
        await t.ensureVisible(sw);
        await lotdSettle(t, frames: 2);
        await t.tap(sw);
        await lotdSettle(t, frames: 4);
        expect(c.ownerNoCar.value, isTrue);
        expect(c.extrasDone1011, isTrue);
        expect(t.takeException(), isNull);

        // Les deux cases d'heure sont là (garde à domicile : pas d'heure à l'étape 3).
        expect(find.byKey(const Key('c1011_time_from'), skipOffstage: false), findsOneWidget);
        expect(find.byKey(const Key('c1011_time_to'), skipOffstage: false), findsOneWidget);
        c.timeFrom.value = const TimeOfDay(hour: 9, minute: 0);
        c.timeTo.value = const TimeOfDay(hour: 18, minute: 30);
        await lotdSettle(t, frames: 4);
        expect(c.timeFromWire, '09:00');
        expect(c.timeToWire, '18:30');
        expect(c.hoursSummary1011, '09:00 – 18:30');
        // La case affiche « De 09:00 » en entier, même à 320 px (pas de « … »).
        final cell = find.descendant(
          of: find.byKey(const Key('c1011_time_from'), skipOffstage: false),
          matching: find.textContaining('09:00', skipOffstage: false),
          skipOffstage: false,
        );
        expect(cell, findsOneWidget);
        final para = t.renderObject<RenderParagraph>(find.descendant(
          of: cell,
          matching: find.byType(RichText, skipOffstage: false),
          skipOffstage: false,
        ));
        expect(para.didExceedMaxLines, isFalse, reason: 'heure coupée à 320 px');
        final box = t.getSize(find.ancestor(
          of: cell,
          matching: find.byType(FittedBox, skipOffstage: false),
        ).first);
        final scale = para.size.width <= box.width ? 1.0 : box.width / para.size.width;
        // ignore: avoid_print
        print('C1011 $lang 320px case heure : texte ${para.size.width.toStringAsFixed(1)} px, place ${box.width.toStringAsFixed(1)} px, échelle ${scale.toStringAsFixed(2)}');
        expect(scale, greaterThanOrEqualTo(0.8), reason: 'heure trop réduite à 320 px');
        // Effacer une heure.
        final clear = find.byKey(const Key('c1011_time_to_clear'), skipOffstage: false);
        expect(clear, findsOneWidget);
        await t.ensureVisible(clear);
        await lotdSettle(t, frames: 2);
        await t.tap(clear);
        await lotdSettle(t, frames: 4);
        expect(c.timeTo.value, isNull);
        expect(c.timeToWire, '');
        expect(t.takeException(), isNull);
      });
    }

    // 638 (contrôle ZOE) — une heure de fin avant l'heure de début est refusée.
    testWidgets('heures souhaitées : fin avant le début refusée, début après la fin efface la fin', (t) async {
      lotdPhone(t, width: 375, height: 800);
      await t.pumpWidget(lotdApp(
        const PublishReservationRequestScreen(initialServiceType: 'house_sitting'),
      ));
      await lotdSettle(t);
      final c = Get.find<PublishReservationRequestController>();

      // Plusieurs jours (ou pas encore de dates) : « 20:00 – 08:00 » est une
      // vraie demande (dépôt le soir, reprise le matin) → acceptée.
      expect(c.setHour1011(isFrom: true, picked: const TimeOfDay(hour: 20, minute: 0)), isTrue);
      expect(c.setHour1011(isFrom: false, picked: const TimeOfDay(hour: 8, minute: 0)), isTrue);
      expect(c.hoursSummary1011, '20:00 – 08:00');
      c.startDate.value = DateTime(2030, 6, 10);
      c.endDate.value = DateTime(2030, 6, 12);
      expect(c.hoursSameDay1011, isFalse);
      expect(c.setHour1011(isFrom: false, picked: const TimeOfDay(hour: 7, minute: 30)), isTrue);
      c.timeFrom.value = null;
      c.timeTo.value = null;

      // Un seul jour : la fin doit venir après le début.
      c.endDate.value = DateTime(2030, 6, 10);
      expect(c.hoursSameDay1011, isTrue);

      // Fin seule, puis début seul : libres.
      expect(c.setHour1011(isFrom: false, picked: const TimeOfDay(hour: 8, minute: 0)), isTrue);
      expect(c.timeToWire, '08:00');
      c.timeTo.value = null;
      expect(c.setHour1011(isFrom: true, picked: const TimeOfDay(hour: 9, minute: 0)), isTrue);
      // Fin avant le début, ou égale : refusée, rien ne bouge.
      expect(c.setHour1011(isFrom: false, picked: const TimeOfDay(hour: 8, minute: 30)), isFalse);
      expect(c.setHour1011(isFrom: false, picked: const TimeOfDay(hour: 9, minute: 0)), isFalse);
      expect(c.timeTo.value, isNull);
      expect(c.timeToWire, '', reason: 'aucune heure de fin invalide ne part au serveur');
      // Fin après le début : acceptée.
      expect(c.setHour1011(isFrom: false, picked: const TimeOfDay(hour: 18, minute: 0)), isTrue);
      expect(c.hoursSummary1011, '09:00 – 18:00');
      // Début repoussé après la fin : la fin est effacée, à rechoisir.
      expect(c.setHour1011(isFrom: true, picked: const TimeOfDay(hour: 19, minute: 0)), isTrue);
      expect(c.timeFromWire, '19:00');
      expect(c.timeTo.value, isNull);

      // À l'écran : case « fin » → sélecteur (18:00 proposé) → OK, avec un
      // début à 19:00 : refus, bandeau « Heure invalide », la case reste vide.
      await lotdSettle(t, frames: 4);
      final to = find.byKey(const Key('c1011_time_to'), skipOffstage: false);
      await t.ensureVisible(to);
      await lotdSettle(t, frames: 2);
      await t.tap(to);
      await lotdSettle(t, frames: 6);
      final ok = find.text(
        MaterialLocalizations.of(t.element(find.byType(Dialog))).okButtonLabel,
      );
      expect(ok, findsOneWidget);
      await t.tap(ok);
      await lotdSettle(t, frames: 6);
      expect(c.timeTo.value, isNull, reason: '18:00 avant 19:00 : refusé');
      expect(find.text(AppTranslations().keys['fr_FR']!['send_request_invalid_time_title']!), findsOneWidget);
      // Le bandeau se ferme tout seul.
      await t.pump(const Duration(seconds: 8));
      await lotdSettle(t, frames: 6);
      expect(t.takeException(), isNull);
    });

    testWidgets('« Garde en journée » est proposée et lisible comme telle', (t) async {
      lotdPhone(t, width: 375, height: 812);
      await t.pumpWidget(lotdApp(const PublishReservationRequestScreen(initialServiceType: 'day_care')));
      await lotdSettle(t);
      expect(t.takeException(), isNull);
      final c = Get.find<PublishReservationRequestController>();
      expect(c.selectedServiceType.value, 'day_care');
      expect(find.text('Garde en journée', skipOffstage: false), findsWidgets);
      expect(find.textContaining('rentre le soir', skipOffstage: false), findsWidgets);
    });

    testWidgets('garde en journée + dates précises : les heures de l\'étape 3 servent d\'horaires, pas de double saisie',
        (t) async {
      lotdPhone(t, width: 375, height: 812);
      await t.pumpWidget(lotdApp(const PublishReservationRequestScreen(initialServiceType: 'day_care')));
      await lotdSettle(t);
      final c = Get.find<PublishReservationRequestController>();
      if (c.hoursComeFromDates1011) {
        expect(find.byKey(const Key('c1011_time_from'), skipOffstage: false), findsNothing);
        c.startTime.value = const TimeOfDay(hour: 8, minute: 0);
        c.endTime.value = const TimeOfDay(hour: 19, minute: 0);
        expect(c.timeFromWire, '08:00');
        expect(c.timeToWire, '19:00');
      } else {
        expect(find.byKey(const Key('c1011_time_from'), skipOffstage: false), findsOneWidget);
      }
      // « Sans voiture » reste proposé dans tous les cas.
      expect(find.byKey(const Key('c1011_no_car_switch'), skipOffstage: false), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  // 638 (contrôle ZOE) — 409 ALREADY_PAID : le serveur ne parle qu'anglais.
  group('ALREADY_PAID (pur)', () {
    for (final lang in _langs) {
      test('$lang : phrase traduite, jamais le code ni l\'anglais du serveur', () {
        final pack = conclure1011I18n[lang]!;
        Get.addTranslations(<String, Map<String, String>>{'${lang}_XX': pack});
        Get.locale = Locale(lang, 'XX');
        final e = ApiException('This request is already paid.', statusCode: 409, details: <String, dynamic>{
          'error': 'This request is already paid.', 'code': 'ALREADY_PAID',
        });
        final msg = alreadyPaidMessage1011(e);
        expect(msg, pack['c1011_already_paid']);
        expect(msg, isNot(contains('ALREADY_PAID')));
        if (lang != 'en') expect(msg, isNot(contains('already paid')));
        expect('c1011_already_paid_title'.tr, pack['c1011_already_paid_title']);
        // Corps sans `code` (ancien client HTTP) : reconnu par la phrase.
        expect(alreadyPaidMessage1011(ApiException('This request is already paid.', statusCode: 409)), msg);
        // Autres 409 : pas concernés.
        expect(
          alreadyPaidMessage1011(ApiException('x', statusCode: 409, details: <String, dynamic>{'code': 'RATE_PENDING'})),
          isNull,
        );
      });
    }

    test('le contrôleur des candidatures passe par ce message (plus de phrase brute)', () {
      final src = File('lib/controllers/applications_controller.dart').readAsStringSync();
      final i = src.indexOf('alreadyPaidMessage1011(error)');
      final j = src.indexOf("CustomSnackbar.showError(title: 'common_error'.tr, message: error.message)");
      expect(i, greaterThan(0));
      expect(j, greaterThan(i), reason: 'ALREADY_PAID traité avant le repli générique');
    });
  });

  group('affichage côté gardien / promeneur', () {
    setUp(() async => lotdSetUp(role: 'sitter'));
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    Widget sheet({String hours = '', bool noCar = false}) => lotdApp(Scaffold(
          body: SingleChildScrollView(
            child: PawMapRequestSheet(
              ownerName: 'Marc', ownerAvatar: '', walking: false, city: 'Zone test',
              distanceLabel: '', dateLabel: '', budgetLabel: '', body: '',
              hoursLabel: hours, ownerNoCar: noCar,
              mine: false, approx: true, viewerRole: 'sitter',
              proposeState: PawProposeState.idle,
              onPropose: () {}, onOpenMine: () {}, onOwnerProfile: () {},
            ),
          ),
        ));

    testWidgets('feuille de la demande (PawMap) : heures et « sans voiture », masqués si vides', (t) async {
      lotdPhone(t, width: 320, height: 800);
      await t.pumpWidget(sheet(hours: '09:00 – 18:00', noCar: true));
      await lotdSettle(t);
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('pawmap_request_hours1011')), findsOneWidget);
      expect(find.text('09:00 – 18:00'), findsOneWidget);
      expect(find.byKey(const Key('pawmap_request_nocar1011')), findsOneWidget);
      expect(find.text('Propriétaire sans voiture'), findsOneWidget);
      await t.pumpWidget(sheet());
      await lotdSettle(t);
      expect(find.byKey(const Key('pawmap_request_hours1011')), findsNothing);
      expect(find.byKey(const Key('pawmap_request_nocar1011')), findsNothing);
    });

    Widget card({String hours = '', bool noCar = false}) => lotdApp(Scaffold(
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
              hoursLabel: hours,
              ownerNoCar: noCar,
              viewerRole: 'sitter',
            ),
          ),
        ));

    for (final width in const <double>[320, 375]) {
      testWidgets('carte d\'annonce ($width px) : cases « Horaires » et « Sans voiture », absentes si vides',
          (t) async {
        lotdPhone(t, width: width, height: 812);
        await t.pumpWidget(card(hours: '09:00 – 18:00', noCar: true));
        await lotdSettle(t, frames: 8);
        expect(t.takeException(), isNull);
        expect(find.text('Horaires'), findsOneWidget);
        expect(find.text('09:00 – 18:00'), findsOneWidget);
        expect(find.text('Sans voiture'), findsOneWidget);
        await t.pumpWidget(card());
        await lotdSettle(t, frames: 8);
        expect(t.takeException(), isNull);
        expect(find.text('Horaires'), findsNothing);
        expect(find.text('Sans voiture'), findsNothing);
      });
    }
  });

  group('pastille « Véhiculé » côté propriétaire', () {
    setUp(() async {
      await lotdSetUp(role: 'owner');
      Get.locale = const Locale('fr', 'FR');
    });
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    for (final lang in _langs) {
      testWidgets('$lang : pastille seule, texte du lot, sans débordement à 320 px', (t) async {
        lotdPhone(t, width: 320, height: 600);
        final locale = <String, Locale>{
          'fr': const Locale('fr', 'FR'), 'en': const Locale('en', 'US'), 'es': const Locale('es', 'ES'),
          'de': const Locale('de', 'DE'), 'it': const Locale('it', 'IT'), 'pt': const Locale('pt', 'PT'),
          'ko': const Locale('ko', 'KR'), 'ja': const Locale('ja', 'JP'), 'pl': const Locale('pl', 'PL'),
        }[lang]!;
        await t.pumpWidget(lotdApp(
          const Scaffold(body: Center(child: VehicleBadge1011(accent: Color(0xFF2563EB)))),
          locale: locale,
        ));
        await lotdSettle(t);
        expect(t.takeException(), isNull);
        expect(find.text(conclure1011I18n[lang]!['c1011_vehicle_badge']!), findsOneWidget);
        expect(find.byIcon(Icons.directions_car_rounded), findsOneWidget);
      });
    }

    Future<void> open(WidgetTester tester, List<Map<String, dynamic>> apps) async {
      lotdResponder = (req) {
        if (req.url.path.endsWith('/applications/my')) {
          return <String, dynamic>{'applications': apps};
        }
        if (req.url.path.contains('/posts/by-id/')) {
          return <String, dynamic>{
            'post': {
              'id': 'p1', '_id': 'p1', 'dateMode': 'exact', 'serviceTypes': ['day_care'],
              'location': {'city': 'Zone test', 'lat': -35, 'lng': -30},
              'owner': {'id': 'o1', 'name': 'Camille'},
              'createdAt': '2026-11-09T10:00:00Z', 'updatedAt': '2026-11-09T10:00:00Z',
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
              onPressed: () => PostCandidatesSheet.show(context: ctx, postId: 'p1', source: 'push'),
              child: const Text('ouvrir'),
            ),
          ),
        );
      })));
      await lotdSettle(tester);
      await tester.tap(find.byKey(const Key('open_sheet')));
      await lotdSettle(tester, frames: 14);
    }

    testWidgets('feuille des candidats : pastille pour le gardien ET le promeneur véhiculés, rien pour les autres',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [
        _app('a1', 'Léa Martin', vehicle: true),
        _app('a2', 'Tom Petit', role: 'walker', vehicle: true),
        _app('a3', 'Zoé Roux', vehicle: false),
        _app('a4', 'Max Noir', vehicle: null),
        _app('a5', 'Lou Brun'),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('Tes candidats (5)'), findsOneWidget);
      expect(find.byKey(const Key('c1011_vehicle_a1'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const Key('c1011_vehicle_a2'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const Key('c1011_vehicle_a3'), skipOffstage: false), findsNothing);
      expect(find.byKey(const Key('c1011_vehicle_a4'), skipOffstage: false), findsNothing);
      expect(find.byKey(const Key('c1011_vehicle_a5'), skipOffstage: false), findsNothing);
      expect(find.byType(VehicleBadge1011, skipOffstage: false), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    Widget appCard({required bool vehicle}) => lotdApp(Scaffold(
          body: SingleChildScrollView(
            child: ServiceProviderCard(
              name: 'Léa Martin',
              phoneNumber: '',
              email: '',
              rating: 0,
              location: 'Zone test',
              status: 'pending',
              pricePerHour: '0',
              sitterId: 's1',
              cardType: ServiceProviderCardType.application,
              hasVehicle: vehicle,
            ),
          ),
        ));

    testWidgets('carte de candidature (écran Candidatures) : pastille à true, rien sinon', (t) async {
      lotdPhone(t, width: 375, height: 812);
      await t.pumpWidget(appCard(vehicle: true));
      await lotdSettle(t, frames: 8);
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('c1011_vehicle_badge')), findsOneWidget);
      expect(find.text('Véhiculé'), findsOneWidget);
      await t.pumpWidget(appCard(vehicle: false));
      await lotdSettle(t, frames: 8);
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('c1011_vehicle_badge')), findsNothing);
      expect(find.text('Véhiculé'), findsNothing);
    });
  });

  // lotdSetUp se fait dans setUp, jamais dans le corps d'un testWidgets
  // (une attente réelle y bloque le test pour toujours).
  group('interrupteur « J\'ai un véhicule » du profil promeneur', () {
    setUp(() async {
      await lotdSetUp(role: 'walker');
      // Dans l'app, main.dart le pose au démarrage.
      Get.put(ThemeController());
    });
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    testWidgets('promeneur : lu du serveur (true), modifiable, 375 px', (t) async {
      lotdResponder = (req) {
        if (req.url.path.endsWith('/walkers/me')) {
          return <String, dynamic>{
            'walker': <String, dynamic>{'id': 'w1', 'name': 'Tom Petit', 'hasVehicle': true},
          };
        }
        return <String, dynamic>{};
      };
      lotdPhone(t, width: 375, height: 812);
      await t.pumpWidget(lotdApp(const EditWalkerProfileScreen()));
      await lotdSettle(t, frames: 12);
      expect(t.takeException(), isNull);
      final c = Get.find<EditWalkerProfileController>();
      final sw = find.byKey(const Key('c1011_has_vehicle_switch'), skipOffstage: false);
      expect(sw, findsOneWidget);
      expect(c.hasVehicleServer1011, isTrue);
      expect(c.hasVehicle.value, isTrue);
      expect(find.text('J\'ai un véhicule', skipOffstage: false), findsOneWidget);
      expect(find.text('Je peux venir chercher l\'animal', skipOffstage: false), findsOneWidget);
      await t.ensureVisible(sw);
      await lotdSettle(t, frames: 2);
      await t.tap(find.descendant(of: sw, matching: find.byType(Switch)));
      await lotdSettle(t, frames: 4);
      expect(c.hasVehicle.value, isFalse);
      expect(c.hasVehicleWire1011, isFalse);
      expect(t.takeException(), isNull);
    });

  });

  group('interrupteur « J\'ai un véhicule » du profil gardien', () {
    setUp(() async {
      await lotdSetUp(role: 'sitter');
      // Dans l'app, main.dart le pose au démarrage.
      Get.put(ThemeController());
    });
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    testWidgets('gardien : pas dit par défaut (rien envoyé), activé à la main → true', (t) async {
      lotdPhone(t, width: 375, height: 812);
      await t.pumpWidget(lotdApp(const EditSitterProfileScreen()));
      await lotdSettle(t, frames: 12);
      expect(t.takeException(), isNull);
      final c = Get.find<EditSitterProfileController>();
      final sw = find.byKey(const Key('c1011_has_vehicle_switch'), skipOffstage: false);
      expect(sw, findsOneWidget);
      expect(c.hasVehicle.value, isFalse);
      expect(c.hasVehicleWire1011, isNull);
      await t.ensureVisible(sw);
      await lotdSettle(t, frames: 2);
      await t.tap(find.descendant(of: sw, matching: find.byType(Switch)));
      await lotdSettle(t, frames: 4);
      expect(c.hasVehicle.value, isTrue);
      expect(c.hasVehicleWire1011, isTrue);
      expect(t.takeException(), isNull);
    });
  });
}
