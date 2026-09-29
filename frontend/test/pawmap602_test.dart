// v602 (PAM, 29/09/2026) — retours de Daniel sur le 601 :
//   1. « Voir signaux » (le drapeau noir au point rouge) passe de la barre de
//      GAUCHE à la barre de DROITE, juste au-dessus du bouton Balade ;
//      migration propre des réglages enregistrés (aucun bouton fantôme).
//   2. Accepter un suivi en direct depuis le chat démarre MON direct (même
//      chemin que le bouton Balade) ; la carte du chat montre l'état réel.
//   3. Le point vert du menu est posé SUR le bord de la tête de l'épingle.
//   4. Pastilles de compteur (cloche, Chat) : posées sur le coin, « 99+ ».
//   5. Les notifications de suivi en direct ouvrent la conversation.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/pawmap602_i18n.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/services/live_share_starter.dart';
import 'package:hopetsit/views/map/widgets/pawmap_rail.dart';
import 'package:hopetsit/widgets/paw_count_badge.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';
import 'package:hopetsit/widgets/pawfollow_request_card.dart';

const List<String> kLangs = <String>[
  'fr', 'en', 'es', 'de', 'it', 'pt', 'pl', 'ja', 'ko',
];
const List<String> _labels = ['Accueil', 'Chat', 'PawMap', 'Réservations', 'Profil'];

