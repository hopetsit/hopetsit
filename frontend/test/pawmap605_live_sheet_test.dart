// v605 (30/09/2026) — Daniel : « TOUT doit passer par le bouton Balade vert
// ou noir » ; « si l'un veut suivre l'autre ça coupe, ça bugue » ; « après
// avoir arrêté le suivi, le pop-up Suivre le direct sort, et le pin reste
// vert ». Ce fichier rejoue :
//   1. l'état du bouton Balade (noir / vert / violet / vert + point violet) ;
//   2. le suivi mutuel « A suit B, puis B se met à suivre A » : aucun sens ne
//      coupe l'autre (service + feuille unique « En direct ») ;
//   3. la feuille : « Arrêter » arrête MA balade seulement, « Arrêter de
//      suivre » le suivi seulement ;
//   4. une personne lâchée n'est plus reproposée tant qu'elle n'a pas
//      relancé une NOUVELLE session ;
//   5. « le pin reste vert » : un direct que le serveur ne liste plus
//      s'éteint au rafraîchissement (au 604 : vert jusqu'à 10 min).
// Le test 5 n'utilise que l'API du 604 : il se rejoue sur l'ancien service.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/chat_shared/pawfollow_widgets.dart';
import 'package:hopetsit/views/map/widgets/pawmap_live_sheet.dart';

/// Faux client : `/friends/live-positions` renvoie [positions] ; les POST
/// (follow-stop, follow-presence, go-offline) sont journalisés.
class _FakeApi implements ApiClient {
  List<Map<String, dynamic>> positions = <Map<String, dynamic>>[];
  final List<String> posts = <String>[];

  @override
  Future<dynamic> get(String endpoint,
      {Map<String, dynamic>? queryParameters,
      Map<String, String>? headers,
      bool requiresAuth = false}) async {
    if (endpoint.startsWith('/friends/live-positions')) {
      return <String, dynamic>{'positions': positions};
    }
    if (endpoint.startsWith('/friends/live-state')) {
      return <String, dynamic>{'active': false, 'followers': 0};
    }
    return <String, dynamic>{};
  }

