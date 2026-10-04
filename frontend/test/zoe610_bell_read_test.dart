// 610 (ZOE, 04/10/2026) — bug de Daniel sur l'iPhone 609 : « quand j'ai lu les
// notifications, elles restent dans la cloche, et sur l'icône de l'app il y a
// toujours le numéro de notifications ».
//
// Causes mesurées : (1) ouvrir la cloche ne lisait RIEN (seule une ligne touchée
// ou « Tout marquer comme lu » l'était) ; (2) une personne a 3 profils et ses
// notifications sont rangées par profil : la cloche ne montrait que le profil
// actif, le badge de l'icône recevait du serveur le compteur d'un autre profil.
//
// Ici : VRAI écran de la cloche + VRAI contrôleur, serveur simulé qui applique
// les mêmes règles que le backend (profil actif sans `scope`, 3 profils avec
// `scope=person`), canal natif `hopetsit/badge` intercepté.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/services/app_badge_service.dart';
import 'package:hopetsit/views/notifications/notifications_screen.dart';
import 'package:http/http.dart' as http;

import 'lotd_harness.dart';

/// Base simulée : 2 non lues sur le profil propriétaire (actif), 1 sur le
/// profil gardien de la MÊME personne.
late List<Map<String, dynamic>> db;
final List<int> badgeCalls = <int>[];

Map<String, dynamic> _n(String id, String role) => <String, dynamic>{
      'id': id,
      'recipientRole': role,
      'recipientId': role == 'owner' ? 'u-test' : 'u-test-sitter',
      'type': 'booking_new',
      'title': 'Nouvelle demande $id',
      'body': 'Rex · samedi',
      'data': <String, dynamic>{},
      'readAt': null,
      'createdAt': '2026-10-04T10:00:00.000Z',
    };

bool _person(http.Request r) => r.url.queryParameters['scope'] == 'person';
Iterable<Map<String, dynamic>> _visible(http.Request r) =>
    _person(r) ? db : db.where((n) => n['recipientRole'] == 'owner');
int _unread(Iterable<Map<String, dynamic>> l) => l.where((n) => n['readAt'] == null).length;

Map<String, dynamic> _server(http.Request req) {
  final p = req.url.path;
  if (!p.contains("/notifications/my")) return const <String, dynamic>{};
  final now = DateTime.now().toUtc().toIso8601String();
  if (p.endsWith('/unread-count')) {
    return <String, dynamic>{
      'unreadCount': _unread(_visible(req)),
      'totalUnreadCount': _unread(db),
      'roleUnreadCount': _unread(db.where((n) => n['recipientRole'] == 'owner')),
    };
  }
  if (p.endsWith('/read-batch')) {
    final ids = ((jsonDecode(req.body) as Map)['ids'] as List).map((e) => '$e').toSet();
    for (final n in db) {
      if (ids.contains(n['id'])) n['readAt'] ??= now;
    }
    return <String, dynamic>{'ok': true};
  }
  if (p.endsWith('/read-all')) {
    for (final n in _visible(req)) {
      n['readAt'] ??= now;
    }
    return <String, dynamic>{'ok': true};
  }
  if (p.endsWith('/read')) {
    final id = req.url.pathSegments[req.url.pathSegments.length - 2];
    for (final n in db) {
      if (n['id'] == id) n['readAt'] ??= now;
    }
    return <String, dynamic>{'ok': true};
  }
  if (p.endsWith('/notifications/my')) {
    return <String, dynamic>{
      'notifications': _visible(req).map((n) => Map<String, dynamic>.from(n)).toList(),
      'nextCursor': null,
    };
  }
  return const <String, dynamic>{};
}

void main() {
  setUp(() async {
    await lotdSetUp(role: 'owner');
    db = <Map<String, dynamic>>[_n('a1', 'owner'), _n('a2', 'owner'), _n('s1', 'sitter')];
    lotdResponder = _server;
    badgeCalls.clear();
    AppBadgeService.debugAssumeIOS = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('hopetsit/badge'), (MethodCall c) async {
      if (c.method == 'setBadge') badgeCalls.add(c.arguments as int);
      return null;
    });
  });

  tearDown(() {
    AppBadgeService.debugAssumeIOS = false;
  });

  testWidgets('ouvrir la cloche = notifications lues : compteur ET badge de l\'icône à 0',
      (tester) async {
    lotdPhone(tester);
    await tester.runAsync(() async {
      Get.put(NotificationsController(), permanent: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    final nc = Get.find<NotificationsController>();
    // Avant d'ouvrir : le badge de l'icône montre les non-lues de la PERSONNE (3).
    expect(nc.unreadCount.value, 3);
    expect(badgeCalls.isNotEmpty ? badgeCalls.last : null, 3);

    await tester.pumpWidget(lotdApp(const NotificationsScreen()));
    await tester.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    });
    await lotdSettle(tester, frames: 8);

    // Les 3 notifications (dont celle du profil gardien) sont dans la cloche…
    expect(find.text('Nouvelle demande s1'), findsOneWidget);
    // … et toutes sont lues côté serveur, sans rien toucher d'autre qu'ouvrir.
    expect(_unread(db), 0, reason: 'notifications restées non lues sur le serveur');
    expect(nc.unreadCount.value, 0);
    expect(badgeCalls.last, 0, reason: 'badge de l\'icône resté > 0');
  });

  testWidgets('« Tout marquer comme lu » porte sur les 3 profils (badge 0, pas 1)', (tester) async {
    lotdPhone(tester);
    await tester.runAsync(() async {
      Get.put(NotificationsController(), permanent: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await Get.find<NotificationsController>().markAllAsRead();
      await Get.find<NotificationsController>().refreshUnreadCount();
    });
    expect(_unread(db), 0);
    expect(Get.find<NotificationsController>().unreadCount.value, 0);
    expect(badgeCalls.last, 0);
  });
}
