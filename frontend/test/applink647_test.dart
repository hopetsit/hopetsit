// 647 (PAM, 27/11/2026) — « je veux que les propriétaires passent par l'app » :
// le lien de l'e-mail « ta demande est en ligne »
//   https://www.hopetsit.com/app/demande?l=<contact pub>[&next=<chemin>]
// ouvre l'app DÉJÀ connectée sur les demandes du propriétaire.
//  a. GET /ad-leads/<id> ;
//  b. confirmé, sans session → POST /ad-leads/<id>/confirm {} → session → route ;
//  c. une session existe → jamais remplacée ;
//  d. non confirmé / 404 / erreur → page du site dans le navigateur externe ;
//  e. échec de la session → écran de connexion, route mémorisée.
// Réponses simulées uniquement : aucun appel réseau, aucune donnée réelle.
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/utils/storage_keys.dart';

import 'lotd_harness.dart';

const String _l = '0123456789abcdef0123456789abcdef'; // 32 hex minuscules
const String _app = '6730a1b2c3d4e5f6a7b8c9d0'; // candidature (24 hex)
const String _k = 'eyJ2IjoxfQ.c2lnbmF0dXJl_-Abc';

class _FakeAuth extends AuthController {
  _FakeAuth(super.authRepository, super.storage, super.userRepository);
  Map<String, dynamic>? applied;
  @override
  Future<bool> applyExchangedSession(Map<String, dynamic> response) async {
    applied = response;
    unawaited(GetStorage().write(StorageKeys.authToken, response['token']));
    return true;
  }
}

Future<_FakeAuth> _setUp({required bool session}) async {
  await lotdSetUp();
  final storage = GetStorage();
  if (!session) await storage.remove(StorageKeys.authToken);
  await storage.remove('pending_deep_route');
  await Get.delete<AuthController>(force: true);
  final fake = _FakeAuth(
    Get.find<AuthRepository>(),
    storage,
    Get.find<UserRepository>(),
  );
  Get.put<AuthController>(fake, permanent: true);
  DeepLinkService.lastOutcome647 = null;
  return fake;
}

Uri _link({String id = _l, String? next, bool custom = false}) => Uri(
      scheme: custom ? 'hopetsit' : 'https',
      host: custom ? 'app' : 'www.hopetsit.com',
      path: custom ? '/demande' : '/app/demande',
      queryParameters: <String, String>{'l': id, if (next != null) 'next': next},
    );

/// Réponses simulées du serveur : contact [confirmed], session du compte [email].
void _server({
  bool confirmed = true,
  int leadStatus = 200,
  int confirmStatus = 200,
  String email = 'lea@example.test',
}) {
  lotdResponder = (req) {
    final p = req.url.path;
    if (req.method == 'GET' && p.endsWith('/ad-leads/$_l')) {
      if (leadStatus != 200) {
        return <String, dynamic>{'__status': leadStatus, 'error': 'Not found'};
      }
      return <String, dynamic>{
        'firstName': 'Léa',
        'city': 'Paris',
        'lang': 'fr',
        'service': 'garde',
        'animal': 'chat',
        'quand': 'ce week-end',
        'confirmed': confirmed,
      };
    }
    if (req.method == 'POST' && p.endsWith('/ad-leads/$_l/confirm')) {
      if (confirmStatus != 200) {
        return <String, dynamic>{'__status': confirmStatus, 'error': 'boom'};
      }
      return <String, dynamic>{
        'token': 'jwt-647',
        'user': <String, dynamic>{
          'id': 'o-647',
          'name': 'Léa',
          'email': email,
          'role': 'owner',
        },
        'postId': '6730a1b2c3d4e5f6a7b8c9ff',
      };
    }
    return <String, dynamic>{};
  };
}

List<LotdRequest> _calls(String method, String suffix) => lotdRequests
    .where((r) => r.method == method && r.path.endsWith(suffix))
    .toList();

