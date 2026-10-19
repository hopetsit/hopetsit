
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/map/widgets/pawmap_rail.dart';
import 'package:integration_test/integration_test.dart';

Future<void> _step(WidgetTester tester, String name,
    {Duration hold = const Duration(seconds: 2)}) async {
  debugPrint('[PARCOURS] ${DateTime.now().toIso8601String()} $name');
  await tester.pump(hold);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Les images sont rendues comme dans la vraie app (captures fidèles).
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    await GetStorage.init();
    await dotenv.load(fileName: '.env');
    // Les dépendances de production (AuthController) lisent Firebase.
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      debugPrint('[PARCOURS] Firebase : $e');
    }
    setupDependencies();
  });

  // PAM lundi 12/10/2026 — passage du lundi : la PawMap s'ouvre (position du
  // simulateur = Paris), puis CHAQUE bouton du rail gauche, de l'en-tête et de
  // la capsule droite est appuyé ; on note ce qui s'ouvre (feuille, dialogue,
  // écran) ou ce qui change, puis on referme. Mode invité (aucun compte, donc
  // aucune position de profil réécrite). Remplace pawmap_parcours_test (v584),
  // périmé depuis la 589 (la feuille s'ouvre par la roue de l'en-tête).
  testWidgets('PawMap lundi — chaque bouton du rail, de l\'en-tête et de la capsule',
      (tester) async {
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr', 'FR'),
        fallbackLocale: const Locale('en', 'US'),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
        home: const PawMapScreen(),
      ),
    ));
    await _step(tester, '00 ouverture de la carte', hold: const Duration(seconds: 4));
    for (var i = 0; i < 60; i++) {
      if (find.byKey(const ValueKey<String>('rail_around')).evaluate().isNotEmpty) break;
      await tester.pump(const Duration(seconds: 1));
    }
    for (var i = 0; i < 3; i++) {
      final next = find.byKey(const ValueKey<String>('coach_next'));
      if (next.evaluate().isEmpty) break;
      await tester.tap(next);
      await _step(tester, '00c decouverte guidee bulle ${i + 1}',
          hold: const Duration(milliseconds: 900));
    }
    await _step(tester, '01 carte posee', hold: const Duration(seconds: 2));
    expect(find.byType(GoogleMap), findsOneWidget, reason: 'UNE seule GoogleMap');
    expect(find.byType(PawMapRail), findsOneWidget, reason: 'le rail gauche est là');

    int sheets() => find.byType(BottomSheet).evaluate().length;
    int dialogs() => find.byType(Dialog).evaluate().length + find.byType(AlertDialog).evaluate().length;
    String topScreen() {
      final scaffolds = find.byType(Scaffold).evaluate().toList();
      if (scaffolds.isEmpty) return '-';
      final w = scaffolds.last.widget as Scaffold;
      return w.body?.runtimeType.toString() ?? 'Scaffold';
    }
    Future<void> closeAll() async {
      // Un viseur (itinéraire, lieu, signalement, photo) n'empile rien : il
      // se ferme par son bouton « Annuler ».
      for (var i = 0; i < 2; i++) {
        final cancel = find.text('common_cancel'.tr);
        if (cancel.evaluate().isEmpty) break;
        await tester.tap(cancel.last, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 700));
      }
      for (var i = 0; i < 4; i++) {
        final navs = find.byType(Navigator, skipOffstage: false);
        if (navs.evaluate().isEmpty) break;
        final nav = Navigator.of(tester.element(
            find.byType(PawMapScreen, skipOffstage: false).first));
        if (!nav.canPop()) break;
        nav.pop();
        await tester.pump(const Duration(milliseconds: 700));
      }
      await tester.pump(const Duration(milliseconds: 400));
    }

    final List<String> bilan = <String>[];
    Future<void> press(String key, String nom) async {
      final f = find.byKey(ValueKey<String>(key));
      if (f.evaluate().isEmpty) {
        bilan.add('$nom ($key) : ABSENT du rail actuel');
        return;
      }
      final before = '${sheets()}/${dialogs()}/${topScreen()}';
      await tester.tap(f.first, warnIfMissed: false);
      await _step(tester, '10 appui $nom', hold: const Duration(seconds: 2));
      final after = '${sheets()}/${dialogs()}/${topScreen()}';
      final changed = before != after;
      final String effet = changed
          ? 'ouvre (feuilles/dialogues/écran : $before → $after)'
          : 'bascule ou agit en place (rien d\'empilé)';
      bilan.add('$nom ($key) : $effet');
      debugPrint('[PARCOURS] BILAN $nom ($key) : $effet');
      await closeAll();
      expect(find.byType(PawMapScreen), findsOneWidget,
          reason: 'la carte revient devant après $nom');
    }

    for (final spec in kPawRailSpecs) {
      await press('rail_${spec.id}', spec.id);
    }
    await press('rail_feed', 'feed');
    await press('pawmap_header_legend', 'legende');
    await press('pawmap_header_search', 'recherche');
    await press('pawmap_header_refresh', 'rafraichir');
    await press('pawmap_header_options', 'options');
    // La roue d'en-tête ouvre la feuille (depuis la 589) : on le mesure.
    await tester.tap(find.byKey(const ValueKey<String>('pawmap_header_options')),
        warnIfMissed: false);
    await _step(tester, '11 options = feuille ouverte', hold: const Duration(seconds: 2));
    final gripVisible =
        find.byKey(const ValueKey<String>('pawmap_sheet_grip')).evaluate().isNotEmpty;
    bilan.add('options → feuille glissante ${gripVisible ? 'OUVERTE (poignée visible)' : 'NON ouverte'}');
    expect(gripVisible, isTrue, reason: 'la roue d\'en-tête ouvre la feuille');
    await closeAll();
    await press('capsule_satellite', 'satellite');
    await press('capsule_everyone', 'tout-le-monde');
    await press('capsule_balade', 'balade');
    await press('capsule_feed', 'signaux');
    await press('capsule_eye', 'oeil');

    debugPrint('[PARCOURS] ===== BILAN =====');
    for (final b in bilan) debugPrint('[PARCOURS] • $b');
    await _step(tester, '99 fin', hold: const Duration(seconds: 1));
    final absents = bilan.where((b) => b.contains('ABSENT')).length;
    debugPrint('[PARCOURS] boutons appuyés : ${bilan.length - absents}, absents : $absents');
  });
}
