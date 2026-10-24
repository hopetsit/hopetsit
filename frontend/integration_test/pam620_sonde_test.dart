// 620 (PAM, 24/10/2026 — contrat CONTRAT_620_dates_visites.md §C) — sonde
// SIMULATEUR : rendu iOS réel des écrans du build 620 dans le harnais lot D
// (faux HTTP = réponses du CONTRAT serveur, aucun compte, aucun réseau, zone
// fictive −35 / −30). Le runner capture l'écran à chaque ligne « [SHOT] nom ».
//
//   flutter test integration_test/pam620_sonde_test.dart -d <udid>
//
// Parcours capturés :
//   01-05  « Publier ma demande » : 3 modes de dates, à prévoir, période
//          approximative, visite à domicile (catalogue serveur) + 2 visites
//          par jour + estimation du moteur, mode sombre ;
//   pawmap/06-08  fiche d'un membre (« dès 12 €/visite », ligne Visite) →
//          « Demander à Léa » = même formulaire, bandeau, services selon
//          SES tarifs, dates à prévoir ;
//   09-10  candidats : indicatif (« 12 €/visite · indicatif », bandeau « Pose
//          tes dates », Choisir verrouillé) puis dates posées (totaux réels) ;
//   11-12  « Mes tarifs » gardien (grille : visite + durée) et promeneur.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/controllers/petsitter_onboarding_controller.dart';
import 'package:hopetsit/controllers/sign_up_controller.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/views/auth/signup_wizard_screen.dart';
import 'package:hopetsit/views/pet_sitter/onboarding/petsitter_onboarding_screen.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/dates620.dart';
import 'package:hopetsit/utils/services620.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:hopetsit/views/map/pawmap_rates.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_candidates_sheet.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/views/profile/my_rates_screen.dart';
import 'package:hopetsit/widgets/city_location_picker.dart';
import 'package:integration_test/integration_test.dart';

import '../test/lotd_harness.dart';

Future<void> _pause(WidgetTester t, int frames) async {
  for (int i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _shot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 200));
  debugPrint('[SHOT] $name');
  await Future<void>.delayed(const Duration(seconds: 3));
}

Future<void> _scrollTo(WidgetTester t, Finder f) async {
  final scrollable = find.byType(Scrollable).first;
  try {
    await t.scrollUntilVisible(f, 160, scrollable: scrollable);
  } catch (_) {/* déjà visible ou non défilable */}
  await _pause(t, 2);
}

Future<void> _tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await _scrollTo(t, f);
  await t.tap(f);
  await _pause(t, 2);
}

const Map<String, dynamic> kCatalog = <String, dynamic>{
  'services': <Map<String, dynamic>>[
    {'key': 'house_sitting', 'unit': 'day'},
    {'key': 'home_visit', 'unit': 'visit', 'durations': [30, 60], 'visitsPerDay': [1, 2]},
    {'key': 'day_care', 'unit': 'day'},
    {'key': 'dog_walking', 'unit': 'walk'},
  ],
};

