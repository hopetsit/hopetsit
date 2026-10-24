// 621 (PAM, 24/10/2026 — serveur 620b) — sonde SIMULATEUR : rendu iOS réel
// des écrans du build 621 dans le harnais lot D (faux HTTP = réponses RÉELLES
// relevées par ZOE le 24/10, aucun compte, aucun réseau, zone fictive
// −35 / −30). Le runner capture l'écran à chaque ligne « [SHOT] nom ».
//
//   python3 ~/hopetsit-social/preuves/pam620_runner.py <udid> \
//       integration_test/pam621_sonde_test.dart ~/hopetsit-social/preuves/pam621
//
// Parcours capturés :
//   01-02  « Publier ma demande » ouverte (sans prestataire) : « à partir de
//          12 €/visite · estimation ~43,20 € », puis « à prévoir » = « à partir
//          de 12 €/visite » seul ;
//   03     carte « Mes annonces » : case « À partir de » ;
//   04     PawMap, feuille « Ma demande » : ligne « à partir de … » ;
//   05-05b candidats : « Tarif à venir » + bandeau, Choisir verrouillé → appui
//          = explication ; 06 la même feuille en mode sombre ;
//   07     Tarifs du gardien ouverts par la notification (bannière).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/models/nearby_request_model.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/from_rate620.dart';
import 'package:hopetsit/utils/services620.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_candidates_sheet.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_post_card.dart';
import 'package:hopetsit/views/profile/my_rates_screen.dart';
import 'package:hopetsit/widgets/city_location_picker.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';
import 'package:hopetsit/utils/app_colors.dart';
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

/// Réponses RÉELLES de `POST /pricing/estimate` sans prestataire (ZOE 24/10,
/// `preuves/zoe620b/preuve_a3.json`) : 1 gardien à 12 €/visite dans le rayon.
Map<String, dynamic> _market(Map<String, dynamic>? body) {
  final mode = (body?['dateMode'] ?? '').toString();
  if (mode == 'tbd') {
    return {
      'serviceType': 'home_visit', 'dateMode': 'tbd', 'indicative': true, 'fromRate': 12,
      'unit': 'visit', 'quantity': null, 'ownerTotalFrom': null, 'basedOn': 1, 'currency': 'EUR',
      'durationMinutes': 30, 'radiusKm': 100, 'rateSource': 'market', 'unitRate': 12,
    };
  }
  final post = body?['post'] is Map ? body!['post'] as Map : const {};
  final vpd = (post['visitsPerDay'] as num?)?.toInt() ?? 1;
  final start = DateTime.tryParse('${body?['startDate']}');
  final end = DateTime.tryParse('${body?['endDate']}');
  final days = (start != null && end != null) ? end.difference(start).inDays + 1 : 3;
  final qty = days * vpd;
  return {
    'serviceType': 'home_visit', 'dateMode': 'exact', 'indicative': true, 'fromRate': 12,
    'unit': 'visit', 'quantity': qty, 'ownerTotalFrom': qty * 12 * 1.2, 'basedOn': 1,
    'currency': 'EUR', 'durationMinutes': 30, 'radiusKm': 100, 'rateSource': 'market',
    'unitRate': 12, 'unitTotal': null, 'commission': null, 'ownerTotal': null,
  };
}

const Map<String, dynamic> kStalePricing = <String, dynamic>{
  'appliedRate': 0, 'unit': 'visit', 'indicative': true, 'stale': true, 'totalPrice': null,
  'commission': null, 'netPayout': null, 'basePrice': null, 'quantity': null, 'currency': 'EUR',
  'pricingTier': 'indicative',
};

