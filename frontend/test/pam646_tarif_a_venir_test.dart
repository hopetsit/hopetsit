// 646 (PAM, 25/11/2026 — ordre de Daniel : « je veux que les clients
// comprennent », « corrige tout proprement », « ça doit être ludique »).
//
// Depuis le 25/11 le serveur ne calcule plus jamais « tarif d'une heure × 8 » :
// un gardien sans tarif à la journée qui répond à une garde voit sa
// candidature créée en « tarif à venir » (pricing.stale = true). Contrôle de
// ZOE sur l'app 645 : la carte affichait encore « Vous recevez 240 € » et
// l'app bloquait elle-même le gardien sans tarif. Les 7 points de la 646 :
//   1. estimateur sans « × 8 » ; une phrase à la place du gain ;
//   2. gardien sans tarif NON bloqué par l'app (le serveur décide) ;
//   3. feuille après l'envoi en « tarif à venir » + « Tarif à venir » sur la carte ;
//   4. Mes tarifs : encadré fixe, curseur dans « Tarif journalier », bouton
//      « Enregistrer mes tarifs » ;
//   5. refus RATE_REQUIRED / VISIT_RATE_REQUIRED / balade : phrases claires, 9 langues ;
//   6. visites à domicile visibles par le gardien ; « Proposer mes services »
//      et gain juste sur l'écran ouvert par la notification ;
//   7. 3 lignes pour le texte d'une notification.
// Aucun réseau : faux serveur du harnais lot D, zone fictive −35 / −30.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/rate646_i18n.dart';
import 'package:hopetsit/models/app_notification_model.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/utils/post_price_estimator.dart';
import 'package:hopetsit/utils/rate646.dart';
import 'package:hopetsit/utils/server_error_message.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/notifications/notification_post_view_screen.dart';
import 'package:hopetsit/views/pet_sitter/home/sitter_homescreen.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_post_card.dart';
import 'package:hopetsit/views/profile/my_rates_screen.dart';
import 'package:hopetsit/views/shared/photo_nudge644.dart';
import 'package:hopetsit/views/shared/rate_sheet646.dart';
import 'package:hopetsit/widgets/notification_card.dart';

import 'home640_harness.dart';
import 'lotd_harness.dart';

const List<String> kLangs = <String>['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const Map<String, Locale> kLocaleOf = <String, Locale>{
  'fr': Locale('fr', 'FR'),
  'en': Locale('en', 'US'),
  'es': Locale('es', 'ES'),
  'de': Locale('de', 'DE'),
  'it': Locale('it', 'IT'),
  'pt': Locale('pt', 'PT'),
  'ko': Locale('ko', 'KR'),
  'ja': Locale('ja', 'JP'),
  'pl': Locale('pl', 'PL'),
};
const List<double> kWidths = <double>[320, 375, 768];

const double kLat = -35.0;
const double kLng = -30.0;

Finder _k(String key) => find.byKey(ValueKey<String>(key));

PostModel _post({
  required List<String> services,
  required DateTime start,
  DateTime? end,
  String? venue,
  int? visitsPerDay,
  int? walkMinutes,
  String id = 'p646',
}) {
  return PostModel.fromJson(_postJson(
    id: id,
    services: services,
    start: start,
    end: end,
    venue: venue,
    visitsPerDay: visitsPerDay,
    walkMinutes: walkMinutes,
  ));
}

Map<String, dynamic> _postJson({
  required String id,
  required List<String> services,
  required DateTime start,
  DateTime? end,
  String? venue,
  int? visitsPerDay,
  int? walkMinutes,
}) {
  return <String, dynamic>{
    'id': id,
    'postType': 'request',
    'body': 'PAM test 646',
    'serviceTypes': services,
    'startDate': start.toUtc().toIso8601String(),
    if (end != null) 'endDate': end.toUtc().toIso8601String(),
    if (venue != null) 'houseSittingVenue': venue,
    if (visitsPerDay != null) 'visitsPerDay': visitsPerDay,
    if (walkMinutes != null) 'walkDurationMinutes': walkMinutes,
    'notes': '',
    'images': const <dynamic>[],
    'videos': const <dynamic>[],
    'likes': const <dynamic>[],
    'comments': const <dynamic>[],
    'location': <String, dynamic>{'city': 'Zone test', 'lat': kLat, 'lng': kLng + 0.02},
    'createdAt': '2026-11-25T10:00:00Z',
    'updatedAt': '2026-11-25T10:00:00Z',
    'owner': <String, dynamic>{'id': 'o-$id', 'name': 'Proprio test', 'email': '', 'avatar': ''},
    'pets': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'pet-$id',
        'petName': 'Rex',
        'avatar': '',
        'photos': <String>[],
        'breed': 'Berger fictif',
        'age': 3,
        'sex': 'male',
      },
    ],
  };
}

PostPriceEstimate? _sitter(PostModel p,
        {double hourly = 0, double daily = 0, double weekly = 0, double monthly = 0, double visit = 0}) =>
    estimatePostPrice(
      post: p,
      userRole: 'sitter',
      hourlyRate: hourly,
      dailyRate: daily,
      weeklyRate: weekly,
      monthlyRate: monthly,
      visitRate: visit,
      currency: 'EUR',
      commissionRate: 0.20,
    );

