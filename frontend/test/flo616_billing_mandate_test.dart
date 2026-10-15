// 616 (FLO, 15/10/2026, demande Daniel du 10/10) — mandat de facturation au
// premier retrait (`billing_mandate_consent.dart`) :
//   · jamais accepté : case obligatoire, bouton INACTIF tant qu'elle n'est pas
//     cochée, ACTIF une fois cochée, et le retrait signale que le mandat vient
//     d'être coché (le serveur l'enregistre avant le retrait) ;
//   · déjà accepté (`billingMandateAcceptedAt` renseigné) : rappel « Mandat
//     accepté le … » seul, aucune case, bouton actif directement ;
//   · les 9 langues ont les 3 clés.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/wallet/billing_mandate_consent.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'lotd_harness.dart';

const _button = Key('flo616_gate');

Widget _gate({DateTime? acceptedAt, required List<bool> calls, bool loading = false}) {
  return Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: BillingMandateWithdrawGate(
        key: _button,
        acceptedAt: acceptedAt,
        acceptedVersion: acceptedAt == null ? '' : '2.4',
        currentVersion: '2.4',
        accent: const Color(0xFFC92A12),
        buttonLabel: 'Confirmer le retrait',
        loading: loading,
        onConfirm: ({required bool mandateJustChecked}) async {
          calls.add(mandateJustChecked);
        },
      ),
    ),
  );
}

PawButton _paw(WidgetTester tester) => tester.widget<PawButton>(find.byType(PawButton));

void main() {
  setUp(() async {
    await lotdSetUp(role: 'sitter');
    await initializeDateFormatting('fr');
  });

  testWidgets('mandat jamais accepté : case affichée, bouton INACTIF', (tester) async {
    lotdPhone(tester);
    final calls = <bool>[];
    await tester.pumpWidget(lotdApp(_gate(calls: calls)));
    await lotdSettle(tester);
    expect(find.byKey(const Key('billing_mandate_checkbox')), findsOneWidget);
    expect(find.byKey(const Key('billing_mandate_reminder')), findsNothing);
    expect(find.textContaining('CARDELLI HERMANOS LIMITED'), findsOneWidget);
    expect(_paw(tester).enabled, isFalse);
    expect(_paw(tester).onTap, isNull);
    await tester.tap(find.text('Confirmer le retrait'), warnIfMissed: false);
    await lotdSettle(tester);
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('case cochée → bouton ACTIF, le retrait sait que le mandat vient d’être coché', (tester) async {
    lotdPhone(tester);
    final calls = <bool>[];
    await tester.pumpWidget(lotdApp(_gate(calls: calls)));
    await lotdSettle(tester);
    await tester.tap(find.byKey(const Key('billing_mandate_checkbox')));
    await lotdSettle(tester);
    expect(_paw(tester).enabled, isTrue);
    expect(_paw(tester).onTap, isNotNull);
    await tester.tap(find.text('Confirmer le retrait'));
    await lotdSettle(tester);
    expect(calls, [true]);
    // Décocher → de nouveau inactif.
    await tester.tap(find.byKey(const Key('billing_mandate_checkbox')));
    await lotdSettle(tester);
    expect(_paw(tester).enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mandat déjà accepté : rappel seul (date + version), pas de case, bouton actif', (tester) async {
    lotdPhone(tester);
    final calls = <bool>[];
    await tester.pumpWidget(lotdApp(_gate(acceptedAt: DateTime(2026, 10, 15, 9, 30), calls: calls)));
    await lotdSettle(tester);
    expect(find.byKey(const Key('billing_mandate_checkbox')), findsNothing);
    expect(find.byKey(const Key('billing_mandate_reminder')), findsOneWidget);
    expect(find.textContaining('Mandat de facturation accepté le'), findsOneWidget);
    expect(find.textContaining('15 oct. 2026'), findsOneWidget);
    expect(find.textContaining('v2.4'), findsOneWidget);
    expect(_paw(tester).enabled, isTrue);
    await tester.tap(find.text('Confirmer le retrait'));
    await lotdSettle(tester);
    expect(calls, [false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en cours d’envoi : bouton inactif même mandat accepté', (tester) async {
    lotdPhone(tester);
    final calls = <bool>[];
    await tester.pumpWidget(lotdApp(_gate(acceptedAt: DateTime(2026, 10, 15), calls: calls, loading: true)));
    await lotdSettle(tester);
    expect(_paw(tester).onTap, isNull);
    expect(tester.takeException(), isNull);
  });

  test('les 9 langues ont les 3 clés du mandat', () {
    final keys = AppTranslations().keys;
    for (final lang in ['fr_FR', 'en_US', 'es_ES', 'de_DE', 'it_IT', 'pt_PT', 'ko_KR', 'ja_JP', 'pl_PL']) {
      final map = keys.entries.firstWhere((e) => e.key.startsWith(lang.split('_').first)).value;
      for (final k in ['wallet_mandate_checkbox', 'wallet_mandate_accepted_on', 'wallet_mandate_required']) {
        expect(map[k], isNotNull, reason: '$lang $k');
        expect(map[k]!.contains('CARDELLI HERMANOS LIMITED') || k != 'wallet_mandate_checkbox', isTrue, reason: '$lang $k');
      }
      expect(map['wallet_mandate_accepted_on'], contains('@date'), reason: lang);
      expect(map['wallet_mandate_accepted_on'], contains('@version'), reason: lang);
    }
  });
}