Widget _app(Widget child, {Brightness b = Brightness.light, String lang = 'fr'}) =>
    ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: Locale(lang),
        theme: ThemeData(brightness: b),
        home: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ── 1. « Voir signaux » : gauche → droite ─────────────────────────────
  group('Voir signaux passe à droite, au-dessus de Balade', () {
    test('plus à gauche ; à droite juste avant Balade par défaut', () {
      expect(pawRailSpecOf('feed'), isNull);
      expect(kPawRailDefaultOrder.contains('feed'), isFalse);
      expect(pawCapsuleSlotOf('feed'), same(kPawFeedSpec));
      final d = kPawCapsuleDefaultOrder;
      expect(d.indexOf('feed') + 1, d.indexOf('balade'));
      // Ancien réglage de gauche avec « feed » : plus de bouton fantôme.
      expect(normalizeRailOrder(['feed', 'chat', 'report']), ['chat', 'report']);
    });

    test('jamais réglé → feed au-dessus de Balade', () {
      final m = migrateCapsuleFeed602(capsule: null, rail: null);
      expect(m.order, ['satellite', 'everyone', 'feed', 'balade', 'eye']);
      expect(m.changed, isTrue);
    });

    test('réglage du 601 (sans feed) → feed inséré juste avant Balade', () {
      final m = migrateCapsuleFeed602(
          capsule: ['eye', 'balade', 'satellite'], rail: ['feed', 'chat']);
      expect(m.order, ['eye', 'feed', 'balade', 'satellite']);
      expect(m.changed, isTrue);
    });

    test('Balade masquée au 601 → feed en fin de barre', () {
      final m = migrateCapsuleFeed602(capsule: ['satellite'], rail: null);
      expect(m.order, ['satellite', 'feed']);
    });

    test('feed masqué à GAUCHE → reste masqué à droite (marqueur posé)', () {
      final m = migrateCapsuleFeed602(capsule: ['balade'], rail: ['chat', 'report']);
      expect(m.order, ['balade']);
      expect(m.changed, isTrue);
      expect(capsuleOrderToSave(m.order), ['balade', kCapsuleFeedHiddenMarker]);
    });

    test('réglage 602 respecté, jamais re-migré', () {
      final a = migrateCapsuleFeed602(
          capsule: ['feed', 'eye', 'balade'], rail: ['chat']);
      expect(a.order, ['feed', 'eye', 'balade']);
      expect(a.changed, isFalse);
      final b = migrateCapsuleFeed602(
          capsule: ['eye', kCapsuleFeedHiddenMarker], rail: null);
      expect(b.order, ['eye']);
      expect(b.changed, isFalse);
      expect(capsuleOrderToSave(['feed', 'eye']), ['feed', 'eye']);
    });

    test('le marqueur passe la règle du serveur (/^[a-z_]{2,32}\$/)', () {
      expect(RegExp(r'^[a-z_]{2,32}$').hasMatch(kCapsuleFeedHiddenMarker), isTrue);
    });

    test('source : bouton dessiné dans la barre de droite, même action', () {
      final src = File('lib/views/map/paw_map_screen.dart').readAsStringSync();
      final slot = src.indexOf("case 'feed':", src.indexOf('Widget? _buildCapsuleSlot('));
      expect(slot, greaterThan(0));
      final end = src.indexOf("case 'eye':", slot);
      final body = src.substring(slot, end);
      expect(body, contains('kJewelFeed'));
      expect(body, contains('PawJewelDot()'));
      expect(body, contains('AlertsScreen()'));
    });

    test('aide : « Voir signaux » dit « barre de droite » dans les 9 langues', () {
      final src = File('lib/localization/v565/help587_i18n.dart').readAsStringSync();
      expect(src, contains('"Dans la barre de droite, juste au-dessus du bouton Balade.'));
      expect(src.contains('Dans la barre de gauche. Touche-le pour voir tous les signalements'), isFalse);
    });
  });

  // ── 2. Suivi accepté depuis le chat ───────────────────────────────────
  group('suivi en direct accepté depuis le chat', () {
    test('qui partage sa position', () {
      // Un propriétaire demande à SUIVRE : c'est le destinataire qui partage.
      expect(pawfollowSharerIsMe(requesterRole: 'owner', isMine: false), isTrue);
      expect(pawfollowSharerIsMe(requesterRole: 'owner', isMine: true), isFalse);
      // Un gardien / promeneur propose de PARTAGER : c'est lui qui partage.
      expect(pawfollowSharerIsMe(requesterRole: 'walker', isMine: true), isTrue);
      expect(pawfollowSharerIsMe(requesterRole: 'sitter', isMine: false), isFalse);
    });

    test('ma proposition acceptée en direct → mon direct démarre, une fois', () {
      expect(
          pawfollowAcceptedForMyShare(
              previousStatus: 'pending', newStatus: 'accepted',
              requesterRole: 'walker', isMine: true),
          isTrue);
      // Rechargement d'une vieille carte déjà acceptée : jamais.
      expect(
          pawfollowAcceptedForMyShare(
              previousStatus: 'accepted', newStatus: 'accepted',
              requesterRole: 'walker', isMine: true),
          isFalse);
      // Je suivais (propriétaire) : ma position ne part pas.
      expect(
          pawfollowAcceptedForMyShare(
              previousStatus: 'pending', newStatus: 'accepted',
              requesterRole: 'owner', isMine: true),
          isFalse);
    });

    test('source : Accepter démarre le direct dans les 2 écrans de chat', () {
      for (final f in [
        'lib/views/pet_owner/chat/individual_chat_screen.dart',
        'lib/views/pet_sitter/chat/sitter_individual_chat_screen.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src, contains('LiveShareStarter.startWithFeedback()'), reason: f);
        expect(src, contains('pawfollowSharerIsMe('), reason: f);
      }
    });

    test('9 langues pour chaque texte nouveau', () {
      for (final l in kLangs) {
        for (final k in pawmap602I18n['fr']!.keys) {
          expect(pawmap602I18n[l]?[k], isNotEmpty, reason: '$l $k');
        }
      }
    });

    for (final b in [Brightness.light, Brightness.dark]) {
      testWidgets('carte du chat : mon direct ($b)', (tester) async {
        var started = 0;
        Widget card(bool live) => _app(
              SingleChildScrollView(
                child: PawfollowRequestCard(
                  messageId: 'm1',
                  requesterRole: 'owner',
                  responderRole: 'owner',
                  status: 'accepted',
                  myRole: 'owner',
                  isMine: false,
                  onAccept: () {},
                  onRefuse: () {},
                  iShare: true,
                  liveNow: live,
                  onStartLive: () => started += 1,
                ),
              ),
              b: b,
            );
        await tester.pumpWidget(card(false));
        await tester.pump(const Duration(milliseconds: 100));
        final start = find.byKey(const ValueKey<String>('pawfollow_my_live_start'));
        expect(start, findsOneWidget);
        await tester.tap(start);
        expect(started, 1);
        await tester.pumpWidget(card(true));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const ValueKey<String>('pawfollow_my_live_on')), findsOneWidget);
        expect(start, findsNothing);
      });
    }

    testWidgets('carte du chat : je suis celui qui suit → rien de « mon direct »',
        (tester) async {
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: PawfollowRequestCard(
          messageId: 'm1',
          requesterRole: 'owner',
          responderRole: 'owner',
          status: 'accepted',
          myRole: 'owner',
          isMine: true,
          onAccept: () {},
          onRefuse: () {},
        ),
      )));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey<String>('pawfollow_my_live_start')), findsNothing);
      expect(find.byKey(const ValueKey<String>('pawfollow_my_live_on')), findsNothing);
    });
  });

  // ── 3. Point vert du menu ─────────────────────────────────────────────
  group('point vert du menu posé sur le bord de la tête', () {
    test('géométrie : à cheval sur le liseré blanc, jamais dans le vide', () {
      const head = Offset(kPawTabBarPawBox / 2, kPawTabBarPawBox - 24);
      final c = pawLiveDotCenter();
      final dist = (c - head).distance;
      expect(dist, closeTo(kPawLiveDotRadius, 0.01));
      for (final n in [1, 3]) {
        final r = PawLiveDot.outerSize(n) / 2;
        // Le point mord le liseré blanc (21 → 24) …
        expect(dist - r, lessThan(21), reason: 'n=$n : touche le noir');
        expect(dist + r, greaterThan(24), reason: 'n=$n : couvre le bord');
        // … et ne dépasse de la tête que de quelques dp (jamais orphelin).
        expect(dist + r - 24, lessThanOrEqualTo(4.01), reason: 'n=$n');
        // Plus de la moitié du point est SUR la tête.
        expect(dist, lessThan(24));
      }
      // En haut à droite, à 45°.
      expect((c.dx - head.dx - (head.dy - c.dy)).abs(), lessThan(0.01));
    });

    for (final active in [false, true]) {
      for (final b in [Brightness.light, Brightness.dark]) {
        testWidgets('widget : même place, onglet PawMap ${active ? 'ouvert' : 'fermé'}, $b',
            (tester) async {
          tester.view.physicalSize = const Size(393, 300);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (_, __) => GetMaterialApp(
              theme: ThemeData(brightness: b),
              home: Scaffold(
                extendBody: true,
                bottomNavigationBar: PawTabBar(
                  currentIndex: active ? 2 : 0,
                  onTap: (_) {},
                  role: PawNavRole.owner,
                  systemInset: 0,
                  labels: _labels,
                  liveFriends: 1,
                ),
              ),
            ),
          ));
          await tester.pump(const Duration(milliseconds: 900));
          final dot = find.byKey(const ValueKey<String>('paw_tab_live_dot'));
          expect(dot, findsOneWidget);
          // Le point vit dans le même bloc que la patte : son centre est à
          // pawLiveDotCenter() du coin de la boîte de la patte.
          final glyph = find.byType(PawGlyph);
          final box = tester.getTopLeft(glyph);
          final center = tester.getCenter(dot);
          final expected = box + pawLiveDotCenter();
          expect((center - expected).distance, lessThan(1.0));
        });
      }
    }

    _exportMenuProofs();
  });

  // ── 4. Pastilles de compteur ──────────────────────────────────────────
  group('pastilles cloche et Chat', () {
    test('libellés', () {
      expect(pawBadgeLabel(1), '1');
      expect(pawBadgeLabel(99), '99');
      expect(pawBadgeLabel(100), '99+');
      expect(pawBadgeLabel(12, max: 9), '9+');
    });

    testWidgets('ancrée par la gauche : « 99+ » s’allonge vers l’extérieur',
        (tester) async {
      Future<Rect> place(int n) async {
        await tester.pumpWidget(_app(const SizedBox()));
        await tester.pumpWidget(_app(Padding(
          padding: const EdgeInsets.all(40),
          child: PawBadgeAnchor(
            iconWidth: 40,
            bite: 12,
            lift: 6,
            badge: PawCountBadge(count: n),
            child: const SizedBox(key: ValueKey('icon'), width: 40, height: 40),
          ),
        )));
        await tester.pump();
        return tester.getRect(find.byType(PawCountBadge));
      }

      final one = await place(1);
      final many = await place(250);
      final icon = tester.getRect(find.byKey(const ValueKey('icon')));
      expect(one.height, PawCountBadge.height);
      expect(many.height, PawCountBadge.height);
      expect(one.left, many.left, reason: 'même point d’accroche');
      expect(many.width, greaterThan(one.width));
      // Mord le coin haut-droit de l'icône, sans la recouvrir davantage.
      expect(one.left, closeTo(icon.right - 12, 0.01));
      expect(one.top, closeTo(icon.top - 6, 0.01));
      expect(find.text('99+'), findsOneWidget);
      // Le texte du téléphone agrandi ne déforme pas la pastille.
      await tester.pumpWidget(_app(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: PawCountBadge(count: 7),
      )));
      await tester.pump();
      expect(tester.getSize(find.byType(PawCountBadge)).height, PawCountBadge.height);
    });

    test('source : cloches et Chat utilisent la pastille commune', () {
      for (final f in [
        'lib/widgets/custom_app_bar.dart',
        'lib/views/profile/widgets/profile_notification_bell.dart',
        'lib/widgets/stacked_navigation_wrapper.dart',
      ]) {
        expect(File(f).readAsStringSync(), contains('PawCountBadge('), reason: f);
      }
      expect(File('lib/widgets/paw_tab_bar.dart').readAsStringSync(),
          contains('PawBadgeAnchor('));
      expect(File('lib/widgets/custom_app_bar.dart').readAsStringSync(),
          isNot(contains('shape: BoxShape.circle,\n                  border: Border.all(color: Colors.white, width: 1.5),')));
    });

    _exportBadgeProofs();
  });

  // ── 5. Notifications de suivi → la conversation ───────────────────────
  group('notifications de suivi en direct', () {
    const conv = '64b7f0c2a1b2c3d4e5f60718';
    test('demande, acceptation, refus → la conversation ; jamais les Amis', () {
      for (final t in [
        'live_tracking_request_received',
        'live_tracking_accepted',
        'live_tracking_refused',
      ]) {
        expect(DeepLinkService.routeForNotification(t, {'conversationId': conv}),
            '/chat/$conv', reason: t);
      }
      expect(DeepLinkService.routeForNotification(
          'live_tracking_request_received', {'bookingId': conv}), '/chat');
      expect(DeepLinkService.routeForNotification('live_tracking_accepted', {}),
          '/friends/live');
      expect(DeepLinkService.routeForNotification('walk_started', {'bookingId': conv}),
          '/walk/$conv');
      expect(DeepLinkService.routeForNotification('walk_finished', {'bookingId': conv}),
          '/walk/$conv');
    });

    test('cloche : le suivi passe par la route, avant la branche « acceptée »', () {
      final src = File('lib/views/notifications/notifications_screen.dart').readAsStringSync();
      final live = src.indexOf("if (type.startsWith('live_tracking') ||");
      expect(live, greaterThan(0));
      final ownerAccepted = src.indexOf("type.contains('accepted')");
      expect(ownerAccepted, greaterThan(live));
    });
  });
}

