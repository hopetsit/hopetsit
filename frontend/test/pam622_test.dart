// 622 (PAM, 25/10/2026 — 6 captures iPhone de Daniel, app 621) :
//   · bulles qui se chevauchent / coupées au bord : écartement avec les bords
//     de l'écran (`pawRepelBoxes(bounds:, screen:)`), simulation de 400 points
//     à 4 zooms : aucune boîte ne touche une autre, aucune n'est coupée ;
//   · prix des demandes : route publique `POST /pricing/estimate/public`
//     (réponse RÉELLE du 25/10 pour New York), texte d'épingle « dès 40 $ »,
//     rien quand `basedOn` vaut 0 ;
//   · notifications : ré-enregistrement du jeton au retour (30 min), rappel
//     « Active les notifications » pour gardien / promeneur seulement ;
//   · i18n 8 clés × 9 langues.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/localization/v565/pawmap622_i18n.dart';
import 'package:hopetsit/localization/v565/v565_i18n.dart';
import 'package:hopetsit/models/nearby_request_model.dart';
import 'package:hopetsit/services/push_notification_service.dart';
import 'package:hopetsit/utils/dates620.dart';
import 'package:hopetsit/utils/from_rate620.dart';
import 'package:hopetsit/views/map/pawmap_person.dart';
import 'package:hopetsit/views/map/widgets/pawmap_layout622.dart';
import 'package:hopetsit/views/map/widgets/pawmap_overlap607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/widgets/notif_nudge622.dart';

import 'lotd_harness.dart';

/// Réponse RÉELLE de `POST /pricing/estimate/public` (25/10/2026, 01 h 50,
/// garde à New York, devise USD) : 5 gardiens, minimum 40 $/jour.
const Map<String, dynamic> kPublicNy = <String, dynamic>{
  'serviceType': 'pet_sitting',
  'dateMode': 'tbd',
  'indicative': true,
  'fromRate': 40,
  'unit': 'day',
  'quantity': null,
  'ownerTotalFrom': null,
  'basedOn': 5,
  'excludedOutliers': 1,
  'median': 50,
  'currency': 'USD',
  'durationMinutes': null,
  'radiusKm': 100,
  'rateSource': 'market',
  'unitRate': 40,
  'positionSource': 'coords',
  'country': null,
  'public': true,
  'cached': false,
};

NearbyRequestPost _req({
  String id = 'r1',
  double lat = 40.8123,
  double lng = -73.9234,
  double budget = 0,
  String currency = 'USD',
  bool currencyKnown = true,
  String dateMode = 'tbd',
  DateTime? start,
  DateTime? end,
}) =>
    NearbyRequestPost(
      id: id,
      ownerId: 'o1',
      ownerName: 'Brenda',
      ownerAvatar: '',
      body: '',
      serviceTypes: const ['pet_sitting'],
      serviceLocation: 'owner_home',
      startDate: start,
      endDate: end,
      city: 'New York',
      lat: lat,
      lng: lng,
      distanceKm: 2.6,
      createdAt: null,
      budget: budget,
      currency: currency,
      currencyKnown: currencyKnown,
      dateMode: dateMode,
    );

