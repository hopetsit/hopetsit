// Lot D (25/09/2026) — DEVISE : « même devise et même format partout où un
// prix apparaît, symbole au bon endroit selon la langue » (Daniel).
//
//   1. Règle pure `CurrencyHelper.format` / `formatCompact` : 6 devises
//      (EUR, USD, GBP, CHF, KRW, JPY) × les langues de l'app.
//   2. Profil › Mes tarifs (gardien ET promeneur) : le suffixe de chaque champ
//      de prix est le symbole de la devise du profil (USD → $, GBP → £,
//      EUR → €) et il change IMMÉDIATEMENT quand on change la devise.
//   3. Là où un prix s'affiche : carte gardien et carte promeneur de l'accueil
//      propriétaire, libellé de budget des annonces PawMap : même helper, même
//      devise que la donnée, jamais deux devises.
//
// `lotdSetUp` est appelé dans `setUp` (hors du temps simulé de testWidgets).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/nearby_request_model.dart';
import 'package:hopetsit/models/sitter_model.dart';
import 'package:hopetsit/models/walker_model.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/pet_owner/home/widgets/sitter_card.dart';
import 'package:hopetsit/views/pet_owner/home/widgets/walker_card.dart';
import 'package:hopetsit/views/profile/my_rates_screen.dart';

import 'lotd_harness.dart';

Finder _symbolText(String s) => find.byWidgetPredicate((w) => w is Text && w.data == s);

Map<String, dynamic> Function(dynamic req) _ratesResponder(String currency) => (req) {
      final path = req.url.path as String;
      if (path.contains('/walkers/me/rates')) {
        return <String, dynamic>{
          'walkRates': <Map<String, dynamic>>[
            {'durationMinutes': 30, 'basePrice': 10, 'enabled': true, 'currency': currency},
            {'durationMinutes': 60, 'basePrice': 18, 'enabled': true, 'currency': currency},
          ]
        };
      }
      if (path.contains('/walkers/me')) {
        return <String, dynamic>{'id': 'u-test', 'name': 'Camille', 'currency': currency, 'extraPetRate': 5};
      }
      if (path.contains('/sitters/')) {
        return <String, dynamic>{
          'id': 'u-test', 'name': 'Camille', 'currency': currency,
          'hourlyRate': 12, 'dailyRate': 40, 'weeklyRate': 200, 'monthlyRate': 600,
        };
      }
      return <String, dynamic>{};
    };

