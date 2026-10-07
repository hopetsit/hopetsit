// v613 — la commission affichée dans l'app suit le VRAI taux du serveur
// (15 % pour un prestataire Top, 20 % sinon) : écran « Envoyer une demande »
// (`send_request_screen.dart`) et facture PDF (`invoice_pdf_generator.dart`).
// Le taux vient de `GET /pricing/commission-rate` (même fonction serveur que la
// réservation) ; tant qu'il n'est pas connu, aucun total ni pourcentage.
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/send_request_controller.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/utils/commission_rate.dart';
import 'package:hopetsit/views/service_provider/send_request_screen.dart';

import 'lotd_harness.dart';

Future<void> _openFor(WidgetTester tester, String providerId) async {
  lotdPhone(tester, height: 4000);
  await tester.pumpWidget(lotdApp(SendRequestScreen(
    serviceProviderName: 'Paul',
    serviceProviderId: providerId,
    serviceProviderRole: 'sitter',
    sitterDailyRate: 100,
    currencyCode: 'EUR',
    initialServiceType: 'pet_sitting',
  )));
  await lotdSettle(tester);
  final c = Get.find<SendRequestController>(tag: 'send_request_$providerId');
  final start = DateTime.now().add(const Duration(days: 10));
  c.startDate.value = DateTime(start.year, start.month, start.day);
  c.endDate.value = DateTime(start.year, start.month, start.day + 1);
  await lotdSettle(tester);
}

void _serverRate(Object? rate) {
  lotdResponder = (req) => req.url.path.endsWith('/pricing/commission-rate')
      ? <String, dynamic>{'commissionRate': rate}
      : <String, dynamic>{};
}

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));

  testWidgets('prestataire normal : 100 € → 120 € payés, commission (20%)', (tester) async {
    _serverRate(0.2);
    await _openFor(tester, 'aaaaaaaaaaaaaaaaaaaaaa01');
    final call = lotdRequests.where((r) => r.path.endsWith('/pricing/commission-rate')).toList();
    expect(call, hasLength(1));
    expect(call.first.query, {'providerId': 'aaaaaaaaaaaaaaaaaaaaaa01', 'role': 'sitter'});
    expect(find.text('120.00 EUR'), findsWidgets);
    expect(find.text('Commission HoPetSit (20%)'), findsOneWidget);
    expect(find.textContaining('(20%)'), findsWidgets);
    expect(find.textContaining('(15%)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prestataire Top : 100 € → 115 € payés, commission (15%)', (tester) async {
    _serverRate(0.15);
    await _openFor(tester, 'aaaaaaaaaaaaaaaaaaaaaa02');
    expect(find.text('115.00 EUR'), findsWidgets);
    expect(find.text('120.00 EUR'), findsNothing);
    expect(find.text('Commission HoPetSit (15%)'), findsOneWidget);
    expect(find.textContaining('(20%)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('taux inconnu (serveur muet) : « À confirmer », aucun pourcentage', (tester) async {
    _serverRate(null);
    await _openFor(tester, 'aaaaaaaaaaaaaaaaaaaaaa03');
    expect(find.text('À confirmer'), findsOneWidget);
    expect(find.textContaining('EUR'), findsNothing);
    expect(find.textContaining('%)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('utilitaire', () {
    test('pourcentage affiché', () {
      expect(commissionPercentLabel(0.2), '20');
      expect(commissionPercentLabel(0.15), '15');
      expect(commissionPercentLabel(0.175), '17.5');
      expect(parseCommissionRate(0), isNull);
      expect(parseCommissionRate(1), isNull);
      expect(parseCommissionRate('0.15'), 0.15);
    });

    test('facture PDF : 15/20 reconnus, le reste sans pourcentage, 9 langues', () {
      final keys = AppTranslations().keys;
      for (final l in keys.keys) {
        final tpl = keys[l]!['invoice_pdf_commission'];
        if (tpl == null) continue;
        expect(tpl, contains('@percent'), reason: l);
        expect(commissionLabel(tpl, invoiceCommissionRate(15, 100)), contains('15'), reason: l);
        expect(commissionLabel(tpl, invoiceCommissionRate(20, 100)), contains('20'), reason: l);
        final none = commissionLabel(tpl, invoiceCommissionRate(24, 96));
        expect(none, isNot(contains('%')), reason: l);
        expect(none, isNot(contains('@')), reason: l);
        expect(none.trim(), isNotEmpty, reason: l);
      }
    });

    test('les 4 libellés de l\'écran ont @percent et plus de « 20 » figé, 9 langues', () {
      final keys = AppTranslations().keys;
      final langs = <String>{};
      for (final l in keys.keys) {
        for (final k in const [
          'send_request_breakdown_walk',
          'send_request_breakdown_days_one',
          'send_request_breakdown_days_many',
          'send_request_commission_label',
          'invoice_pdf_commission',
        ]) {
          final v = keys[l]![k];
          if (v == null) continue;
          langs.add(l.split('_').first);
          expect(v, contains('@percent'), reason: '$l $k');
          expect(RegExp(r'20\s?[%％]').hasMatch(v), isFalse, reason: '$l $k');
        }
      }
      expect(langs, containsAll(<String>['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']));
    });
  });
}