void main() {
  group('reconnaissance du lien (pure)', () {
    test('https et hopetsit://, id de 32 hex minuscules', () {
      expect(DeepLinkService.adLeadId647(_link()), _l);
      expect(DeepLinkService.adLeadId647(_link(custom: true)), _l);
      expect(
        DeepLinkService.adLeadId647(
          Uri.parse('https://hopetsit.com/app/demande?l=$_l'),
        ),
        _l,
      );
      expect(
        DeepLinkService.adLeadId647(
          Uri.parse('hopetsit://app/demande?l=$_l&next=%2Fposts'),
        ),
        _l,
      );
    });

    test('id invalide : 31 ou 33 caractères, majuscules, non hexadécimal, absent', () {
      final short = _l.substring(0, 31);
      expect(DeepLinkService.adLeadId647(_link(id: short)), isNull);
      expect(DeepLinkService.adLeadId647(_link(id: '${_l}0')), isNull);
      expect(DeepLinkService.adLeadId647(_link(id: _l.toUpperCase())), isNull);
      expect(
        DeepLinkService.adLeadId647(_link(id: 'A${_l.substring(1)}')),
        isNull,
      );
      expect(
        DeepLinkService.adLeadId647(_link(id: 'g${_l.substring(1)}')),
        isNull,
      );
      expect(DeepLinkService.adLeadId647(_link(id: '')), isNull);
      expect(
        DeepLinkService.adLeadId647(
          Uri.parse('https://www.hopetsit.com/app/demande'),
        ),
        isNull,
      );
      expect(
        DeepLinkService.adLeadId647(_link(id: short, custom: true)),
        isNull,
      );
    });

    test('autre chemin, autre hôte, http : jamais reconnu', () {
      for (final u in <String>[
        'https://www.hopetsit.com/app?l=$_l',
        'https://www.hopetsit.com/app/demandes?l=$_l',
        'https://www.hopetsit.com/app/demande/x?l=$_l',
        'https://www.hopetsit.com/application/demande?l=$_l',
        'https://www.hopetsit.com/posts/confirmer?l=$_l',
        'https://evil.example/app/demande?l=$_l',
        'http://www.hopetsit.com/app/demande?l=$_l',
        'hopetsit://demande?l=$_l',
        'hopetsit://app?l=$_l',
      ]) {
        expect(DeepLinkService.adLeadId647(Uri.parse(u)), isNull, reason: u);
      }
      // Le lien du site reste au site (627).
      expect(
        DeepLinkService.isLeadConfirmLink627(
          Uri.parse('https://www.hopetsit.com/posts/confirmer?l=$_l'),
        ),
        isTrue,
      );
    });
  });

  group('next (pure)', () {
    test('candidature avec choose : gardée, jeton k retiré', () {
      final u = _link(next: '/application/$_app?k=$_k&choose=1');
      expect(DeepLinkService.targetRoute647(u), '/application/$_app?choose=1');
      final t = DeepLinkService.applicationTarget627(
        Uri.parse('https://hopetsit.com${DeepLinkService.targetRoute647(u)}'),
      );
      expect(t?.id, _app);
      expect(t?.choose, isTrue);
    });

    test('candidature sans choose', () {
      final u = _link(next: '/application/$_app?k=$_k');
      expect(DeepLinkService.targetRoute647(u), '/application/$_app');
      expect(
        DeepLinkService.targetRoute647(_link(next: '/application/$_app')),
        '/application/$_app',
      );
      final t = DeepLinkService.applicationTarget627(
        Uri.parse('https://hopetsit.com/application/$_app'),
      );
      expect(t?.choose, isFalse);
    });

    test('/posts, /chat, /bookings : gardés', () {
      expect(DeepLinkService.targetRoute647(_link(next: '/posts')), '/posts');
      expect(
        DeepLinkService.targetRoute647(_link(next: '/posts?application=$_app')),
        '/posts?application=$_app',
      );
      expect(
        DeepLinkService.targetRoute647(_link(next: '/chat/$_app')),
        '/chat/$_app',
      );
      expect(
        DeepLinkService.targetRoute647(_link(next: '/bookings/$_app')),
        '/bookings/$_app',
      );
    });

    test('absent, externe, //…, http…, chemin inconnu → /posts', () {
      expect(DeepLinkService.targetRoute647(_link()), '/posts');
      expect(DeepLinkService.safeNext647(_link()), isNull);
      for (final n in <String>[
        '',
        'https://evil.example/posts',
        'http://evil.example',
        '//evil.example/posts',
        '/\\evil.example',
        'posts',
        'javascript:alert(1)',
        '/profile',
        '/pay/$_app',
        '/application/pas-un-id',
        '/application/$_app/extra',
        '/application',
        '/posts/confirmer?l=$_l',
        '/',
      ]) {
        expect(DeepLinkService.safeNext647(_link(next: n)), isNull, reason: n);
        expect(
          DeepLinkService.targetRoute647(_link(next: n)),
          '/posts',
          reason: n,
        );
      }
    });

    test('page du site : next valide gardé et ré-encodé, sinon retiré', () {
      final plain = DeepLinkService.confirmBrowserUri647(_l, _link());
      expect(plain.toString(), 'https://www.hopetsit.com/posts/confirmer?l=$_l');
      final withNext = DeepLinkService.confirmBrowserUri647(
        _l,
        _link(next: '/application/$_app?k=$_k&choose=1'),
      );
      expect(withNext.host, 'www.hopetsit.com');
      expect(withNext.path, '/posts/confirmer');
      expect(withNext.queryParameters, <String, String>{
        'l': _l,
        'next': '/application/$_app?k=$_k&choose=1',
      });
      expect(withNext.toString(), contains('next=%2Fapplication%2F'));
      final ext = DeepLinkService.confirmBrowserUri647(
        _l,
        _link(next: 'https://evil.example'),
      );
      expect(ext.queryParameters.containsKey('next'), isFalse);
      // Ce lien-là n'est PAS repris par l'app (pas de boucle).
      expect(DeepLinkService.adLeadId647(withNext), isNull);
      expect(DeepLinkService.isLeadConfirmLink627(withNext), isTrue);
    });
  });

  group('sans session', () {
    late _FakeAuth fake;
    final browser = <Uri>[];
    setUp(() async {
      fake = await _setUp(session: false);
      browser.clear();
      DeepLinkService.browserOverride647 = (u) async => browser.add(u);
    });
    tearDown(() => DeepLinkService.browserOverride647 = null);

    Future<void> open(WidgetTester tester, Uri link) async {
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(const Scaffold(body: SizedBox())));
      await tester.pump();
      await DeepLinkService.instance.flushPending();
      final String route = link.scheme == 'hopetsit'
          ? '/${link.host}${link.path}?${link.query}'
          : '${link.path}?${link.query}';
      unawaited(DeepLinkService.instance.openRoute(route));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    testWidgets('confirmé → GET puis POST {} , session posée, route /posts',
        (tester) async {
      _server();
      await open(tester, _link());
      expect(_calls('GET', '/ad-leads/$_l'), hasLength(1));
      final post = _calls('POST', '/ad-leads/$_l/confirm');
      expect(post, hasLength(1));
      expect(post.single.body, <String, dynamic>{});
      expect(fake.applied?['token'], 'jwt-647');
      expect((fake.applied?['user'] as Map)['role'], 'owner');
      expect(GetStorage().read<String>(StorageKeys.authToken), 'jwt-647');
      expect(DeepLinkService.lastOutcome647, 'session:/posts');
      expect(
        GetStorage().read<String>('pending_deep_route'),
        anyOf(isNull, '/posts'),
      );
      expect(browser, isEmpty);
      // L'indicateur de chargement a disparu.
      expect(find.byKey(const Key('applink647_loader')), findsNothing);
      await tester.pump(const Duration(seconds: 8));
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('confirmé + next candidature avec choose → cette candidature',
        (tester) async {
      _server();
      await open(tester, _link(next: '/application/$_app?k=$_k&choose=1'));
      expect(fake.applied?['token'], 'jwt-647');
      expect(
        DeepLinkService.lastOutcome647,
        'session:/application/$_app?choose=1',
      );
      expect(
        GetStorage().read<String>('pending_deep_route'),
        anyOf(isNull, '/application/$_app?choose=1'),
      );
      // La session vient du contact : /auth/application-link n'est pas rejoué.
      expect(_calls('POST', '/auth/application-link'), isEmpty);
      expect(browser, isEmpty);
      await tester.pump(const Duration(seconds: 8));
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('confirmé + next candidature sans choose', (tester) async {
      _server();
      await open(tester, _link(next: '/application/$_app?k=$_k'));
      expect(fake.applied?['token'], 'jwt-647');
      expect(DeepLinkService.lastOutcome647, 'session:/application/$_app');
      expect(browser, isEmpty);
      await tester.pump(const Duration(seconds: 8));
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('confirmé + next externe → /posts, rien d\'externe ouvert',
        (tester) async {
      _server();
      await open(tester, _link(next: 'https://evil.example/x'));
      expect(fake.applied?['token'], 'jwt-647');
      expect(DeepLinkService.lastOutcome647, 'session:/posts');
      expect(browser, isEmpty);
      await tester.pump(const Duration(seconds: 8));
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('hopetsit://app/demande confirmé → même parcours',
        (tester) async {
      _server();
      await open(tester, _link(custom: true));
      expect(_calls('POST', '/ad-leads/$_l/confirm'), hasLength(1));
      expect(fake.applied?['token'], 'jwt-647');
      await tester.pump(const Duration(seconds: 8));
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('non confirmé → navigateur externe, aucune session, aucun POST',
        (tester) async {
      _server(confirmed: false);
      await open(tester, _link());
      expect(_calls('GET', '/ad-leads/$_l'), hasLength(1));
      expect(_calls('POST', '/ad-leads/$_l/confirm'), isEmpty);
      expect(fake.applied, isNull);
      expect(GetStorage().read<String>(StorageKeys.authToken), isNull);
      expect(GetStorage().read<String>('pending_deep_route'), isNull);
      expect(browser, hasLength(1));
      expect(
        browser.single.toString(),
        'https://www.hopetsit.com/posts/confirmer?l=$_l',
      );
      expect(find.byKey(const Key('applink647_loader')), findsNothing);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('non confirmé + next valide → le navigateur garde next',
        (tester) async {
      _server(confirmed: false);
      await open(tester, _link(next: '/application/$_app?k=$_k&choose=1'));
      expect(browser, hasLength(1));
      expect(browser.single.queryParameters, <String, String>{
        'l': _l,
        'next': '/application/$_app?k=$_k&choose=1',
      });
      expect(fake.applied, isNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('non confirmé + next externe → navigateur sans next',
        (tester) async {
      _server(confirmed: false);
      await open(tester, _link(next: '//evil.example'));
      expect(
        browser.single.toString(),
        'https://www.hopetsit.com/posts/confirmer?l=$_l',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('contact inconnu (404) → navigateur externe, aucune session',
        (tester) async {
      _server(leadStatus: 404);
      await open(tester, _link());
      expect(_calls('POST', '/ad-leads/$_l/confirm'), isEmpty);
      expect(fake.applied, isNull);
      expect(GetStorage().read<String>(StorageKeys.authToken), isNull);
      expect(browser, hasLength(1));
      expect(browser.single.path, '/posts/confirmer');
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('erreur serveur à la lecture (500) → navigateur externe',
        (tester) async {
      _server(leadStatus: 500);
      await open(tester, _link());
      expect(fake.applied, isNull);
      expect(browser, hasLength(1));
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets(
        'confirmé mais session refusée (500) → connexion, route mémorisée, pas de navigateur',
        (tester) async {
      _server(confirmStatus: 500);
      await open(tester, _link());
      expect(_calls('POST', '/ad-leads/$_l/confirm'), hasLength(1));
      expect(fake.applied, isNull);
      expect(GetStorage().read<String>(StorageKeys.authToken), isNull);
      expect(GetStorage().read<String>('pending_deep_route'), '/posts');
      expect(DeepLinkService.lastOutcome647, 'login:/posts');
      expect(browser, isEmpty);
      expect(find.byKey(const Key('applink647_loader')), findsNothing);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('une session existe déjà', () {
    late _FakeAuth fake;
    final browser = <Uri>[];
    setUp(() async {
      fake = await _setUp(session: true); // camille@example.test
      browser.clear();
      DeepLinkService.browserOverride647 = (u) async => browser.add(u);
      navWrapperMounted.value = true; // le menu du bas est monté
      requestedTab.value = -1;
    });
    tearDown(() {
      DeepLinkService.browserOverride647 = null;
      navWrapperMounted.value = false;
      requestedTab.value = -1;
    });

    Future<void> open(WidgetTester tester, Uri link) async {
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(const Scaffold(body: SizedBox())));
      await tester.pump();
      await DeepLinkService.instance.flushPending();
      unawaited(
        DeepLinkService.instance.openRoute('${link.path}?${link.query}'),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    testWidgets('AUTRE compte connecté → session intacte, /posts pour lui',
        (tester) async {
      _server(email: 'lea@example.test');
      await open(tester, _link(next: '/chat'));
      expect(fake.applied, isNull);
      expect(
        GetStorage().read<String>(StorageKeys.authToken),
        'test-token-lotd',
      );
      expect(
        (GetStorage().read(StorageKeys.userProfile) as Map)['email'],
        'camille@example.test',
      );
      expect(DeepLinkService.lastOutcome647, 'other:/posts');
      expect(requestedTab.value, 0); // accueil « Mes annonces », pas le chat
      expect(browser, isEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('MÊME compte déjà connecté → route visée, session non reposée',
        (tester) async {
      _server(email: 'Camille@Example.test');
      await open(tester, _link(next: '/chat'));
      expect(fake.applied, isNull);
      expect(
        GetStorage().read<String>(StorageKeys.authToken),
        'test-token-lotd',
      );
      expect(DeepLinkService.lastOutcome647, 'same:/chat');
      expect(requestedTab.value, 1); // onglet Messages, menu du bas présent
      expect(browser, isEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('même compte sans next → /posts (onglet des demandes)',
        (tester) async {
      _server(email: 'camille@example.test');
      await open(tester, _link());
      expect(DeepLinkService.lastOutcome647, 'same:/posts');
      expect(requestedTab.value, 0);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('session existante + demande non publiée → navigateur',
        (tester) async {
      _server(confirmed: false);
      await open(tester, _link());
      expect(browser, hasLength(1));
      expect(fake.applied, isNull);
      expect(
        GetStorage().read<String>(StorageKeys.authToken),
        'test-token-lotd',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