Map<String, dynamic> _application(String id, String name, {required bool stale}) =>
    <String, dynamic>{
      'id': id,
      'postId': 'p1',
      'status': 'pending',
      'createdAt': '2026-10-24T10:00:00Z',
      'description': 'Je passe nourrir et câliner votre chat, 30 min par visite.',
      'serviceLocation': 'at_owner',
      'sitter': {
        'id': 's-$id', 'name': name, 'currency': 'EUR', 'rating': id == 'a1' ? 4.8 : 0,
        'reviewsCount': id == 'a1' ? 12 : 0, 'verified': true,
        'location': {'city': 'Zone test'}, 'avatar': {'url': ''},
      },
      'pricing': stale
          ? kStalePricing
          : {'indicative': false, 'pricingTier': 'visit', 'unitRate': 14, 'unit': 'visit',
              'quantity': 6, 'basePrice': 84, 'commission': 16.8, 'totalPrice': 100.8,
              'netPayout': 84, 'currency': 'EUR'},
    };

PostModel _post({String dateMode = 'exact'}) => PostModel.fromJson(<String, dynamic>{
      'id': 'p1',
      'postType': 'request',
      'body': 'Mimi, chat calme, 2 visites par jour pour les croquettes et les câlins.',
      'serviceTypes': ['home_visit'],
      'dateMode': dateMode,
      'startDate': dateMode == 'tbd' ? null : '2026-11-03T00:00:00.000Z',
      'endDate': dateMode == 'tbd' ? null : '2026-11-05T00:00:00.000Z',
      'visitsPerDay': 1,
      'serviceLocation': 'at_owner',
      'location': {'city': 'Zone test', 'lat': -35.2, 'lng': -30.4},
      'notes': '',
      'images': [],
      'videos': [],
      'likes': [],
      'comments': [],
      'owner': {'id': 'u-test', 'name': 'Camille Durand', 'email': '', 'avatar': ''},
      'pets': [
        {'id': 'pet1', 'petName': 'Mimi', 'category': 'cat', 'avatar': ''},
      ],
    });

void _respond() {
  lotdResponder = (req) {
    final path = req.url.path;
    if (path.endsWith('/app-config/services')) return kCatalog;
    if (path.endsWith('/pricing/estimate')) return _market(lotdRequests.last.body);
    if (path.contains('/sitters/me/rates')) {
      return <String, dynamic>{'rates': {'dailyRate': 18, 'weeklyRate': 110, 'visitRate': 0, 'visitDurationMinutes': 30}};
    }
    if (path.contains('/users/me/profile') || path.contains('/sitters/')) {
      return <String, dynamic>{'dailyRate': 18, 'weeklyRate': 110, 'visitRate': 0, 'currency': 'EUR', 'service': <String>[]};
    }
    return <String, dynamic>{};
  };
}

