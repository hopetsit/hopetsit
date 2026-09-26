// v586 (25/09/2026) — PawMap « très discrète et dégagée » : preuves de widget.
//   1. la poignée « Options » ouvre la feuille COMPLÈTE (appui ET glissement) ;
//   2. le rond Direct bascule noir ↔ vert, sur UNE vérité ;
//   3. l'œil : 3 états (Tous · Amis · Masqué), cycle et migration ;
//   4. « Mon fond » : les 3 choix redessinent les fonds DÉJÀ construits ;
//   5. effacement au geste (35 % puis retour 1 s après) ;
//   7. « Ce que je veux voir » : chaque pastille ne touche QU'une famille.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/v565/lotc584_i18n.dart';
import 'package:hopetsit/localization/v565/map_i18n.dart';
import 'package:hopetsit/localization/v565/pawmap586_i18n.dart';
import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/services/map_prefs_service.dart';
import 'package:hopetsit/views/map/widgets/paw_rail_button.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

const List<String> _langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

class _T extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        for (final l in _langs)
          l: {
            ...mapI18n[l] ?? const <String, String>{},
            ...lotC584I18n[l]!,
            ...pawmap586I18n[l]!,
          },
      };
}

Widget _app(Widget body, {String lang = 'fr', double width = 393}) {
  return MediaQuery(
    data: MediaQueryData(size: Size(width, 852)),
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: _T(),
        locale: Locale(lang),
        fallbackLocale: const Locale('en'),
        home: Scaffold(body: body),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() {
    PawWallpaperPrefs.debugMode = 'auto';
    PawWallpaperPrefs.debugSpecies = const ['dog'];
    PawWallpaperPrefs.debugRole = 'owner';
  });
  tearDown(() {
    PawWallpaperPrefs.debugMode = null;
    PawWallpaperPrefs.debugSpecies = null;
    PawWallpaperPrefs.debugRole = null;
  });

  // ─── 1. Poignée → feuille complète ───────────────────────────────────────
  group('poignée « Options »', () {
    Future<DraggableScrollableController> pumpMap(WidgetTester t) async {
      final ctl = DraggableScrollableController();
      await t.pumpWidget(_app(Stack(children: [
        Positioned.fill(
          child: PawMapSheet(
            controller: ctl,
            availableHeight: 852,
            peekHeight: 0, // v586 : rangée au repos
            header: const SizedBox(height: 52, key: ValueKey('hdr')),
            children: const [
              SizedBox(height: 40, child: Text('SOS', key: ValueKey('last_option'))),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 20,
          child: Center(
            child: PawMapOptionsHandle(
              roleColor: const Color(0xFF2563EB),
              showLabel: true,
              onOpen: () => ctl.animateTo(0.9,
                  duration: const Duration(milliseconds: 200), curve: Curves.easeOut),
            ),
          ),
        ),
      ])));
      await t.pump(const Duration(milliseconds: 50));
      return ctl;
    }

    testWidgets('au repos la feuille est rangée (taille 0) ; un APPUI l\'ouvre en haut',
        (t) async {
      final ctl = await pumpMap(t);
      expect(ctl.size, 0.0);
      expect(find.text('Options'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('pawmap_options_handle')));
      await _settle(t);
      expect(ctl.size, closeTo(0.9, 0.001));
      // Le contenu complet est là (dernière option touchable).
      expect(t.getRect(find.byKey(const ValueKey('last_option'))).top, lessThan(852));
    });

    testWidgets('au repos : AUCUNE bande (ni fond, ni liseré, ni ombre)', (t) async {
      await pumpMap(t);
      final painted = find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byWidgetPredicate((w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            ((w.decoration as BoxDecoration).color != null ||
                (w.decoration as BoxDecoration).gradient != null ||
                (w.decoration as BoxDecoration).boxShadow != null ||
                (w.decoration as BoxDecoration).border != null)),
      );
      expect(painted, findsNothing);
    });

    testWidgets('un GLISSEMENT vers le haut l\'ouvre aussi', (t) async {
      final ctl = await pumpMap(t);
      await t.timedDrag(find.byKey(const ValueKey('pawmap_options_handle')),
          const Offset(0, -60), const Duration(milliseconds: 250));
      await _settle(t);
      expect(ctl.size, closeTo(0.9, 0.001));
    });

    testWidgets('icône seule après 3 ouvertures ; appui long = libellé 2 s', (t) async {
      expect(pawMap586ShowLabels(1), isTrue);
      expect(pawMap586ShowLabels(3), isTrue);
      expect(pawMap586ShowLabels(4), isFalse);
      await t.pumpWidget(_app(Center(
        child: PawMapOptionsHandle(
            roleColor: const Color(0xFF16A34A), showLabel: false, onOpen: () {}),
      )));
      expect(find.text('Options'), findsNothing);
      expect(find.byKey(const ValueKey('pawmap_handle_paw')), findsOneWidget);
      await t.longPress(find.byKey(const ValueKey('pawmap_options_handle')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Options'), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      expect(find.text('Options'), findsNothing);
    });

    testWidgets('la poignée de la feuille ouverte la range', (t) async {
      final ctl = DraggableScrollableController();
      await t.pumpWidget(_app(PawMapSheet(
        controller: ctl,
        availableHeight: 852,
        peekHeight: 0,
        header: const SizedBox(height: 52),
        onGripTap: () => ctl.animateTo(0,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut),
        children: const [SizedBox(height: 200)],
      )));
      ctl.jumpTo(0.9);
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(find.byKey(const ValueKey('pawmap_sheet_grip')));
      await _settle(t);
      expect(ctl.size, 0.0);
    });
  });

  // ─── 2. Direct ───────────────────────────────────────────────────────────
  group('rond Direct / Publier', () {
    testWidgets('Direct : noir = arrêté, vert = en direct ; un appui bascule la MÊME vérité',
        (t) async {
      final live = false.obs; // = LiveMapService.broadcasting
      await t.pumpWidget(_app(Center(
        child: Obx(() => PawCapsuleRoleAction(
              kind: PawRoleActionKind.direct,
              live: live.value,
              showLabel: true,
              onTap: () => live.value = !live.value,
            )),
      )));
      expect(find.byKey(const ValueKey('pawmap_action_direct_off')), findsOneWidget);
      expect(find.text('Direct'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('pawmap_action_direct_off')));
      await t.pump(const Duration(milliseconds: 100));
      expect(live.value, isTrue);
      expect(find.byKey(const ValueKey('pawmap_action_direct_on')), findsOneWidget);
      // Vert #16A34A (dégradé) quand en direct.
      final box = t.widget<Container>(find.descendant(
          of: find.byKey(const ValueKey('pawmap_action_direct_on')),
          matching: find.byType(Container)).first);
      final g = (box.decoration as BoxDecoration).gradient as LinearGradient;
      expect(g.colors.last, const Color(0xFF16A34A));
      await t.tap(find.byKey(const ValueKey('pawmap_action_direct_on')));
      await t.pump(const Duration(milliseconds: 100));
      expect(live.value, isFalse);
      final off = t.widget<Container>(find.descendant(
          of: find.byKey(const ValueKey('pawmap_action_direct_off')),
          matching: find.byType(Container)).first);
      expect(((off.decoration as BoxDecoration).gradient as LinearGradient).colors.last,
          const Color(0xFF17141F));
    });

    testWidgets('Publier : mégaphone rouge, appui = action ; appui long = explication',
        (t) async {
      var taps = 0, longs = 0;
      await t.pumpWidget(_app(Center(
        child: PawCapsuleRoleAction(
          kind: PawRoleActionKind.publish,
          live: false,
          showLabel: false,
          onTap: () => taps++,
          onLongPress: () => longs++,
        ),
      )));
      expect(find.byIcon(Icons.campaign_rounded), findsOneWidget);
      // v589 — « Publier » TOUJOURS écrit, et un « + » sur le mégaphone.
      expect(find.text('Publier'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('pawmap_action_publish')));
      await t.longPress(find.byKey(const ValueKey('pawmap_action_publish')));
      expect([taps, longs], [1, 1]);
    });

    testWidgets('capsule : l\'action du rôle est SOUS un trait, hors découpe', (t) async {
      await t.pumpWidget(_app(Center(
        child: PawGlassCapsule(
          width: 54,
          footer: PawCapsuleRoleAction(
            kind: PawRoleActionKind.direct,
            live: true,
            showLabel: true,
            onTap: () {},
          ),
          children: [
            PawCapsuleEyeButton(state: 'all', onTap: () {}),
          ],
        ),
      )));
      await t.pump(const Duration(milliseconds: 100));
      final trait = t.getRect(find.byKey(const ValueKey('pawmap_capsule_trait')));
      final eye = t.getRect(find.byKey(const ValueKey('pawmap_eye')));
      final direct = t.getRect(find.byKey(const ValueKey('pawmap_action_direct_on')));
      expect(eye.bottom, lessThanOrEqualTo(trait.top));
      expect(direct.top, greaterThanOrEqualTo(trait.bottom));
    });
  });

  // ─── 3. Œil ──────────────────────────────────────────────────────────────
  group('œil : Tous · Amis seulement · Masqué', () {
    test('cycle et migration douce (même règle que le serveur)', () {
      expect(MapPrefsService.nextVisibility('all'), 'friends');
      expect(MapPrefsService.nextVisibility('friends'), 'hidden');
      expect(MapPrefsService.nextVisibility('hidden'), 'all');
      expect(MapPrefsService.visibilityFrom({'mapVisibility': 'hidden'}), 'hidden');
      expect(MapPrefsService.visibilityFrom({'hideFromMap': true}), 'friends');
      expect(MapPrefsService.visibilityFrom({}), 'all');
    });

    test('Préférences du profil : la visibilité part sous ses DEUX formes', () {
      final p = ProfilePreferences.fromJson({'hideFromMap': true});
      expect(p.mapVisibility, 'friends');
      final j = p.copyWith(mapVisibility: 'hidden').toJson();
      expect(j['mapVisibility'], 'hidden');
      expect(j['hideFromMap'], isTrue);
      expect(p.copyWith(mapVisibility: 'all').toJson()['hideFromMap'], isFalse);
      // « Mon fond » : le compte ne fait foi que s'il a renvoyé la valeur.
      expect(ProfilePreferences.fromJson({}).wallpaperKnown, isFalse);
      expect(ProfilePreferences.fromJson({'wallpaper': 'none'}).wallpaperKnown, isTrue);
    });

    testWidgets('3 icônes, un appui = état suivant, persistant dans l\'état partagé',
        (t) async {
      final state = 'all'.obs; // = MapPrefsService.mapVisibility
      await t.pumpWidget(_app(Center(
        child: Obx(() => PawCapsuleEyeButton(
              state: state.value,
              onTap: () => state.value = MapPrefsService.nextVisibility(state.value),
            )),
      )));
      expect(find.byKey(const ValueKey('pawmap_eye_all')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('pawmap_eye')));
      await t.pump();
      expect(find.byKey(const ValueKey('pawmap_eye_friends')), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget); // œil + cœur
      await t.tap(find.byKey(const ValueKey('pawmap_eye')));
      await t.pump();
      expect(find.byKey(const ValueKey('pawmap_eye_hidden')), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('pawmap_eye')));
      await t.pump();
      expect(state.value, 'all');
    });

    testWidgets('la feuille « Qui me voit » propose les 3 états', (t) async {
      final got = <String>[];
      await t.pumpWidget(_app(SingleChildScrollView(
        child: PawMapVisibilitySheet(state: 'all', saving: false, onChanged: got.add),
      )));
      await t.tap(find.byKey(const ValueKey('visibility_friends')));
      await t.tap(find.byKey(const ValueKey('visibility_hidden')));
      await t.tap(find.byKey(const ValueKey('visibility_all')));
      expect(got, ['friends', 'hidden', 'all']);
    });
  });

  // ─── 4. Mon fond ─────────────────────────────────────────────────────────
  group('« Mon fond » (auto / pattes / aucun)', () {
    Set<PawMotif> painted(WidgetTester t) {
      final cp = t.widget<CustomPaint>(find.descendant(
          of: find.byType(PawPatternBackground), matching: find.byType(CustomPaint)).first);
      return (cp.painter! as PawPatternPainter).motifs;
    }

    testWidgets('un fond DÉJÀ construit suit les 3 choix sans être reconstruit',
        (t) async {
      // L'écran (comme l'Accueil dans son onglet) n'est construit qu'une fois.
      await t.pumpWidget(_app(const PawPatternBackground(
        color: Color(0xFFC92A12),
        child: SizedBox.expand(),
      )));
      expect(painted(t), containsAll([PawMotif.bone, PawMotif.ball, PawMotif.leash]));
      PawWallpaperPrefs.setMode('paws');
      await t.pump();
      expect(painted(t), {PawMotif.paw, PawMotif.heart});
      PawWallpaperPrefs.setMode('none');
      await t.pump();
      expect(painted(t), isEmpty);
      PawWallpaperPrefs.setMode('auto');
      await t.pump();
      expect(painted(t), contains(PawMotif.bone));
    });

    test('le compte fait foi, sans écraser une valeur absente', () {
      PawWallpaperPrefs.setMode('paws');
      PawWallpaperPrefs.syncFromAccount(null);
      expect(PawWallpaperPrefs.mode(), 'paws');
      PawWallpaperPrefs.syncFromAccount('none');
      expect(PawWallpaperPrefs.mode(), 'none');
      PawWallpaperPrefs.syncFromAccount('n/importe');
      expect(PawWallpaperPrefs.mode(), 'none');
    });
  });

  // ─── 5. Effacement au geste ──────────────────────────────────────────────
  group('effacement au geste', () {
    testWidgets('glisser efface ; retour 1 s après le lâcher ; jamais en placement / suivi',
        (t) async {
      final f = PawChromeFade();
      f.down(const Offset(100, 100), allowed: true);
      f.move(const Offset(104, 102), allowed: true); // tremblement : rien
      expect(f.faded.value, isFalse);
      f.move(const Offset(160, 100), allowed: true);
      expect(f.faded.value, isTrue);
      f.end();
      await t.pump(const Duration(milliseconds: 900));
      expect(f.faded.value, isTrue);
      await t.pump(const Duration(milliseconds: 200));
      expect(f.faded.value, isFalse);
      // Placement au viseur / suivi : jamais.
      f.down(const Offset(0, 0), allowed: false);
      f.move(const Offset(200, 200), allowed: false);
      expect(f.faded.value, isFalse);
      f.end();
      f.dispose();
    });

    testWidgets('pincer (2 doigts) efface ; un appui ailleurs rend tout de suite',
        (t) async {
      final f = PawChromeFade();
      f.down(const Offset(100, 100), allowed: true);
      f.down(const Offset(200, 200), allowed: true);
      expect(f.faded.value, isTrue);
      f.end();
      f.end();
      f.restore(); // premier appui sur un bouton
      expect(f.faded.value, isFalse);
      await t.pump(const Duration(seconds: 2));
      expect(f.faded.value, isFalse);
      f.dispose();
    });

    testWidgets('les commandes restent touchables pendant l\'effacement', (t) async {
      final f = PawChromeFade();
      var taps = 0;
      await t.pumpWidget(_app(Center(
        child: Obx(() => AnimatedOpacity(
              opacity: f.faded.value ? 0.35 : 1,
              duration: const Duration(milliseconds: 150),
              child: PawCapsuleEyeButton(state: 'all', onTap: () => taps++),
            )),
      )));
      f.down(Offset.zero, allowed: true);
      f.down(const Offset(5, 5), allowed: true);
      await t.pump(const Duration(milliseconds: 200));
      expect(t.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0.35);
      await t.tap(find.byKey(const ValueKey('pawmap_eye')));
      expect(taps, 1);
      f.dispose();
    });
  });

  // ─── 7. Ce que je veux voir ──────────────────────────────────────────────
  group('« Ce que je veux voir »', () {
    testWidgets('chaque pastille ne bascule QUE sa famille ; Lieux off ≠ personnes',
        (t) async {
      final on = <String>{for (final f in kPawSeeFamilies) f.id}.obs;
      await t.pumpWidget(_app(SingleChildScrollView(
        child: Obx(() => PawMapSeeSection(
              on: on.toSet(),
              onToggle: (id) => on.contains(id) ? on.remove(id) : on.add(id),
              onAll: () => on.addAll(kPawSeeFamilies.map((f) => f.id)),
              onNone: on.clear,
            )),
      )));
      expect(find.text('Ce que je veux voir'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('see_places')));
      await t.pump();
      expect(on.contains('places'), isFalse);
      for (final keep in ['friends', 'owners', 'sitters', 'walkers']) {
        expect(on.contains(keep), isTrue, reason: '$keep doit rester');
      }
      expect(on.length, kPawSeeFamilies.length - 1);
      await t.tap(find.byKey(const ValueKey('see_none')));
      await t.pump();
      expect(on, isEmpty);
      await t.tap(find.byKey(const ValueKey('see_all')));
      await t.pump();
      expect(on.length, 8);
    });

    for (final lang in _langs) {
      testWidgets('rien de coupé à 320 px ($lang)', (t) async {
        await t.pumpWidget(_app(
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: PawMapSeeSection(
                on: const {'friends', 'places'},
                onToggle: (_) {},
                onAll: () {},
                onNone: () {},
              ),
            ),
          ),
          lang: lang,
          width: 320,
        ));
        await t.pump(const Duration(milliseconds: 250));
        expect(t.takeException(), isNull);
        for (final f in kPawSeeFamilies) {
          expect(find.byKey(ValueKey('see_${f.id}')), findsOneWidget);
          expect(pawmap586I18n[lang]![f.labelKey], isNotEmpty);
        }
      });
    }
  });

  test('9 langues : toutes les clés 586 présentes et non vides', () {
    final ref = pawmap586I18n['fr']!.keys.toSet();
    for (final l in _langs) {
      expect(pawmap586I18n[l]!.keys.toSet(), ref, reason: l);
      for (final v in pawmap586I18n[l]!.values) {
        expect(v.trim(), isNotEmpty, reason: l);
      }
    }
  });
}
