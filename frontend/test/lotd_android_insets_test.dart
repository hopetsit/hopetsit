// v585 (lot D) — écran « Samsung » généralisé (point 4 du lot D) : sur tous les
// écrans qui ancrent un bouton en bas, rien ne doit être caché par la barre de
// navigation système (3 boutons = 48 dp, ou gestes ~20 dp annoncés, ou 0
// annoncé alors que la barre est là — le piège du Samsung de Daniel).
//
// Même méthode que le lot C (`lotc_pawmap_android_insets_test.dart`) : le
// crochet `debugBottomInsetForceAndroid` force la règle Android, on annonce un
// inset de 0 / 20 / 48, et on MESURE que le bas du bouton reste à ≥ 48 px du
// bord bas de l'écran. Écrans mesurés : les sous-pages du Profil
// (`ProfileSubPageScaffold`, 42 écrans), la boîte à idées, la feuille
// « Avant de partir » (suppression de compte), la fiche facture.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/views/profile/idea_box_screen.dart';
import 'package:hopetsit/views/profile/widgets/delete_account_reasons_sheet.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';

import 'lotd_harness.dart';

Widget _withInset(Widget child, double inset) => MediaQuery(
      data: MediaQueryData(
        size: const Size(393, 852),
        viewPadding: EdgeInsets.only(bottom: inset),
        padding: EdgeInsets.only(bottom: inset),
      ),
      child: child,
    );

void main() {
  setUp(() async {
    await lotdSetUp(role: 'owner');
    debugBottomInsetForceAndroid = true;
  });
  tearDown(() => debugBottomInsetForceAndroid = null);

  test('règle unique : Android = jamais moins de 48, iOS = inset réel', () {
    // (les 5 cas de la PawMap du lot C restent dans lotc_pawmap_android_insets_test)
    expect(debugBottomInsetForceAndroid, isTrue);
  });

  for (final double inset in <double>[0, 20, 48]) {
    testWidgets('sous-page Profil (ProfileSubPageScaffold) — barre système annoncée $inset', (tester) async {
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(_withInset(
        ProfileSubPageScaffold(
          title: 'Test',
          accent: const Color(0xFFC92A12),
          body: const SizedBox(height: 200),
          bottom: PawButton(label: 'Enregistrer', onTap: () {}, key: const ValueKey('btn')),
        ),
        inset,
      )));
      await lotdSettle(tester);
      final Rect r = tester.getRect(find.byKey(const ValueKey('btn')));
      expect(852 - r.bottom, greaterThanOrEqualTo(48 + 12 - 0.5),
          reason: 'bouton bas à ${852 - r.bottom} px du bord (inset annoncé $inset)');
    });

    testWidgets('boîte à idées — bouton Envoyer au-dessus de la barre (annoncée $inset)', (tester) async {
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(_withInset(const IdeaBoxScreen(), inset)));
      await lotdSettle(tester);
      final Rect r = tester.getRect(find.widgetWithText(PawButton, 'Envoyer'));
      expect(852 - r.bottom, greaterThanOrEqualTo(48), reason: 'Envoyer à ${852 - r.bottom} px du bord');
    });

    testWidgets('feuille « Avant de partir » — bouton Continuer au-dessus de la barre (annoncée $inset)', (tester) async {
      lotdPhone(tester);
      late BuildContext ctx;
      await tester.pumpWidget(lotdApp(_withInset(
        Scaffold(body: Builder(builder: (c) {
          ctx = c;
          return const SizedBox.expand();
        })),
        inset,
      )));
      await lotdSettle(tester);
      // ignore: unawaited_futures
      showDeleteAccountReasonsSheet(ctx);
      await lotdSettle(tester, frames: 6);
      final buttons = find.byType(PawButton);
      expect(buttons, findsWidgets);
      double lowest = 0;
      for (final e in buttons.evaluate()) {
        final Rect r = tester.getRect(find.byWidget(e.widget));
        if (r.bottom > lowest) lowest = r.bottom;
      }
      expect(852 - lowest, greaterThanOrEqualTo(48), reason: 'bouton le plus bas à ${852 - lowest} px du bord');
    });
  }
}
