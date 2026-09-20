// v573 — lot 3 : helper de dialogue partagé (`showAppConfirmDialog`) et
// rangée de choix maison (`AppChoiceRow`).
//
// Ce test monte le dialogue SEUL sur un écran de 320 dp (le plus petit que
// Daniel puisse avoir en main) et vérifie :
//   · il se construit sans débordement en thème CLAIR comme en SOMBRE ;
//   · les libellés longs (allemand / polonais) ne débordent pas ;
//   · chaque bouton renvoie la bonne valeur (principal = true, secondaire =
//     false) et le retour en arrière renvoie `null` ;
//   · une action destructive prend le rouge `AppColors.errorColor` ;
//   · avec `onConfirm`, le dialogue reste ouvert pendant l'attente (spinner)
//     puis se ferme sur `true` ;
//   · `AppChoiceRow` dessine sa pastille radio et déclenche `onTap`.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

const Color _kSitterAccent = Color(0xFF2563EB);

/// Contexte pris SOUS le `MaterialApp` (un `showDialog` a besoin d'un
/// Navigator au-dessus de lui).
late BuildContext _ctx;

Widget _harness({Brightness brightness = Brightness.light, Widget? body}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Builder(
        builder: (BuildContext c) {
          _ctx = c;
          return Scaffold(body: body ?? const SizedBox.shrink());
        },
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

/// Laisse jouer l'animation d'ouverture du dialogue (les spinners tournent
/// sans fin : jamais de `pumpAndSettle` quand il y en a un à l'écran).
Future<void> _settleDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() {
    // Hors réseau, google_fonts ne peut pas télécharger ses polices : on coupe
    // la récupération, la police par défaut prend le relais.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('showAppConfirmDialog', () {
    testWidgets('320 dp, thème clair et sombre : aucun débordement',
        (WidgetTester tester) async {
      for (final Brightness b in <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        _sizeTo320(tester);
        await tester.pumpWidget(_harness(brightness: b));
        await tester.pump();

        final Future<bool?> result = showAppConfirmDialog(
          _ctx,
          title: 'Supprimer ce message',
          message: 'Ce message sera retiré de la conversation.',
          confirmLabel: 'Supprimer',
          cancelLabel: 'Annuler',
          destructive: true,
          icon: Icons.delete_outline_rounded,
          accent: _kSitterAccent,
        );
        await _settleDialog(tester);

        expect(tester.takeException(), isNull, reason: 'thème $b');
        expect(find.byType(AppDialogCard), findsOneWidget);
        expect(find.text('Supprimer ce message'), findsOneWidget);
        expect(find.text('Ce message sera retiré de la conversation.'),
            findsOneWidget);
        expect(find.byType(CustomButton), findsNWidgets(2));

        // Action destructive → bouton principal rouge.
        final CustomButton primary =
            tester.widget<CustomButton>(find.byType(CustomButton).first);
        expect(primary.bgColor, AppColors.errorColor);

        await tester.tap(find.text('Annuler'));
        await _settleDialog(tester);
        expect(await result, isFalse);
      }
    });

    testWidgets('libellés longs (de / pl) : aucun débordement',
        (WidgetTester tester) async {
      const List<List<String>> samples = <List<String>>[
        <String>[
          'Benachrichtigungseinstellungen zurücksetzen',
          'Möchtest du dieses Haustierprofil wirklich unwiderruflich löschen?',
          'Endgültig löschen',
          'Abbrechen',
        ],
        <String>[
          'Nieodwracalne usunięcie wiadomości',
          'Czy na pewno chcesz trwale usunąć tę wiadomość z rozmowy?',
          'Usuń bezpowrotnie',
          'Anuluj',
        ],
      ];
      for (final List<String> s in samples) {
        _sizeTo320(tester);
        await tester.pumpWidget(_harness());
        await tester.pump();

        final Future<bool?> result = showAppConfirmDialog(
          _ctx,
          title: s[0],
          message: s[1],
          confirmLabel: s[2],
          cancelLabel: s[3],
          icon: Icons.warning_amber_rounded,
          accent: _kSitterAccent,
        );
        await _settleDialog(tester);
        expect(tester.takeException(), isNull, reason: s[0]);
        expect(find.text(s[0]), findsOneWidget);

        await tester.tap(find.text(s[2]));
        await _settleDialog(tester);
        expect(await result, isTrue);
      }
    });

    testWidgets('le bouton principal renvoie true, le retour renvoie null',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness());
      await tester.pump();

      Future<bool?> result = showAppConfirmDialog(
        _ctx,
        title: 'Bloquer cette personne',
        message: 'Elle ne pourra plus t’écrire.',
        confirmLabel: 'Bloquer',
        cancelLabel: 'Annuler',
        destructive: true,
        icon: Icons.block_rounded,
      );
      await _settleDialog(tester);
      await tester.tap(find.text('Bloquer'));
      await _settleDialog(tester);
      expect(await result, isTrue);

      // Fermeture sans choisir (tap à côté) → null.
      result = showAppConfirmDialog(
        _ctx,
        title: 'Bloquer cette personne',
        message: 'Elle ne pourra plus t’écrire.',
        confirmLabel: 'Bloquer',
        cancelLabel: 'Annuler',
      );
      await _settleDialog(tester);
      Navigator.of(_ctx).pop();
      await _settleDialog(tester);
      expect(await result, isNull);
    });

    testWidgets('sans libellé d’annulation : un seul bouton',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness());
      await tester.pump();

      final Future<bool?> result = showAppConfirmDialog(
        _ctx,
        title: 'Information',
        message: 'Message seul.',
        confirmLabel: 'OK',
      );
      await _settleDialog(tester);
      expect(find.byType(CustomButton), findsOneWidget);
      await tester.tap(find.text('OK'));
      await _settleDialog(tester);
      expect(await result, isTrue);
    });

    testWidgets('onConfirm : attente visible puis fermeture sur true',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness());
      await tester.pump();

      final Completer<void> gate = Completer<void>();
      final Future<bool?> result = showAppConfirmDialog(
        _ctx,
        title: 'Mon profil gardien',
        message: 'Veux-tu passer sur ce profil ?',
        busyMessage: 'Changement de profil en cours…',
        confirmLabel: 'Continuer',
        cancelLabel: 'Annuler',
        accent: _kSitterAccent,
        barrierDismissible: false,
        onConfirm: () => gate.future,
      );
      await _settleDialog(tester);

      await tester.tap(find.text('Continuer'));
      await tester.pump();
      // Pendant l'attente : message « busy », spinner, dialogue encore ouvert.
      expect(find.text('Changement de profil en cours…'), findsOneWidget);
      expect(find.byType(AppSpinner), findsOneWidget);
      expect(find.byType(AppDialogCard), findsOneWidget);

      gate.complete();
      await _settleDialog(tester);
      expect(await result, isTrue);
      expect(find.byType(AppDialogCard), findsNothing);
    });
  });

  group('AppChoiceRow', () {
    testWidgets('coche la ligne choisie et déclenche onTap',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      final List<String> taps = <String>[];
      await tester.pumpWidget(_harness(
        body: Column(
          children: <Widget>[
            AppChoiceRow(
              key: const ValueKey<String>('row_light'),
              label: 'Clair',
              icon: Icons.light_mode_rounded,
              accent: _kSitterAccent,
              selected: true,
              onTap: () => taps.add('light'),
            ),
            AppChoiceRow(
              key: const ValueKey<String>('row_dark'),
              label: 'Systemeinstellung übernehmen (sehr langer Eintrag)',
              leadingText: '🇩🇪',
              accent: _kSitterAccent,
              selected: false,
              onTap: () => taps.add('dark'),
            ),
          ],
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('Clair'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('row_dark')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey<String>('row_light')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(taps, <String>['dark', 'light']);
    });
  });
}
