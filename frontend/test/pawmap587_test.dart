// v587 (25/09/2026) — PawMap : le direct « suspendu », le frère « dans l'eau »,
// les amis introuvables, les barres repliables, « Mon fond » qui saute.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';
import 'package:hopetsit/views/profile/widgets/profile_settings_tabs.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

import 'lotd_harness.dart';

void main() {
  group('1b — direct : âge mesuré par le serveur, jamais l\'horloge du téléphone', () {
    test('ageMs du serveur : 20 s → « en direct », quelle que soit l\'heure du téléphone', () {
      final now = DateTime(2026, 9, 25, 12, 0, 0);
      // Horodatage serveur 3 min « dans le passé » vu d'un téléphone en avance.
      final fp = FriendPosition.fromJson({
        'userId': 'a', 'role': 'sitter', 'lat': -35.2, 'lng': -30.4,
        'at': now.subtract(const Duration(minutes: 3)).toUtc().toIso8601String(),
        'lastSeenAt': now.subtract(const Duration(minutes: 3)).toUtc().toIso8601String(),
        'sharing': true, 'ageMs': 20000,
      }, now: now);
      expect(fp.seenAt, now.subtract(const Duration(seconds: 20)));
      expect(friendLiveState(sharing: fp.sharing, seenAt: fp.seenAt, now: now),
          FriendLiveState.live);
    });

    test('ancien serveur (sans ageMs) : lastSeenAt reste lu', () {
      final t = DateTime.utc(2026, 9, 25, 10);
      final fp = FriendPosition.fromJson({
        'userId': 'a', 'lat': 1, 'lng': 2, 'at': t.toIso8601String(),
        'lastSeenAt': t.add(const Duration(seconds: 5)).toIso8601String(),
        'sharing': true,
      });
      expect(fp.seenAt, t.add(const Duration(seconds: 5)));
    });

    test('événement socket : le signe de vie = l\'heure de RÉCEPTION (battement qui rejoue une vieille position)', () {
      final old = FriendPosition(
        userId: 'a', role: 'sitter', latitude: -35.2, longitude: -30.4,
        at: DateTime(2026, 9, 25, 11, 50), // position rejouée, vieille de 10 min
      );
      final now = DateTime(2026, 9, 25, 12, 0);
      final fp = applyLiveEvent(old, now);
      expect(fp.sharing, isTrue);
      expect(fp.stale, isFalse);
      expect(friendLiveState(sharing: fp.sharing, seenAt: fp.seenAt, now: now),
          FriendLiveState.live);
    });
  });

  group('1b — le suivi ne se met en pause que sur un VRAI geste', () {
    test('un appui (sans glisser) : jamais de pause', () {
      final w = PawMapDragWatch();
      expect(w.down(const Offset(100, 100)), isFalse);
      expect(w.move(const Offset(105, 104)), isFalse);
      w.end();
    });
    test('glisser de plus de 12 px : une pause, une seule fois', () {
      final w = PawMapDragWatch();
      w.down(const Offset(100, 100));
      expect(w.move(const Offset(100, 120)), isTrue);
      expect(w.move(const Offset(100, 160)), isFalse);
      w.end();
      w.down(const Offset(10, 10));
      expect(w.move(const Offset(40, 10)), isTrue);
    });
    test('pincer (2 doigts) : pause', () {
      final w = PawMapDragWatch();
      expect(w.down(const Offset(100, 100)), isFalse);
      expect(w.down(const Offset(200, 200)), isTrue);
    });
  });

  for (final role in ['owner', 'sitter', 'walker']) {
    group('4 — « Mon fond » ne saute plus ($role)', () {
      setUp(() async {
        await lotdSetUp(role: role);
        PawWallpaperPrefs.debugMode = 'auto';
        PawWallpaperPrefs.debugResetPending();
      });
      tearDown(() {
        PawWallpaperPrefs.debugMode = null;
        PawWallpaperPrefs.debugResetPending();
      });

      bool selected(WidgetTester t, String v) => t
          .widget<PawChoicePill>(
              find.byKey(ValueKey<String>('pref_wallpaper_$v')))
          .selected;

      testWidgets('3 appuis rapides → reste sur le dernier, malgré les relectures périmées',
          (t) async {
        lotdPhone(t);
        final sent = <String>[];
        await t.pumpWidget(lotdApp(Scaffold(
          body: SingleChildScrollView(
            child: ProfilePreferencesTab(
              accent: const Color(0xFF16A34A),
              prefs: const ProfilePreferences(),
              onSave: (u) async => sent.add(u.toJson()['wallpaper'] as String),
              onLanguage: () {},
            ),
          ),
        )));
        await lotdSettle(t);
        await t.tap(find.byKey(const ValueKey<String>('pref_wallpaper_paws')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey<String>('pref_wallpaper_none')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey<String>('pref_wallpaper_auto')));
        await t.pump();
        expect(sent, ['paws', 'none', 'auto']);
        // Les relectures du compte arrivent APRÈS, dans l'ordre des
        // écritures : les deux premières sont périmées, jamais affichées.
        for (final echo in ['paws', 'none', 'auto']) {
          PawWallpaperPrefs.syncFromAccount(echo);
          await t.pump();
          expect(selected(t, 'auto'), isTrue, reason: 'relecture « $echo »');
          expect(selected(t, 'paws') || selected(t, 'none'), isFalse);
        }
        expect(PawWallpaperPrefs.mode(), 'auto');
      });

      test('le compte reprend la main après 30 s (autre téléphone)', () {
        final t0 = DateTime(2026, 9, 25, 12);
        PawWallpaperPrefs.choose('none', now: t0);
        PawWallpaperPrefs.syncFromAccount('paws',
            now: t0.add(const Duration(seconds: 5)));
        expect(PawWallpaperPrefs.mode(), 'none');
        PawWallpaperPrefs.syncFromAccount('paws',
            now: t0.add(const Duration(seconds: 31)));
        expect(PawWallpaperPrefs.mode(), 'paws');
      });

      test('sans choix en attente : le compte fait foi tout de suite', () {
        PawWallpaperPrefs.syncFromAccount('none');
        expect(PawWallpaperPrefs.mode(), 'none');
      });
    });
  }

  group('1a — pilule « ● Direct »', () {
    setUp(() async => lotdSetUp(role: 'sitter'));
    testWidgets('libellés : arrêté, à l\'instant, durée, sans GPS', (t) async {
      await t.pumpWidget(lotdApp(const SizedBox()));
      final t0 = DateTime(2026, 9, 25, 12);
      expect(pawDirectPillLabel(live: false, startedAt: null, now: t0), 'Direct');
      expect(pawDirectPillLabel(live: true, startedAt: t0, now: t0.add(const Duration(seconds: 30))), 'En direct');
      expect(pawDirectPillLabel(live: true, startedAt: t0, now: t0.add(const Duration(minutes: 12))), 'En direct · 12 min');
      expect(pawDirectPillLabel(live: true, startedAt: t0, now: t0, noGps: true), 'Direct · pas de GPS');
    });
    testWidgets('un appui bascule ; noire → verte ; jamais coupée à 320 px', (t) async {
      lotdPhone(t, width: 320);
      var live = false;
      await t.pumpWidget(lotdApp(Scaffold(
        body: StatefulBuilder(
          builder: (ctx, set) => Align(
            alignment: Alignment.topLeft,
            child: PawMapDirectPill(
              live: live,
              startedAt: DateTime(2026, 9, 25, 12),
              now: () => DateTime(2026, 9, 25, 12, 12),
              onTap: () => set(() => live = !live),
            ),
          ),
        ),
      )));
      await t.pump();
      expect(find.byKey(const ValueKey('pawmap_direct_pill_off')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('pawmap_direct_pill_off')));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('pawmap_direct_pill_on')), findsOneWidget);
      expect(find.text('En direct · 12 min'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('Direct pour les 3 profils (Daniel, 25/09)', () {
    test('pilule « ● Direct » : propriétaire, gardien, promeneur ; pas sans compte', () {
      for (final r in ['owner', 'sitter', 'walker', 'Owner']) {
        expect(pawMapShowsDirectPill(r), isTrue, reason: r);
      }
      expect(pawMapShowsDirectPill(''), isFalse);
      expect(pawMapShowsDirectPill('guest'), isFalse);
    });
    test('capsule : même capsule pour tous, « Publier » en plus pour le propriétaire', () {
      expect(pawMapCapsuleHasPublish('owner'), isTrue);
      expect(pawMapCapsuleHasPublish('sitter'), isFalse);
      expect(pawMapCapsuleHasPublish('walker'), isFalse);
    });
  });

  group('3 — barres repliables', () {
    setUp(() async => lotdSetUp(role: 'owner'));
    for (final left in [true, false]) {
      testWidgets('${left ? 'rail gauche' : 'capsule droite'} : range hors écran en 200 ms, languette au bord, puis revient',
          (t) async {
        lotdPhone(t);
        var collapsed = false;
        await t.pumpWidget(lotdApp(Scaffold(
          body: StatefulBuilder(
            builder: (ctx, set) => Stack(children: [
              Positioned(
                left: left ? 12 : null,
                right: left ? null : 12,
                bottom: 100,
                child: PawCollapsibleBar(
                  left: left,
                  collapsed: collapsed,
                  tint: const Color(0xFF2563EB),
                  onToggle: () => set(() => collapsed = !collapsed),
                  child: Container(
                      key: const ValueKey('bar'), width: 56, height: 220,
                      color: const Color(0xFFFFFBF7)),
                ),
              ),
            ]),
          ),
        )));
        await t.pump();
        await t.pump();
        final screenW = t.view.physicalSize.width / t.view.devicePixelRatio;
        Rect bar() => t.getRect(find.byKey(const ValueKey('bar')));
        expect(bar().left >= 0 && bar().right <= screenW, isTrue, reason: 'départ ${bar()} / $screenW');
        final side = left ? 'pawmap_rail' : 'pawmap_capsule';
        await t.tap(find.byKey(ValueKey('${side}_hide')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 205));
        // La barre est entièrement hors écran ; la languette est au bord.
        if (left) {
          expect(bar().right <= 0.5, isTrue, reason: '${bar()}');
        } else {
          expect(bar().left >= screenW - 0.5, isTrue, reason: '${bar()}');
        }
        final tab = t.getRect(find.byKey(ValueKey('${side}_show')));
        expect(tab.left >= -0.5 && tab.right <= screenW + 0.5, isTrue, reason: '$tab');
        await t.tap(find.byKey(ValueKey('${side}_show')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 205));
        expect(bar().left >= 0 && bar().right <= screenW, isTrue);
      });
    }
  });

  test('2 — un ami n\'est jamais absorbé dans un groupe (zoom pays)', () {
    // Zoom pays : tout le monde tombe dans la même case de regroupement.
    final members = ['ami1', 'x1', 'x2', 'ami2', 'x3'];
    final groups = pawGroupKeepingFriends<String>(
      members,
      (m) => m.startsWith('ami'),
      (others) => [others], // une seule case pour tous les autres
    );
    expect(groups, [
      ['ami1'],
      ['ami2'],
      ['x1', 'x2', 'x3'],
    ]);
  });
}
