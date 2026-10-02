// 607 NEO (02/10/2026, décision de Daniel) — « Ramène tes clients » :
// carte d'accueil (0 réservation) ou carte « Pionnier », entrée Profil,
// feuille lien + message prêt + affiche, badge sur la fiche. 3 rôles :
// le propriétaire ne voit RIEN et n'appelle rien. 9 langues à 375 dp.
// Sans réseau (harnais lot D, réponses simulées).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hopetsit/localization/v565/pioneer607_i18n.dart';
import 'package:hopetsit/services/my_link607.dart';
import 'package:hopetsit/utils/server_error_message.dart';
import 'package:hopetsit/widgets/bring_clients607.dart';

import 'lotd_harness.dart';

Finder _k(String k) => find.byKey(Key(k), skipOffstage: false);

Map<String, dynamic> _link({String role = 'sitter', bool? pioneer = false, int bookings = 0, String city = 'Zone test'}) =>
    <String, dynamic>{
      'slug': 'nora-t-zone-test',
      'url': 'https://www.hopetsit.com/s/nora-t-zone-test',
      'role': role,
      'city': city,
      'isPioneer': pioneer,
      'bookingsCount': bookings,
      'posterPath': '/public/providers/nora-t-zone-test/poster.pdf',
    };

Future<void> _home(WidgetTester t, {Locale locale = const Locale('fr', 'FR'), double width = 393}) async {
  lotdPhone(t, width: width);
  await t.pumpWidget(lotdApp(
    const Scaffold(body: SingleChildScrollView(child: BringClientsHomeCard607())),
    locale: locale,
  ));
  await lotdSettle(t);
}

int _linkCalls() => lotdRequests.where((r) => r.path.endsWith('/public/providers/me/link')).length;