final DateTime kD1 = DateTime.utc(2026, 12, 10, 9);
final DateTime kD3 = DateTime.utc(2026, 12, 12, 18);

Future<void> _profile(String role) async {
  await GetStorage().write(StorageKeys.userProfile, <String, dynamic>{
    'id': 'u-test',
    '_id': 'u-test',
    'name': 'Camille Durand',
    'email': 'camille@example.test',
    'role': role,
    'city': 'Zone test',
    'mobile': '+33600000000',
    'address': '1 rue du Test',
    'location': <String, dynamic>{'city': 'Zone test', 'country': 'Test', 'lat': kLat, 'lng': kLng},
  });
}

/// Faux serveur : annonces, profil du gardien avec [rates], candidatures.
void _serve({
  required List<Map<String, dynamic>> posts,
  Map<String, dynamic> rates = const <String, dynamic>{},
  Map<String, dynamic> Function(http.Request req)? onApply,
  List<Map<String, dynamic>> Function()? myApplications,
}) {
  lotdResponder = (http.Request req) {
    final String path = req.url.path;
    if (path.endsWith('/posts/requests')) return <String, dynamic>{'posts': posts};
    if (path.endsWith('/applications/my')) {
      return <String, dynamic>{'applications': myApplications?.call() ?? <Map<String, dynamic>>[]};
    }
    if (req.method == 'POST' && path.endsWith('/applications')) {
      return onApply?.call(req) ?? <String, dynamic>{};
    }
    if (path.endsWith('/sitters/u-test')) {
      return <String, dynamic>{
        'sitter': <String, dynamic>{
          'id': 'u-test',
          'name': 'Camille Durand',
          'email': 'camille@example.test',
          'mobile': '+33600000000',
          'address': '1 rue du Test',
          'city': 'Zone test',
          'currency': 'EUR',
          ...rates,
        },
      };
    }
    if (path.endsWith('/sitters/me/rates')) {
      return <String, dynamic>{'rates': rates};
    }
    if (path.endsWith('/users/me/profile')) {
      return <String, dynamic>{
        'profile': <String, dynamic>{
          'id': 'u-test',
          'name': 'Camille Durand',
          'email': 'camille@example.test',
          'mobile': '+33600000000',
          'address': '1 rue du Test',
          'city': 'Zone test',
          'avatar': <String, dynamic>{'url': 'https://example.test/a.jpg'},
        },
      };
    }
    return <String, dynamic>{
      'pets': <Map<String, dynamic>>[],
      'posts': <Map<String, dynamic>>[],
      'notifications': <Map<String, dynamic>>[],
      'blocks': <Map<String, dynamic>>[],
      'bookings': <Map<String, dynamic>>[],
      'applications': <Map<String, dynamic>>[],
      'conversations': <Map<String, dynamic>>[],
      'count': 0,
    };
  };
}

Future<void> _openHome(WidgetTester tester, {double width = 393, double height = 2400}) async {
  lotdPhone(tester, width: width, height: height);
  await tester.pumpWidget(home640App(const SitterHomescreen(), designHeight: height));
  await lotdSettle(tester, frames: 10);
}