void main() {
  group('écartement : bords de l\'écran', () {
    const bounds = Rect.fromLTRB(-190, -300, 190, 330);
    const screen = Rect.fromLTRB(-196, -426, 196, 426);
    final box = pawPinBox(27);

    test('bulle coupée au bord gauche → rentrée entière dans l\'écran', () {
      final s = pawFreeSpot(const Offset(-200, 0), box, const [], bounds: bounds);
      expect(s, isNotNull);
      expect(pawBoxInside(const Offset(-200, 0) + s!, box, bounds), isTrue);
    });

    test('bulle sous l\'en-tête (visible à l\'écran) → descendue sous l\'en-tête', () {
      final sh = pawRepelBoxes([const Offset(0, -380)], [box], const [],
          bounds: bounds, screen: screen);
      expect(pawBoxInside(const Offset(0, -380) + sh.first, box, bounds), isTrue);
    });

    test('point hors de l\'écran : il ne vient PAS se coller au bord', () {
      final sh = pawRepelBoxes([const Offset(-600, 0)], [box], const [],
          bounds: bounds, screen: screen);
      expect(sh.first, Offset.zero);
    });

    test('sans bords (ancien appel) : comportement inchangé', () {
      final sh = pawRepelBoxes([const Offset(-200, 0)], [box], const []);
      expect(sh.first, Offset.zero);
    });
  });

  group('simulation : 400 points, 4 zooms (Europe, France, Paris, rue)', () {
    // Vues et densités inspirées des captures : grappes autour de villes.
    final rnd = math.Random(622);
    final cities = <Offset>[
      for (var i = 0; i < 14; i++)
        Offset(rnd.nextDouble() * 360 - 180, rnd.nextDouble() * 760 - 380),
    ];
    for (final scale in const [0.6, 1.0, 2.5, 6.0]) {
      test('échelle $scale : aucune bulle visible ne touche une autre ni n\'est coupée', () {
        const bounds = Rect.fromLTRB(-190, -300, 190, 330);
        const screen = Rect.fromLTRB(-196, -426, 196, 426);
        // Caméra centrée sur la première ville (comme un utilisateur qui
        // regarde une zone dense).
        final c0 = cities[0] * scale;
        final pts = <Offset>[
          for (var i = 0; i < 400; i++)
            (cities[i % cities.length] +
                        Offset(rnd.nextDouble() * 60 - 30, rnd.nextDouble() * 60 - 30)) *
                    scale -
                c0,
        ];
        Rect boxOfG(List<Offset> g) =>
            g.length > 1 ? pawPinBox(27) : pawPinBox(30, bubbleW: 54);
        // 1. regroupement 607 (fusion < 50 px), 2. fusion jusqu'à ce que tout
        // tienne (622) — exactement l'enchaînement de la carte.
        final groups = pawMergeUntilPlaced622<Offset>(
          pawMergeCloseGroups<Offset>([for (final p in pts) <Offset>[p]], (p) => p),
          (p) => p,
          boxOf: boxOfG,
          bounds: bounds,
          screen: screen,
        );
        final at = <Offset>[];
        final boxes = <Rect>[];
        for (final g in groups) {
          var x = 0.0, y = 0.0;
          for (final p in g) {
            x += p.dx;
            y += p.dy;
          }
          at.add(Offset(x / g.length, y / g.length));
          boxes.add(boxOfG(g));
        }
        final sh = pawRepelBoxes(at, boxes, const [], bounds: bounds, screen: screen);
        final placed = [for (var i = 0; i < at.length; i++) at[i] + sh[i]];
        var visible = 0;
        for (var i = 0; i < placed.length; i++) {
          if (!boxes[i].shift(placed[i]).overlaps(screen)) continue;
          visible++;
          expect(pawBoxInside(placed[i], boxes[i], bounds), isTrue,
              reason: 'bulle $i coupée : ${boxes[i].shift(placed[i])}');
          for (var j = i + 1; j < placed.length; j++) {
            if (!boxes[j].shift(placed[j]).overlaps(screen)) continue;
            expect(pawBoxesTouch(placed[i], boxes[i], placed[j], boxes[j], air: 0), isFalse,
                reason: 'bulles $i et $j se touchent');
          }
        }
        expect(visible, greaterThan(0));
      });
    }
  });

  group('prix des demandes (route publique)', () {
    test('corps plat : service, position arrondie à 0,1°, devise, sans dates', () {
      final b = publicBodyForNearby622(_req())!;
      expect(b['serviceType'], 'pet_sitting');
      expect(b['lat'], 40.8);
      expect(b['lng'], -73.9);
      expect(b['currency'], 'USD');
      expect(b.containsKey('startDate'), isFalse);
    });

    test('avec dates (fiche / feuille) : position exacte + dates', () {
      final r = _req(
          dateMode: 'exact', start: DateTime.utc(2026, 10, 5), end: DateTime.utc(2026, 10, 29));
      final b = publicBodyForNearby622(r, withDates: true)!;
      expect(b['lat'], 40.8123);
      expect(b['startDate'], '2026-10-05T00:00:00.000Z');
      expect(b['endDate'], '2026-10-29T00:00:00.000Z');
    });

    test('même quartier → même clé (une requête pour plusieurs épingles)', () {
      expect(publicKey622(_req(id: 'a', lat: 40.81, lng: -73.92)),
          publicKey622(_req(id: 'b', lat: 40.83, lng: -73.94)));
      expect(publicKey622(_req(lat: 40.81)), isNot(publicKey622(_req(lat: 41.3))));
    });

    test('demande américaine SANS devise → pays US ; européenne sans devise → rien', () {
      final us = publicBodyForNearby622(_req(currency: 'EUR', currencyKnown: false))!;
      expect(us['country'], 'US');
      expect(us.containsKey('currency'), isFalse);
      final fr = publicBodyForNearby622(
          _req(lat: 48.85, lng: 2.35, currency: 'EUR', currencyKnown: false))!;
      expect(fr.containsKey('country'), isFalse);
      expect(fr.containsKey('currency'), isFalse);
    });

    test('demande sans position ni service : rien n\'est demandé', () {
      expect(publicBodyForNearby622(_req(lat: 0, lng: 0)), isNull);
    });

    group('textes', () {
      setUp(() {
        Get.testMode = true;
        Get.addTranslations(<String, Map<String, String>>{
          'fr_FR': v565For('fr'),
          'en_US': v565For('en'),
        });
        Get.locale = const Locale('fr', 'FR');
      });

      test('épingle : « dès 40 USD » ; rien quand basedOn 0 ; rien sans réponse', () {
        final e = PricingEstimate620.tryParse(kPublicNy)!;
        expect(e.hasFromRate, isTrue);
        final t = fromRatePinText622(e);
        expect(t, startsWith('dès '));
        expect(t, contains('40'));
        expect(t, contains(r'$'));
        final none = PricingEstimate620.tryParse(<String, dynamic>{
          ...kPublicNy,
          'fromRate': null,
          'basedOn': 0,
        });
        expect(fromRatePinText622(none), '');
        expect(fromRatePinText622(null), '');
      });

      test('feuille : « à partir de 40 USD par jour »', () {
        final e = PricingEstimate620.tryParse(kPublicNy)!;
        final t = fromRateText620(e);
        expect(t, startsWith('à partir de '));
        expect(t, contains('40'));
      });
    });

    group('appel réseau', () {
      setUp(() async {
        await lotdSetUp(role: 'sitter');
        FromRateCache620.reset();
      });
      tearDown(() async {
        await Get.deleteAll(force: true);
        Get.reset();
      });

      test('POST /pricing/estimate/public (jamais /pricing/estimate) ; cache : 1 seul appel', () async {
        lotdResponder = (req) =>
            req.url.path.endsWith('/pricing/estimate/public') ? kPublicNy : <String, dynamic>{};
        final a = await FromRateCache620.forNearbyPublic(_req(id: 'a'));
        final b = await FromRateCache620.forNearbyPublic(_req(id: 'b', lat: 40.82));
        expect(a?.fromRate, 40);
        expect(b?.fromRate, 40);
        final calls = lotdRequests.where((r) => r.path.contains('/pricing/')).toList();
        expect(calls.length, 1);
        expect(calls.first.path, endsWith('/pricing/estimate/public'));
        expect(calls.first.body?['currency'], 'USD');
      });

      test('quota : au plus 20 appels publics par minute (le serveur en tolère 30)', () async {
        lotdResponder = (req) => kPublicNy;
        for (var i = 0; i < 25; i++) {
          await FromRateCache620.forNearbyPublic(_req(id: 'q$i', lat: 10.0 + i));
        }
        final calls = lotdRequests.where((r) => r.path.endsWith('/pricing/estimate/public')).length;
        expect(calls, 20);
      });

      test('serveur muet ou ancien : rien, aucune exception', () async {
        lotdResponder = (req) => <String, dynamic>{};
        final e = await FromRateCache620.forNearbyPublic(_req(id: 'c', lat: 12.3));
        expect(fromRatePinText622(e), '');
      });
    });
  });

  group('tarifs des prestataires (parité site)', () {
    String fmt(String c, double v) => '$v $c';
    test('tarif effectif : priceFrom, sinon le plus petit de prices (cas réel 14,29 €/jour)', () {
      expect(pawMapEffectivePrice622({'priceFrom': 12, 'priceUnit': 'visit'})!.amount, 12);
      final e = pawMapEffectivePrice622({
        'priceFrom': 0,
        'prices': {
          'house_sitting': {'amount': 14.29, 'unit': 'day'},
          'dog_walking': {'amount': 0, 'unit': 'walk'},
        },
      })!;
      expect(e.amount, 14.29);
      expect(e.unit, 'day');
      expect(pawMapEffectivePrice622({'priceFrom': 0}), isNull);
    });

    test('« dès X » d\'un groupe : gardiens d\'abord, plus petit, une seule devise', () {
      final g = <Map<String, dynamic>>[
        {'_role': 'sitter', 'priceFrom': 20, 'priceUnit': 'day', 'currency': 'EUR'},
        {'_role': 'sitter', 'priceFrom': 0, 'prices': {'h': {'amount': 14.29, 'unit': 'day'}}, 'currency': 'EUR'},
        {'_role': 'walker', 'priceFrom': 8, 'priceUnit': 'walk', 'currency': 'EUR'},
      ];
      final r = pawMapClusterFromPrice622(g,
          shows: (_) => true, shownRoles: const {}, format: fmt)!;
      expect(r.role, 'sitter');
      expect(r.price, '14.29 EUR');
      final mixed = <Map<String, dynamic>>[
        {'_role': 'sitter', 'priceFrom': 20, 'currency': 'EUR'},
        {'_role': 'sitter', 'priceFrom': 30, 'currency': 'USD'},
      ];
      expect(pawMapClusterFromPrice622(mixed, shows: (_) => true, shownRoles: const {}, format: fmt), isNull);
      // Règle du marché : un gardien ne voit pas les tarifs des autres prestataires.
      expect(pawMapClusterFromPrice622(g, shows: (_) => false, shownRoles: const {}, format: fmt), isNull);
    });
  });

  group('bulle de demande : groupe avec chiffre', () {
    test('se dessine (1, 3, 120) sans exception, dans son image', () {
      for (final n in const [1, 3, 120]) {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        PawMapPinPainter.paintRequestBubble(c, priceLabel: 'dès 40 \$', walking: false, count: n);
        final pic = rec.endRecording();
        expect(pic, isNotNull);
      }
    });
  });

  group('notifications', () {
    test('ré-enregistrement au retour : au plus toutes les 30 min', () {
      final t0 = DateTime(2026, 10, 25, 2);
      expect(PushNotificationService.resumeSyncDue622(null, t0), isTrue);
      expect(PushNotificationService.resumeSyncDue622(t0, t0.add(const Duration(minutes: 10))), isFalse);
      expect(PushNotificationService.resumeSyncDue622(t0, t0.add(const Duration(minutes: 31))), isTrue);
    });

    test('rappel : seulement si l\'autorisation manque', () {
      expect(PushNotificationService.needsNudge622(AuthorizationStatus.authorized), isFalse);
      expect(PushNotificationService.needsNudge622(AuthorizationStatus.provisional), isFalse);
      expect(PushNotificationService.needsNudge622(AuthorizationStatus.denied), isTrue);
      expect(PushNotificationService.needsNudge622(AuthorizationStatus.notDetermined), isTrue);
      expect(PushNotificationService.needsNudge622(null), isFalse);
    });

    test('rappel : gardien et promeneur seulement, « Plus tard » = 7 jours', () {
      final now = DateTime(2026, 10, 25);
      expect(notifNudgeVisible622(role: 'sitter', needsPermission: true, now: now), isTrue);
      expect(notifNudgeVisible622(role: 'walker', needsPermission: true, now: now), isTrue);
      expect(notifNudgeVisible622(role: 'owner', needsPermission: true, now: now), isFalse);
      expect(notifNudgeVisible622(role: 'sitter', needsPermission: false, now: now), isFalse);
      final later = now.add(const Duration(days: 7)).millisecondsSinceEpoch;
      expect(
          notifNudgeVisible622(
              role: 'sitter', needsPermission: true, snoozedUntilMs: later, now: now),
          isFalse);
      expect(
          notifNudgeVisible622(
              role: 'sitter',
              needsPermission: true,
              snoozedUntilMs: later,
              now: now.add(const Duration(days: 8))),
          isTrue);
    });

    group('carte', () {
      setUp(() async {
        await lotdSetUp(role: 'sitter');
        Get.addTranslations(<String, Map<String, String>>{'fr_FR': v565For('fr')});
        Get.locale = const Locale('fr', 'FR');
      });
      tearDown(() async {
        await Get.deleteAll(force: true);
        Get.reset();
      });

      Widget app(Widget child) => ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (_, __) => GetMaterialApp(
              translations: _Tr(),
              locale: const Locale('fr', 'FR'),
              home: Scaffold(body: Center(child: child)),
            ),
          );

      testWidgets('gardien sans autorisation : carte visible ; « Plus tard » la masque 7 j',
          (tester) async {
        await tester.pumpWidget(app(NotifNudge622(
          role: 'sitter',
          statusOverride: () async => true,
        )));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byKey(const ValueKey<String>('notif_nudge_622')), findsOneWidget);
        expect(find.text('Active les notifications'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey<String>('notif_nudge_622_later')));
        await tester.pump();
        expect(find.byKey(const ValueKey<String>('notif_nudge_622')), findsNothing);
        expect(GetStorage().read(kNotifNudgeSnoozeKey622), isA<int>());
      });

      testWidgets('propriétaire ou autorisation déjà donnée : rien', (tester) async {
        await tester.pumpWidget(app(Column(children: [
          NotifNudge622(role: 'owner', statusOverride: () async => true),
          NotifNudge622(role: 'walker', statusOverride: () async => false),
        ])));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byKey(const ValueKey<String>('notif_nudge_622')), findsNothing);
      });
    });
  });

  group('i18n 622', () {
    test('8 clés × 9 langues, jamais vides, mêmes jetons, enregistrées', () {
      const langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
      final keys = pawmap622I18n['en']!.keys.toList();
      expect(keys.length, 8);
      final tokens = RegExp(r'@[a-z]+');
      for (final l in langs) {
        for (final k in keys) {
          final v = pawmap622I18n[l]![k];
          expect(v, isNotNull, reason: '$l.$k');
          expect(v!.trim(), isNotEmpty, reason: '$l.$k');
          final en = tokens.allMatches(pawmap622I18n['en']![k]!).map((m) => m.group(0)).toSet();
          final mine = tokens.allMatches(v).map((m) => m.group(0)).toSet();
          expect(mine, en, reason: '$l.$k jetons');
          expect(v600For(l)[k], v, reason: '$l.$k enregistrée');
        }
      }
    });
  });
}

Map<String, String> v600For(String l) => v565For(l);

class _Tr extends Translations {
  @override
  Map<String, Map<String, String>> get keys => <String, Map<String, String>>{
        'fr_FR': v565For('fr'),
      };
}