void main() {
  setUp(() => resetMyLinkCache607());

  group('accueil', () {
    testWidgets('gardien sans réservation : carte « Ramène tes clients » + feuille lien / message', (t) async {
      await t.runAsync(() => lotdSetUp(role: 'sitter'));
      lotdResponder = (req) => req.url.path.endsWith('/public/providers/me/link') ? _link() : <String, dynamic>{};
      await _home(t);
      expect(_k('neo607_home_card'), findsOneWidget);
      expect(find.text(pioneer607I18n['fr']!['neo607_card_title']!), findsOneWidget);
      expect(_k('neo607_pioneer_badge'), findsNothing);
      expect(_linkCalls(), 1);
      await t.tap(_k('neo607_home_more'));
      await lotdSettle(t);
      expect(_k('neo607_sheet'), findsOneWidget);
      expect(find.text('www.hopetsit.com/s/nora-t-zone-test'), findsOneWidget);
      final msg = pioneer607I18n['fr']!['neo607_message_sitter']!
          .replaceAll('{link}', 'https://www.hopetsit.com/s/nora-t-zone-test');
      expect(find.text(msg), findsOneWidget);
      expect(_k('neo607_sheet_share'), findsOneWidget);
      expect(_k('neo607_sheet_poster'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('promeneur pionnier : carte honnête avec la ville + badge', (t) async {
      await t.runAsync(() => lotdSetUp(role: 'walker'));
      lotdResponder = (req) => req.url.path.endsWith('/public/providers/me/link')
          ? _link(role: 'walker', pioneer: true, bookings: 2)
          : <String, dynamic>{};
      await _home(t);
      expect(_k('neo607_home_pioneer'), findsOneWidget);
      expect(_k('neo607_pioneer_badge'), findsOneWidget);
      expect(find.text('Tu es le premier promeneur autour de Zone test.'), findsOneWidget);
      expect(find.text(pioneer607I18n['fr']!['neo607_pioneer_body']!), findsOneWidget);
    });

    testWidgets('pionnier sans ville connue : phrase « autour de chez toi »', (t) async {
      await t.runAsync(() => lotdSetUp(role: 'sitter'));
      lotdResponder = (req) => req.url.path.endsWith('/public/providers/me/link')
          ? _link(pioneer: true, city: '')
          : <String, dynamic>{};
      await _home(t);
      expect(find.text(pioneer607I18n['fr']!['neo607_pioneer_title_sitter_nocity']!), findsOneWidget);
    });

    testWidgets('gardien qui a déjà des réservations et pas pionnier : rien', (t) async {
      await t.runAsync(() => lotdSetUp(role: 'sitter'));
      lotdResponder = (req) => req.url.path.endsWith('/public/providers/me/link')
          ? _link(bookings: 3)
          : <String, dynamic>{};
      await _home(t);
      expect(_k('neo607_home_card'), findsNothing);
      expect(_k('neo607_home_pioneer'), findsNothing);
    });

    testWidgets('propriétaire : aucune carte, aucun appel serveur', (t) async {
      await t.runAsync(() => lotdSetUp(role: 'owner'));
      lotdResponder = (req) => _link();
      await _home(t);
      expect(_k('neo607_home_card'), findsNothing);
      expect(_k('neo607_home_pioneer'), findsNothing);
      expect(_linkCalls(), 0);
    });

    testWidgets('serveur muet ou réponse invalide : rien, pas d\'erreur', (t) async {
      await t.runAsync(() => lotdSetUp(role: 'sitter'));
      lotdResponder = (req) => <String, dynamic>{'error': 'unavailable'};
      await _home(t);
      expect(_k('neo607_home_card'), findsNothing);
      expect(t.takeException(), isNull);
    });
  });

  group('Profil', () {
    for (final role in <String>['sitter', 'walker']) {
      testWidgets('$role : « Mon lien personnel » ouvre la feuille', (t) async {
        await t.runAsync(() => lotdSetUp(role: role));
        lotdResponder = (req) => req.url.path.endsWith('/public/providers/me/link')
            ? _link(role: role)
            : <String, dynamic>{};
        lotdPhone(t);
        await t.pumpWidget(lotdApp(Scaffold(body: MyLinkProfileTile607(role: role))));
        await lotdSettle(t);
        expect(_k('neo607_profile_tile'), findsOneWidget);
        await t.tap(_k('neo607_profile_tile'));
        await lotdSettle(t);
        expect(_k('neo607_sheet'), findsOneWidget);
        final key = role == 'walker' ? 'neo607_message_walker' : 'neo607_message_sitter';
        expect(find.textContaining(pioneer607I18n['fr']![key]!.split('{link}').first.trim()), findsOneWidget);
      });
    }
    testWidgets('propriétaire : pas d\'entrée', (t) async {
      await t.runAsync(() => lotdSetUp(role: 'owner'));
      lotdPhone(t);
      await t.pumpWidget(lotdApp(const Scaffold(body: MyLinkProfileTile607(role: 'owner'))));
      await lotdSettle(t);
      expect(_k('neo607_profile_tile'), findsNothing);
    });
  });

  group('fiche publique', () {
    testWidgets('badge Pionnier seulement si le serveur dit oui', (t) async {
      await t.runAsync(() => lotdSetUp(role: 'owner'));
      lotdPhone(t);
      await t.pumpWidget(lotdApp(Scaffold(
        body: Column(children: <Widget>[
          PioneerFicheBadge607(role: 'sitter', providerId: 'a1', fetcher: (_, __) async => true),
          PioneerFicheBadge607(role: 'walker', providerId: 'b2', fetcher: (_, __) async => false),
        ]),
      )));
      await lotdSettle(t);
      expect(_k('neo607_pioneer_badge'), findsOneWidget);
    });
  });

  group('affiche', () {
    test('télécharge avec le jeton, refuse ce qui n\'est pas un PDF', () async {
      await lotdSetUp(role: 'sitter');
      final seen = <http.Request>[];
      final client = MockClient((req) async {
        seen.add(req);
        return http.Response('{"error":"not_found"}', 404);
      });
      final link = MyLink607.fromJson(_link())!;
      final ok = await downloadPoster607(link, httpClient: client);
      expect(ok, isFalse);
      expect(seen.single.url.path, '/api/v1/public/providers/nora-t-zone-test/poster.pdf');
      expect(seen.single.url.queryParameters['lang'], isNotEmpty);
      expect(seen.single.headers['Authorization'], 'Bearer test-token-lotd');
    });
  });

  group('ville refusée par le serveur (CITY_INVALID, 02/10)', () {
    test('le code serveur donne le message traduit, présent dans les 9 langues', () {
      expect(serverErrorKey(code: 'CITY_INVALID', statusCode: 400, rawMessage: 'x'), 'neo607_err_city_invalid');
      for (final l in pioneer607I18n.keys) {
        expect(pioneer607I18n[l]!['neo607_err_city_invalid'], isNotEmpty, reason: l);
      }
    });
  });

  group('9 langues (375 dp)', () {
    for (final lang in <String>['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      testWidgets('$lang : carte pionnier + feuille, aucune clé brute, aucun débordement', (t) async {
        await t.runAsync(() => lotdSetUp(role: 'sitter'));
        lotdResponder = (req) => req.url.path.endsWith('/public/providers/me/link')
            ? _link(pioneer: true)
            : <String, dynamic>{};
        await _home(t, locale: Locale(lang), width: 375);
        expect(t.takeException(), isNull);
        final m = pioneer607I18n[lang]!;
        expect(find.text(m['neo607_pioneer_body']!), findsOneWidget);
        expect(find.text(m['neo607_pioneer_badge']!), findsOneWidget);
        await t.tap(_k('neo607_home_more'));
        await lotdSettle(t);
        expect(t.takeException(), isNull);
        expect(find.text(m['neo607_sheet_title']!), findsOneWidget);
        expect(find.text(m['neo607_poster']!), findsOneWidget);
        for (final k in m.keys) {
          expect(find.text(k, skipOffstage: false), findsNothing, reason: 'clé brute $k');
        }
        await Get.deleteAll(force: true);
      });
    }
    test('mêmes clés partout, {link} et {city} intacts, aucune promesse de revenus', () {
      final ref = pioneer607I18n['fr']!.keys.toSet();
      expect(pioneer607I18n.keys.toSet(), <String>{'fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'});
      for (final e in pioneer607I18n.entries) {
        expect(e.value.keys.toSet(), ref, reason: e.key);
        expect(e.value['neo607_message_sitter'], contains('{link}'));
        expect(e.value['neo607_message_walker'], contains('{link}'));
        expect(e.value['neo607_pioneer_title_sitter'], contains('{city}'));
        expect(e.value['neo607_pioneer_title_walker'], contains('{city}'));
        expect(e.value.containsKey('help607_pioneer_title'), isTrue);
        expect(e.value.containsKey('help607_pioneer_body'), isTrue);
        for (final v in e.value.values) {
          expect(v, isNot(matches(RegExp(r'€|\$|gagne|earn|revenu|income', caseSensitive: false))), reason: '${e.key}: $v');
        }
      }
    });
  });
}
