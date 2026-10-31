// 631 (PAM-C, 31/10/2026) — Profil › Préférences › « Ouverture » :
//   · décision pure « quel onglet ouvrir » (lien / écran poussé / carte
//     demandée gagnent toujours ; « dernière page » ; 30 min) ;
//   · l'onglet (fr, ja, 320 px) : 5 pilules, choix enregistré sur le
//     téléphone, interrupteur Balade rapide + côté ;
//   · les 9 langues ont les mêmes clés.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/localization/v565/pamc3110_i18n.dart';
import 'package:hopetsit/services/open_on_prefs_3110.dart';
import 'package:hopetsit/views/profile/widgets/prefs_open_on_3110.dart';
import 'package:hopetsit/widgets/app_switch.dart';

import 'lotd_harness.dart';

void main() {
  group('openOnDecide3110 (pure)', () {
    int? d({
      OpenOnChoice3110 choice = OpenOnChoice3110.pawmap,
      int? lastTab,
      bool deepLinkPending = false,
      bool routeOnTop = false,
      bool mapRequested = false,
      int currentTab = 0,
    }) =>
        openOnDecide3110(
          choice: choice,
          lastTab: lastTab,
          deepLinkPending: deepLinkPending,
          routeOnTop: routeOnTop,
          mapRequested: mapRequested,
          currentTab: currentTab,
        );

    test('Accueil (défaut) = rien à faire', () {
      expect(d(choice: OpenOnChoice3110.home), isNull);
    });
    test('PawMap / Chat / Réservations → leur onglet', () {
      expect(d(choice: OpenOnChoice3110.pawmap), 2);
      expect(d(choice: OpenOnChoice3110.chat), 1);
      expect(d(choice: OpenOnChoice3110.bookings), 3);
    });
    test('déjà sur le bon onglet = rien', () {
      expect(d(choice: OpenOnChoice3110.pawmap, currentTab: 2), isNull);
    });
    test('un lien, un écran poussé ou une carte demandée gagnent toujours', () {
      expect(d(deepLinkPending: true), isNull);
      expect(d(routeOnTop: true), isNull);
      expect(d(mapRequested: true), isNull);
    });
    test('dernière page = dernier onglet mémorisé ; jamais le Profil', () {
      expect(d(choice: OpenOnChoice3110.last, lastTab: 3), 3);
      expect(d(choice: OpenOnChoice3110.last, lastTab: null), isNull);
      expect(d(choice: OpenOnChoice3110.last, lastTab: 4), isNull);
      expect(d(choice: OpenOnChoice3110.last, lastTab: 0), isNull);
    });
    test('retour depuis l’arrière-plan : seulement après plus de 30 min', () {
      final now = DateTime(2026, 10, 31, 16);
      expect(openOnResumeCounts3110(null, now), isFalse);
      expect(openOnResumeCounts3110(now.subtract(const Duration(minutes: 5)), now), isFalse);
      expect(openOnResumeCounts3110(now.subtract(const Duration(minutes: 30)), now), isFalse);
      expect(openOnResumeCounts3110(now.subtract(const Duration(minutes: 31)), now), isTrue);
    });
    test('codes enregistrés : relecture tolérante', () {
      expect(OpenOnChoice3110.fromCode('chat'), OpenOnChoice3110.chat);
      expect(OpenOnChoice3110.fromCode('n’importe quoi'), OpenOnChoice3110.home);
      expect(OpenOnChoice3110.fromCode(null), OpenOnChoice3110.home);
      expect(QuickWalkSide3110.fromCode('left'), QuickWalkSide3110.left);
      expect(QuickWalkSide3110.fromCode(null), QuickWalkSide3110.right);
    });
  });

  test('i18n : 9 langues, mêmes clés', () {
    const langs = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
    final ref = pamc3110I18n['en']!.keys.toSet();
    expect(ref.length, 19);
    for (final l in langs) {
      expect(pamc3110I18n[l]!.keys.toSet(), ref, reason: l);
      for (final v in pamc3110I18n[l]!.values) {
        expect(v.trim(), isNotEmpty, reason: '$l vide');
      }
    }
  });

  group('onglet Ouverture (widget)', () {
    setUp(() async {
      await lotdSetUp(role: 'walker');
      OpenOnPrefs3110.resetForTest();
    });

    for (final lang in const ['fr', 'ja']) {
      final locale = lang == 'fr' ? const Locale('fr', 'FR') : const Locale('ja', 'JP');
      final v = pamc3110I18n[lang]!;

      testWidgets('$lang : 5 pilules, choix enregistré, Balade rapide ON/OFF + côté', (t) async {
        lotdPhone(t, width: 320, height: 1400);
        await t.pumpWidget(lotdApp(
          Scaffold(
            body: SingleChildScrollView(
              child: PrefsOpenOnTab3110(accent: const Color(0xFF16A34A)),
            ),
          ),
          locale: locale,
        ));
        await lotdSettle(t);
        expect(t.takeException(), isNull);

        expect(find.text(v['pamc3110_open_title']!), findsOneWidget);
        for (final c in OpenOnChoice3110.values) {
          expect(find.byKey(ValueKey<String>('pamc3110_open_${c.code}')), findsOneWidget, reason: c.code);
        }
        // Accueil est le défaut, et l'étiquette le dit.
        expect(find.textContaining(v['pamc3110_default']!), findsOneWidget);
        expect(OpenOnPrefs3110.openOn.value, OpenOnChoice3110.home);

        // Choisir PawMap → réglage + téléphone.
        await t.tap(find.byKey(const ValueKey<String>('pamc3110_open_pawmap')));
        await lotdSettle(t);
        expect(OpenOnPrefs3110.openOn.value, OpenOnChoice3110.pawmap);
        expect(GetStorage().read(OpenOnPrefs3110.kOpenOn), 'pawmap');

        // « Dernière page » affiche sa phrase d'explication.
        await t.tap(find.byKey(const ValueKey<String>('pamc3110_open_last')));
        await lotdSettle(t);
        expect(find.byKey(const ValueKey<String>('pamc3110_open_last_sub')), findsOneWidget);
        expect(GetStorage().read(OpenOnPrefs3110.kOpenOn), 'last');

        // Balade rapide : ON par défaut, côté Droite par défaut.
        expect(find.text(v['pamc3110_qw_visible']!), findsOneWidget);
        final sw = find.byKey(const ValueKey<String>('pamc3110_qw_switch'));
        expect(t.widget<AppSwitch>(sw).value, isTrue);
        expect(find.byKey(const ValueKey<String>('pamc3110_qw_side_block')), findsOneWidget);
        await t.tap(find.byKey(const ValueKey<String>('pamc3110_qw_left')));
        await lotdSettle(t);
        expect(OpenOnPrefs3110.quickWalkSide.value, QuickWalkSide3110.left);
        expect(GetStorage().read(OpenOnPrefs3110.kQuickWalkSide), 'left');

        // OFF → le choix du côté se replie, et c'est enregistré.
        await t.tap(sw);
        await lotdSettle(t);
        expect(OpenOnPrefs3110.quickWalkVisible.value, isFalse);
        expect(GetStorage().read(OpenOnPrefs3110.kQuickWalkVisible), isFalse);
        expect(find.byKey(const ValueKey<String>('pamc3110_qw_side_block')), findsNothing);

        // Note « sur ce téléphone seulement » visible.
        expect(find.text(v['pamc3110_local_note']!), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    test('relecture depuis le téléphone (relance à froid)', () async {
      await GetStorage().write(OpenOnPrefs3110.kOpenOn, 'bookings');
      await GetStorage().write(OpenOnPrefs3110.kQuickWalkVisible, false);
      await GetStorage().write(OpenOnPrefs3110.kQuickWalkSide, 'left');
      OpenOnPrefs3110.load(force: true);
      expect(OpenOnPrefs3110.openOn.value, OpenOnChoice3110.bookings);
      expect(OpenOnPrefs3110.quickWalkVisible.value, isFalse);
      expect(OpenOnPrefs3110.quickWalkSide.value, QuickWalkSide3110.left);
      OpenOnPrefs3110.rememberTab(4); // Profil : jamais mémorisé
      expect(OpenOnPrefs3110.lastTab(), isNull);
      OpenOnPrefs3110.rememberTab(1);
      expect(OpenOnPrefs3110.lastTab(), 1);
    });
  });
}
