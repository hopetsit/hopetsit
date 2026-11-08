// 636 (08/11/2026) — « le proprio doit pouvoir payer du site OU de l'app » :
//  - lien signé `k=` des e-mails « candidats » reçu dans l'app SANS session
//    (compte créé par le site, sans mot de passe) → POST /auth/application-link
//    → session appliquée → candidature rejouée avec `choose` ;
//  - lien invalide (401 LINK_INVALID) → écran de connexion, route mémorisée ;
//  - encart « Pas de mot de passe ? » → POST /auth/owner-link.
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/auth/owner_link636.dart';

import 'lotd_harness.dart';

const String _id = '6730a1b2c3d4e5f6a7b8c9d0';
const String _k = 'eyJ2IjoxfQ.c2lnbmF0dXJl_-Abc';

class _FakeAuth extends AuthController {
  _FakeAuth(super.authRepository, super.storage, super.userRepository);
  Map<String, dynamic>? applied;
  @override
  Future<bool> applyExchangedSession(Map<String, dynamic> response) async {
    applied = response;
    // Valeur posée en mémoire tout de suite ; l'écriture disque n'est pas
    // attendue (sous l'horloge factice des tests de widgets, elle ne revient pas).
    unawaited(GetStorage().write(StorageKeys.authToken, response['token']));
    return true;
  }
}

Future<_FakeAuth> _setUpNoSession() async {
  await lotdSetUp();
  final storage = GetStorage();
  await storage.remove(StorageKeys.authToken); // aucune session
  await storage.remove('pending_deep_route');
  await Get.delete<AuthController>(force: true);
  final fake = _FakeAuth(
    Get.find<AuthRepository>(),
    storage,
    Get.find<UserRepository>(),
  );
  Get.put<AuthController>(fake, permanent: true);
  return fake;
}