/// Aucun texte de [root] ne sort de l'écran ni ne dépasse ses lignes.
void _expectTextsFit(WidgetTester tester, Finder root, double width, String why) {
  for (final Element e in find.descendant(of: root, matching: find.byType(RichText)).evaluate()) {
    final RenderParagraph p = e.renderObject! as RenderParagraph;
    final String txt = p.text.toPlainText();
    if (txt.trim().isEmpty) continue;
    if (txt.trim().length < 2 && txt.runes.every((int r) => r > 0xE000)) continue; // icône
    expect(p.didExceedMaxLines, isFalse, reason: '$why — coupé : « $txt »');
    final Rect r = MatrixUtils.transformRect(p.getTransformTo(null), Offset.zero & p.size);
    expect(r.left, greaterThanOrEqualTo(-0.5), reason: '$why — « $txt » sort à gauche');
    expect(r.right, lessThanOrEqualTo(width + 0.5), reason: '$why — « $txt » sort à droite');
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await home640LoadIconFont();
  });

  // ───────────────────────── 1. Estimateur ─────────────────────────
  group('1. estimateur : plus jamais « heure × 8 »', () {
    test('gardien, tarif à l heure seul (10 €/h), garde de 3 jours : AUCUN gain (avant : 240 €)', () {
      final p = _post(services: <String>['house_sitting'], start: kD1, end: kD3, venue: 'owners_home');
      expect(_sitter(p, hourly: 10), isNull);
      expect(missingRate646(post: p, userRole: 'sitter'), 'day');
      expect(gainHintKey646('day'), 'pam646_gain_add_day');
    });

    test('garderie (day_care) et pet_sitting avec tarif à l heure seul : aucun gain non plus', () {
      expect(_sitter(_post(services: <String>['day_care'], start: kD1, end: kD3), hourly: 10), isNull);
      expect(_sitter(_post(services: <String>['pet_sitting'], start: kD1, end: kD1.add(const Duration(hours: 8))), hourly: 10), isNull);
      expect(_sitter(_post(services: <String>['pet_sitting'], start: kD1), hourly: 10), isNull);
    });

    test('avec un tarif à la journée, rien ne change : 3 j × 25 € = 75 € net, 90 € client', () {
      final est = _sitter(_post(services: <String>['house_sitting'], start: kD1, end: kD3, venue: 'owners_home'), hourly: 10, daily: 25)!;
      expect(est.net, 75);
      expect(est.brut, closeTo(90, 0.001));
    });

    test('tarif semaine seul (140 €) : jour = semaine ÷ 7 (règle du serveur), 3 j → 60 €', () {
      final est = _sitter(_post(services: <String>['house_sitting'], start: kD1, end: kD3, venue: 'owners_home'), weekly: 140)!;
      expect(est.net, closeTo(60, 0.001));
      expect(missingRate646(post: _post(services: <String>['house_sitting'], start: kD1, end: kD3), userRole: 'sitter', weeklyRate: 140), isNull);
    });

    test('promeneur (12 €/h) sur une GARDE : aucun gain inventé (avant : 576 €)', () {
      final p = _post(services: <String>['house_sitting', 'dog_walking'], start: kD1, end: kD3);
      final est = estimatePostPrice(post: p, userRole: 'walker', hourlyRate: 12, dailyRate: 0, weeklyRate: 0, monthlyRate: 0, currency: 'EUR', walkRate60: 12);
      expect(est, isNull);
      // Ce n'est pas son tarif qui manque : aucune phrase « ajoute ton prix ».
      expect(missingRate646(post: p, userRole: 'walker', hasWalkRate: true), isNull);
    });

    test('promeneur, balades sur 3 jours (60 min, 12 €) : 3 balades = 36 € (une par jour, comme le serveur)', () {
      final p = _post(services: <String>['dog_walking'], start: kD1, end: kD3, walkMinutes: 60);
      final est = estimatePostPrice(post: p, userRole: 'walker', hourlyRate: 12, dailyRate: 0, weeklyRate: 0, monthlyRate: 0, currency: 'EUR', walkRate60: 12)!;
      expect(est.net, 36);
      expect(est.brut, closeTo(43.2, 0.001));
      expect(missingRate646(post: p, userRole: 'walker', hasWalkRate: false), 'walk');
    });

    test('promeneur, balade d une heure le même jour : inchangé (12 €)', () {
      final p = _post(services: <String>['dog_walking'], start: kD1, end: kD1.add(const Duration(hours: 1)));
      final est = estimatePostPrice(post: p, userRole: 'walker', hourlyRate: 12, dailyRate: 0, weeklyRate: 0, monthlyRate: 0, currency: 'EUR', walkRate60: 12)!;
      expect(est.net, 12);
    });

    test('visite à domicile : visites × tarif par visite (3 j × 2 × 12 € = 72 €) ; sans tarif par visite : rien', () {
      final p = _post(services: <String>['home_visit'], start: kD1, end: kD3, visitsPerDay: 2);
      final est = _sitter(p, daily: 25, visit: 12)!;
      expect(est.net, 72);
      expect(est.unit, 'visit');
      // Tarif à la journée seul : pas de gain « à la journée » sur une visite (avant : 50 € faux).
      expect(_sitter(p, daily: 25), isNull);
      expect(missingRate646(post: p, userRole: 'sitter', dailyRate: 25), 'visit');
      expect(missingRate646(post: p, userRole: 'sitter', visitRate: 12), isNull);
    });

    test('le code de l estimateur ne contient plus de « × 8 »', () {
      final String src = File('lib/utils/post_price_estimator.dart').readAsStringSync();
      final String code = src.split('\n').where((String l) => !l.trimLeft().startsWith('//')).join('\n');
      expect(RegExp(r'\*\s*8\b').hasMatch(code), isFalse);
      expect(RegExp(r'/\s*8\b').hasMatch(code), isFalse);
    });
  });

  // ───────────────────────── 5. Refus du serveur ─────────────────────────
  group('5. refus du serveur : phrases claires', () {
    test('codes et messages → bonne clé', () {
      expect(serverErrorKey(code: 'RATE_REQUIRED', statusCode: 400), 'pam646_need_any');
      expect(serverErrorKey(code: 'VISIT_RATE_REQUIRED', statusCode: 400), 'pam646_need_visit');
      expect(
        serverErrorKey(statusCode: 400, rawMessage: 'You must set at least one walk rate before sending requests to owners.'),
        'pam646_need_walk',
      );
      expect(
        serverErrorKey(statusCode: 400, rawMessage: 'You must set at least one rate (hourly, daily, weekly or monthly) before sending requests to owners.'),
        'pam646_need_any',
      );
      expect(
        serverErrorKey(statusCode: 400, rawMessage: 'Set your price per home visit before applying to a home-visit request.'),
        'pam646_need_visit',
      );
      expect(
        serverErrorKey(statusCode: 400, rawMessage: 'Set your price for this service before applying to this request.'),
        'pam646_need_any',
      );
      // Un autre refus n'est pas pris pour un refus de tarif.
      expect(serverErrorKey(code: 'TOO_FAR', statusCode: 403), 'bob617_err_too_far');
    });

    test('rateNeedOfError646 : gardien → tarif ; promeneur + RATE_REQUIRED → « c est une garde »', () {
      final ApiException visit = ApiException('Set your price per home visit before applying to a home-visit request.',
          statusCode: 400, details: <String, dynamic>{'code': 'VISIT_RATE_REQUIRED'});
      final ApiException rate = ApiException('Set your price for this service before applying to this request.',
          statusCode: 400, details: <String, dynamic>{'code': 'RATE_REQUIRED'});
      final ApiException walk = ApiException('You must set at least one walk rate before sending requests to owners.', statusCode: 400);
      final ApiException other = ApiException('You cannot apply to your own request.',
          statusCode: 403, details: <String, dynamic>{'code': 'OWN_POST'});
      expect(rateNeedOfError646(visit, role: 'sitter'), 'visit');
      expect(rateNeedOfError646(rate, role: 'sitter'), 'any');
      expect(rateNeedOfError646(rate, role: 'walker'), 'not_for_walker');
      expect(rateNeedOfError646(walk, role: 'walker'), 'walk');
      expect(rateNeedOfError646(other, role: 'sitter'), isNull);
      expect(rateNeedOfError646(Exception('x'), role: 'sitter'), isNull);
    });

    test('les 3 refus sont traduits dans les 9 langues et disent où aller (Mes tarifs)', () {
      final Map<String, Map<String, String>> all = AppTranslations().keys;
      final Map<String, String> en = all['en_US']!;
      for (final String lang in kLangs) {
        final Locale l = kLocaleOf[lang]!;
        final Map<String, String> m = all['${l.languageCode}_${l.countryCode}']!;
        final String ratesScreen = m['my_rates_section_title']!;
        for (final String key in <String>['pam646_need_day', 'pam646_need_visit', 'pam646_need_walk', 'pam646_need_any', 'request_sitter_pricing_error', 'pawmap_request_pricing_missing']) {
          final String v = m[key] ?? '';
          expect(v.trim(), isNotEmpty, reason: '$lang / $key');
          expect(v, isNot(key), reason: '$lang / $key');
          expect(v.contains(ratesScreen), isTrue, reason: '$lang / $key doit nommer « $ratesScreen » : $v');
          if (lang != 'en') expect(v, isNot(en[key]), reason: '$lang / $key est resté en anglais');
        }
      }
      // Français : tutoiement, plus de « tarif horaire ».
      final Map<String, String> fr = all['fr_FR']!;
      expect(fr['request_sitter_pricing_error'], "Ajoute d'abord ton tarif dans Profil › Mes tarifs.");
      expect(fr['pam646_need_visit'], 'Ajoute ton prix par visite dans Profil › Mes tarifs pour répondre à cette demande.');
      for (final String k in rate646I18n['fr']!.keys) {
        final String v = fr[k]!;
        expect(RegExp(r'\b(veuillez|votre|vos|vous)\b', caseSensitive: false).hasMatch(v), isFalse, reason: 'vouvoiement : $k = $v');
        expect(v.toLowerCase().contains('horaire'), isFalse, reason: '« horaire » : $k = $v');
      }
    });
  });

  // ───────────────────────── i18n ─────────────────────────
  group('paquet i18n 646', () {
    test('9 langues, mêmes clés, aucune valeur vide, aucune accolade', () {
      expect(rate646I18n.keys.toSet(), kLangs.toSet());
      final Set<String> ref = rate646I18n['fr']!.keys.toSet();
      expect(ref.length, greaterThanOrEqualTo(20));
      for (final String lang in kLangs) {
        final Map<String, String> m = rate646I18n[lang]!;
        expect(m.keys.toSet(), ref, reason: lang);
        for (final MapEntry<String, String> e in m.entries) {
          expect(e.value.trim(), isNotEmpty, reason: '$lang / ${e.key}');
          expect(e.value.contains('{'), isFalse, reason: '$lang / ${e.key}');
        }
      }
    });

    test('le paquet est branché : les clés sortent traduites dans l app', () {
      final Map<String, Map<String, String>> all = AppTranslations().keys;
      expect(all['fr_FR']!['pam646_sent_title'], 'Candidature envoyée 💶');
      expect(all['fr_FR']!['pam646_rates_box_day'], '📅 Écris ici ton prix pour une journée, puis enregistre.');
      expect(all['fr_FR']!['pam646_rates_save'], 'Enregistrer mes tarifs');
      expect(all['pl_PL']!['pam646_rates_save'], 'Zapisz moje stawki');
    });
  });

  // ───────────────────────── 3. « tarif à venir » ─────────────────────────
  test('3. isRateToCome646 lit la réponse du serveur', () {
    expect(isRateToCome646(<String, dynamic>{
      'application': <String, dynamic>{'id': 'a1', 'pricing': <String, dynamic>{'stale': true, 'indicative': true, 'totalPrice': null}},
    }), isTrue);
    expect(isRateToCome646(<String, dynamic>{'id': 'a1', 'pricing': <String, dynamic>{'stale': true}}), isTrue);
    expect(isRateToCome646(<String, dynamic>{
      'application': <String, dynamic>{'id': 'a1', 'pricing': <String, dynamic>{'totalPrice': 90, 'indicative': false}},
    }), isFalse);
    expect(isRateToCome646(<String, dynamic>{}), isFalse);
    expect(isRateToCome646(null), isFalse);
  });

  test('4. rubrique ouverte en venant de la notification : celle qui est vide', () {
    expect(autoFocus646(role: 'sitter', visitRate: 12), 'day'); // cas de ZOE : visite 12 €, pas de prix par jour
    expect(autoFocus646(role: 'sitter'), 'day');
    expect(autoFocus646(role: 'sitter', dailyRate: 25), 'visit');
    expect(autoFocus646(role: 'sitter', weeklyRate: 140, visitRate: 12), '');
    expect(autoFocus646(role: 'walker'), 'walk');
    expect(autoFocus646(role: 'walker', hasWalkRate: true), '');
    expect(ratesBoxKey646('day'), 'pam646_rates_box_day');
  });

  // ───────────────────────── Écrans réels ─────────────────────────
  group('accueil gardien (vrai écran, faux serveur)', () {
    late List<String> opened;

    setUp(() async {
      await lotdSetUp(role: 'sitter');
      await _profile('sitter');
      PhotoNudge644.resetForTest();
      PhotoNudge644.enabled = false;
      opened = <String>[];
      RateSheet646.openRates = (String role, String focus) => opened.add('$role/$focus');
    });
    tearDown(() {
      RateSheet646.resetForTest();
      PhotoNudge644.resetForTest();
    });

    testWidgets('1+2+3. gardien SANS AUCUN tarif : phrase à la place du gain, envoi non bloqué, feuille « tarif à venir », carte « Tarif à venir »', (tester) async {
      bool applied = false;
      _serve(
        posts: <Map<String, dynamic>>[
          _postJson(id: 'g1', services: <String>['house_sitting'], start: kD1, end: kD3, venue: 'owners_home'),
        ],
        onApply: (http.Request req) {
          applied = true;
          return <String, dynamic>{
            '__status': 201,
            'application': <String, dynamic>{
              'id': 'app-1',
              'postId': 'g1',
              'status': 'pending',
              'pricing': <String, dynamic>{'stale': true, 'indicative': true, 'totalPrice': null},
            },
          };
        },
        myApplications: () => applied
            ? <Map<String, dynamic>>[
                <String, dynamic>{'id': 'app-1', 'postId': 'g1', 'status': 'pending', 'pricing': <String, dynamic>{'stale': true}},
              ]
            : <Map<String, dynamic>>[],
      );
      await _openHome(tester);
      expect(tester.takeException(), isNull);

      // 1. La carte : la phrase, pas de gain.
      expect(find.byType(PetPostCard), findsOneWidget);
      expect(_k('rate646_price_hint'), findsOneWidget);
      expect(find.text('💶 Ton gain'), findsOneWidget);
      expect(find.text('Ajoute ton prix par jour pour voir ton gain.'), findsOneWidget);
      expect(find.text('post_gain_you_get'.tr), findsNothing);
      expect(find.textContaining('240'), findsNothing);

      // La phrase est un bouton : Mes tarifs, rubrique « par jour ».
      await tester.ensureVisible(_k('rate646_price_hint_tap'));
      await tester.tap(_k('rate646_price_hint_tap'));
      await tester.pump();
      expect(opened, <String>['sitter/day']);
      opened.clear();

      // 2. « Proposer mes services » : l'app ne bloque plus, la demande part au serveur.
      final Finder offer = find.text('Proposer mes services');
      expect(offer, findsOneWidget);
      await tester.ensureVisible(offer);
      await tester.pump();
      await tester.tap(offer);
      await lotdSettle(tester, frames: 10);
      final List<LotdRequest> posts = lotdRequests.where((LotdRequest r) => r.method == 'POST' && r.path.endsWith('/applications')).toList();
      expect(posts, hasLength(1), reason: 'la candidature doit partir au serveur');
      expect(posts.first.body!['postId'], 'g1');
      expect(find.text('Veuillez d’abord définir votre tarif horaire dans le profil.'), findsNothing);

      // 3. La feuille claire et positive, une action.
      expect(_k('rate646_sent_sheet'), findsOneWidget);
      expect(find.text('Candidature envoyée 💶'), findsOneWidget);
      expect(find.text('Il manque ton prix par jour. Ajoute-le : le propriétaire verra ton tarif et pourra te choisir.'), findsOneWidget);
      expect(find.descendant(of: _k('rate646_sent_sheet'), matching: find.text('Ajouter mon tarif')), findsOneWidget);
      // Derrière la feuille, le bouton de la carte n'est plus « en cours ».
      expect(find.text('request_cancel_button'.tr), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(_k('rate646_cta'));
      await lotdSettle(tester, frames: 6);
      expect(opened, <String>['sitter/day']);
      expect(_k('rate646_sent_sheet'), findsNothing);

      // La carte : « Tarif à venir » au lieu d'un gain, bouton devenu « Annuler la demande ».
      expect(find.descendant(of: _k('rate646_price_hint'), matching: find.text('Tarif à venir')), findsOneWidget);
      expect(find.text('Ta candidature est partie. Ajoute ton prix par jour : le propriétaire verra ton tarif.'), findsOneWidget);
      expect(find.text('request_cancel_button'.tr), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1. tarif à l heure seul (10 €/h) : plus de « Vous recevez 240 € » ; avec 25 €/jour : 75 €', (tester) async {
      _serve(
        posts: <Map<String, dynamic>>[
          _postJson(id: 'g2', services: <String>['house_sitting'], start: kD1, end: kD3, venue: 'owners_home'),
        ],
        rates: <String, dynamic>{'hourlyRate': 10},
      );
      await _openHome(tester);
      expect(_k('rate646_price_hint'), findsOneWidget);
      expect(find.textContaining('240'), findsNothing);
      expect(find.textContaining('288'), findsNothing);
      expect(find.text('post_gain_you_get'.tr), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('1. avec un tarif à la journée (25 €) : le gain réel s affiche, 3 j = 75 €', (tester) async {
      _serve(
        posts: <Map<String, dynamic>>[
          _postJson(id: 'g2', services: <String>['house_sitting'], start: kD1, end: kD3, venue: 'owners_home'),
        ],
        rates: <String, dynamic>{'hourlyRate': 10, 'dailyRate': 25},
      );
      await _openHome(tester);
      expect(_k('rate646_price_hint'), findsNothing);
      expect(find.text('post_gain_you_get'.tr), findsOneWidget);
      expect(find.textContaining('75'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. le gardien voit aussi une demande « visite à domicile » ; refus VISIT_RATE_REQUIRED → feuille « Ouvrir Mes tarifs »', (tester) async {
      _serve(
        posts: <Map<String, dynamic>>[
          _postJson(id: 'v1', services: <String>['home_visit'], start: kD1, end: kD3, visitsPerDay: 1),
        ],
        rates: <String, dynamic>{'dailyRate': 25},
        onApply: (http.Request req) => <String, dynamic>{
          '__status': 400,
          'error': 'Set your price per home visit before applying to a home-visit request.',
          'code': 'VISIT_RATE_REQUIRED',
        },
      );
      await _openHome(tester);
      expect(find.byType(PetPostCard), findsOneWidget, reason: 'la visite à domicile doit être dans le fil du gardien');
      // Pas de gain « à la journée » sur une visite : la phrase « par visite ».
      expect(find.text('Ajoute ton prix par visite pour voir ton gain.'), findsOneWidget);
      expect(find.text('post_gain_you_get'.tr), findsNothing);

      final Finder offer = find.text('Proposer mes services');
      await tester.ensureVisible(offer);
      await tester.pump();
      await tester.tap(offer);
      await lotdSettle(tester, frames: 10);
      expect(_k('rate646_need_sheet'), findsOneWidget);
      expect(find.text('Il manque ton tarif 💶'), findsOneWidget);
      expect(find.text('Ajoute ton prix par visite dans Profil › Mes tarifs pour répondre à cette demande.'), findsOneWidget);
      expect(find.textContaining('Set your price'), findsNothing, reason: 'jamais la phrase anglaise du serveur');
      await tester.tap(_k('rate646_cta'));
      await lotdSettle(tester, frames: 6);
      expect(opened, <String>['sitter/visit']);
      expect(tester.takeException(), isNull);
    });
  });

  // ───────────────────────── 4. Mes tarifs ─────────────────────────
  group('4. Mes tarifs en venant de la notification', () {
    setUp(() async {
      await lotdSetUp(role: 'sitter');
      await _profile('sitter');
    });

    testWidgets('gardien avec visite 12 € et sans prix par jour : encadré fixe dans « Garde », curseur dans « Tarif journalier », bouton « Enregistrer mes tarifs »', (tester) async {
      _serve(posts: const <Map<String, dynamic>>[], rates: <String, dynamic>{'visitRate': 12, 'hourlyRate': 10});
      lotdPhone(tester, width: 375, height: 667);
      await tester.pumpWidget(lotdApp(const MyRatesScreen(role: 'sitter', focus: 'auto')));
      await lotdSettle(tester, frames: 10);
      expect(tester.takeException(), isNull);

      expect(_k('rate646_box'), findsOneWidget);
      expect(find.text('📅 Écris ici ton prix pour une journée, puis enregistre.'), findsOneWidget);
      // L'encadré est DANS la rubrique « Garde — par jour ou par nuit »…
      expect(find.descendant(of: _k('rate646_sitting_card'), matching: _k('rate646_box')), findsOneWidget);
      expect(find.descendant(of: _k('dates620_rates_visit_card'), matching: _k('rate646_box')), findsNothing);
      // …et à l'écran (l'écran est descendu : la rubrique était sous le pli à 375 × 667).
      final Rect box = tester.getRect(_k('rate646_box'));
      expect(box.top, greaterThanOrEqualTo(0));
      expect(box.bottom, lessThanOrEqualTo(667));
      // Curseur dans « Tarif journalier ».
      final Finder daily = find.ancestor(of: find.text('Tarif journalier'), matching: find.byType(Column)).first;
      final Finder field = find.descendant(of: daily, matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(field.first).focusNode.hasFocus, isTrue);
      // Toujours là 5 secondes plus tard (pas un bandeau de 2 secondes).
      await tester.pump(const Duration(seconds: 5));
      expect(_k('rate646_box'), findsOneWidget);
      // Bouton.
      expect(find.text('Enregistrer mes tarifs'), findsOneWidget);
      expect(find.text('edit_profile_button'.tr), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ouverture normale depuis le profil : rien ne bouge (pas d encadré), bouton renommé', (tester) async {
      _serve(posts: const <Map<String, dynamic>>[], rates: <String, dynamic>{'visitRate': 12});
      lotdPhone(tester, width: 375, height: 667);
      await tester.pumpWidget(lotdApp(const MyRatesScreen(role: 'sitter')));
      await lotdSettle(tester, frames: 8);
      expect(_k('rate646_box'), findsNothing);
      expect(find.text('Enregistrer mes tarifs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

  });

  group('4. Mes tarifs — promeneur', () {
    setUp(() async {
      await lotdSetUp(role: 'walker');
      await _profile('walker');
    });

    testWidgets('promeneur : encadré « balade » et bouton', (tester) async {
      lotdPhone(tester, width: 375, height: 667);
      await tester.pumpWidget(lotdApp(const MyRatesScreen(role: 'walker', focus: 'walk')));
      await lotdSettle(tester, frames: 10);
      expect(find.text('📅 Écris ici ton prix pour une balade, puis enregistre.'), findsOneWidget);
      expect(find.text('Enregistrer mes tarifs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ───────────────────────── 6. Écran ouvert par la notification ─────────────────────────
  group('6. écran « Publication » ouvert par la notification', () {
    setUp(() async {
      await lotdSetUp(role: 'sitter');
      await _profile('sitter');
      PhotoNudge644.resetForTest();
      PhotoNudge644.enabled = false;
    });
    tearDown(PhotoNudge644.resetForTest);

    testWidgets('visite à domicile, gardien à 25 €/jour sans tarif par visite : bouton « Proposer mes services », plus de gain faux', (tester) async {
      final Map<String, dynamic> json = _postJson(id: 'n1', services: <String>['home_visit'], start: kD1, end: kD1.add(const Duration(days: 1)), visitsPerDay: 1);
      _serve(posts: <Map<String, dynamic>>[json], rates: <String, dynamic>{'dailyRate': 25});
      lotdPhone(tester, width: 393, height: 2200);
      await tester.pumpWidget(lotdApp(NotificationPostViewScreen(post: PostModel.fromJson(json))));
      await lotdSettle(tester, frames: 10);
      expect(tester.takeException(), isNull);
      expect(find.text('Proposer mes services'), findsOneWidget);
      expect(find.text('post_gain_you_get'.tr), findsNothing, reason: 'avant : « Vous recevez 50 € », calculé à la journée');
      expect(find.text('Ajoute ton prix par visite pour voir ton gain.'), findsOneWidget);

      // Le bouton envoie bien la candidature.
      await tester.ensureVisible(find.text('Proposer mes services'));
      await tester.pump();
      await tester.tap(find.text('Proposer mes services'));
      await lotdSettle(tester, frames: 10);
      final List<LotdRequest> sent = lotdRequests.where((LotdRequest r) => r.method == 'POST' && r.path.endsWith('/applications')).toList();
      expect(sent, hasLength(1));
      expect(sent.first.body!['postId'], 'n1');
      expect(sent.first.body!['serviceType'], 'home_visit');
      expect(tester.takeException(), isNull);
    });

    testWidgets('avec un tarif par visite (12 €) : 2 jours × 1 visite = 24 € au gardien', (tester) async {
      final Map<String, dynamic> json = _postJson(id: 'n2', services: <String>['home_visit'], start: kD1, end: kD1.add(const Duration(days: 1)), visitsPerDay: 1);
      _serve(posts: <Map<String, dynamic>>[json], rates: <String, dynamic>{'dailyRate': 25, 'visitRate': 12});
      lotdPhone(tester, width: 393, height: 2200);
      await tester.pumpWidget(lotdApp(NotificationPostViewScreen(post: PostModel.fromJson(json))));
      await lotdSettle(tester, frames: 10);
      expect(find.text('post_gain_you_get'.tr), findsOneWidget);
      expect(find.textContaining('24'), findsWidgets);
      expect(find.textContaining('50'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ───────────────────────── 7. Notification : 3 lignes ─────────────────────────
  group('7. cloche', () {
    setUp(() async {
      await lotdSetUp(role: 'sitter');
    });

    testWidgets('le texte de la notification « il manque juste ton tarif » se lit en entier à 375 px (3 lignes)', (tester) async {
      lotdPhone(tester, width: 375, height: 812);
      final AppNotificationModel n = AppNotificationModel.fromJson(<String, dynamic>{
        'id': 'n1',
        'recipientRole': 'sitter',
        'recipientId': 'u-test',
        'type': 'application_service_changed',
        'title': '💶 Ta candidature est partie… il manque juste ton tarif !',
        'body': 'Ouvre Profil › Mes tarifs, écris ton prix par jour, puis enregistre : ta candidature est recalculée.',
        'data': <String, dynamic>{},
        'createdAt': DateTime.now().toIso8601String(),
      });
      await tester.pumpWidget(lotdApp(Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: NotificationCard(notification: n, onTap: () {})),
      )));
      await lotdSettle(tester);
      expect(tester.takeException(), isNull);
      final Finder body = find.textContaining('écris ton prix par jour');
      expect(body, findsOneWidget);
      final RenderParagraph p = tester.renderObject<RenderParagraph>(
          find.descendant(of: body, matching: find.byType(RichText)).first);
      expect(p.maxLines, 3);
      expect(p.didExceedMaxLines, isFalse, reason: 'le texte ne doit plus être coupé');
    });
  });

  // ───────────────────────── Débordements ─────────────────────────
  group('pas de débordement à 320 / 375 / 768 px, 9 langues', () {
    setUp(() async {
      await lotdSetUp(role: 'sitter');
      await _profile('sitter');
      RateSheet646.openRates = (String role, String focus) {};
    });
    tearDown(RateSheet646.resetForTest);

    for (final double w in kWidths) {
      for (final String lang in kLangs) {
        testWidgets('feuilles + carte + Mes tarifs — $lang — ${w.toInt()} px', (tester) async {
          final Locale locale = kLocaleOf[lang]!;
          lotdPhone(tester, width: w, height: 900);
          _serve(posts: const <Map<String, dynamic>>[], rates: <String, dynamic>{'visitRate': 12});

          // a) La phrase à la place du gain, sur la carte (les 3 variantes + « Tarif à venir »).
          Widget card(String hintKey, {String? titleKey}) => Builder(
                builder: (BuildContext _) => PetPostCard(
                  userName: 'Proprio test',
                  userEmail: '',
                  petImages: const <String>[],
                  serviceTypes: 'Garde',
                  dateRange: '10 – 12 déc.',
                  likeCount: 0,
                  commentCount: 0,
                  viewerRole: 'sitter',
                  priceHint: hintKey.tr,
                  priceHintTitle: titleKey?.tr,
                  onPriceHintTap: () {},
                  onSendRequest: () {},
                  requestButtonText: 'home628_offer_services'.tr,
                ),
              );
          for (final List<String?> c in <List<String?>>[
            <String?>['pam646_gain_add_day', null],
            <String?>['pam646_gain_add_visit', null],
            <String?>['pam646_gain_add_walk', null],
            <String?>['pam646_stale_card', 'dates620_stale_label'],
          ]) {
            await tester.pumpWidget(lotdApp(
              Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: card(c[0]!, titleKey: c[1])))),
              locale: locale,
            ));
            await lotdSettle(tester);
            expect(tester.takeException(), isNull, reason: 'carte ${c[0]} $lang $w');
            expect(_k('rate646_price_hint'), findsOneWidget);
            _expectTextsFit(tester, _k('rate646_price_hint'), w, 'carte ${c[0]} $lang $w');
          }

          // b) Les feuilles : envoi en « tarif à venir », puis chaque refus.
          Future<void> sheet(Future<void> Function(BuildContext ctx) open, String key) async {
            late BuildContext host;
            await tester.pumpWidget(lotdApp(
              Scaffold(body: Builder(builder: (BuildContext c) {
                host = c;
                return const SizedBox.expand();
              })),
              locale: locale,
            ));
            await lotdSettle(tester);
            // ignore: unawaited_futures
            open(host);
            await lotdSettle(tester, frames: 6);
            expect(tester.takeException(), isNull, reason: '$key $lang $w');
            expect(_k(key), findsOneWidget, reason: '$key $lang $w');
            _expectTextsFit(tester, _k(key), w, '$key $lang $w');
            final Rect r = tester.getRect(_k(key));
            expect(r.right, lessThanOrEqualTo(w + 0.5));
            expect(r.bottom, lessThanOrEqualTo(900.5));
            Navigator.of(host).pop();
            await lotdSettle(tester, frames: 4);
          }

          await sheet((BuildContext c) => RateSheet646.showSent(context: c, role: 'sitter'), 'rate646_sent_sheet');
          for (final String need in <String>['day', 'visit', 'walk', 'any', 'not_for_walker']) {
            await sheet((BuildContext c) => RateSheet646.showNeed(need, context: c, role: 'sitter'), 'rate646_need_sheet');
          }

          // c) Mes tarifs avec l'encadré fixe et le bouton renommé.
          await tester.pumpWidget(lotdApp(const MyRatesScreen(role: 'sitter', focus: 'day'), locale: locale));
          await lotdSettle(tester, frames: 10);
          expect(tester.takeException(), isNull, reason: 'Mes tarifs $lang $w');
          expect(_k('rate646_box'), findsOneWidget);
          _expectTextsFit(tester, _k('rate646_box'), w, 'encadré $lang $w');
          expect(find.text('pam646_rates_save'.tr), findsOneWidget);
        });
      }
    }
  });
}
