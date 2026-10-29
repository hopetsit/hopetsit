// 628 (PAM, 29/10/2026) — parcours propriétaire « choisir → (dates) → payer »
// et parité site (BOB 2910) :
//  - garanties sous « Choisir <prénom> et payer » (72 h si début > 72 h,
//    séquestre, fêtes 15/12 – 06/01) ;
//  - « Choisir » sur une demande SANS dates = dates puis encart « Choisir
//    <prénom> et payer · prix » (plus de bandeau « pose d'abord tes dates ») ;
//  - candidats PawBoost en tête, ordre du serveur conservé (plus de retri) ;
//  - bandeau « <Prénom> a candidaté à ta demande » dans la conversation ;
//  - halo PawBoost : liseré blanc puis anneau turquoise plein, lueur large.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/localization/v565/cand2610_i18n.dart';
import 'package:hopetsit/localization/v565/dates620_i18n.dart';
import 'package:hopetsit/localization/v565/pay627_i18n.dart';
import 'package:hopetsit/localization/v565/pay628_i18n.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/views/pet_owner/chat/chat_choose_banner628.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_candidates_sheet.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'lotd_harness.dart';

Map<String, dynamic> _app(String id, String name, Map<String, dynamic> pricing,
        {String status = 'pending', bool boosted = false, String createdAt = '2026-10-27T10:00:00Z'}) =>
    <String, dynamic>{
      'id': id,
      'postId': 'p1',
      'status': status,
      'createdAt': createdAt,
      'description': 'Bonjour, je suis dispo.',
      'sitter': {
        'id': 's-$id',
        'name': name,
        'currency': 'EUR',
        'rating': 0,
        'reviewsCount': 0,
        'verified': true,
        'isBoosted': boosted,
      },
      'pricing': pricing,
    };

const _priced = <String, dynamic>{
  'totalPrice': 120, 'appliedRate': 20, 'unit': 'day', 'currency': 'EUR',
};
const _stale = <String, dynamic>{'stale': true, 'unit': 'visit', 'currency': 'EUR'};
const _indicative = <String, dynamic>{
  'indicative': true, 'pricingTier': 'indicative', 'unitRate': 10, 'ownerUnitRate': 12,
  'unit': 'day', 'currency': 'EUR',
};

ApplicationModel _m(Map<String, dynamic> j) => ApplicationModel.fromJson(j);

const _bookingId = '6ae3b1bee86658cbe6d9e34c';