Future<PublishReservationRequestController> _openForm(WidgetTester t, {String? initial}) async {
  await t.pumpWidget(lotdApp(PublishReservationRequestScreen(initialServiceType: initial)));
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

Future<void> _teardown(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await _pause(t, 1);
  FromRateCache620.reset();
  await Get.deleteAll(force: true);
  Get.reset();
}

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  b.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('sonde 621 — à partir de, tarif à venir, notification → Tarifs', (t) async {
    final fails = <String>[];
    final eur12 = CurrencyHelper.formatCompact('EUR', 12);
    final eur432 = CurrencyHelper.formatCompact('EUR', 43.2);

    // ── 1-2. « Publier ma demande » ouverte : « à partir de … » ──
    await lotdSetUp(role: 'owner');
    ServiceCatalog620.reset();
    _respond();
    final p = Map<String, dynamic>.from(GetStorage().read(StorageKeys.userProfile) as Map);
    p['country'] = 'FR';
    p['city'] = 'Zone test';
    await GetStorage().write(StorageKeys.userProfile, p);
    var c = await _openForm(t, initial: 'home_visit');
    c.serviceLocation.value = 'at_owner';
    await ServiceCatalog620.load(force: true);
    await _pause(t, 2);
    await _tapKey(t, 'dates620_mode_exact');
    c.startDate.value = DateTime(2026, 11, 3);
    c.endDate.value = DateTime(2026, 11, 5);
    c.onDatesChanged();
    await c.refreshEstimate();
    await _pause(t, 3);
    final est = c.estimate.value;
    if (est == null || !est.hasFromTotal) fails.add('01 : estimation market absente ($est)');
    await _scrollTo(t, find.byKey(const Key('dates620_estimate'), skipOffstage: false));
    final ok1 = find.textContaining(eur432).evaluate().isNotEmpty;
    await _shot(t, ok1 ? '01_publier_ouverte_a_partir_de' : '01_publier_ouverte_a_partir_de_ECHEC');
    if (!ok1) fails.add('01 : « estimation ~43,20 € » non affichée');
    await _tapKey(t, 'dates620_mode_tbd');
    await c.refreshEstimate();
    await _pause(t, 3);
    await _scrollTo(t, find.byKey(const Key('dates620_estimate'), skipOffstage: false));
    final ok2 = find.text('à partir de $eur12/visite').evaluate().isNotEmpty;
    await _shot(t, ok2 ? '02_publier_a_prevoir_a_partir_de' : '02_publier_a_prevoir_a_partir_de_ECHEC');
    if (!ok2) fails.add('02 : « à partir de 12 €/visite » non affiché');
    expect(t.takeException(), isNull);
    await _teardown(t);

    // ── 3. Carte « Mes annonces » (même widget, même constructeur) ──
    await lotdSetUp(role: 'owner');
    _respond();
    final post = _post();
    await t.pumpWidget(lotdApp(Scaffold(
      body: PawPatternBackground(
        color: AppColors.primaryColor,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: FromRate620Builder(
              future: FromRateCache620.forPost(post),
              builder: (ctx, label) => PetPostCard(
                userName: post.owner.name,
                userEmail: '',
                petImages: const <String>[],
                pets: post.pets,
                serviceLocation: post.serviceLocation,
                postBody: post.body,
                petName: 'Mimi',
                serviceTypes: 'Visite à domicile',
                dateRange: '03/11/2026 → 05/11/2026',
                location: 'Zone test',
                isNetworkImage: false,
                likeCount: 0,
                commentCount: 0,
                fromRateLabel: label,
                ownerViewOfOwnPost: true,
              ),
            ),
          ),
        ),
      ),
    )));
    await _pause(t, 6);
    final ok3 = find.text('À partir de').evaluate().isNotEmpty &&
        find.text('$eur12/visite · estimation ~$eur432').evaluate().isNotEmpty;
    await _shot(t, ok3 ? '03_mes_annonces_a_partir_de' : '03_mes_annonces_a_partir_de_ECHEC');
    if (!ok3) fails.add('03 : case « À partir de » absente');
    expect(t.takeException(), isNull);
    await _teardown(t);

    // ── 4. PawMap : feuille « Ma demande » ──
    await lotdSetUp(role: 'owner');
    _respond();
    final r = NearbyRequestPost.fromJson(<String, dynamic>{
      'id': 'p1', 'ownerId': 'u-test', 'ownerName': 'Camille Durand',
      'serviceTypes': ['home_visit'], 'dateMode': 'exact', 'visitsPerDay': 1,
      'startDate': '2026-11-03T00:00:00Z', 'endDate': '2026-11-05T00:00:00Z',
      'serviceLocation': 'at_owner',
      'body': 'Mimi, chat calme, 2 visites par jour pour les croquettes et les câlins.',
      'location': {'city': 'Zone test', 'lat': -35.2, 'lng': -30.4},
    });
    await t.pumpWidget(lotdApp(Scaffold(
      backgroundColor: const Color(0xFFFFF1EC),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: PawMapSheetShell(
          maxHeightFactor: 0.9,
          child: PawMapRequestSheet(
            ownerName: r.ownerName,
            ownerAvatar: '',
            walking: false,
            city: r.city,
            distanceLabel: '',
            dateLabel: '3 nov. → 5 nov.',
            locationLabel: 'Chez moi',
            budgetLabel: '',
            body: r.body,
            mine: true,
            approx: false,
            viewerRole: 'owner',
            proposeState: PawProposeState.idle,
            estimateLine: FromRateLine620(
              future: FromRateCache620.forNearby(r),
              tone: PawMapLegend.owner,
              compact: true,
            ),
            onPropose: () {},
            onOpenMine: () {},
            onOwnerProfile: () {},
          ),
        ),
      ),
    )));
    await _pause(t, 6);
    final ok4 = find.byKey(const Key('dates620_from_rate_line')).evaluate().isNotEmpty;
    await _shot(t, ok4 ? 'pawmap/04_ma_demande_a_partir_de' : 'pawmap/04_ma_demande_a_partir_de_ECHEC');
    if (!ok4) fails.add('04 : ligne « à partir de » absente de la feuille PawMap');
    expect(t.takeException(), isNull);
    await _teardown(t);

    // ── 5-6. Candidats : « Tarif à venir » (clair puis sombre) ──
    for (final dark in <bool>[false, true]) {
      await lotdSetUp(role: 'owner');
      lotdResponder = (req) {
        if (req.url.path.endsWith('/applications/my')) {
          return <String, dynamic>{
            'applications': [
              _application('a1', 'Léa Martin', stale: true),
              _application('a2', 'Tom Petit', stale: false),
            ],
          };
        }
        return <String, dynamic>{};
      };
      if (dark) Get.put(ThemeController(), permanent: true);
      try {
        await t.pumpWidget(lotdApp(
          Builder(builder: (ctx) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              PostCandidatesSheet.show(context: ctx, postId: 'p1');
            });
            return const Scaffold(body: SizedBox.expand());
          }),
          brightness: dark ? Brightness.dark : Brightness.light,
        ));
        await _pause(t, 8);
        final banner = find.byKey(const Key('dates620_stale_banner')).evaluate().isNotEmpty;
        final noDates = find.byKey(const Key('dates620_set_dates_banner')).evaluate().isEmpty;
        final label = find.text('Tarif à venir').evaluate().isNotEmpty;
        final ok = banner && noDates && label;
        final name = dark ? '06_candidats_tarif_a_venir_sombre' : '05_candidats_tarif_a_venir';
        await _shot(t, ok ? name : '${name}_ECHEC');
        if (!ok) fails.add('$name : bandeau=$banner sansDates=$noDates libellé=$label');
        if (!dark) {
          await t.tap(find.byKey(const Key('dates620_choose_a1')));
          await _pause(t, 2);
          final warned = find.textContaining('encore de tarif').evaluate().isNotEmpty;
          await _shot(t, warned ? '05b_candidats_choisir_verrouille_explication' : '05b_candidats_choisir_ECHEC');
          if (!warned) fails.add('05b : explication « tarif à venir » absente');
        }
        final ex = t.takeException();
        if (ex != null) fails.add('$name : exception $ex');
      } catch (e) {
        fails.add('candidats (sombre=$dark) : $e');
      }
      await _teardown(t);
    }

    // ── 7. Gardien : Tarifs ouverts depuis la notification (bannière) ──
    await lotdSetUp(role: 'sitter');
    _respond();
    Get.put(ThemeController(), permanent: true);
    await t.pumpWidget(lotdApp(MyRatesScreen(role: 'sitter')));
    await _pause(t, 5);
    CustomSnackbar.showInfo(title: 'dates620_stale_label'.tr, message: 'dates620_rates_from_notif'.tr);
    await _pause(t, 2);
    final card = find.byKey(const Key('dates620_rates_visit_card'), skipOffstage: false);
    if (card.evaluate().isEmpty) fails.add('07 : carte Visite à domicile absente');
    final ok7 = find.textContaining('sera recalculée').evaluate().isNotEmpty;
    await _shot(t, ok7 ? '07_tarifs_gardien_depuis_notification' : '07_tarifs_gardien_depuis_notification_ECHEC');
    if (!ok7) fails.add('07 : bannière « ajoute ton tarif … » absente');
    expect(t.takeException(), isNull);
    await _teardown(t);

    expect(fails, isEmpty, reason: fails.join('\n'));
  });
}
