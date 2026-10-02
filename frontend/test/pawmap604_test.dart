// v604 (30/09/2026) — retours de Daniel sur le 603 :
//   1. la pilule « Direct » revient en haut à gauche (avec le drapeau Balade) ;
//   2. « Le menu ne doit JAMAIS disparaître » : la PawMap n'est plus jamais
//      poussée en page (chat, cloche, lien, alerte) — onglet du menu + demande ;
//   3. arrêts qui « ne marchent pas » (direct, balade, suivi) ;
//   5. bulles de prix duo : un rôle sans tarif n'efface pas l'autre.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/map/pawmap_person.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';
import 'package:hopetsit/widgets/stacked_navigation_wrapper.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // 607 (ZOE) — `stopBroadcasting()` écrit dans GetStorage, qui a besoin
    // d'un dossier (path_provider). Sans ce faux dossier, l'écriture échouait
    // APRÈS la fin du test quand il tournait avant un test qui le fournit
    // (ordre aléatoire) : échec « failed after it had already completed ».
    final dir = Directory.systemTemp.createTempSync('pawmap604');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
  });

  // ── 2. Le menu ne disparaît jamais ─────────────────────────────────────
  group('PawMap jamais poussée hors du menu', () {
    test('source : aucun PawMapScreen( hors des 3 menus et du constructeur', () {
      const wrappers = <String>{
        'lib/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart',
        'lib/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart',
        'lib/views/pet_walker/bottom_wrapper/walker_nav_wrapper.dart',
      };
      final offenders = <String>[];
      for (final e in Directory('lib').listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        final path = e.path.replaceAll('\\', '/');
        final lines = e.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final l = lines[i].trimLeft();
          if (l.startsWith('//')) continue;
          if (!l.contains('PawMapScreen(')) continue;
          if (wrappers.contains(path)) continue;
          if (l.startsWith('const PawMapScreen({')) continue;
          offenders.add('$path:${i + 1}');
        }
      }
      expect(offenders, isEmpty,
          reason: 'Utilise openPawMap(...) (lib/utils/map_ui_state.dart) : '
              '${offenders.join(', ')}');
    });

    test('menu pas encore monté (lien / notification à froid) : la demande attend', () {
      Get.testMode = true;
      navWrapperMounted.value = false;
      pawMapOpenOnMount = false;
      pawMapPendingIntent.value = null;
      openPawMap(lat: 48.85, lng: 2.35, focusUserId: 'u1', focusUserName: 'Rex');
      expect(pawMapOpenOnMount, isTrue);
      final i = pawMapPendingIntent.value!;
      expect(i.hasUser, isTrue);
      expect(i.hasCenter, isTrue);
      expect(i.focusUserName, 'Rex');
      pawMapPendingIntent.value = null;
      pawMapOpenOnMount = false;
    });

    test('ouverture simple : pas de demande, l\'ami seul en balade reste possible', () {
      navWrapperMounted.value = false;
      pawMapPendingIntent.value = null;
      openPawMap();
      expect(pawMapPendingIntent.value, isNull);
      expect(pawMapExplicitOpenAt, isNull);
      pawMapOpenOnMount = false;
    });

    Widget shell() => ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, __) => GetMaterialApp(
            home: StackedNavigationWrapper(screens: [
              for (final t in ['home', 'chat', 'map', 'bookings', 'profile'])
                Center(child: Text('tab-$t')),
            ]),
          ),
        );

    testWidgets('app ouverte sur une conversation → « voir la carte » : onglet PawMap, menu visible',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(shell());
      await tester.pump(const Duration(milliseconds: 500));
      expect(navWrapperMounted.value, isTrue);
      // Une conversation empilée par-dessus le menu (comme le chat).
      Get.to(() => const Scaffold(body: Text('conversation')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('conversation'), findsOneWidget);
      // « En direct · voir la carte » du chat.
      openPawMap(lat: 48.86, lng: 2.34, focusUserId: 'peer', focusUserRole: 'walker');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('conversation'), findsNothing, reason: 'la conversation est refermée');
      expect(currentMainTab.value, kPawMapTabIndex);
      expect(find.byType(PawTabBar), findsOneWidget, reason: 'le menu est là');
      // La demande attend la carte (consommée une fois par PawMapScreen).
      expect(pawMapPendingIntent.value?.focusUserId, 'peer');
      pawMapPendingIntent.value = null;
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('app fermée + notification : demande AVANT le menu → onglet PawMap au montage',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      navWrapperMounted.value = false;
      openPawMap(focusReportId: 'a' * 24);
      expect(pawMapOpenOnMount, isTrue);
      await tester.pumpWidget(shell());
      await tester.pump(const Duration(milliseconds: 500));
      expect(currentMainTab.value, kPawMapTabIndex);
      expect(pawMapOpenOnMount, isFalse);
      expect(find.byType(PawTabBar), findsOneWidget);
      expect(pawMapPendingIntent.value?.focusReportId, 'a' * 24);
      pawMapPendingIntent.value = null;
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  // ── 1. Pilule Direct revenue ──────────────────────────────────────────
  test('pilule Direct en haut à gauche + drapeau Balade, mêmes mesures', () {
    final src = File('lib/views/map/paw_map_screen.dart').readAsStringSync();
    final header = src.indexOf('_fading(_buildFloatingHeader())');
    final pill = src.indexOf('PawMapDirectPill(', header);
    expect(header, greaterThan(0));
    expect(pill, greaterThan(header));
    expect(pill - header, lessThan(2500), reason: 'juste sous l\'en-tête');
    expect(src.contains("ValueKey<String>('pawmap_walk_btn')"), isTrue);
    // Les 3 replis de hauteur réservent la pilule (≈ 42) : rien ne se superpose.
    expect('(pawMapShowsDirectPill(_role) ? 42.h : 0)'.allMatches(src).length, 3);
  });

  // ── 3. Arrêts ─────────────────────────────────────────────────────────
  group('arrêt du direct / de la balade', () {
    final t0 = DateTime(2026, 9, 30, 12);
    test('écho « actif » juste après MON arrêt : ignoré (pas de « en direct ailleurs »)', () {
      expect(
          liveActiveIsStaleAfterStop(
              localStopAt: t0, now: t0.add(const Duration(seconds: 3))),
          isTrue);
      // Session serveur commencée AVANT mon arrêt : c'est la mienne, finie.
      expect(
          liveActiveIsStaleAfterStop(
              localStopAt: t0,
              now: t0.add(const Duration(seconds: 50)),
              serverStartedAt: t0.subtract(const Duration(minutes: 5))),
          isTrue);
      // Vrai nouveau direct sur un autre téléphone, après mon arrêt.
      expect(
          liveActiveIsStaleAfterStop(
              localStopAt: t0,
              now: t0.add(const Duration(seconds: 50)),
              serverStartedAt: t0.add(const Duration(seconds: 40))),
          isFalse);
      expect(liveActiveIsStaleAfterStop(localStopAt: null, now: t0), isFalse);
    });

    test('service : arrêter → broadcasting faux, « ailleurs » faux, double appui bloqué', () {
      Get.testMode = true;
      final svc = LiveMapService();
      svc.broadcasting.value = true;
      svc.liveElsewhere.value = false;
      svc.stopBroadcasting();
      expect(svc.broadcasting.value, isFalse);
      expect(svc.liveElsewhere.value, isFalse);
      expect(svc.localStopAt, isNotNull);
      expect(svc.justStopped, isTrue, reason: '2e appui d\'un double-tap ignoré');
      expect(svc.liveStatus.value, LiveShareStatus.off);
    });

    test('suivi : arrêter de suivre ne touche pas à MON direct (sens indépendants)', () async {
      Get.testMode = true;
      final svc = LiveMapService();
      svc.broadcasting.value = true;
      svc.markFollowing('b');
      expect(svc.isFollowing('b'), isTrue);
      await svc.stopFollowing('b', byUser: true);
      expect(svc.isFollowing('b'), isFalse);
      expect(svc.followDeclined.contains('b'), isTrue,
          reason: 'la carte ne le re-suit plus toute seule');
      expect(svc.broadcasting.value, isTrue, reason: 'mon direct continue');
      svc.markFollowing('b');
      expect(svc.followDeclined.contains('b'), isFalse);
      // Arrêter mon direct laisse mon suivi en place.
      svc.stopBroadcasting();
      expect(svc.isFollowing('b'), isTrue);
    });

    test('contour rouge : mon direct lancé mais position perdue', () {
      Get.testMode = true;
      final svc = LiveMapService();
      svc.broadcasting.value = true;
      svc.liveStatus.value = LiveShareStatus.lost;
      expect(svc.myLiveIsLost, isTrue);
      svc.liveStatus.value = LiveShareStatus.active;
      expect(svc.myLiveIsLost, isFalse);
    });
  });

  // ── 5. Bulles de prix ─────────────────────────────────────────────────
  group('bulles de prix multi-rôles', () {
    String fmt(String c, double p) => '${p.round()} €';
    final world = <Map<String, dynamic>>[
      {
        'id': 's1',
        'role': 'sitter',
        'roles': [
          {'id': 's1', 'role': 'sitter', 'priceFrom': 20, 'currency': 'EUR'},
          {'id': 'w1', 'role': 'walker', 'priceFrom': 12, 'currency': 'EUR'},
          {'id': 'o1', 'role': 'owner', 'priceFrom': 0},
        ],
      },
    ];
    // Couche « proches » (serveur ≤ 603) : rôles SANS tarif.
    final nearby = <String, dynamic>{
      'id': 's1',
      '_role': 'sitter',
      'roles': [
        {'id': 's1', 'role': 'sitter'},
        {'id': 'w1', 'role': 'walker'},
        {'id': 'o1', 'role': 'owner'},
      ],
    };

    test('triple rôle vu par un propriétaire : bulle DUO gardien|promeneur', () {
      final p = pawMapWithWorldPrices(nearby, pawMapWorldIndex(world));
      final b = pawMapPersonPriceBubble(pawMapExpandRoles(p),
          shows: (r) => r == 'sitter' || r == 'walker',
          shownRoles: const {},
          format: fmt);
      expect(b, isNotNull);
      expect(b!.role, 'duo');
      expect(b.text, '20 €|12 €');
      // Sans la reprise des tarifs (bug du 603) : aucune bulle.
      expect(
          pawMapPersonPriceBubble(pawMapExpandRoles(nearby),
              shows: (r) => true, shownRoles: const {}, format: fmt),
          isNull);
    });

    test('un rôle sans tarif n\'efface pas l\'autre', () {
      final roles = [
        {'id': 's1', '_role': 'sitter', 'priceFrom': 0},
        {'id': 'w1', '_role': 'walker', 'priceFrom': 15},
      ];
      final b = pawMapPersonPriceBubble(roles,
          shows: (_) => true, shownRoles: const {}, format: fmt);
      expect(b!.role, 'walker');
      expect(b.text, '15 €');
    });

    test('un tarif présent n\'est jamais écrasé par la couche monde', () {
      final p = pawMapWithWorldPrices({
        'id': 's1',
        'roles': [
          {'id': 's1', 'role': 'sitter', 'priceFrom': 30},
          {'id': 'w1', 'role': 'walker'},
        ],
      }, pawMapWorldIndex(world));
      final roles = (p['roles'] as List).cast<Map>();
      expect(roles[0]['priceFrom'], 30);
      expect(roles[1]['priceFrom'], 12);
    });

    test('bulle duo plus large qu\'une bulle simple (deux prix dessinés)', () {
      expect(PawMapPinPainter.priceBubbleWidth('20 €|12 €'),
          greaterThan(PawMapPinPainter.priceBubbleWidth('20 €')));
    });
  });
}
