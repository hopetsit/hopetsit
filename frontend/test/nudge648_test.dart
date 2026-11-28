// 648 (PAM, 28/11/2026) — notification « Besoin de faire garder ton animal ?
// Publie ta demande… » (type `owner_publish_nudge_2711`, serveur du 27/11,
// envoyée au profil PROPRIÉTAIRE, `data` vide, `route` serveur `/posts`).
//
// Refus de ZOE du 27/11 : dans la cloche, l'appui rouvrait la liste où l'on
// était déjà (`/notifications`). Ici, les deux entrées — notification système
// (push) et cloche — sont rejouées avec le VRAI routeur, le VRAI écran de la
// cloche et le VRAI formulaire de publication :
//  a. propriétaire → accueil (1er onglet) + formulaire de publication ;
//  b. app ouverte sur le profil gardien / promeneur de la même personne →
//     la session n'est jamais changée ; message « concerne ton profil
//     propriétaire » (comportement existant des notifications propriétaire) ;
//  c. sans session → route mémorisée, rejouée après la connexion ;
//  d. jamais la simple liste, jamais d'écran d'erreur.
// Serveur simulé uniquement : aucun appel réseau, aucune donnée réelle.
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/notifications/notifications_screen.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:http/http.dart' as http;

import 'lotd_harness.dart';

const String kType = 'owner_publish_nudge_2711';
const String kTitle = 'Besoin de faire garder ton animal ?';
const String kOtherProfile = 'Cette notification concerne ton profil propriétaire.';

/// Charge utile du push telle que le serveur l'envoie (27/11).
Map<String, dynamic> _pushData() => <String, dynamic>{
      'type': kType,
      'route': '/posts',
      'recipientRole': 'owner',
    };

/// Serveur simulé : la cloche contient LA notification, tout le reste est vide.
Map<String, dynamic> _server(http.Request req) {
  final String p = req.url.path;
  if (p.endsWith('/notifications/my/unread-count')) {
    return <String, dynamic>{'unreadCount': 1, 'totalUnreadCount': 1, 'roleUnreadCount': 1};
  }
  if (p.endsWith('/notifications/my')) {
    return <String, dynamic>{
      'notifications': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'n648',
          'recipientRole': 'owner',
          'recipientId': 'u-test',
          'type': kType,
          'title': kTitle,
          'body': 'Publie ta demande : les gardiens près de chez toi te répondent.',
          'data': <String, dynamic>{},
          'readAt': null,
          'createdAt': DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String(),
        },
      ],
      'nextCursor': null,
    };
  }
  if (p.endsWith('/sitters/nearby')) return <String, dynamic>{'sitters': <Map<String, dynamic>>[]};
  if (p.endsWith('/walkers/nearby')) return <String, dynamic>{'walkers': <Map<String, dynamic>>[]};
  return <String, dynamic>{
    'ok': true,
    'pets': <Map<String, dynamic>>[],
    'posts': <Map<String, dynamic>>[],
    'notifications': <Map<String, dynamic>>[],
    'bookings': <Map<String, dynamic>>[],
    'applications': <Map<String, dynamic>>[],
    'conversations': <Map<String, dynamic>>[],
    'count': 0,
  };
}

Future<void> _setUp(String role) async {
  await lotdSetUp(role: role);
  lotdResponder = _server;
  await GetStorage().remove('pending_deep_route');
  // L'anti-doublon de la bannière (même message deux fois de suite) survit
  // d'un test à l'autre : remis à zéro.
  CustomSnackbar.debugResetBannerDedupe();
  DeepLinkService.lastOutcome648 = null;
  DeepLinkService.publishOpenerOverride648 = null;
  navWrapperMounted.value = true; // le menu du bas est monté
  requestedTab.value = -1;
}

String _role() => (Get.find<AuthController>().userRole.value ?? '').toLowerCase();