void main() {
  setUpAll(() {
    Get.testMode = true;
    Get.locale = const Locale('fr', 'FR');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  group('i18n 628', () {
    test('mêmes clés dans les 9 langues, jamais vides, {name} gardé, mots du site', () {
      final fr = pay628I18n['fr']!;
      expect(fr.keys.toSet(), {
        'cand628_g_cancel', 'cand628_g_escrow', 'cand628_g_holiday', 'cand628_chat_title', 'cand628_chat_see',
        'home628_see_candidates', 'home628_offer_services', // point 8 (accueils)
      });
      expect(fr['home628_see_candidates'], 'Voir les candidats');
      expect(fr['home628_offer_services'], 'Proposer mes services');
      expect(fr['cand628_g_cancel'], 'Annulation gratuite jusqu\'à 72 h avant, remboursement intégral');
      expect(fr['cand628_g_escrow'], 'Ton argent n\'est versé qu\'une fois le service terminé');
      expect(fr['cand628_chat_title'], '{name} a candidaté à ta demande');
      expect(pay628I18n['en']!['cand628_chat_see'], 'See the application');
      for (final l in const ['en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
        final m = pay628I18n[l]!;
        expect(m.keys.toSet(), fr.keys.toSet(), reason: l);
        for (final e in m.entries) {
          expect(e.value.trim(), isNotEmpty, reason: '$l ${e.key}');
          if (fr[e.key]!.contains('{name}')) expect(e.value, contains('{name}'), reason: '$l ${e.key}');
        }
      }
    });
  });

  group('garanties (pur)', () {
    final now = DateTime.utc(2026, 10, 29, 20);
    test('début à plus de 72 h → annulation + séquestre', () {
      expect(guaranteeLines628(start: now.add(const Duration(days: 10)), end: now.add(const Duration(days: 12)), now: now),
          ['cand628_g_cancel', 'cand628_g_escrow']);
    });
    test('début dans 24 h → séquestre seul', () {
      expect(guaranteeLines628(start: now.add(const Duration(hours: 24)), now: now), ['cand628_g_escrow']);
      expect(guaranteeLines628(start: now.add(const Duration(hours: 72)), now: now), ['cand628_g_escrow'],
          reason: 'exactement 72 h : pas « plus de 72 h »');
    });
    test('sans date → séquestre seul', () {
      expect(guaranteeLines628(now: now), ['cand628_g_escrow']);
    });
    test('fêtes : période qui touche le 15/12 – 06/01', () {
      expect(guaranteeLines628(start: DateTime.utc(2026, 12, 20), end: DateTime.utc(2026, 12, 27), now: now),
          contains('cand628_g_holiday'));
      expect(guaranteeLines628(start: DateTime.utc(2027, 1, 2), now: now), contains('cand628_g_holiday'));
      expect(guaranteeLines628(start: DateTime.utc(2026, 12, 10), end: DateTime.utc(2026, 12, 15), now: now),
          contains('cand628_g_holiday'), reason: 'la fin tombe le 15/12');
      expect(guaranteeLines628(start: DateTime.utc(2026, 11, 10), end: DateTime.utc(2026, 11, 12), now: now),
          isNot(contains('cand628_g_holiday')));
      expect(guaranteeLines628(start: DateTime.utc(2027, 1, 7), now: now), isNot(contains('cand628_g_holiday')));
    });
    test('ordre : annulation, séquestre, fêtes', () {
      expect(guaranteeLines628(start: DateTime.utc(2026, 12, 24), end: DateTime.utc(2026, 12, 26), now: now),
          ['cand628_g_cancel', 'cand628_g_escrow', 'cand628_g_holiday']);
    });
  });

  group('ordre des candidats (pur)', () {
    test('isBoosted lu du serveur ; boostés d\'abord, ordre du serveur gardé, candidat du lien en tête', () {
      final a = _m(_app('a1', 'Ana', _priced, createdAt: '2026-10-27T12:00:00Z'));
      final b = _m(_app('a2', 'Bob', _priced, createdAt: '2026-10-27T11:00:00Z', boosted: true));
      final c = _m(_app('a3', 'Chloé', _priced, createdAt: '2026-10-27T10:00:00Z'));
      final d = _m(_app('a4', 'Dan', _priced, createdAt: '2026-10-27T09:00:00Z', boosted: true));
      expect(b.sitter.isBoosted, isTrue);
      expect(a.sitter.isBoosted, isFalse);
      // ordre serveur : a, b, c, d (le serveur 2910 met déjà les boostés en tête ; ici on vérifie que
      // l'app NE RETRIE PLUS par date et met les boostés devant si un vieux serveur ne l'a pas fait)
      expect(orderCandidates628([a, b, c, d], null).map((x) => x.id), ['a2', 'a4', 'a1', 'a3']);
      expect(orderCandidates628([a, b, c, d], 'a3').map((x) => x.id), ['a3', 'a2', 'a4', 'a1']);
      // ordre serveur conservé entre non boostés même si createdAt est « à l'envers »
      final old = _m(_app('a5', 'Eve', _priced, createdAt: '2026-10-01T00:00:00Z'));
      expect(orderCandidates628([old, a], null).map((x) => x.id), ['a5', 'a1']);
    });
  });

  group('bandeau du chat (pur)', () {
    test('candidature en attente de l\'interlocuteur, libellé selon le prix', () {
      Get.addTranslations(<String, Map<String, String>>{
        'fr_FR': {...cand2610I18n['fr']!, ...pay627I18n['fr']!, ...pay628I18n['fr']!, ...dates620I18n['fr']!},
      });
      Get.locale = const Locale('fr', 'FR');
      final priced = _m(_app('a1', 'Imane Benali', _priced));
      final stale = _m(_app('a2', 'Sohane', _stale));
      final done = _m(_app('a3', 'Max', _priced, status: 'accepted'));
      final apps = [done, stale, priced];
      expect(chatChooseApplication628(apps, 's-a1')?.id, 'a1');
      expect(chatChooseApplication628(apps, 's-a2')?.id, 'a2');
      expect(chatChooseApplication628(apps, 's-a3'), isNull, reason: 'déjà choisie');
      expect(chatChooseApplication628(apps, ''), isNull);
      expect(chatChooseApplication628(apps, 'zz'), isNull);
      expect(chatChoosePayable628(priced), isTrue);
      expect(chatChoosePayable628(stale), isFalse);
      expect(chatChooseLabel628(priced), contains('Choisir Imane et payer · 120,00'));
      expect(chatChooseLabel628(stale), 'Voir sa candidature');
    });
  });

  group('halo PawBoost (rendu)', () {
    Future<Uint8List> render(void Function(Canvas) paint, double w, double h) async {
      final rec = ui.PictureRecorder();
      paint(Canvas(rec));
      final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
      return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    }

    (int, int, int, int) px(Uint8List b, int w, int x, int y) {
      final i = (y * w + x) * 4;
      return (b[i], b[i + 1], b[i + 2], b[i + 3]);
    }

    test('épingle membre boostée : liseré blanc, anneau turquoise plein, lueur au-delà', () async {
      const size = PawMapLegend.memberSize;
      const margin = PawMapPinPainter.memberMargin;
      const w = size + 2 * margin;
      final b = await render(
          (c) => PawMapPinPainter.paintMemberDot(c, role: 'sitter', boostPhase: 0.25), w, w);
      const cx = margin + size / 2;
      final r = size / 2;
      // à r + 1,5 : blanc (liseré)
      final white = px(b, w.toInt(), cx.round(), (cx - r - 1.5).round());
      expect(white.$1, greaterThan(235), reason: 'liseré blanc R $white');
      expect(white.$2, greaterThan(235));
      expect(white.$3, greaterThan(235));
      // à r + 5 : turquoise PLEIN (#06B6D4 ≈ 6/182/212, ≥ 95 %)
      final ring = px(b, w.toInt(), cx.round(), (cx - r - 5).round());
      expect(ring.$4, greaterThan(235), reason: 'anneau opaque $ring');
      expect(ring.$1, lessThan(60), reason: 'R faible $ring');
      expect(ring.$2, inInclusiveRange(150, 200), reason: 'G $ring');
      expect(ring.$3, greaterThan(180), reason: 'B $ring');
      // à r + 12 : lueur turquoise encore nette (avant : ~0,55 d'opacité max)
      final glow = px(b, w.toInt(), cx.round(), (cx - r - 12).round());
      expect(glow.$4, greaterThan(110), reason: 'lueur $glow');
      expect(glow.$1, lessThan(glow.$3), reason: 'teinte turquoise $glow');
    });

    test('épingle normale : rien de turquoise autour', () async {
      const size = PawMapLegend.memberSize;
      final margin = PawMapPinPainter.memberMarginFor();
      final w = size + 2 * margin;
      final b = await render((c) => PawMapPinPainter.paintMemberDot(c, role: 'sitter', margin: margin), w, w);
      final cx = margin + size / 2;
      final r = size / 2;
      final p = px(b, w.toInt(), cx.round(), (cx - r - 5).round());
      expect(p.$4 < 60 || p.$3 < p.$1 + 40, isTrue, reason: 'pas de turquoise $p');
    });
  });

  group('feuille des candidats', () {
    setUp(() async {
      await lotdSetUp(role: 'owner');
      // La feuille des dates formate en français (intl) : données de locale.
      await initializeDateFormatting('fr_FR');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall c) async => null);
      Get.addTranslations(<String, Map<String, String>>{
        'fr_FR': {...dates620I18n['fr']!, ...cand2610I18n['fr']!, ...pay627I18n['fr']!, ...pay628I18n['fr']!},
      });
      Get.locale = const Locale('fr', 'FR');
    });
    final paid = <String>[];
    setUp(() {
      paid.clear();
      openBookingPayment628 = (id) async => paid.add(id);
    });
    tearDown(() async {
      openBookingPayment628 = (id) => DeepLinkService.instance.openBookingPayment628(id);
      await Get.deleteAll(force: true);
      Get.reset();
    });

    /// Faux serveur : demande `dateMode` donné ; après un PATCH /posts (dates posées), la demande
    /// devient « exact » et les candidatures reviennent avec un total (recalcul serveur).
    Future<void> open(WidgetTester tester,
        {required String dateMode,
        required List<Map<String, dynamic>> appsBefore,
        List<Map<String, dynamic>>? appsAfter,
        String? highlight,
        bool chooseNow = false,
        String? startDate,
        String? endDate,
        double height = 667}) async {
      var saved = false;
      var responded = false;
      Map<String, dynamic> post() => <String, dynamic>{
            'id': 'p1', '_id': 'p1',
            'dateMode': saved ? 'exact' : dateMode,
            if (saved || startDate != null) 'startDate': startDate ?? '2026-10-29T00:00:00.000Z',
            if (saved || endDate != null) 'endDate': endDate ?? '2026-10-29T00:00:00.000Z',
            'serviceTypes': ['house_sitting'], 'houseSittingVenue': 'owners_home',
            'location': {'city': 'Zone test', 'lat': -35, 'lng': -30},
            'owner': {'id': 'o1', 'name': 'Camille'},
            'createdAt': '2026-10-26T10:00:00Z', 'updatedAt': '2026-10-26T10:00:00Z',
          };
      lotdResponder = (req) {
        if (req.url.path.endsWith('/applications/my')) {
          final base = saved ? (appsAfter ?? appsBefore) : appsBefore;
          if (!responded) return <String, dynamic>{'applications': base};
          return <String, dynamic>{
            'applications': [
              for (final a in base)
                a['id'] == 'a1' ? {...a, 'status': 'accepted', 'bookingId': _bookingId} : a,
            ],
          };
        }
        if (req.method == 'PATCH' && req.url.path.contains('/posts/')) {
          saved = true;
          return <String, dynamic>{'post': post()};
        }
        if (req.url.path.endsWith('/respond')) {
          responded = true;
          return <String, dynamic>{'application': {'id': 'a1', 'status': 'accepted', 'bookingId': _bookingId}};
        }
        if (req.url.path.contains('/posts/by-id/')) return <String, dynamic>{'post': post()};
        return <String, dynamic>{};
      };
      lotdPhone(tester, width: 375, height: height);
      await tester.pumpWidget(lotdApp(Builder(builder: (ctx) {
        return Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open_sheet'),
              onPressed: () => PostCandidatesSheet.show(
                  context: ctx, postId: 'p1', highlightApplicationId: highlight, chooseNow: chooseNow),
              child: const Text('ouvrir'),
            ),
          ),
        );
      })));
      await lotdSettle(tester);
      await tester.tap(find.byKey(const Key('open_sheet')));
      await lotdSettle(tester, frames: 14);
    }

    Future<void> pickDatesAndSave(WidgetTester tester) async {
      // Début : le sélecteur s'ouvre sur aujourd'hui → OK.
      await tester.tap(find.byKey(const Key('dates2610_start')));
      await lotdSettle(tester, frames: 6);
      await tester.tap(find.text('OK').last);
      await lotdSettle(tester, frames: 6);
      await tester.tap(find.byKey(const Key('dates2610_end')));
      await lotdSettle(tester, frames: 6);
      await tester.tap(find.text('OK').last);
      await lotdSettle(tester, frames: 6);
      await tester.tap(find.byKey(const Key('dates2610_save')));
      await lotdSettle(tester, frames: 16);
    }

    testWidgets('demande SANS dates : « Choisir » ouvre les dates, puis l\'encart « Choisir et payer · prix »',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester,
          dateMode: 'tbd',
          appsBefore: [_app('a1', 'Imane Benali', _indicative)],
          appsAfter: [_app('a1', 'Imane Benali', _priced)]);
      expect(find.byKey(const Key('cand627_fast')), findsNothing, reason: 'pas d\'encart sans dates');
      expect(find.byKey(const Key('dates620_set_dates_banner')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('dates620_choose_a1')));
      await tester.tap(find.byKey(const Key('dates620_choose_a1')));
      await lotdSettle(tester, frames: 8);
      expect(find.byKey(const Key('dates2610_sheet')), findsOneWidget, reason: 'les dates s\'ouvrent, pas une alerte');
      await pickDatesAndSave(tester);
      expect(find.byKey(const Key('dates2610_sheet')), findsNothing);
      expect(lotdRequests.where((r) => r.method == 'PATCH' && r.path.contains('/posts/')), hasLength(1));
      // Dates posées → encart pour le candidat retenu, prix du serveur, garanties.
      expect(find.byKey(const Key('cand627_fast')), findsOneWidget);
      expect(find.text('Réserver Imane ?'), findsOneWidget);
      expect(find.textContaining('Choisir Imane et payer · 120,00'), findsOneWidget);
      expect(find.byKey(const Key('cand628_g_escrow')), findsOneWidget);
      expect(find.text('Ton argent n\'est versé qu\'une fois le service terminé'), findsOneWidget);
      expect(find.byKey(const Key('cand628_g_cancel')), findsNothing, reason: 'début aujourd\'hui : pas 72 h');
      expect(find.byKey(const Key('dates620_set_dates_banner')), findsNothing);
      // Un geste → choix envoyé, feuille fermée.
      await tester.tap(find.byKey(const Key('cand627_fast_cta')));
      await lotdSettle(tester, frames: 12);
      expect(lotdRequests.where((r) => r.path.endsWith('/respond')), hasLength(1));
      expect(find.byKey(const Key('cand2610_sheet')), findsNothing);
      // 628 — IMPASSE corrigée : le paiement s'ouvre tout de suite, même depuis le bandeau d'accueil.
      expect(paid, [_bookingId]);
    });

    testWidgets('depuis le bandeau d\'accueil (sans ?choose=1) : « Choisir » → confirmation → paiement ouvert',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, dateMode: 'exact', appsBefore: [_app('a1', 'Imane Benali', _priced)]);
      expect(find.byKey(const Key('cand627_fast')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('dates620_choose_a1')));
      await tester.tap(find.byKey(const Key('dates620_choose_a1')));
      await lotdSettle(tester, frames: 6);
      // dialogue de confirmation « Choisir » (libellé fr.dart via lotdApp)
      final confirm = find.text('candidates_choose_confirm'.tr);
      expect(confirm, findsOneWidget, reason: 'bouton de confirmation du choix');
      await tester.tap(confirm);
      await lotdSettle(tester, frames: 12);
      expect(lotdRequests.where((r) => r.path.endsWith('/respond')), hasLength(1));
      expect(find.byKey(const Key('cand2610_sheet')), findsNothing);
      expect(paid, [_bookingId]);
    });

    testWidgets('pure : chosenBookingId628', (tester) async {
      final a = _m({..._app('a1', 'Ana', _priced), 'status': 'accepted', 'bookingId': _bookingId});
      final b = _m(_app('a2', 'Bob', _priced));
      expect(chosenBookingId628([b, a], 'p1'), _bookingId);
      expect(chosenBookingId628([b], 'p1'), isNull);
      expect(chosenBookingId628([a], 'autre'), isNull);
      expect(chosenBookingId628([_m({..._app('a3', 'C', _priced), 'status': 'accepted', 'bookingId': 'x'})], 'p1'), isNull);
    });

    testWidgets('lien ?choose=1 sur une demande SANS dates : les dates s\'ouvrent d\'office',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester,
          dateMode: 'tbd',
          appsBefore: [_app('a1', 'Imane Benali', _indicative)],
          appsAfter: [_app('a1', 'Imane Benali', _priced)],
          highlight: 'a1',
          chooseNow: true);
      expect(find.byKey(const Key('dates2610_sheet')), findsOneWidget);
      await pickDatesAndSave(tester);
      expect(find.byKey(const Key('cand627_fast')), findsOneWidget);
      expect(find.textContaining('Choisir Imane et payer · 120,00'), findsOneWidget);
    });

    testWidgets('encart : annulation 72 h quand le début est loin, ligne fêtes en décembre',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      final start = DateTime.now().toUtc().add(const Duration(days: 10));
      // Période qui touche les fêtes : du 20 au 27 décembre de l'année en cours (ou suivante si passé).
      final y = DateTime.now().month == 12 && DateTime.now().day > 27 ? DateTime.now().year + 1 : DateTime.now().year;
      await open(tester,
          dateMode: 'exact',
          appsBefore: [_app('a1', 'Imane Benali', _priced)],
          highlight: 'a1',
          chooseNow: true,
          startDate: '${start.toIso8601String().substring(0, 10)}T00:00:00.000Z',
          endDate: '$y-12-27T00:00:00.000Z');
      expect(find.byKey(const Key('cand627_fast')), findsOneWidget);
      expect(find.byKey(const Key('cand628_g_cancel')), findsOneWidget);
      expect(find.text('Annulation gratuite jusqu\'à 72 h avant, remboursement intégral'), findsOneWidget);
      expect(find.byKey(const Key('cand628_g_escrow')), findsOneWidget);
      expect(find.byKey(const Key('cand628_g_holiday')), findsOneWidget);
      // Tout tient sur un iPhone SE sans défiler : le bouton ET les garanties.
      final h = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(tester.getBottomLeft(find.byKey(const Key('cand628_g_holiday'))).dy, lessThan(h));
      expect(tester.takeException(), isNull);
    });

    testWidgets('point 7 : photo et prénom du candidat ouvrent son profil public (gardien / promeneur)',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      final opened = <String>[];
      final saved = openCandidateProfile628;
      openCandidateProfile628 = (a) async => opened.add('${a.providerRole}:${a.sitter.id}');
      addTearDown(() => openCandidateProfile628 = saved);
      final walker = _app('a2', 'Léo Martin', _priced);
      walker['walker'] = walker.remove('sitter');
      await open(tester, dateMode: 'exact', appsBefore: [_app('a1', 'Imane Benali', _priced), walker],
          highlight: 'a1', chooseNow: true, height: 1400);
      await tester.tap(find.byKey(const Key('cand628_avatar_a1')));
      await tester.tap(find.byKey(const Key('cand628_name_a1')));
      await tester.tap(find.byKey(const Key('cand628_fast_profile_a1')));
      await tester.tap(find.byKey(const Key('cand628_name_a2')));
      await lotdSettle(tester, frames: 2);
      expect(opened, ['sitter:s-a1', 'sitter:s-a1', 'sitter:s-a1', 'walker:s-a2']);
      // La feuille et l'encart sont toujours là (retour vers la liste, choix conservé).
      expect(find.byKey(const Key('cand627_fast')), findsOneWidget);
    });

    testWidgets('point 7 (navigation RÉELLE) : la photo ouvre ServiceProviderDetailScreen par-dessus la feuille, retour = liste intacte',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, dateMode: 'exact', appsBefore: [_app('a1', 'Imane Benali', _priced)],
          highlight: 'a1', chooseNow: true, height: 1000);
      lotdResponder = (req) {
        if (req.url.path.endsWith('/sitters/s-a1')) {
          return <String, dynamic>{'sitter': {'id': 's-a1', 'name': 'Imane Benali', 'dailyRate': 20, 'currency': 'EUR'}};
        }
        if (req.url.path.endsWith('/applications/my')) {
          return <String, dynamic>{'applications': [_app('a1', 'Imane Benali', _priced)]};
        }
        return <String, dynamic>{};
      };
      await tester.tap(find.byKey(const Key('cand628_avatar_a1')));
      await lotdSettle(tester, frames: 10);
      expect(find.byType(ServiceProviderDetailScreen), findsOneWidget, reason: 'fiche publique poussée');
      expect(lotdRequests.where((r) => r.path.endsWith('/sitters/s-a1')), isNotEmpty);
      Get.back();
      await lotdSettle(tester, frames: 8);
      expect(find.byType(ServiceProviderDetailScreen), findsNothing);
      expect(find.byKey(const Key('cand627_fast')), findsOneWidget, reason: 'retour vers la liste, encart conservé');
      expect(tester.takeException(), isNull);
    });

    testWidgets('boostés en tête dans la feuille (ordre du serveur), candidat du lien devant',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, dateMode: 'exact', appsBefore: [
        _app('a1', 'Ana', _priced),
        _app('a2', 'Bob', _priced, boosted: true),
        _app('a3', 'Chloé', _priced),
      ]);
      final yAna = tester.getTopLeft(find.byKey(const Key('dates620_choose_a1'))).dy;
      final yBob = tester.getTopLeft(find.byKey(const Key('dates620_choose_a2'))).dy;
      expect(yBob, lessThan(yAna), reason: 'Bob (PawBoost) avant Ana');
    });
  });

  group('bandeau d\'action (capture de Daniel 23 h)', () {
    setUp(() async {
      await lotdSetUp(role: 'owner');
      Get.locale = const Locale('fr', 'FR');
    });
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    testWidgets('« Nouvelle candidature — Anne-Charlotte » se lit en entier sur 375 pt, avec pastille, bouton et croix',
        (tester) async {
      const title = 'Nouvelle candidature — Anne-Charlotte';
      lotdPhone(tester, width: 375, height: 667);
      await tester.pumpWidget(lotdApp(Scaffold(
        body: Column(children: [
          ActionBanner(
            tone: ActionTone.pending,
            icon: Icons.how_to_reg_rounded,
            title: title,
            subtitle: '8 nov. 2026 • Anne-Charlotte Dupont-Martin',
            extraCount: 24,
            onDismiss: () {},
            onTap: () {},
            trailing: ActionPillButton(
              label: 'Voir les candidats',
              tone: ActionTone.pending,
              compact: true,
              maxWidth: 124.w,
              onPressed: () {},
            ),
          ),
        ]),
      )));
      await lotdSettle(tester, frames: 4);
      final para = tester.renderObject<RenderParagraph>(find.text(title));
      expect(para.didExceedMaxLines, isFalse, reason: 'titre coupé');
      expect(para.size.width, greaterThan(180), reason: 'le titre a de la place (avant : ~110 pt)');
      expect(find.text('Voir les candidats'), findsOneWidget);
      expect(find.byKey(const Key('banner628_trailing')), findsOneWidget);
      // bouton ≥ 44 pt
      expect(tester.getSize(find.byType(ActionPillButton)).height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
      // Titre long ET bouton sous le texte : rien ne déborde dans 9 langues (le plus long : allemand).
      // Vrais titres (`notif_title_new_application` × 9 langues) + prénom long.
      for (final t in const [
        'Nouvelle candidature — Anne-Charlotte', 'New application — Anne-Charlotte', 'Nueva candidatura — Anne-Charlotte',
        'Neue Bewerbung — Anne-Charlotte', 'Nuova candidatura — Anne-Charlotte', 'Nova candidatura — Anne-Charlotte',
        '새 지원 — Anne-Charlotte', '新しい応募 — Anne-Charlotte', 'Nowe zgłoszenie — Anne-Charlotte',
      ]) {
        await tester.pumpWidget(lotdApp(Scaffold(
          body: ActionBanner(
            tone: ActionTone.pending, icon: Icons.how_to_reg_rounded, title: t, subtitle: 'x', extraCount: 3,
            onDismiss: () {}, onTap: () {},
            trailing: ActionPillButton(label: 'Voir les candidats', tone: ActionTone.pending, compact: true, maxWidth: 124.w, onPressed: () {}),
          ),
        )));
        await lotdSettle(tester, frames: 2);
        expect(tester.renderObject<RenderParagraph>(find.text(t)).didExceedMaxLines, isFalse, reason: t);
        expect(tester.takeException(), isNull, reason: t);
      }
    });
  });

  group('bandeau du chat (widget)', () {
    setUp(() async {
      await lotdSetUp(role: 'owner');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall c) async => null);
      Get.addTranslations(<String, Map<String, String>>{
        'fr_FR': {...dates620I18n['fr']!, ...cand2610I18n['fr']!, ...pay627I18n['fr']!, ...pay628I18n['fr']!},
      });
      Get.locale = const Locale('fr', 'FR');
    });
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    ChatConversation conv(String contactId) => ChatConversation(
          id: 'c1',
          contactName: 'Imane Benali',
          contactImage: '',
          lastMessage: 'Bonjour',
          lastMessageTime: DateTime(2026, 10, 29),
          isOnline: false,
          unreadCount: 0,
          contactId: contactId,
          contactRole: 'sitter',
        );

    Future<void> mount(WidgetTester tester, List<Map<String, dynamic>> apps, String contactId,
        {Future<void> Function(ApplicationModel)? onOpen}) async {
      lotdResponder = (req) {
        if (req.url.path.endsWith('/applications/my')) return <String, dynamic>{'applications': apps};
        return <String, dynamic>{};
      };
      lotdPhone(tester, width: 375, height: 667);
      final convs = <ChatConversation>[conv(contactId)].obs;
      await tester.pumpWidget(lotdApp(Scaffold(
        body: Column(children: [
          ChatChooseBanner628(conversationId: 'c1', conversations: () => convs, onOpen: onOpen),
          const Expanded(child: SizedBox()),
        ]),
      )));
      await lotdSettle(tester, frames: 10);
    }

    testWidgets('l\'interlocuteur a candidaté : titre + « Choisir Imane et payer · prix » + séquestre ; tap = parcours',
        (tester) async {
      ApplicationModel? opened;
      await mount(tester, [_app('a1', 'Imane Benali', _priced)], 's-a1', onOpen: (a) async => opened = a);
      expect(find.byKey(const Key('chat628_choose')), findsOneWidget);
      expect(find.text('Imane a candidaté à ta demande'), findsOneWidget);
      expect(find.textContaining('Choisir Imane et payer · 120,00'), findsOneWidget);
      expect(find.byKey(const Key('chat628_escrow')), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat628_cta')));
      await lotdSettle(tester, frames: 4);
      expect(opened?.id, 'a1');
      expect(tester.takeException(), isNull);
    });

    testWidgets('sans prix (tarif à venir) : « Voir sa candidature », pas de ligne séquestre', (tester) async {
      await mount(tester, [_app('a1', 'Imane Benali', _stale)], 's-a1');
      expect(find.byKey(const Key('chat628_choose')), findsOneWidget);
      expect(find.text('Voir sa candidature'), findsOneWidget);
      expect(find.byKey(const Key('chat628_escrow')), findsNothing);
    });

    testWidgets('pas de candidature de cet interlocuteur : rien', (tester) async {
      await mount(tester, [_app('a1', 'Imane Benali', _priced)], 's-autre');
      expect(find.byKey(const Key('chat628_choose')), findsNothing);
    });
  });
}
