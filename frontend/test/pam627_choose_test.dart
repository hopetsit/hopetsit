// 627 (PAM, 28/10/2026) — parité app / site après SAM (4dd86df2, 117d3541)
// et ZOE (eee4b792) :
//  - lien « Choisir <prénom> » de l'e-mail / du SMS (`?choose=1`) → encart
//    « Réserver <prénom> ? » + « Choisir <prénom> et payer · prix » = UN geste ;
//  - 409 RATE_PENDING (candidature « Tarif à venir ») → la phrase du serveur,
//    jamais une erreur technique ;
//  - `/posts/confirmer?l=…` rendu au navigateur (session sans mot de passe
//    ouverte par le site) ; Android ne l'attrape plus.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/localization/v565/cand2610_i18n.dart';
import 'package:hopetsit/localization/v565/dates620_i18n.dart';
import 'package:hopetsit/localization/v565/lotc584_i18n.dart';
import 'package:hopetsit/localization/v565/pay627_i18n.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_candidates_sheet.dart';

import 'lotd_harness.dart';

Map<String, dynamic> _app(String id, String name, Map<String, dynamic> pricing,
        {String status = 'pending'}) =>
    <String, dynamic>{
      'id': id,
      'postId': 'p1',
      'status': status,
      'createdAt': '2026-10-27T10:00:00Z',
      'description': 'Bonjour, je suis dispo.',
      'sitter': {
        'id': 's-$id',
        'name': name,
        'currency': 'EUR',
        'rating': 0,
        'reviewsCount': 0,
        'verified': true,
      },
      'pricing': pricing,
    };

const _priced = <String, dynamic>{
  'totalPrice': 120, 'appliedRate': 20, 'unit': 'day', 'currency': 'EUR',
};
const _stale = <String, dynamic>{
  'stale': true, 'unit': 'visit', 'currency': 'EUR',
};
const _indicative = <String, dynamic>{
  'indicative': true, 'pricingTier': 'indicative', 'unitRate': 10, 'ownerUnitRate': 12,
  'unit': 'walk', 'currency': 'EUR',
};

const _ratePendingFr =
    'Sohane n’a pas encore de tarif par visite : son prix sera calculé dès qu’il l’aura ajouté, puis tu pourras le choisir.';