void main() {
  group('règle pure — un seul format monétaire', () {
    test('fr : symbole APRÈS, virgule, « 12 € » / « 48,00 € »', () {
      expect(CurrencyHelper.formatCompact('EUR', 12, locale: 'fr'), '12 €');
      expect(CurrencyHelper.formatCompact('USD', 12, locale: 'fr'), '12 \$');
      expect(CurrencyHelper.formatCompact('GBP', 12.5, locale: 'fr'), '12,50 £');
      expect(CurrencyHelper.format('EUR', 48, locale: 'fr'), '48,00 €');
      expect(CurrencyHelper.format('CHF', 48, locale: 'fr'), '48,00 CHF');
      expect(CurrencyHelper.format('KRW', 48000, locale: 'fr'), '48 000 ₩');
    });
    test('en : symbole AVANT, point, « \$12 » / « €48.00 »', () {
      expect(CurrencyHelper.formatCompact('USD', 12, locale: 'en'), '\$12');
      expect(CurrencyHelper.formatCompact('EUR', 12, locale: 'en'), '€12');
      expect(CurrencyHelper.formatCompact('GBP', 12.5, locale: 'en'), '£12.50');
      expect(CurrencyHelper.format('EUR', 48, locale: 'en'), '€48.00');
      expect(CurrencyHelper.format('USD', 1250, locale: 'en'), '\$1,250.00');
      expect(CurrencyHelper.format('CHF', 48, locale: 'en'), 'CHF 48.00');
    });
    test('ko / ja : won et yen sans décimales, symbole avant', () {
      expect(CurrencyHelper.format('KRW', 48000, locale: 'ko'), '₩48,000');
      expect(CurrencyHelper.formatCompact('JPY', 1500, locale: 'ja'), '¥1,500');
      expect(CurrencyHelper.format('JPY', 1500.7, locale: 'ja'), '¥1,501');
    });
    test('les autres langues de l\'app suivent leur convention', () {
      for (final l in <String>['de', 'es', 'it', 'pt', 'pl']) {
        expect(CurrencyHelper.formatCompact('EUR', 12, locale: l), '12 €', reason: l);
      }
    });
    test('le libellé de budget d\'une annonce PawMap passe par le même helper', () {
      Get.locale = const Locale('fr', 'FR');
      final p = NearbyRequestPost.fromJson(<String, dynamic>{
        'id': 'r1', 'budget': 30, 'currency': 'USD', 'lat': 0, 'lng': 0,
      });
      expect(p.budgetLabel, '30 \$');
    });
  });

  group('cartes de l\'accueil propriétaire', () {
    setUp(() async => lotdSetUp(role: 'owner'));

    testWidgets('carte gardien : tarifs dans la devise du gardien (GBP)', (tester) async {
      lotdPhone(tester);
      final sitter = SitterModel.fromJson(<String, dynamic>{
        'id': 's1', 'name': 'Léa', 'email': 'lea@example.test', 'currency': 'GBP',
        'hourlyRate': 12, 'dailyRate': 40, 'weeklyRate': 200,
      });
      await tester.pumpWidget(lotdApp(Scaffold(
          body: SingleChildScrollView(child: SitterCard(sitter: sitter, onTap: () {}, onSendRequest: () {})))));
      await lotdSettle(tester, frames: 3);
      expect(tester.takeException(), isNull);
      expect(find.text('40 £'), findsOneWidget);
      expect(find.text('200 £'), findsOneWidget);
      expect(find.textContaining('€'), findsNothing);
    });

    testWidgets('carte promeneur : tarifs dans la devise du promeneur (USD), plus d\'€ en dur', (tester) async {
      lotdPhone(tester);
      final walker = WalkerModel.fromJson(<String, dynamic>{
        'id': 'w1', 'name': 'Max', 'email': 'max@example.test', 'currency': 'USD',
        'walkRates': <Map<String, dynamic>>[
          {'durationMinutes': 30, 'basePrice': 10, 'enabled': true, 'currency': 'USD'},
          {'durationMinutes': 60, 'basePrice': 18, 'enabled': true, 'currency': 'USD'},
        ],
        'extraPetRate': 5,
      });
      await tester.pumpWidget(lotdApp(Scaffold(
          body: SingleChildScrollView(child: WalkerCard(walker: walker, onTap: () {}, onRequestWalk: () {})))));
      await lotdSettle(tester, frames: 3);
      expect(tester.takeException(), isNull);
      expect(find.text('10 \$'), findsOneWidget);
      expect(find.text('18 \$'), findsOneWidget);
      expect(find.textContaining('€'), findsNothing);
    });
  });

  for (final c in <({String role, String currency, String symbol})>[
    (role: 'sitter', currency: 'USD', symbol: '\$'),
    (role: 'sitter', currency: 'GBP', symbol: '£'),
    (role: 'walker', currency: 'EUR', symbol: '€'),
  ]) {
    group('Profil › Mes tarifs — ${c.role} en ${c.currency}', () {
      setUp(() async {
        await lotdSetUp(role: c.role);
        lotdResponder = _ratesResponder(c.currency);
      });

      testWidgets('suffixe « ${c.symbol} » sur chaque champ, aucune autre devise', (tester) async {
        lotdPhone(tester);
        await tester.pumpWidget(lotdApp(MyRatesScreen(role: c.role)));
        await lotdSettle(tester, frames: 8);
        expect(tester.takeException(), isNull);
        expect(_symbolText(c.symbol), findsWidgets, reason: 'aucun champ de prix avec le suffixe ${c.symbol}');
        for (final other in <String>['€', '\$', '£']) {
          if (other == c.symbol) continue;
          expect(_symbolText(other), findsNothing,
              reason: 'une autre devise ($other) est affichée en même temps que ${c.symbol}');
        }
      });
    });
  }

  group('Profil › Mes tarifs — changement immédiat', () {
    setUp(() async {
      await lotdSetUp(role: 'sitter');
      lotdResponder = _ratesResponder('USD');
    });

    testWidgets('gardien : USD → GBP change tous les suffixes tout de suite', (tester) async {
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(const MyRatesScreen(role: 'sitter')));
      await lotdSettle(tester, frames: 8);
      expect(_symbolText('\$'), findsWidgets);
      final dropdown = find.byWidgetPredicate((w) => w is DropdownButton<String>);
      expect(dropdown, findsOneWidget);
      tester.widget<DropdownButton<String>>(dropdown).onChanged!('GBP');
      await lotdSettle(tester, frames: 2);
      expect(_symbolText('£'), findsWidgets);
      expect(_symbolText('\$'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
