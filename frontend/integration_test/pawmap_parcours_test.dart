// v584 — lot C du chantier du 24/09 : PARCOURS PAWMAP SUR LE SIMULATEUR.
//
// Méthode imposée (une tâche planifiée ne peut pas toucher l'écran) :
//   xcrun simctl location <udid> set 48.8566,2.3522
//   flutter test integration_test/pawmap_parcours_test.dart -d <udid>
// Le test monte la VRAIE PawMap (une seule GoogleMap, fusion du lot C) dans
// l'app minimale (dépendances de production, sans compte = mode invité), puis
// appuie sur CHAQUE bouton du rail, de l'en-tête, de la feuille glissante et
// du dock, et vérifie ce qui s'ouvre. Chaque étape est annoncée par
// `debugPrint('[PARCOURS] …')` et laisse 2 s à l'écran : un script prend des
// captures pendant ce temps (`xcrun simctl io <udid> screenshot`).
//
// Ce que ce parcours ne peut PAS prouver (à vérifier avec Daniel) : le geste
// de pincement, la fluidité ressentie, les épingles de membres (elles
// demandent un compte connecté).

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
import 'package:hopetsit/views/map/alerts_screen.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:hopetsit/views/pet_owner/chat/chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_chat_screen.dart';
import 'package:hopetsit/views/map/widgets/pawmap_rail.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:integration_test/integration_test.dart';

Future<void> _step(WidgetTester tester, String name,
    {Duration hold = const Duration(seconds: 2)}) async {
  debugPrint('[PARCOURS] ${DateTime.now().toIso8601String()} $name');
  await tester.pump(hold);
}