void main() {
  setUpAll(() {
    Get.testMode = true;
    Get.locale = const Locale('fr', 'FR');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  group('i18n 627', () {
    test('mêmes clés dans les 9 langues, jamais vides, {name} gardé', () {
      final fr = pay627I18n['fr']!;
      expect(fr['cand627_fast_title'], 'Réserver {name} ?');
      expect(fr['cand627_fast_cta'], 'Choisir {name} et payer');
      for (final l in const ['en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
        final m = pay627I18n[l]!;
        expect(m.keys.toSet(), fr.keys.toSet(), reason: l);
        for (final e in m.entries) {
          expect(e.value.trim(), isNotEmpty, reason: '$l ${e.key}');
          if (fr[e.key]!.contains('{name}')) expect(e.value, contains('{name}'), reason: '$l ${e.key}');
        }
      }
    });

    test('légende : plus de « carré = groupe de lieux » (groupes en rond, LEO 2d583ccb)', () {
      for (final l in const ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
        final memo = lotC584I18n[l]!['pawmap_legend_memo']!;
        final intro = lotC584I18n[l]!['pawmap_help_intro']!;
        for (final w in const ['Carré', 'carré', 'Square', 'square', 'Cuadrado', 'cuadrado', 'Quadrat',
          'Quadrato', 'quadrato', 'Quadrado', 'quadrado', '사각형', '四角', 'Kwadrat', 'kwadrat']) {
          expect(memo.contains(w), isFalse, reason: '$l memo « $w »');
          expect(intro.contains(w), isFalse, reason: '$l intro « $w »');
        }
      }
      expect(lotC584I18n['fr']!['pawmap_legend_memo'], contains('Rond avec un nombre = un groupe'));
    });
  });

  group('choix rapide (pur)', () {
    ApplicationModel m(Map<String, dynamic> j) => ApplicationModel.fromJson(j);
    final priced = m(_app('a1', 'Imane Benali', _priced));
    final stale = m(_app('a2', 'Sohane', _stale));
    final indic = m(_app('a3', 'Ana', _indicative));
    final done = m(_app('a4', 'Max', _priced, status: 'accepted'));
    final all = [priced, stale, indic, done];

    test('encart seulement pour la candidature du lien, en attente, avec un total', () {
      expect(fastChoice627(applications: all, focusId: 'a1', chooseNow: true, tbd: false)?.id, 'a1');
      expect(fastChoice627(applications: all, focusId: 'a1', chooseNow: false, tbd: false), isNull,
          reason: 'sans choose=1 : page normale');
      expect(fastChoice627(applications: all, focusId: 'a1', chooseNow: true, tbd: true), isNull,
          reason: 'dates à prévoir');
      expect(fastChoice627(applications: all, focusId: 'a2', chooseNow: true, tbd: false), isNull,
          reason: 'tarif à venir');
      expect(fastChoice627(applications: all, focusId: 'a3', chooseNow: true, tbd: false), isNull,
          reason: 'indicative');
      expect(fastChoice627(applications: all, focusId: 'a4', chooseNow: true, tbd: false), isNull,
          reason: 'déjà choisie');
      expect(fastChoice627(applications: all, focusId: 'zz', chooseNow: true, tbd: false), isNull);
      expect(fastChoice627(applications: all, focusId: null, chooseNow: true, tbd: false), isNull);
    });
  });

  group('liens', () {
    const id = '6a1f0c2b9d8e7f6a5b4c3d2e';
    test('choose=1 lu sur /application/<id>, /posts?application= et hopetsit://', () {
      final a = DeepLinkService.applicationTarget627(
          Uri.parse('https://hopetsit.com/application/$id?from=email&choose=1'))!;
      expect(a.id, id);
      expect(a.choose, isTrue);
      final s = DeepLinkService.applicationTarget627(
          Uri.parse('https://www.hopetsit.com/application/$id?from=sms&choose=1'))!;
      expect(s.choose, isTrue);
      final n = DeepLinkService.applicationTarget627(
          Uri.parse('https://hopetsit.com/application/$id?from=email'))!;
      expect(n.choose, isFalse, reason: 'lien classique : pas d\'encart');
      final p = DeepLinkService.applicationTarget627(
          Uri.parse('https://hopetsit.com/posts?application=$id&choose=1'))!;
      expect(p.id, id);
      expect(p.choose, isTrue);
      final c = DeepLinkService.applicationTarget627(Uri.parse('hopetsit://application/$id?choose=1'))!;
      expect(c.id, id);
      expect(c.choose, isTrue);
      expect(DeepLinkService.applicationTarget627(Uri.parse('https://hopetsit.com/application/abc?choose=1')),
          isNull, reason: 'id invalide refusé');
      expect(DeepLinkService.applicationTarget627(Uri.parse('https://hopetsit.com/posts')), isNull);
      expect(DeepLinkService.applicationTarget627(
          Uri.parse('https://hopetsit.com/posts/confirmer?l=$id&next=%2Fapplication%2F$id')), isNull);
    });

    test('/posts/confirmer appartient au site, jamais à l\'app', () {
      expect(DeepLinkService.isLeadConfirmLink627(Uri.parse(
          'https://hopetsit.com/posts/confirmer?l=$id&next=%2Fapplication%2F$id%3Fchoose%3D1')), isTrue);
      expect(DeepLinkService.isLeadConfirmLink627(Uri.parse('https://hopetsit.com/posts')), isFalse);
      expect(DeepLinkService.isLeadConfirmLink627(Uri.parse('https://hopetsit.com/application/$id')), isFalse);
    });

    test('Android : plus de préfixe « /post » qui attrapait /posts/confirmer', () {
      final xml = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(xml.contains('android:pathPrefix="/post" '), isFalse);
      expect(xml, contains('android:path="/posts"'));
      expect(xml, contains('android:pathPrefix="/post/"'));
      expect(xml, contains('android:pathPrefix="/application"'));
      // Aucune règle restante ne couvre /posts/confirmer.
      final prefixes = RegExp(r'android:pathPrefix="([^"]+)"').allMatches(xml).map((x) => x.group(1)!);
      final paths = RegExp(r'android:path="([^"]+)"').allMatches(xml).map((x) => x.group(1)!);
      const target = '/posts/confirmer';
      expect(prefixes.where(target.startsWith), isEmpty);
      expect(paths.where((p) => p == target), isEmpty);
    });
  });

  group('RATE_PENDING (pur)', () {
    test('phrase du serveur, sinon explication locale, jamais le code', () {
      Get.addTranslations(<String, Map<String, String>>{'fr_FR': dates620I18n['fr']!});
      Get.locale = const Locale('fr', 'FR');
      final e = ApiException(_ratePendingFr, statusCode: 409, details: {
        'error': _ratePendingFr, 'code': 'RATE_PENDING', 'unit': 'visit', 'postId': 'p1',
      });
      expect(ratePendingMessage627(e), _ratePendingFr);
      final bare = ApiException('Request failed (409)', statusCode: 409, details: {'code': 'RATE_PENDING'});
      expect(ratePendingMessage627(bare), dates620I18n['fr']!['dates620_stale_explain']);
      expect(ratePendingMessage627(bare), isNot(contains('RATE_PENDING')));
      final other = ApiException('x', statusCode: 409, details: {'code': 'DATES_REQUIRED'});
      expect(ratePendingMessage627(other), isNull);
    });
  });

  group('feuille des candidats', () {
    setUp(() async {
      await lotdSetUp(role: 'owner');
      // Retour haptique : le canal plateforme n'existe pas en test.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall c) async => null);
      Get.addTranslations(<String, Map<String, String>>{
        'fr_FR': {...dates620I18n['fr']!, ...cand2610I18n['fr']!, ...pay627I18n['fr']!},
      });
      Get.locale = const Locale('fr', 'FR');
    });
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    Future<void> open(WidgetTester tester, List<Map<String, dynamic>> apps,
        {String? highlight, bool chooseNow = false, Map<String, dynamic>? respond, double width = 375, double height = 667}) async {
      lotdResponder = (req) {
        if (req.url.path.endsWith('/applications/my')) {
          return <String, dynamic>{'applications': apps};
        }
        if (req.url.path.endsWith('/respond')) {
          return respond ?? <String, dynamic>{'application': {'id': 'a1', 'status': 'accepted'}};
        }
        if (req.url.path.contains('/posts/by-id/')) {
          return <String, dynamic>{
            'post': {
              'id': 'p1', '_id': 'p1', 'dateMode': 'exact', 'serviceTypes': ['home_visit'],
              'location': {'city': 'Paris', 'lat': 48.8566, 'lng': 2.3522},
              'owner': {'id': 'o1', 'name': 'Camille'},
              'createdAt': '2026-10-26T10:00:00Z', 'updatedAt': '2026-10-26T10:00:00Z',
            },
          };
        }
        return <String, dynamic>{};
      };
      lotdPhone(tester, width: width, height: height);
      await tester.pumpWidget(lotdApp(Builder(builder: (ctx) {
        return Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open_sheet'),
              onPressed: () => PostCandidatesSheet.show(
                  context: ctx,
                  postId: 'p1',
                  highlightApplicationId: highlight,
                  source: 'notification',
                  chooseNow: chooseNow),
              child: const Text('ouvrir'),
            ),
          ),
        );
      })));
      await lotdSettle(tester);
      await tester.tap(find.byKey(const Key('open_sheet')));
      await lotdSettle(tester, frames: 14);
    }

    testWidgets('choose=1 : « Réserver Imane ? » puis UN geste = choix envoyé sans dialogue, feuille fermée',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [
        _app('a2', 'Tom Petit', _priced),
        _app('a1', 'Imane Benali', _priced),
      ], highlight: 'a1', chooseNow: true);
      expect(find.byKey(const Key('cand627_fast')), findsOneWidget);
      expect(find.text('Réserver Imane ?'), findsOneWidget);
      expect(find.textContaining('Choisir Imane et payer · 120,00'), findsOneWidget);
      expect(find.text('Paiement sécurisé par carte'), findsOneWidget);
      // Encart en tête, visible sans défiler (375 × 667).
      final h = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(tester.getBottomLeft(find.byKey(const Key('cand627_fast_cta'))).dy, lessThan(h));
      await tester.tap(find.byKey(const Key('cand627_fast_cta')));
      await lotdSettle(tester, frames: 12);
      final sent = lotdRequests.where((r) => r.path.endsWith('/respond')).toList();
      expect(sent, hasLength(1));
      expect(sent.single.path, contains('/a1/'));
      expect(sent.single.body, {'action': 'accept'});
      expect(find.byKey(const Key('cand2610_sheet')), findsNothing, reason: 'feuille fermée → paiement');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('768 dp (tablette, échelle ×2) : encart sans débordement',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [_app('a1', 'Imane Benali', _priced)], highlight: 'a1', chooseNow: true,
          width: 768, height: 1152);
      expect(find.byKey(const Key('cand627_fast')), findsOneWidget);
      expect(find.text('Paiement sécurisé par carte'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'aucun RenderFlex overflowed');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('sans choose=1 : aucun encart (page normale)',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [_app('a1', 'Imane Benali', _priced)], highlight: 'a1');
      expect(find.byKey(const Key('cand627_fast')), findsNothing);
      expect(find.byKey(const Key('cand2610_sheet')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('choose=1 sur une candidature « Tarif à venir » : aucun encart',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [_app('a1', 'Sohane', _stale)], highlight: 'a1', chooseNow: true);
      expect(find.byKey(const Key('cand627_fast')), findsNothing);
      expect(find.text('Tarif à venir'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('409 RATE_PENDING : rien de choisi, feuille ouverte, liste rechargée, aucune exception',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [_app('a1', 'Sohane', _priced)], highlight: 'a1', chooseNow: true,
          respond: <String, dynamic>{
            '__status': 409, 'error': _ratePendingFr, 'code': 'RATE_PENDING', 'unit': 'visit', 'postId': 'p1',
          });
      final loadsBefore = lotdRequests.where((r) => r.path.endsWith('/applications/my')).length;
      await tester.tap(find.byKey(const Key('cand627_fast_cta')));
      await lotdSettle(tester, frames: 12);
      expect(lotdRequests.where((r) => r.path.endsWith('/respond')), hasLength(1));
      expect(find.byKey(const Key('cand2610_sheet')), findsOneWidget, reason: 'pas fermée : rien n\'est payé');
      expect(lotdRequests.where((r) => r.path.endsWith('/applications/my')).length, greaterThan(loadsBefore),
          reason: 'liste rechargée (le candidat passera en « Tarif à venir »)');
      expect(find.textContaining('RATE_PENDING'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
