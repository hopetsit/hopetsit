// v571 — pages Réservations des 3 rôles : sélecteur segmenté des 4 onglets
// et fond à motif de pattes.
//
// Ce test monte les widgets SEULS et vérifie :
//   · le sélecteur des 4 onglets tient à 320 dp (le plus petit écran visé)
//     avec des libellés allemands / polonais très longs, SANS débordement ;
//   · un tap sur un onglet rappelle bien sa valeur, et l'onglet actif change
//     d'apparence (pastille pleine à la couleur du rôle) ;
//   · une valeur « lien » (Factures) reste non sélectionnée ;
//   · les compteurs s'affichent ;
//   · `PawPatternBackground` se peint sans exception en clair ET en sombre,
//     laisse passer les taps, et ne se repeint pas sans changement de couleur.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

const Color _kOwnerAccent = Color(0xFFC92A12);

/// Les 4 onglets réels de la page Réservations.
const List<String> _values = <String>['all', 'refunded', 'paid', 'factures'];

/// Libellés VOLONTAIREMENT longs (allemand + polonais) : c'est le pire cas.
const Map<String, String> _longLabels = <String, String>{
  'all': 'Alle Buchungen',
  'refunded': 'Zwrócone płatności',
  'paid': 'Bezahlte Buchungen',
  'factures': 'Rechnungen',
};