/// Preuves visuelles (clair / nuit, onglet fermé / ouvert, 1 et 3 amis) +
/// golden de la patte avec le point vert.
void _exportMenuProofs() {
  testWidgets('export PNG + golden du point vert (preuve)', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory('${Platform.environment['HOME']}/hopetsit-social/pawmap_602/preuves');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    for (final dark in [false, true]) {
      for (final tab in [0, 2]) {
        for (final n in [1, 3]) {
          final key = GlobalKey();
          final Color bg = dark ? const Color(0xFF1B1412) : const Color(0xFFFFF1EC);
          await tester.pumpWidget(ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (_, __) => GetMaterialApp(
              theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
              home: Scaffold(
                backgroundColor: bg,
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: RepaintBoundary(
                    key: key,
                    child: SizedBox(
                      width: 393,
                      height: 150,
                      child: Scaffold(
                        backgroundColor: bg,
                        extendBody: true,
                        bottomNavigationBar: PawTabBar(
                          currentIndex: tab,
                          onTap: (_) {},
                          role: PawNavRole.owner,
                          systemInset: 0,
                          labels: _labels,
                          liveFriends: n,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ));
          await tester.pump(const Duration(milliseconds: 900));
          final name = 'menu_point_${dark ? 'nuit' : 'clair'}_${tab == 2 ? 'pawmap' : 'accueil'}_$n';
          if (!dark && tab == 2 && n == 1) {
            await expectLater(find.byKey(key), matchesGoldenFile('goldens/pawmap602/$name.png'));
          }
          final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final img = await boundary.toImage(pixelRatio: 3);
            final data = await img.toByteData(format: ui.ImageByteFormat.png);
            File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
          });
        }
      }
    }
  });
}

void _exportBadgeProofs() {
  testWidgets('export PNG + golden des pastilles (preuve)', (tester) async {
    tester.view.physicalSize = const Size(393, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory('${Platform.environment['HOME']}/hopetsit-social/pawmap_602/preuves');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    for (final dark in [false, true]) {
      final key = GlobalKey();
      final Color bg = dark ? const Color(0xFF1B1412) : const Color(0xFFFFF7F3);
      Widget bell(int n) => Padding(
            padding: const EdgeInsets.all(14),
            child: PawBadgeAnchor(
              iconWidth: 40,
              bite: 12,
              lift: 6,
              badge: PawCountBadge(count: n),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFC92A12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 21),
              ),
            ),
          );
      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, __) => GetMaterialApp(
          home: Scaffold(
            backgroundColor: bg,
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: Container(
                  color: bg,
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [bell(1), bell(12), bell(250)]),
                      SizedBox(
                        width: 393,
                        height: 110,
                        child: Scaffold(
                          backgroundColor: bg,
                          extendBody: true,
                          bottomNavigationBar: PawTabBar(
                            currentIndex: 1,
                            onTap: (_) {},
                            role: PawNavRole.owner,
                            systemInset: 0,
                            labels: _labels,
                            badges: {1: (_) => const PawCountBadge(count: 128)},
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 900));
      final name = 'pastilles_${dark ? 'nuit' : 'clair'}';
      if (!dark) {
        await expectLater(find.byKey(key), matchesGoldenFile('goldens/pawmap602/$name.png'));
      }
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 3);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  });
  // math import used for geometry above.
  assert(math.pi > 3);
}