void main() {
  group('règles pures', () {
    test(
      'applicationLinkToken636 : jeton lu seulement sur un lien candidature',
      () {
        expect(
          DeepLinkService.applicationLinkToken636(
            Uri.parse('https://hopetsit.com/application/$_id?choose=1&k=$_k'),
          ),
          _k,
        );
        expect(
          DeepLinkService.applicationLinkToken636(
            Uri.parse('hopetsit://application/$_id?k=$_k'),
          ),
          _k,
        );
        expect(
          DeepLinkService.applicationLinkToken636(
            Uri.parse('https://hopetsit.com/application/$_id?choose=1'),
          ),
          isNull,
        );
        expect(
          DeepLinkService.applicationLinkToken636(
            Uri.parse('https://hopetsit.com/posts?k=$_k'),
          ),
          isNull,
        );
        expect(
          DeepLinkService.applicationLinkToken636(
            Uri.parse(
              'https://hopetsit.com/application/$_id?k=pas%20un%20jeton',
            ),
          ),
          isNull,
        );
      },
    );

    test('withoutLinkToken636 : retire k, garde choose', () {
      final u = DeepLinkService.withoutLinkToken636(
        Uri.parse('https://hopetsit.com/application/$_id?choose=1&k=$_k'),
      );
      expect(u.queryParameters.containsKey('k'), isFalse);
      expect(u.queryParameters['choose'], '1');
      expect(u.path, '/application/$_id');
      final plain = Uri.parse('https://hopetsit.com/application/$_id');
      expect(DeepLinkService.withoutLinkToken636(plain), plain);
    });

    test('ownerLinkNext636 : seulement /application/… et /posts…', () {
      expect(
        DeepLinkService.ownerLinkNext636('/application/$_id?choose=1'),
        '/application/$_id?choose=1',
      );
      expect(
        DeepLinkService.ownerLinkNext636('/posts?application=$_id'),
        '/posts?application=$_id',
      );
      expect(DeepLinkService.ownerLinkNext636('/chat/abc'), '/posts');
      expect(DeepLinkService.ownerLinkNext636(null), '/posts');
    });

    test('ownerLinkMessageKey636 / e-mail', () {
      expect(ownerLinkMessageKey636(null), 'ownerlink636_sent');
      expect(ownerLinkMessageKey636(200), 'ownerlink636_sent');
      expect(ownerLinkMessageKey636(400), 'ownerlink636_email_invalid');
      expect(ownerLinkMessageKey636(429), 'ownerlink636_too_many');
      expect(ownerLinkMessageKey636(403), 'common_error_message');
      expect(ownerLinkEmailLooksValid636(' Léa@Exemple.fr '), isTrue);
      expect(ownerLinkEmailLooksValid636('pas-un-mail'), isFalse);
    });
  });

  // L'installation (GetStorage.init, Firebase simulé, path_provider) fait de
  // vraies entrées-sorties : elle doit tourner dans `setUp` (temps réel), pas
  // dans le corps d'un testWidgets (horloge factice → ne revient jamais).
  group('widgets', () {
    late _FakeAuth fake;
    setUp(() async {
      fake = await _setUpNoSession();
    });

    testWidgets(
      'lien k= valide → POST /auth/application-link, session, route avec choose',
      (tester) async {
        lotdResponder = (req) {
          if (req.url.path.endsWith('/auth/application-link')) {
            return <String, dynamic>{
              'token': 'jwt-636',
              'role': 'owner',
              'user': <String, dynamic>{
                'id': 'o1',
                'email': 'lea@example.test',
              },
              'applicationId': _id,
            };
          }
          return <String, dynamic>{};
        };
        lotdPhone(tester);
        await tester.pumpWidget(lotdApp(const Scaffold(body: SizedBox())));
        await tester.pump();
        // Comme MyApp après la première image : navigateur prêt (sinon le
        // lien reste en attente dans _safeHandle et rien ne se passe).
        await DeepLinkService.instance.flushPending();

        // Horloge factice : openRoute attend le menu principal (Future.delayed)
        // → on ne l'attend pas, on avance le temps.
        unawaited(
          DeepLinkService.instance.openRoute(
            '/application/$_id?choose=1&k=$_k',
          ),
        );
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(seconds: 1));
        }

        final call = lotdRequests
            .where(
              (r) =>
                  r.method == 'POST' &&
                  r.path.endsWith('/auth/application-link'),
            )
            .toList();
        expect(call, hasLength(1));
        expect(call.single.body, {'token': _k, 'applicationId': _id});
        expect(fake.applied?['token'], 'jwt-636');
        expect(GetStorage().read<String>(StorageKeys.authToken), 'jwt-636');
        // La route mémorisée (sans k, avec choose) attend le rejeu après la session.
        expect(
          GetStorage().read<String>('pending_deep_route'),
          anyOf(isNull, '/application/$_id?choose=1'),
        );
        await tester.pump(const Duration(seconds: 3));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets(
      'lien k= invalide (401 LINK_INVALID) → pas de session, route mémorisée',
      (tester) async {
        lotdResponder = (req) {
          if (req.url.path.endsWith('/auth/application-link')) {
            return <String, dynamic>{
              '__status': 401,
              'error': 'Invalid link.',
              'code': 'LINK_INVALID',
            };
          }
          return <String, dynamic>{};
        };
        lotdPhone(tester);
        await tester.pumpWidget(lotdApp(const Scaffold(body: SizedBox())));
        await tester.pump();
        // Comme MyApp après la première image : navigateur prêt (sinon le
        // lien reste en attente dans _safeHandle et rien ne se passe).
        await DeepLinkService.instance.flushPending();

        // Horloge factice : openRoute attend le menu principal (Future.delayed)
        // → on ne l'attend pas, on avance le temps.
        unawaited(
          DeepLinkService.instance.openRoute(
            '/application/$_id?choose=1&k=$_k',
          ),
        );
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(seconds: 1));
        }

        expect(fake.applied, isNull);
        expect(GetStorage().read<String>(StorageKeys.authToken), isNull);
        expect(
          GetStorage().read<String>('pending_deep_route'),
          '/application/$_id?choose=1',
        );
        await tester.pump(const Duration(seconds: 3));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets(
      'encart « Pas de mot de passe ? » → POST /auth/owner-link { email, next, lang }',
      (tester) async {
        // Posée en mémoire (écriture disque non attendue : horloge factice).
        unawaited(
          GetStorage().write(
            'pending_deep_route',
            '/application/$_id?choose=1',
          ),
        );
        lotdPhone(
          tester,
        ); // fenêtre téléphone : le bouton de la feuille doit être à l'écran
        await tester.pumpWidget(
          lotdApp(
            Scaffold(
              body: Center(
                child: OwnerLinkCard636(emailOf: () => 'Lea@Example.test'),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.text('Pas de mot de passe ? Reçois ton lien par e-mail'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('ownerlink636_card')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.byKey(const Key('ownerlink636_send')), findsOneWidget);
        await tester.tap(find.byKey(const Key('ownerlink636_send')));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        final call = lotdRequests
            .where(
              (r) => r.method == 'POST' && r.path.endsWith('/auth/owner-link'),
            )
            .toList();
        expect(call, hasLength(1));
        expect(call.single.body, {
          'email': 'lea@example.test',
          'next': '/application/$_id?choose=1',
          'lang': 'fr',
        });
        await tester.pump(const Duration(seconds: 4));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