/// Ferme ce qui est ouvert (feuille modale ou écran empilé) par la touche
/// retour du navigateur, puis attend que la carte soit de nouveau devant.
Future<void> _closeTop(WidgetTester tester) async {
  // Un écran EMPILÉ (chat, signaux) est opaque : la carte reste dans l'arbre
  // mais hors scène → skipOffstage: false, sinon elle est « introuvable ».
  final nav = Navigator.of(
      tester.element(find.byType(PawMapScreen, skipOffstage: false).first));
  if (nav.canPop()) nav.pop();
  await tester.pump(const Duration(milliseconds: 600));
  // La carte est de nouveau devant.
  expect(find.byType(PawMapScreen), findsOneWidget,
      reason: 'la carte revient devant après la fermeture');
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

  testWidgets('PawMap — chaque bouton du rail, de l\'en-tête, de la feuille et du dock',
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
    // La carte native et le GPS ont besoin de quelques secondes ; la
    // fenêtre iOS « Autoriser la position » (installation neuve) peut aussi
    // retenir l'app : on attend jusqu'à 90 s que la feuille soit posée.
    await _step(tester, '00 ouverture de la carte', hold: const Duration(seconds: 4));
    for (var i = 0; i < 90; i++) {
      if (find.byKey(const ValueKey<String>('pawmap_sheet_grip')).evaluate().isNotEmpty) break;
      await tester.pump(const Duration(seconds: 1));
    }
    await _step(tester, '00b carte posee', hold: const Duration(seconds: 3));
    // Découverte guidée (3 bulles au 1er lancement) : on la parcourt, ce qui
    // libère l'écran pour la suite.
    for (var i = 0; i < 3; i++) {
      final next = find.byKey(const ValueKey<String>('coach_next'));
      if (next.evaluate().isEmpty) break;
      await tester.tap(next);
      await _step(tester, '00c decouverte guidee, bulle ${i + 1}',
          hold: const Duration(milliseconds: 900));
    }
    expect(find.byKey(const ValueKey<String>('pawmap_coach')), findsNothing,
        reason: 'la découverte guidée se termine après 3 bulles');
    expect(find.byType(GoogleMap), findsOneWidget, reason: 'UNE seule GoogleMap');
    expect(find.byKey(const ValueKey<String>('pawmap_google_map')), findsOneWidget);
    Size? sz(Finder f) {
      try {
        return tester.getSize(f.first);
      } catch (e) {
        return null;
      }
    }
    debugPrint('[PARCOURS] tailles: ecran=${sz(find.byType(PawMapScreen))} '
        'scaffold=${sz(find.byType(Scaffold))} stack=${sz(find.byType(Stack))} '
        'map=${sz(find.byType(GoogleMap))} '
        'view=${tester.view.physicalSize} dpr=${tester.view.devicePixelRatio} '
        'header=${find.text('PawMap').evaluate().length} '
        'exception0=${tester.takeException()}');
    final mapKey = find.byKey(const ValueKey<String>('pawmap_google_map'));
    final stacks = find.byType(Stack).evaluate().toList();
    final buf = StringBuffer();
    for (var i = 0; i < stacks.length && i < 12; i++) {
      final ro = stacks[i].renderObject as RenderBox?;
      final hasMap = find
          .descendant(of: find.byWidget(stacks[i].widget), matching: mapKey)
          .evaluate()
          .isNotEmpty;
      buf.write('S$i=${ro?.hasSize == true ? ro!.size : 'nosize'}${hasMap ? '*' : ''} ');
    }
    debugPrint('[PARCOURS] stacks: $buf');
    debugPrint('[PARCOURS] header=${sz(find.text('PawMap'))} '
        'sheet=${sz(find.byType(PawMapSheet))} '
        'drag=${sz(find.byType(DraggableScrollableSheet))} '
        'rail=${sz(find.byKey(const ValueKey<String>('rail_around')))} '
        'primary=${find.byKey(const ValueKey<String>('pawmap_primary')).evaluate().length}');
    debugPrint('[PARCOURS] feuille: ${find.byType(PawMapSheet).evaluate().length} '
        'draggable: ${find.byType(DraggableScrollableSheet).evaluate().length} '
        'grip: ${find.byKey(const ValueKey<String>('pawmap_sheet_grip')).evaluate().length} '
        'exception: ${tester.takeException()}');
    expect(find.byKey(const ValueKey<String>('pawmap_sheet_grip')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('pawmap_primary')), findsOneWidget);

    // ── En-tête : « ? » (légende), recherche de ville ──
    await tester.tap(find.byKey(const ValueKey<String>('pawmap_header_legend')));
    await _step(tester, '01 legende ouverte');
    // Écran réutilisable « Comprendre la PawMap » (Daniel, 25/09).
    expect(find.byType(PawMapHelpScreen), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('legend_me')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('help_rail_around'), skipOffstage: false),
        findsOneWidget);
    // « Voir sur la carte » ramène à la carte.
    final seeMap = find.byKey(const ValueKey<String>('pawmap_help_see_map'));
    await tester.ensureVisible(seeMap);
    await tester.tap(seeMap);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(PawMapHelpScreen), findsNothing);
    expect(find.byType(PawMapScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('pawmap_header_search')));
    await _step(tester, '02 recherche de ville');
    expect(find.byType(TextField), findsWidgets);
    await _closeTop(tester);

    // ── Rail : chaque bouton, dans l'ordre affiché ──
    final railState = tester.state<State<PawMapScreen>>(find.byType(PawMapScreen));
    expect(railState, isNotNull);
    final order = <String>[];
    for (final spec in kPawRailSpecs) {
      if (find.byKey(ValueKey<String>('rail_${spec.id}')).evaluate().isNotEmpty) {
        order.add(spec.id);
      }
    }
    expect(order.length, greaterThanOrEqualTo(6), reason: 'rail visible : $order');

    Future<void> tapRail(String id) async {
      final f = find.byKey(ValueKey<String>('rail_$id'));
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pump(const Duration(milliseconds: 700));
    }

    if (order.contains('around')) {
      await tapRail('around');
      await _step(tester, '03 autour de moi');
      expect(find.text('pawmap_around_title'.tr), findsOneWidget);
      await _closeTop(tester);
    }
    if (order.contains('directions')) {
      await tapRail('directions');
      await _step(tester, '04 itineraire : viseur');
      expect(find.text('pawmap_pick_title_route'.tr), findsOneWidget);
      // Annuler le viseur (retour).
      await tester.tap(find.text('pawspot_pick_cancel'.tr));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('pawmap_pick_title_route'.tr), findsNothing);
    }
    if (order.contains('live_friends')) {
      await tapRail('live_friends');
      await _step(tester, '05 amis en direct');
      expect(find.text('v565_live_friends_title'.tr), findsWidgets);
      await _closeTop(tester);
    }
    if (order.contains('chat')) {
      await tapRail('chat');
      await _step(tester, '06 chat du cercle');
      // Le chat est un écran empilé (avec retour, v553) : la carte reste
      // dans l'arbre, derrière lui.
      expect(find.byType(PawMapScreen, skipOffstage: false), findsOneWidget);
      expect(
          find.byType(ChatScreen, skipOffstage: false).evaluate().isNotEmpty ||
              find.byType(SitterChatScreen, skipOffstage: false)
                  .evaluate()
                  .isNotEmpty,
          isTrue,
          reason: 'le chat du cercle est ouvert');
      await _closeTop(tester);
    }
    if (order.contains('spots')) {
      await tapRail('spots');
      await _step(tester, '07 liste des PawSpots');
      await _closeTop(tester);
    }
    if (order.contains('tag')) {
      await tapRail('tag');
      await _step(tester, '08 marquer un lieu : viseur');
      expect(find.text('pawmap_pick_title_spot'.tr), findsOneWidget);
      await tester.tap(find.text('pawspot_pick_cancel'.tr));
      await tester.pump(const Duration(milliseconds: 600));
    }
    if (order.contains('report')) {
      await tapRail('report');
      await _step(tester, '09 signaler : viseur');
      expect(find.text('pawmap_pick_title_report'.tr), findsOneWidget);
      await tester.tap(find.text('pawspot_pick_cancel'.tr));
      await tester.pump(const Duration(milliseconds: 600));
    }
    if (order.contains('feed')) {
      await tapRail('feed');
      await _step(tester, '10 voir signaux');
      expect(find.byType(AlertsScreen, skipOffstage: false), findsOneWidget,
          reason: 'la liste des signaux est ouverte');
      await _closeTop(tester);
    }

    // Appui long = explication ; « personnaliser » = menu.
    // Le rail défile sur petit écran : ramener le 1er bouton à l'écran.
    await tester.ensureVisible(find.byKey(ValueKey<String>('rail_${order.first}')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.longPress(find.byKey(ValueKey<String>('rail_${order.first}')));
    await _step(tester, '11 explication du bouton (appui long)');
    expect(find.byType(PawRailHelpSheet), findsOneWidget);
    await _closeTop(tester);
    await tester.ensureVisible(find.byKey(const ValueKey<String>('rail_customize')));
    await tester.tap(find.byKey(const ValueKey<String>('rail_customize')));
    await _step(tester, '12 personnaliser le rail');
    expect(find.byType(PawRailCustomizeSheet), findsOneWidget);
    await _closeTop(tester);

    // ── Feuille glissante : basse → haute, sélecteur, dock, abonnements ──
    final grip = find.byKey(const ValueKey<String>('pawmap_sheet_grip'));
    final sheetCtl = tester
        .widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet))
        .controller!;
    // Le défilement DE LA FEUILLE (le rail a le sien).
    final sheetScroll = find
        .descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(Scrollable))
        .first;
    Future<void> reveal(Finder f) async {
      if (f.evaluate().isEmpty) {
        // La liste est paresseuse : l'élément n'existe pas tant qu'il est
        // hors de la fenêtre → on fait défiler jusqu'à lui.
        // v585 (lot D, émulateur Android) : selon l'appareil le geste de
        // montée fait aussi défiler la liste, et l'élément peut être
        // AU-DESSUS de la fenêtre → on cherche d'abord vers le haut.
        try {
          await tester.scrollUntilVisible(f, -120,
              scrollable: sheetScroll, maxScrolls: 30);
        } catch (_) {
          await tester.scrollUntilVisible(f, 120, scrollable: sheetScroll);
        }
      }
      await tester.ensureVisible(f);
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Geste réel de glissement sur la poignée ; si le geste synthétique n'est
    // pas pris (binding « live »), on le dit et on pilote le contrôleur.
    await tester.drag(grip, const Offset(0, -520));
    await tester.pump(const Duration(milliseconds: 700));
    if (sheetCtl.size < 0.6) {
      debugPrint('[PARCOURS] geste de glissement non pris (size=${sheetCtl.size}) → jumpTo');
      sheetCtl.jumpTo(0.9);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await _step(tester, '13 feuille glissante en haut');
    expect(sheetCtl.size, greaterThan(0.6), reason: 'feuille en haut');
    // La feuille haute s'arrête SOUS l'en-tête et la rangée Partager/Agrandir.
    final sheetTop = tester.getTopLeft(find.byType(DraggableScrollableSheet)).dy +
        (1 - sheetCtl.size) * tester.getSize(find.byType(DraggableScrollableSheet)).height;
    final rowBottom = tester.getBottomLeft(find.text('pawmap_live_share_off'.tr).first).dy;
    debugPrint('[PARCOURS] feuille haute: top=$sheetTop, bas de la rangee=$rowBottom');
    expect(sheetTop, greaterThanOrEqualTo(rowBottom - 1),
        reason: 'la feuille ne passe pas sous la rangée du haut');
    expect(find.byKey(const ValueKey<String>('looking_sitters')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('looking_sitters')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey<String>('looking_sitters')));
    await _step(tester, '14 je cherche : gardiens puis tout');
    await reveal(find.byKey(const ValueKey<String>('dock_layers')));
    await tester.tap(find.byKey(const ValueKey<String>('dock_layers')));
    await _step(tester, '15 calques');
    expect(find.text('pawmap_layer_members'.tr), findsOneWidget);
    await _closeTop(tester);
    await reveal(find.byKey(const ValueKey<String>('dock_night')));
    await tester.tap(find.byKey(const ValueKey<String>('dock_night')));
    await _step(tester, '16 mode nuit');
    await tester.tap(find.byKey(const ValueKey<String>('dock_night')));
    await tester.pump(const Duration(milliseconds: 400));
    await reveal(find.byKey(const ValueKey<String>('pawmap_counter_tap')));
    await tester.tap(find.byKey(const ValueKey<String>('pawmap_counter_tap')));
    await _step(tester, '17 compteur : liste autour de toi');
    expect(find.byType(PawMapAroundList), findsOneWidget);
    await _closeTop(tester);
    // Feuille redescendue (geste sur la liste de la feuille : elle remonte
    // d'abord en haut de son contenu puis la feuille descend ; sinon
    // contrôleur).
    await tester.drag(sheetScroll, const Offset(0, 900));
    await tester.pump(const Duration(milliseconds: 700));
    if (sheetCtl.size > 0.3) {
      await tester.drag(sheetScroll, const Offset(0, 900));
      await tester.pump(const Duration(milliseconds: 700));
    }
    if (sheetCtl.size > 0.3) {
      debugPrint('[PARCOURS] geste de descente non pris (size=${sheetCtl.size}) → jumpTo');
      final low = tester.widget<DraggableScrollableSheet>(
              find.byType(DraggableScrollableSheet))
          .minChildSize;
      sheetCtl.jumpTo(low);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await _step(tester, '18 feuille redescendue');
    expect(sheetCtl.size, lessThan(0.3), reason: 'feuille en bas');

    // ── Carte agrandie : dock + bouton retour ──
    final expandPill = find.text('pawmap_expand_short'.tr);
    if (expandPill.evaluate().isNotEmpty) {
      await tester.tap(expandPill.first);
      await _step(tester, '19 carte agrandie (dock)');
      expect(find.byKey(const ValueKey<String>('dock_sos')), findsOneWidget);
      expect(find.byType(GoogleMap), findsOneWidget, reason: 'toujours UNE carte');
      await tester.tap(find.text('pawmap_reduce_map'.tr).first);
      await _step(tester, '20 carte reduite');
      expect(find.byKey(const ValueKey<String>('pawmap_sheet_grip')), findsOneWidget);
    }

    // ── Bouton principal (sans compte : inscription) ──
    await tester.tap(find.byKey(const ValueKey<String>('pawmap_primary')));
    await _step(tester, '21 bouton principal');
    await _closeTop(tester);
    await _step(tester, '22 fin', hold: const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
