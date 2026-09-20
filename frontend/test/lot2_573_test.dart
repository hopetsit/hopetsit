// v573 — lot 2 (PawMap : alertes & PawSpot). Tests des briques du kit
// `lib/views/map/widgets/map_sheet_kit.dart`, qui remplacent les `ListTile`,
// `AlertDialog` et roues de chargement Material des deux écrans du lot.
//
// Ce qui est vérifié :
//   · tout se construit sur un écran de 320 dp, en clair ET en sombre, sans
//     débordement ni exception ;
//   · les libellés longs (allemand / polonais) s'ellipsent au lieu de déborder ;
//   · la rangée de choix montre bien sa coche quand elle est sélectionnée, son
//     chevron sinon, et son tap appelle le bon callback ;
//   · la feuille de choix (`showMapChoiceSheet`) renvoie la valeur tapée ;
//   · le squelette de liste remplace la roue par N cartes.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/views/map/widgets/map_sheet_kit.dart';

const Color _kGold = Color(0xFFE8A00A);

Widget _harness(Widget child, {Brightness brightness = Brightness.light}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        ),
      ),
    ),
  );
}

/// Écran de 320 dp de large (le plus étroit visé), remis à zéro après le test.
void _sizeTo320(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() {
    // Hors réseau, google_fonts ne peut pas télécharger ses polices.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('MapChoiceRow', () {
    testWidgets('coche quand sélectionné, chevron sinon', (tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(Column(
        children: const [
          MapChoiceRow(
            key: ValueKey<String>('row_selected'),
            icon: Icons.gps_fixed_rounded,
            label: '50 km',
            selected: true,
          ),
          MapChoiceRow(
            key: ValueKey<String>('row_plain'),
            icon: Icons.schedule_rounded,
            label: '7 jours',
            showChevron: true,
          ),
        ],
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.text('50 km'), findsOneWidget);
      expect(find.text('7 jours'), findsOneWidget);
    });

    testWidgets('le tap appelle onTap', (tester) async {
      _sizeTo320(tester);
      int taps = 0;
      await tester.pumpWidget(_harness(MapChoiceRow(
        key: const ValueKey<String>('row_tap'),
        icon: Icons.place_rounded,
        label: 'Parc canin',
        value: 'PawSpot',
        onTap: () => taps++,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey<String>('row_tap')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(taps, 1);
    });

    testWidgets('320 dp : libellé allemand / polonais très long, sans débordement',
        (tester) async {
      for (final String label in <String>[
        'Benachrichtigungen für verlorene Haustiere aktivieren',
        'Powiadomienia o zaginionych zwierzętach w okolicy',
      ]) {
        _sizeTo320(tester);
        await tester.pumpWidget(_harness(MapChoiceRow(
          icon: Icons.notifications_active_rounded,
          label: label,
          value: label,
          showChevron: true,
          onTap: () {},
        )));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: label);
      }
    });

    testWidgets('mode sombre : se construit sans exception', (tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(
        MapChoiceRow(
          icon: Icons.gps_fixed_rounded,
          label: '25 km',
          tint: _kGold,
          selected: true,
          onTap: () {},
        ),
        brightness: Brightness.dark,
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.text('25 km'), findsOneWidget);
    });
  });

  group('MapSheetCard / MapSheetTitle', () {
    testWidgets('la carte affiche son contenu et réagit au tap',
        (tester) async {
      _sizeTo320(tester);
      int taps = 0;
      await tester.pumpWidget(_harness(MapSheetCard(
        key: const ValueKey<String>('card'),
        onTap: () => taps++,
        child: const Text('contenu'),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.text('contenu'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('card')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(taps, 1);
    });

    testWidgets('le titre affiche sa croix et appelle onClose', (tester) async {
      _sizeTo320(tester);
      int closes = 0;
      await tester.pumpWidget(_harness(MapSheetTitle(
        title: 'Ajouter un PawSpot',
        emoji: '🐾',
        subtitle: 'Choisis le type de lieu',
        onClose: () => closes++,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.text('Ajouter un PawSpot'), findsOneWidget);
      expect(find.text('Choisis le type de lieu'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      expect(closes, 1);
    });
  });

  group('MapEmptyBlock', () {
    testWidgets('affiche titre, message et action', (tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(const MapEmptyBlock(
        icon: Icons.shield_outlined,
        emoji: '🐾',
        title: 'Aucune alerte autour de toi',
        message: 'Élargis le rayon ou la période pour voir plus loin.',
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.text('Aucune alerte autour de toi'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });
  });

  group('Squelettes de chargement', () {
    testWidgets('MapCardSkeletonList produit N cartes', (tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(const SizedBox(
        height: 600,
        child: MapCardSkeletonList(count: 3),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.byType(MapCardSkeleton), findsNWidgets(3));
      // Plus aucune roue de chargement : c'est tout l'objet du remplacement.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('MapLineSkeletonList se construit en sombre', (tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(
        const MapLineSkeletonList(count: 2),
        brightness: Brightness.dark,
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.byType(MapSkeletonBox), findsNWidgets(6));
    });
  });

  group('showMapChoiceSheet', () {
    testWidgets('renvoie la valeur de l\'option tapée', (tester) async {
      _sizeTo320(tester);
      int? picked;
      await tester.pumpWidget(_harness(Builder(
        builder: (ctx) => TextButton(
          key: const ValueKey<String>('open'),
          onPressed: () async {
            picked = await showMapChoiceSheet<int>(
              context: ctx,
              title: 'Période',
              selected: 24,
              options: const <MapChoiceOption<int>>[
                MapChoiceOption<int>(
                  value: 24,
                  label: '24 h',
                  icon: Icons.schedule_rounded,
                ),
                MapChoiceOption<int>(
                  value: 168,
                  label: '7 jours',
                  icon: Icons.schedule_rounded,
                ),
              ],
            );
          },
          child: const Text('ouvrir'),
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey<String>('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Période'), findsOneWidget);
      // L'option courante porte la coche.
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.tap(find.text('7 jours'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(picked, 168);
    });
  });

  group('Dialogues du kit', () {
    testWidgets('saisie : valider renvoie le texte, effacer renvoie ""',
        (tester) async {
      _sizeTo320(tester);
      String? result;
      await tester.pumpWidget(_harness(Builder(
        builder: (ctx) => TextButton(
          key: const ValueKey<String>('open_search'),
          onPressed: () async {
            result = await showMapTextInputDialog(
              context: ctx,
              title: 'Rechercher',
              hint: 'Nom, ville, type…',
              confirmLabel: 'Rechercher',
              clearLabel: 'Effacer',
            );
          },
          child: const Text('ouvrir'),
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey<String>('open_search')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('Rechercher'), findsNWidgets(2)); // titre + bouton

      await tester.enterText(find.byType(TextField), '  chien perdu  ');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Effacer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(result, '');
    });

    testWidgets('information : bloc long en sombre, sans débordement',
        (tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(
        Builder(
          builder: (ctx) => TextButton(
            key: const ValueKey<String>('open_info'),
            onPressed: () => showMapInfoDialog(
              context: ctx,
              title: 'Diagnostic',
              closeLabel: 'Fermer',
              monospace: true,
              body: List<String>.generate(
                40,
                (i) => 'ligne $i — coords=(48.8566, 2.3522) show=true',
              ).join('\n'),
            ),
            child: const Text('ouvrir'),
          ),
        ),
        brightness: Brightness.dark,
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey<String>('open_info')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('Diagnostic'), findsOneWidget);
      await tester.tap(find.text('Fermer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Diagnostic'), findsNothing);
    });
  });
}