Widget _harness(Widget child, {Brightness brightness = Brightness.light}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: child),
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
    // Hors réseau, google_fonts ne peut pas télécharger ses polices : on coupe
    // la récupération, la police par défaut prend le relais.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('BookingSegmentedTabs', () {
    testWidgets('320 dp + libellés longs : aucun débordement', (tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(BookingSegmentedTabs(
        values: _values,
        selected: 'all',
        label: (String v) => _longLabels[v]!,
        icon: bookingTabIcon,
        accent: _kOwnerAccent,
        linkValues: const <String>{'factures'},
        counts: const <String, int>{'paid': 3, 'refunded': 1},
        onSelected: (_) {},
      )));
      await tester.pump(const Duration(milliseconds: 300));

      // Un RenderFlex qui déborde lève une exception captée ici.
      expect(tester.takeException(), isNull);
      expect(find.byType(BookingSegmentedTabs), findsOneWidget);
      // Les 4 onglets sont présents, libellés entiers (pas de troncature).
      for (final String v in _values) {
        expect(find.text(_longLabels[v]!), findsOneWidget, reason: v);
      }
      // Les compteurs sont affichés.
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('un tap change l\'onglet actif', (tester) async {
      _sizeTo320(tester);
      String selected = 'all';
      final List<String> taps = <String>[];

      await tester.pumpWidget(_harness(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) =>
              BookingSegmentedTabs(
            values: _values,
            selected: selected,
            label: (String v) => _longLabels[v]!,
            icon: bookingTabIcon,
            accent: _kOwnerAccent,
            linkValues: const <String>{'factures'},
            onSelected: (String v) {
              taps.add(v);
              if (v == 'factures') return; // ouvre un écran, ne filtre pas
              setState(() => selected = v);
            },
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Au départ « all » est la pastille pleine.
      expect(_pillColor(tester, 'all'), _kOwnerAccent);
      expect(_pillColor(tester, 'paid'), Colors.transparent);

      // À 320 dp la rangée DÉFILE : l'onglet visé peut être hors écran, il
      // faut donc l'amener dans la vue avant de le toucher (ce que fait
      // l'utilisateur d'un glissement, et le widget lui-même à la sélection).
      await tester
          .ensureVisible(find.byKey(const ValueKey<String>('booking_tab_paid')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey<String>('booking_tab_paid')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(taps, <String>['paid']);
      expect(selected, 'paid');
      expect(_pillColor(tester, 'paid'), _kOwnerAccent);
      expect(_pillColor(tester, 'all'), Colors.transparent);
      expect(tester.takeException(), isNull);
    });

    testWidgets('une valeur « lien » ne prend jamais l\'état actif',
        (tester) async {
      _sizeTo320(tester);
      final List<String> taps = <String>[];
      await tester.pumpWidget(_harness(BookingSegmentedTabs(
        values: _values,
        // Même si la sélection vaut « factures », la pastille reste vide :
        // c'est un raccourci vers l'écran Factures, pas un filtre.
        selected: 'factures',
        label: (String v) => _longLabels[v]!,
        icon: bookingTabIcon,
        accent: _kOwnerAccent,
        linkValues: const <String>{'factures'},
        onSelected: taps.add,
      )));
      await tester.pump(const Duration(milliseconds: 300));

      expect(_pillColor(tester, 'factures'), Colors.transparent);
      await tester.ensureVisible(
          find.byKey(const ValueKey<String>('booking_tab_factures')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester
          .tap(find.byKey(const ValueKey<String>('booking_tab_factures')));
      await tester.pump();
      expect(taps, <String>['factures']);
    });

    testWidgets('se construit aussi en mode sombre', (tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(
        BookingSegmentedTabs(
          values: _values,
          selected: 'refunded',
          label: (String v) => _longLabels[v]!,
          icon: bookingTabIcon,
          accent: _kOwnerAccent,
          onSelected: (_) {},
        ),
        brightness: Brightness.dark,
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(_pillColor(tester, 'refunded'), _kOwnerAccent);
    });
  });

  group('Carte de réservation', () {
    for (final Brightness b in Brightness.values) {
      testWidgets('320 dp, nom long + statut long : pas de débordement '
          '(${b.name})', (tester) async {
        _sizeTo320(tester);
        await tester.pumpWidget(_harness(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: BookingCard(
              accent: _kOwnerAccent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const BookingPartyHeader(
                    name: 'Marie-Charlotte de Villeneuve-Saint-Georges',
                    // Pas d'URL : aucun appel réseau dans les tests.
                    subtitle: 'Mehrtägige Tierbetreuung zu Hause',
                    accent: _kOwnerAccent,
                    trailing: BookingStatusChip(
                      status: 'agreed',
                      paymentStatus: 'paid',
                      accent: _kOwnerAccent,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const <Widget>[
                      BookingMetaChip(icon: Icons.pets_rounded, value: 'Rex'),
                      BookingMetaChip(
                          icon: Icons.calendar_today_rounded,
                          value: 'mercredi 24 septembre 2026'),
                      BookingMetaChip(
                          icon: Icons.access_time_rounded, value: '14:30'),
                      BookingMetaChip(
                          icon: Icons.timer_rounded, value: '60 min'),
                    ],
                  ),
                  const BookingCardDivider(),
                  const BookingPriceRow(
                    accent: _kOwnerAccent,
                    amount: 'Tu as payé 48,00 €',
                  ),
                ],
              ),
            ),
          ),
          brightness: b,
        ));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.byType(BookingCard), findsOneWidget);
        expect(find.text('Tu as payé 48,00 €'), findsOneWidget);
        expect(find.text('Rex'), findsOneWidget);
      });
    }
  });

  group('PawPatternBackground', () {
    for (final Brightness b in Brightness.values) {
      testWidgets('se peint sans erreur (${b.name})', (tester) async {
        _sizeTo320(tester);
        await tester.pumpWidget(_harness(
          PawPatternBackground(
            color: _kOwnerAccent,
            child: const Center(child: Text('contenu')),
          ),
          brightness: b,
        ));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        expect(find.byType(PawPatternBackground), findsOneWidget);
        expect(find.text('contenu'), findsOneWidget);
      });
    }

    testWidgets('accepte une colonne avec Expanded (structure des 3 écrans)',
        (tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(PawPatternBackground(
        color: _kOwnerAccent,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 60, child: Text('onglets')),
            Expanded(
              child: ListView(
                children: const <Widget>[Text('ligne 1'), Text('ligne 2')],
              ),
            ),
          ],
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.text('ligne 2'), findsOneWidget);
    });

    testWidgets('ne capte aucun tap : le contenu reste cliquable',
        (tester) async {
      _sizeTo320(tester);
      int taps = 0;
      await tester.pumpWidget(_harness(PawPatternBackground(
        color: _kOwnerAccent,
        child: Center(
          child: GestureDetector(
            onTap: () => taps++,
            child: const SizedBox(
              key: ValueKey<String>('cible'),
              width: 200,
              height: 80,
              child: ColoredBox(color: Color(0xFFFFFFFF)),
            ),
          ),
        ),
      )));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('cible')));
      expect(taps, 1);
    });

    test('shouldRepaint : seulement sur changement de couleur / opacité', () {
      const PawPatternPainter a =
          PawPatternPainter(color: _kOwnerAccent, opacity: 0.05);
      const PawPatternPainter same =
          PawPatternPainter(color: _kOwnerAccent, opacity: 0.05);
      const PawPatternPainter other =
          PawPatternPainter(color: Color(0xFF2563EB), opacity: 0.05);
      const PawPatternPainter fainter =
          PawPatternPainter(color: _kOwnerAccent, opacity: 0.02);
      expect(a.shouldRepaint(same), isFalse);
      expect(a.shouldRepaint(other), isTrue);
      expect(a.shouldRepaint(fainter), isTrue);
    });
  });
}

/// Couleur de fond de la pastille d'un onglet (accent = actif, transparent
/// sinon).
Color? _pillColor(WidgetTester tester, String value) {
  final AnimatedContainer box = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byKey(ValueKey<String>('booking_tab_$value')),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (box.decoration as BoxDecoration?)?.color;
}