/// Extrait RÉEL de `GET /app-config/services` (24/10/2026) : liste `all` avec
/// libellés 9 langues.
const Map<String, dynamic> kCatalogLabels = <String, dynamic>{
  'services': <Map<String, dynamic>>[
    {'key': 'house_sitting', 'unit': 'day'},
    {'key': 'home_visit', 'unit': 'visit', 'durations': [30, 60], 'visitsPerDay': [1, 2]},
    {'key': 'day_care', 'unit': 'day'},
    {'key': 'dog_walking', 'unit': 'walk'},
  ],
  'all': <Map<String, dynamic>>[
    {'key': 'house_sitting', 'unit': 'day', 'active': true,
     'label': {'fr': 'Garde à domicile', 'en': 'House sitting', 'de': 'Betreuung zu Hause', 'pt': 'Cuidado ao domicílio'},
     'desc': {'fr': 'Un gardien chez vous ou chez lui, par jour (par nuit chez le gardien).', 'de': 'Betreuung bei dir oder beim Sitter, pro Tag (pro Nacht beim Sitter).', 'pt': 'Um cuidador em sua casa ou na dele, por dia (por noite em casa do cuidador).'}},
    {'key': 'home_visit', 'unit': 'visit', 'active': true, 'durations': [30, 60], 'visitsPerDay': [1, 2],
     'label': {'fr': 'Visite à domicile', 'en': 'Home visit', 'de': 'Hausbesuch', 'pt': 'Visita ao domicílio'},
     'desc': {'fr': 'Le gardien passe chez vous, 1 ou 2 fois par jour, 30 ou 60 min. Prix par visite.', 'de': 'Der Sitter kommt 1- oder 2-mal täglich zu Ihnen, 30 oder 60 Minuten. Preis pro Besuch.', 'pt': 'O cuidador passa por sua casa, 1 ou 2 vezes por dia, 30 ou 60 min. Preço por visita.'}},
    {'key': 'day_care', 'unit': 'day', 'active': true,
     'label': {'fr': 'Garderie', 'en': 'Day care', 'de': 'Tagesbetreuung', 'pt': 'Creche'},
     'desc': {'fr': 'À la journée, sans nuit.', 'de': 'Tagsüber, ohne Übernachtung.', 'pt': 'Durante o dia, sem pernoita.'}},
    {'key': 'dog_walking', 'unit': 'walk', 'active': true,
     'label': {'fr': 'Promenade', 'en': 'Dog walking', 'de': 'Gassi gehen', 'pt': 'Passeio'},
     'desc': {'fr': 'Une balade, prix par balade.', 'de': 'Ein Spaziergang, Preis pro Spaziergang.', 'pt': 'Um passeio, preço por passeio.'}},
  ],
};

Map<String, dynamic> _profile(String role) => <String, dynamic>{
      'id': 'u-test',
      '_id': 'u-test',
      'name': 'Camille Durand',
      'firstName': 'Camille',
      'lastName': 'Durand',
      'email': 'camille@example.test',
      'mobile': '612345678',
      'countryCode': '+33',
      'country': 'FR',
      'city': 'Zone test',
      'postalCode': '75011',
      'avatar': <String, dynamic>{'url': ''},
      'role': role,
      'location': <String, dynamic>{
        'type': 'Point',
        'coordinates': <double>[-30.4, -35.2],
        'city': 'Zone test',
      },
      'language': 'Français',
      'bio': '',
      'currency': 'EUR',
      'service': <String>[],
      'acceptedPetTypes': <String>['dog'],
      'experienceTags': <String>[],
      'coverageRadiusKm': 10,
      'walkRates': <Map<String, dynamic>>[
        {'durationMinutes': 30, 'basePrice': 10, 'currency': 'EUR', 'enabled': true},
        {'durationMinutes': 60, 'basePrice': 15, 'currency': 'EUR', 'enabled': true},
      ],
      'dailyRate': 18,
      'weeklyRate': 110,
      'visitRate': 12,
      'visitDurationMinutes': 30,
    };

Map<String, dynamic> _application(String id, String name, {required bool indicative}) =>
    <String, dynamic>{
      'id': id,
      'postId': 'p-tbd',
      'status': 'pending',
      'createdAt': '2026-10-24T10:00:00Z',
      'description': indicative
          ? 'Je passe nourrir et câliner votre chat, 30 min par visite.'
          : 'Je passe nourrir et câliner votre chat, 30 min par visite.',
      'serviceLocation': 'at_owner',
      'sitter': {
        'id': 's-$id',
        'name': name,
        'currency': 'EUR',
        'rating': id == 'a1' ? 4.8 : 0,
        'reviewsCount': id == 'a1' ? 12 : 0,
        'verified': true,
        'location': {'city': 'Zone test'},
        'avatar': {'url': ''},
      },
      'pricing': indicative
          ? {'indicative': true, 'pricingTier': 'indicative', 'unitRate': id == 'a1' ? 12 : 14, 'unit': 'visit', 'currency': 'EUR'}
          : {'indicative': false, 'pricingTier': 'visit', 'unitRate': id == 'a1' ? 12 : 14, 'unit': 'visit',
              'quantity': 6, 'basePrice': id == 'a1' ? 72 : 84, 'commission': id == 'a1' ? 14.4 : 16.8,
              'totalPrice': id == 'a1' ? 86.4 : 100.8, 'netPayout': id == 'a1' ? 72 : 84, 'currency': 'EUR'},
    };