  @override
  Future<dynamic> post(String endpoint,
      {Map<String, dynamic>? queryParameters,
      Object? body,
      Map<String, String>? headers,
      bool requiresAuth = false}) async {
    posts.add(endpoint);
    return <String, dynamic>{'ok': true};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FriendPosition _pos(String id, {String name = 'Kathy', DateTime? seen, bool sharing = true}) =>
    FriendPosition(
      userId: id,
      role: 'walker',
      latitude: -35,
      longitude: -30,
      at: seen ?? DateTime.now(),
      lastSeenAt: seen ?? DateTime.now(),
      sharing: sharing,
      name: name,
    );

Widget _app(Widget child) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // GetStorage écrit sur disque : dossier temporaire.
    final dir = Directory.systemTemp.createTempSync('pm605');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
  });
  late _FakeApi api;
  setUp(() {
    Get.testMode = true;
    Get.reset();
    api = _FakeApi();
    Get.put<ApiClient>(api);
  });

  test('1. état du bouton Balade', () {
    expect(pawLiveButtonState(meLive: false, following: false), PawLiveButtonState.off);
    expect(pawLiveButtonState(meLive: true, following: false), PawLiveButtonState.sharing);
    expect(pawLiveButtonState(meLive: false, following: true), PawLiveButtonState.following);
    expect(pawLiveButtonState(meLive: true, following: true), PawLiveButtonState.both);
    expect(pawLiveJewelPalette(PawLiveButtonState.following), kJewelWalkFollow);
  });

  test('2. A suit B, puis B se met à suivre A : aucun sens ne coupe l\'autre', () async {
    final a = Get.put(LiveMapService()); // onInit : meLive suit broadcasting
    // A suit B (la carte de A est collée sur B).
    a.friendPositions['b'] = _pos('b');
    a.markFollowing('b', name: 'Kathy');
    expect(a.isFollowing('b'), isTrue);
    // B se met à suivre A : A reçoit 1 suiveur puis démarre son direct
    // (acceptation dans le chat → LiveShareStarter → startBroadcasting).
    a.myFollowers.value = 1;
    a.broadcasting.value = true;
    a.sessionStartedAt.value = DateTime.now();
    expect(a.isFollowing('b'), isTrue, reason: 'mon suivi de B continue');
    expect(pawLiveButtonState(meLive: a.meLive.value, following: a.followingUserId.value != null),
        PawLiveButtonState.both);
    // A arrête SON direct : il suit toujours B.
    a.stopBroadcasting();
    expect(a.broadcasting.value, isFalse);
    expect(a.isFollowing('b'), isTrue);
    // A relance, puis arrête de suivre B : son direct continue.
    a.broadcasting.value = true;
    await a.stopFollowing('b', byUser: true);
    expect(a.isFollowing('b'), isFalse);
    expect(a.broadcasting.value, isTrue);
    expect(api.posts, contains('/friends/follow-stop'));
  });

  testWidgets('3. feuille unique : lignes et arrêts indépendants', (t) async {
    final live = LiveMapService();
    live.friendPositions['b'] = _pos('b');
    live.friendPositions['c'] = _pos('c', name: 'John');
    live.markFollowing('b', name: 'Kathy');
    live.broadcasting.value = true;
    live.sessionStartedAt.value = DateTime.now().subtract(const Duration(minutes: 12));
    live.myFollowers.value = 2;
    live.followerNames.assignAll(<String>['Daniel', 'John']);
    await t.pumpWidget(_app(PawLiveSheet(live: live, onFollowFriend: (_) {})));
    await t.pump();
    expect(find.text('Ma balade'), findsOneWidget);
    expect(find.textContaining('12 min'), findsOneWidget);
    expect(find.text('Tu suis Kathy'), findsOneWidget);
    expect(find.text('Ils te suivent : Daniel, John'), findsOneWidget);
    expect(find.text('John est en direct'), findsOneWidget,
        reason: 'le contour vert du menu s\'explique dans la feuille');

    await t.tap(find.byKey(const ValueKey<String>('live_sheet_stop_follow')));
    await t.pump(const Duration(milliseconds: 100));
    expect(live.isFollowing('b'), isFalse);
    expect(live.broadcasting.value, isTrue, reason: 'ma balade continue');
    expect(find.text('Tu suis Kathy'), findsNothing);

    await t.tap(find.byKey(const ValueKey<String>('live_sheet_stop_walk')));
    await t.pump(const Duration(milliseconds: 100));
    expect(live.broadcasting.value, isFalse);
    expect(find.text('Ma balade'), findsNothing);
    await t.pump(const Duration(seconds: 6)); // relectures différées
  });

  testWidgets('3b. rien en cours : « Démarrer ma balade »', (t) async {
    final live = LiveMapService();
    var started = false;
    await t.pumpWidget(_app(PawLiveSheet(
        live: live,
        onStartWalk: () async => started = true)));
    await t.pump();
    expect(find.byKey(const ValueKey<String>('live_sheet_nothing')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey<String>('live_sheet_start_walk')));
    await t.pump();
    expect(started, isTrue);
  });

  test('4. personne lâchée : pas reproposée avant une NOUVELLE session', () async {
    final live = LiveMapService();
    live.friendPositions['b'] = _pos('b');
    live.markFollowing('b');
    await live.stopFollowing('b', byUser: true);
    expect(live.isFollowDeclined(live.friendPositions['b']!), isTrue);
    // Même session : d'autres positions arrivent → toujours lâchée.
    live.ingestLivePosition(_pos('b'));
    expect(live.isFollowDeclined(live.friendPositions['b']!), isTrue);
    // La session se termine (le serveur ne la dit plus en partage)…
    api.positions = <Map<String, dynamic>>[
      {
        'userId': 'b', 'role': 'walker', 'lat': -35, 'lng': -30,
        'at': DateTime.now().toIso8601String(), 'sharing': false, 'stale': true,
      },
    ];
    await live.refreshFriendPositions();
    expect(live.friendPositions['b']!.liveState, FriendLiveState.seen);
    expect(live.isFollowDeclined(live.friendPositions['b']!), isTrue);
    // … puis un NOUVEAU direct : proposable à nouveau.
    live.ingestLivePosition(_pos('b'));
    expect(live.isFollowDeclined(live.friendPositions['b']!), isFalse);
  });

  test('5. « le pin reste vert » : direct que le serveur ne liste plus → éteint', () async {
    final live = LiveMapService();
    live.friendPositions['b'] =
        _pos('b', seen: DateTime.now().subtract(const Duration(seconds: 60)));
    live.recountLiveFriends();
    expect(live.liveFriendsCount.value, 1);
    api.positions = <Map<String, dynamic>>[]; // plus rien pour moi
    await live.refreshFriendPositions();
    live.recountLiveFriends();
    expect(live.liveFriendsCount.value, 0,
        reason: 'contour vert éteint dès le rafraîchissement (604 : 10 min)');
  });

  test('5b. direct tout frais (< 30 s) absent de la liste : gardé (course)', () async {
    final live = LiveMapService();
    live.friendPositions['b'] = _pos('b');
    api.positions = <Map<String, dynamic>>[];
    await live.refreshFriendPositions();
    live.recountLiveFriends();
    expect(live.liveFriendsCount.value, 1);
  });

  testWidgets('6. chat : « Arrêter » ouvre la MÊME feuille (BRANCHEMENT 605)', (t) async {
    final live = Get.put(LiveMapService());
    live.friendPositions['b'] = _pos('b');
    live.markFollowing('b', name: 'Kathy');
    live.broadcasting.value = true;
    await t.pumpWidget(_app(Builder(
      builder: (ctx) => TextButton(
        onPressed: () => openLiveSheetFromChat(ctx,
            conversationId: 'c', messageId: 'm', iShare: true),
        child: const Text('stop'),
      ),
    )));
    await t.tap(find.text('stop'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey<String>('pawmap_live_sheet')), findsOneWidget);
    expect(find.text('Ma balade'), findsOneWidget);
    expect(find.text('Tu suis Kathy'), findsOneWidget);
    live.stopBroadcasting();
    await t.pump(const Duration(seconds: 6));
    Get.delete<LiveMapService>(force: true);
    await t.pump(const Duration(seconds: 6));
  });
}