Future<void> _pumpFor(WidgetTester tester, {int seconds = 9}) async {
  for (int i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// App ouverte sur un écran quelconque, navigation prête.
Future<void> _app(WidgetTester tester, {Widget? home}) async {
  lotdPhone(tester);
  await tester.pumpWidget(lotdApp(home ?? const Scaffold(body: SizedBox())));
  await tester.pump();
  await DeepLinkService.instance.flushPending();
}

/// Appui sur le push : exactement le code de `push_notification_service`
/// (`resolvePushRoute` puis `openRoute` avec le profil destinataire).
Future<void> _tapPush(WidgetTester tester, Map<String, dynamic> data, {int seconds = 9}) async {
  final String route = DeepLinkService.resolvePushRoute(
    (data['type'] ?? '').toString(),
    data,
    role: (data['recipientRole'] ?? '').toString(),
  );
  unawaited(DeepLinkService.instance
      .openRoute(route, recipientRole: (data['recipientRole'] ?? '').toString()));
  await _pumpFor(tester, seconds: seconds);
}

/// La cloche : vrai écran, vrai contrôleur, la notification chargée.
Future<void> _openBell(WidgetTester tester) async {
  lotdPhone(tester);
  await tester.runAsync(() async {
    Get.put(NotificationsController(), permanent: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpWidget(lotdApp(const NotificationsScreen()));
  await tester.pump();
  await DeepLinkService.instance.flushPending();
  await tester.runAsync(() async {
    for (int i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  });
  await lotdSettle(tester, frames: 8);
  expect(find.text(kTitle), findsOneWidget, reason: 'notification absente de la cloche');
}

Future<void> _tapBell(WidgetTester tester, {int seconds = 9}) async {
  await tester.tap(find.text(kTitle));
  await tester.runAsync(() async {
    for (int i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  });
  await _pumpFor(tester, seconds: seconds);
}

void main() {
  tearDown(() {
    DeepLinkService.publishOpenerOverride648 = null;
    DeepLinkService.lastOutcome648 = null;
    navWrapperMounted.value = false;
    requestedTab.value = -1;
  });

  group('route de la notification (push et cloche, même routeur)', () {
    test('le type mène au formulaire de publication, jamais à la liste', () {
      for (final String role in <String>['owner', '', 'sitter', 'walker']) {
        final String r = DeepLinkService.routeForNotification(kType, <String, dynamic>{}, role: role);
        expect(r, '/posts/new', reason: 'rôle « $role »');
        expect(r, isNot('/notifications'));
      }
      expect(DeepLinkService.routeForNotification(kType, null), '/posts/new');
      expect(
        DeepLinkService.routeForNotification(kType.toUpperCase(), <String, dynamic>{}, role: 'owner'),
        '/posts/new',
      );
      expect(DeepLinkService.kPublishRoute648, '/posts/new');
    });

    test('push : la route de l\'app passe avant le `/posts` du serveur', () {
      expect(DeepLinkService.resolvePushRoute(kType, _pushData(), role: 'owner'), '/posts/new');
      expect(DeepLinkService.resolvePushRoute(kType, <String, dynamic>{}), '/posts/new');
    });

    test('les notifications voisines ne bougent pas', () {
      const String id = '6a0000000000000000000001';
      expect(DeepLinkService.routeForNotification('post_published_617', {'postId': id}, role: 'owner'), '/post/$id');
      expect(DeepLinkService.routeForNotification('application_new', {'applicationId': id}, role: 'owner'),
          '/application/$id');
      expect(DeepLinkService.routeForNotification('type_futur', <String, dynamic>{}, role: 'owner'), '/notifications');
      expect(DeepLinkService.resolvePushRoute('type_futur', {'route': '/posts'}), '/posts');
    });
  });

  group('profil propriétaire', () {
    setUp(() => _setUp('owner'));

    testWidgets('PUSH → accueil (1er onglet) + VRAI formulaire de publication', (tester) async {
      await _app(tester);
      await _tapPush(tester, _pushData());
      expect(DeepLinkService.lastOutcome648, 'form');
      expect(requestedTab.value, 0);
      expect(find.byType(PublishReservationRequestScreen), findsOneWidget);
      expect(find.byType(NotificationsScreen), findsNothing);
      expect(tester.takeException(), isNull);
      // Retour arrière : on retombe sur l'écran du dessous, pas sur du vide.
      Get.back<void>();
      await _pumpFor(tester, seconds: 2);
      expect(find.byType(PublishReservationRequestScreen), findsNothing);
      expect(find.byType(Scaffold), findsWidgets);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('CLOCHE → l\'appui quitte la liste et ouvre le VRAI formulaire', (tester) async {
      await _openBell(tester);
      await _tapBell(tester);
      expect(DeepLinkService.lastOutcome648, 'form');
      expect(requestedTab.value, 0);
      expect(find.byType(PublishReservationRequestScreen), findsOneWidget);
      expect(find.text(kOtherProfile), findsNothing);
      expect(tester.takeException(), isNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('push d\'un ancien serveur sans profil destinataire → formulaire aussi', (tester) async {
      await _app(tester);
      await _tapPush(tester, <String, dynamic>{'type': kType, 'route': '/posts'});
      expect(DeepLinkService.lastOutcome648, 'form');
      expect(find.byType(PublishReservationRequestScreen), findsOneWidget);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('formulaire déjà ouvert (demande en cours de saisie) → on n\'y touche pas', (tester) async {
      await _app(tester);
      await _tapPush(tester, _pushData());
      expect(find.byType(PublishReservationRequestScreen), findsOneWidget);
      requestedTab.value = -1;
      await _tapPush(tester, _pushData());
      expect(DeepLinkService.lastOutcome648, 'form-already');
      expect(requestedTab.value, -1, reason: 'le formulaire a été quitté');
      expect(find.byType(PublishReservationRequestScreen), findsOneWidget);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('formulaire qui échoue à s\'ouvrir → accueil propriétaire, pas d\'erreur', (tester) async {
      DeepLinkService.publishOpenerOverride648 = () => throw StateError('test 648');
      await _app(tester);
      await _tapPush(tester, _pushData());
      expect(DeepLinkService.lastOutcome648, 'home-fallback');
      expect(requestedTab.value, 0);
      expect(tester.takeException(), isNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('demande publiée depuis ce formulaire → le retour ne casse rien', (tester) async {
      DeepLinkService.publishOpenerOverride648 =
          () => Future<dynamic>.value(PublishReservationRequestController.kPublishedResult600);
      await _app(tester);
      await _tapPush(tester, _pushData());
      expect(DeepLinkService.lastOutcome648, 'form');
      expect(requestedTab.value, 0);
      expect(tester.takeException(), isNull);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  for (final String other in <String>['sitter', 'walker']) {
    group('app ouverte sur le profil $other de la même personne', () {
      setUp(() => _setUp(other));

      testWidgets('PUSH → liste des notifications + message, session inchangée', (tester) async {
        await _app(tester);
        final String token = GetStorage().read<String>(StorageKeys.authToken) ?? '';
        await _tapPush(tester, _pushData(), seconds: 1); // le message s'efface vite
        expect(find.byType(NotificationsScreen), findsOneWidget);
        expect(find.text(kOtherProfile), findsOneWidget);
        expect(find.byType(PublishReservationRequestScreen), findsNothing);
        expect(DeepLinkService.lastOutcome648, isNull, reason: 'la route de publication a été ouverte');
        expect(requestedTab.value, -1);
        expect(_role(), other, reason: 'le profil actif a changé');
        expect(GetStorage().read<String>(StorageKeys.authToken), token);
        expect(tester.takeException(), isNull);
        await _pumpFor(tester, seconds: 6); // le message se referme
      }, timeout: const Timeout(Duration(minutes: 2)));

      testWidgets('CLOCHE → message « profil propriétaire », on reste dans la liste', (tester) async {
        await _openBell(tester);
        await _tapBell(tester, seconds: 1); // le message s'efface vite
        expect(find.text(kOtherProfile), findsOneWidget);
        expect(find.byType(NotificationsScreen), findsOneWidget);
        expect(find.byType(PublishReservationRequestScreen), findsNothing);
        expect(DeepLinkService.lastOutcome648, isNull);
        expect(_role(), other);
        expect(tester.takeException(), isNull);
        await _pumpFor(tester, seconds: 6);
      }, timeout: const Timeout(Duration(minutes: 2)));

      testWidgets('route de publication sans profil destinataire → son accueil, pas de formulaire',
          (tester) async {
        await _app(tester);
        unawaited(DeepLinkService.instance.openRoute('/posts/new'));
        await _pumpFor(tester);
        expect(DeepLinkService.lastOutcome648, 'home');
        expect(requestedTab.value, 0);
        expect(find.byType(PublishReservationRequestScreen), findsNothing);
        expect(_role(), other);
      }, timeout: const Timeout(Duration(minutes: 2)));
    });
  }

  group('sans session (déconnecté)', () {
    setUp(() async {
      await _setUp('owner');
      await GetStorage().remove(StorageKeys.authToken);
    });

    testWidgets('PUSH → rien d\'ouvert, route mémorisée ; rejouée après la connexion', (tester) async {
      await _app(tester);
      await _tapPush(tester, _pushData());
      expect(find.byType(PublishReservationRequestScreen), findsNothing);
      expect(DeepLinkService.lastOutcome648, isNull);
      expect(GetStorage().read<String>('pending_deep_route'), '/posts/new');
      // Connexion faite : le jeton revient, la route est rejouée.
      await GetStorage().write(StorageKeys.authToken, 'test-token-lotd');
      unawaited(DeepLinkService.replayPendingRoute());
      await _pumpFor(tester);
      expect(GetStorage().read<String>('pending_deep_route'), isNull);
      expect(DeepLinkService.lastOutcome648, 'form');
      expect(find.byType(PublishReservationRequestScreen), findsOneWidget);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