Future<PublishReservationRequestController> _openForm(
  WidgetTester t, {
  String? initial,
  TargetProvider620? target,
  Brightness brightness = Brightness.light,
}) async {
  await t.pumpWidget(lotdApp(
    PublishReservationRequestScreen(initialServiceType: initial, targetProvider: target),
    brightness: brightness,
  ));
  await _pause(t, 4);
  final c = Get.find<PublishReservationRequestController>();
  c.cityController.text = 'Zone test';
  markCityPicked610(c.cityController, 'Zone test');
  c.userLat.value = -35.2;
  c.userLng.value = -30.4;
  c.gpsPrecise.value = true;
  c.animalTypes.add('cat');
  return c;
}

void _respondCatalogAndEstimate({bool indicativeOnly = false}) {
  lotdResponder = (req) {
    final path = req.url.path;
    if (path.endsWith('/app-config/services')) return kCatalog;
    if (path.endsWith('/pricing/estimate')) {
      final body = lotdRequests.last.body ?? const <String, dynamic>{};
      final mode = (body['dateMode'] ?? '').toString();
      if (mode == 'tbd' || indicativeOnly) {
        return {'indicative': true, 'quantity': null, 'ownerTotal': null, 'unit': 'visit', 'currency': 'EUR'};
      }
      final post = body['post'] is Map ? body['post'] as Map : const {};
      final vpd = (post['visitsPerDay'] as num?)?.toInt() ?? 1;
      final start = DateTime.tryParse('${body['startDate']}');
      final end = DateTime.tryParse('${body['endDate']}');
      final days = (start != null && end != null) ? end.difference(start).inDays + 1 : 1;
      final rate = (body['rate'] as num?)?.toDouble() ?? 12;
      final unit = (body['serviceType'] == 'home_visit') ? 'visit' : 'day';
      final qty = unit == 'visit' ? days * vpd : days;
      final unitTotal = qty * rate;
      return {
        'indicative': false, 'quantity': qty, 'unit': unit, 'unitRate': rate, 'unitTotal': unitTotal,
        'commission': unitTotal * 0.2, 'ownerTotal': unitTotal * 1.2, 'currency': 'EUR',
      };
    }
    if (path.contains('/walkers/me/rates')) {
      return <String, dynamic>{'walkRates': _profile('walker')['walkRates']};
    }
    if (path.contains('/sitters/me/rates')) {
      return <String, dynamic>{'rates': {'dailyRate': 18, 'weeklyRate': 110, 'visitRate': 12, 'visitDurationMinutes': 30}};
    }
    if (path.contains('/users/me/profile')) {
      return <String, dynamic>{'profile': _profile('sitter'), 'user': _profile('sitter'), 'role': 'sitter'};
    }
    if (path.contains('/walkers/me') || path.contains('/sitters/')) return _profile('sitter');
    return <String, dynamic>{};
  };
}

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  b.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('sonde 620 — dates à prévoir, visites, PawMap, candidats, tarifs', (t) async {
    // Les sections facultatives notent leurs échecs ici sans arrêter la sonde
    // (les captures suivantes sont prises) ; la sonde échoue à la fin s'il y en a.
    final fails = <String>[];
    // ── 1. « Publier ma demande » : 3 modes de dates ──
    await lotdSetUp(role: 'owner');
    ServiceCatalog620.reset();
    _respondCatalogAndEstimate();
    final p = Map<String, dynamic>.from(GetStorage().read(StorageKeys.userProfile) as Map);
    p['country'] = 'FR';
    p['city'] = 'Zone test';
    await GetStorage().write(StorageKeys.userProfile, p);
    var c = await _openForm(t, initial: 'pet_sitting');
    c.serviceLocation.value = 'at_owner';
    await ServiceCatalog620.load(force: true);
    await _pause(t, 2);
    final modeExact = find.byKey(const Key('dates620_mode_exact'), skipOffstage: false);
    expect(modeExact, findsOneWidget, reason: '3 cartes de mode de dates');
    await _scrollTo(t, modeExact);
    await _shot(t, '01_publier_modes_dates');
    await _tapKey(t, 'dates620_mode_tbd');
    expect(c.isDatesTbd, isTrue);
    expect(find.byKey(const Key('dates620_tbd_hint'), skipOffstage: false), findsOneWidget);
    await c.refreshEstimate();
    await _pause(t, 3);
    await _scrollTo(t, find.byKey(const Key('dates620_tbd_hint'), skipOffstage: false));
    await _shot(t, '02_publier_dates_a_prevoir');
    await _tapKey(t, 'dates620_mode_approx');
    c.startDate.value = DateTime(2026, 11, 3);
    c.endDate.value = DateTime(2026, 11, 5);
    await _pause(t, 2);
    await _scrollTo(t, find.byKey(const Key('dates620_approx_end'), skipOffstage: false));
    await _shot(t, '03_publier_periode_approximative');
    expect(t.takeException(), isNull);

    // ── 2. Visite à domicile (catalogue serveur) + 2 visites par jour + estimation ──
    await _tapKey(t, 'dates620_service_home_visit');
    expect(c.isHomeVisit, isTrue);
    await _tapKey(t, 'dates620_visits_2');
    await _tapKey(t, 'dates620_mode_exact');
    c.startDate.value = DateTime(2026, 11, 3);
    c.endDate.value = DateTime(2026, 11, 5);
    c.onDatesChanged();
    await c.refreshEstimate();
    await _pause(t, 3);
    expect(c.estimate.value?.quantity, 6, reason: '3 jours × 2 visites');
    await _scrollTo(t, find.byKey(const Key('neo610_start_time'), skipOffstage: false));
    await _shot(t, '04_publier_visite_2_par_jour_estimation');
    await _scrollTo(t, find.byKey(const Key('dates620_visits_2'), skipOffstage: false));
    await _shot(t, '04b_publier_visite_service_visites');
    expect(t.takeException(), isNull);
    // L'écran est démonté AVANT de jeter ses contrôleurs (sinon « addListener
    // après dispose » au rebuild).
    await t.pumpWidget(const SizedBox.shrink());
    await _pause(t, 1);
    await Get.deleteAll(force: true);
    Get.reset();

    // ── 3. Mode sombre ──
    await lotdSetUp(role: 'owner');
    ServiceCatalog620.reset();
    _respondCatalogAndEstimate();
    Get.put(ThemeController(), permanent: true);
    c = await _openForm(t, initial: 'home_visit', brightness: Brightness.dark);
    await ServiceCatalog620.load(force: true);
    await _pause(t, 2);
    c.selectVisitsPerDay(2);
    c.startDate.value = DateTime(2026, 11, 3);
    c.endDate.value = DateTime(2026, 11, 5);
    c.onDatesChanged();
    await c.refreshEstimate();
    await _pause(t, 3);
    await _scrollTo(t, find.byKey(const Key('neo610_start_time'), skipOffstage: false));
    await _shot(t, '05_publier_visite_sombre');
    expect(t.takeException(), isNull);
    // L'écran est démonté AVANT de jeter ses contrôleurs (sinon « addListener
    // après dispose » au rebuild).
    await t.pumpWidget(const SizedBox.shrink());
    await _pause(t, 1);
    await Get.deleteAll(force: true);
    Get.reset();

    // ── 4. PawMap : fiche d'un membre (rendue dans la coquille de feuille,
    //      sans modal : même widget que sur la carte) ──
    await lotdSetUp(role: 'owner');
    ServiceCatalog620.reset();
    _respondCatalogAndEstimate();
    // Les libellés de la fiche se traduisent à la construction : les
    // traductions sont posées AVANT (comme dans l'app réelle).
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr', 'FR');
    const rates = PawProviderRates(
        currency: 'EUR', role: 'sitter', daily: 18, weekly: 110, visit: 12, visitDurationMinutes: 30);
    const member = PawMapMemberData(
      id: 's1', role: 'sitter', name: 'Léa Martin', online: true, verified: true,
      rating: 4.8, reviewsCount: 12, priceFrom: 12, currency: 'EUR', distanceLabel: '450 m',
    );
    final priceLabel = '${CurrencyHelper.formatCompact('EUR', 12)}${priceUnitSuffix620('visit')}';
    try {
      await t.pumpWidget(lotdApp(Scaffold(
        backgroundColor: const Color(0xFFFFF1EC),
        body: Align(
          alignment: Alignment.bottomCenter,
          child: PawMapSheetShell(
            maxHeightFactor: 0.9,
            child: PawMapMemberSheet(
              member: member,
              viewerRole: 'owner',
              viewerLoggedIn: true,
              friendState: PawFriendState.idle,
              priceLabel: priceLabel,
              rates: rates.lines,
              onBook: () {},
              onProfile: () {},
              onMessage: () {},
              onFriend: () {},
              onDirections: null,
              onPropose: () {},
              onSignup: () {},
            ),
          ),
        ),
      )));
      await _pause(t, 5);
      final ok = find.textContaining('/visite').evaluate().isNotEmpty;
      await _shot(t, ok ? 'pawmap/06_pawmap_fiche_membre_visite' : 'pawmap/06_pawmap_fiche_membre_SANS_prix');
      if (!ok) fails.add('06 fiche membre : « /visite » absent');
      final ex = t.takeException();
      if (ex != null) fails.add('06 fiche membre : exception $ex');
    } catch (e) {
      fails.add('06 fiche membre : $e');
    }
    await t.pumpWidget(const SizedBox.shrink());
    await _pause(t, 1);
    await Get.deleteAll(force: true);
    Get.reset();

    await lotdSetUp(role: 'owner');
    ServiceCatalog620.reset();
    _respondCatalogAndEstimate();
    const target = TargetProvider620(
        id: 's1', role: 'sitter', name: 'Léa Martin', currency: 'EUR',
        rateDay: 18, rateVisit: 12, visitDurationMinutes: 30);
    c = await _openForm(t, initial: 'home_visit', target: target);
    await ServiceCatalog620.load(force: true);
    await _pause(t, 2);
    expect(find.byKey(const Key('dates620_target_banner')), findsOneWidget);
    await _shot(t, 'pawmap/07_pawmap_demande_a_lea_bandeau');
    await _scrollTo(t, find.byKey(const Key('dates620_service_dog_walking'), skipOffstage: false));
    await _shot(t, 'pawmap/07b_pawmap_services_selon_ses_tarifs');
    await _tapKey(t, 'dates620_mode_tbd');
    await c.refreshEstimate();
    await _pause(t, 3);
    await _scrollTo(t, find.byKey(const Key('dates620_estimate'), skipOffstage: false));
    await _shot(t, 'pawmap/08_pawmap_demande_dates_a_prevoir');
    await _tapKey(t, 'dates620_mode_exact');
    c.startDate.value = DateTime(2026, 11, 3);
    c.endDate.value = DateTime(2026, 11, 5);
    c.onDatesChanged();
    await c.refreshEstimate();
    await _pause(t, 3);
    expect(c.estimate.value?.hasTotal, isTrue, reason: 'estimation avec SON tarif (12 €/visite)');
    await _scrollTo(t, find.byKey(const Key('dates620_estimate'), skipOffstage: false));
    await _shot(t, 'pawmap/08b_pawmap_demande_dates_posees_total');
    expect(t.takeException(), isNull);
    // L'écran est démonté AVANT de jeter ses contrôleurs (sinon « addListener
    // après dispose » au rebuild).
    await t.pumpWidget(const SizedBox.shrink());
    await _pause(t, 1);
    await Get.deleteAll(force: true);
    Get.reset();

    // ── 5. Candidats : indicatif puis dates posées (feuille modale réelle) ──
    for (final step in <(String, bool)>[('09_candidats_indicatif_choisir_verrouille', true), ('10_candidats_dates_posees_totaux', false)]) {
      await lotdSetUp(role: 'owner');
      lotdResponder = (req) {
        if (req.url.path.endsWith('/applications/my')) {
          return <String, dynamic>{
            'applications': [
              _application('a1', 'Léa Martin', indicative: step.$2),
              _application('a2', 'Tom Petit', indicative: step.$2),
            ],
          };
        }
        return <String, dynamic>{};
      };
      try {
        await t.pumpWidget(lotdApp(Builder(builder: (ctx) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PostCandidatesSheet.show(context: ctx, postId: 'p-tbd');
          });
          return const Scaffold(body: SizedBox.expand());
        })));
        await _pause(t, 8);
        final banner = find.byKey(const Key('dates620_set_dates_banner')).evaluate().isNotEmpty;
        final ok = step.$2
            ? (banner && find.textContaining('indicatif').evaluate().isNotEmpty)
            : (!banner && find.text(CurrencyHelper.formatCompact('EUR', 86.4)).evaluate().isNotEmpty);
        await _shot(t, ok ? step.$1 : '${step.$1}_ECHEC');
        if (!ok) fails.add('${step.$1} : rendu inattendu (bandeau=$banner)');
        final ex = t.takeException();
        if (ex != null) fails.add('${step.$1} : exception $ex');
      } catch (e) {
        fails.add('${step.$1} : $e');
      }
      await t.pumpWidget(const SizedBox.shrink());
      await _pause(t, 1);
      await Get.deleteAll(force: true);
      Get.reset();
    }

    // ── 6. « Mes tarifs » : grille par service, gardien puis promeneur ──
    for (final role in <String>['sitter', 'walker']) {
      await lotdSetUp(role: role);
      _respondCatalogAndEstimate();
      Get.put(ThemeController(), permanent: true);
      await t.pumpWidget(lotdApp(MyRatesScreen(role: role)));
      await _pause(t, 6);
      if (role == 'sitter') {
        final card = find.byKey(const Key('dates620_rates_visit_card'), skipOffstage: false);
        expect(card, findsOneWidget, reason: 'carte Visite à domicile');
        await _scrollTo(t, card);
      }
      await _shot(t, role == 'sitter' ? '11_tarifs_gardien_grille' : '12_tarifs_promeneur_par_balade');
      expect(t.takeException(), isNull);
      // L'écran est démonté AVANT de jeter ses contrôleurs (sinon « addListener
      // après dispose » au rebuild).
      await t.pumpWidget(const SizedBox.shrink());
      await _pause(t, 1);
      await Get.deleteAll(force: true);
      Get.reset();
    }
    // ── 7. Inscription gardien : étape Tarifs = grille par service, aperçu ──
    await lotdSetUp(role: 'sitter');
    _respondCatalogAndEstimate();
    try {
      final sc = Get.put(
        SignUpController(userType: 'pet_sitter', authRepository: Get.find<AuthRepository>()),
        tag: 'pet_sitter',
        permanent: true,
      );
      sc.nameController.text = 'Léa Martin';
      sc.cityController.text = 'Zone test';
      markCityPicked610(sc.cityController, 'Zone test');
      sc.postalCodeController.text = '97500';
      sc.acceptedAnimals.add('cat');
      sc.selectedServices.addAll(['sit_owner', 'home_visit']);
      sc.ratePerDayController.text = '18';
      sc.visitRateController.text = '12';
      sc.currentStep.value = 3;
      await t.pumpWidget(lotdApp(const SignupWizardScreen(userType: 'pet_sitter')));
      await _pause(t, 4);
      final f = find.byKey(const Key('dates620_signup_visit_field'), skipOffstage: false);
      if (f.evaluate().isEmpty) fails.add('inscription : champ Tarif par visite absent');
      await _scrollTo(t, f);
      await _shot(t, 'inscription/01_wizard_gardien_tarifs_grille');
      sc.selectedServices.remove('sit_owner');
      await _pause(t, 2);
      await _shot(t, 'inscription/02_wizard_gardien_visite_seule');
      sc.selectedServices.add('sit_owner');
      sc.currentStep.value = 4;
      await _pause(t, 3);
      final rev = find.textContaining('/ visite', skipOffstage: false);
      if (rev.evaluate().isEmpty) fails.add('inscription : aperçu sans ligne « / visite »');
      await _scrollTo(t, rev);
      await _shot(t, 'inscription/03_wizard_gardien_apercu_tarifs');
      final ex = t.takeException();
      if (ex != null) fails.add('inscription : exception $ex');
    } catch (e) {
      fails.add('inscription : $e');
    }
    await t.pumpWidget(const SizedBox.shrink());
    await _pause(t, 1);
    await Get.deleteAll(force: true);
    Get.reset();

    // ── 7b. Onboarding gardien (profil incomplet) : tarif par visite + durée ──
    await lotdSetUp(role: 'sitter');
    _respondCatalogAndEstimate();
    try {
      Get.put(PetsitterOnboardingController(), permanent: true);
      Get.put(ThemeController(), permanent: true);
      await t.pumpWidget(lotdApp(const PetsitterOnboardingScreen()));
      await _pause(t, 4);
      final f = find.byKey(const Key('dates620_onb_visit_field'), skipOffstage: false);
      if (f.evaluate().isEmpty) fails.add('onboarding : champ Tarif par visite absent');
      await _scrollTo(t, f);
      await _shot(t, 'inscription/04_onboarding_gardien_visite');
      final ex = t.takeException();
      if (ex != null) fails.add('onboarding : exception $ex');
    } catch (e) {
      fails.add('onboarding : $e');
    }
    await t.pumpWidget(const SizedBox.shrink());
    await _pause(t, 1);
    await Get.deleteAll(force: true);
    Get.reset();

    // ── 8. Langues longues (de, pt) + libellés du catalogue serveur (9 langues) ──
    for (final lang in <(String, String)>[('de', 'DE'), ('pt', 'PT')]) {
      await lotdSetUp(role: 'owner');
      ServiceCatalog620.reset();
      lotdResponder = (req) {
        if (req.url.path.endsWith('/app-config/services')) return kCatalogLabels;
        return <String, dynamic>{};
      };
      try {
        await t.pumpWidget(lotdApp(
          const PublishReservationRequestScreen(initialServiceType: 'home_visit'),
          locale: Locale(lang.$1, lang.$2),
        ));
        await _pause(t, 3);
        await ServiceCatalog620.load(force: true);
        await _pause(t, 2);
        final c = Get.find<PublishReservationRequestController>();
        c.animalTypes.add('cat');
        final f = find.byKey(const Key('dates620_service_home_visit'), skipOffstage: false);
        await _scrollTo(t, f);
        final label = (kCatalogLabels['all'] as List)[1]['label'][lang.$1] as String;
        if (find.text(label).evaluate().isEmpty) fails.add('${lang.$1} : libellé serveur « $label » absent');
        await _shot(t, '13_publier_${lang.$1}_catalogue_serveur');
        await _tapKey(t, 'dates620_mode_tbd');
        await _shot(t, '14_publier_${lang.$1}_dates_a_prevoir');
        final ex = t.takeException();
        if (ex != null) fails.add('${lang.$1} : exception $ex');
      } catch (e) {
        fails.add('${lang.$1} : $e');
      }
      await t.pumpWidget(const SizedBox.shrink());
      await _pause(t, 1);
      await Get.deleteAll(force: true);
      Get.reset();
    }

    expect(fails, isEmpty, reason: fails.join(' | '));
  });
}
