// v607 (PAM, 01/10/2026) — deux décisions de Daniel :
//  4.4 — bouton rose « tout le monde » de la PawMap = UN seul comportement
//        partout : afficher / masquer TOUS les membres (comme le site), état
//        visible sur le bouton, retenu sur le compte (`layers.everyone`).
//  4.3 — tarif semaine / mois seul (cas GIRMA) compté dans le « dès X € »,
//        TOUJOURS avec son unité.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/pawmap607_i18n.dart';
import 'package:hopetsit/models/sitter_model.dart';
import 'package:hopetsit/views/guest/guest_discovery_screen.dart';
import 'package:hopetsit/views/map/pawmap_rates.dart';
import 'package:hopetsit/views/map/widgets/paw_rail_button.dart';
import 'package:hopetsit/views/map/widgets/pawmap_everyone607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_rail.dart';
import 'package:hopetsit/views/pet_owner/home/widgets/sitter_card.dart';
import 'package:hopetsit/views/service_provider/widgets/provider_action_bar.dart';

const List<String> kLangs = <String>[
  'fr', 'en', 'es', 'de', 'it', 'pt', 'pl', 'ja', 'ko',
];

// GIRMA tel que renvoyé par GET /sitters/6aa1b248505cbf5f66d04ada (serveur
// de production, lu le 01/10/2026) : seulement semaine et mois.
final Map<String, dynamic> girmaJson = <String, dynamic>{
  'id': '6aa1b248505cbf5f66d04ada',
  'name': 'GIRMA',
  'currency': 'EUR',
  'hourlyRate': 0,
  'dailyRate': 0,
  'weeklyRate': 100,
  'monthlyRate': 350,
};

Widget _app(Widget child,
    {String lang = 'fr', Brightness b = Brightness.light}) {
  return ScreenUtilInit(
    key: ValueKey<String>('app_$lang'),
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      key: ValueKey<String>('get_$lang'),
      translations: AppTranslations(),
      locale: Locale(lang),
      theme: ThemeData(brightness: b),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void _size(WidgetTester t) {
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

/// Harnais : le bouton et un faux « calque membres » qui suit la même règle
/// que `_buildMarkers` de la PawMap.
class _Harness extends StatelessWidget {
  _Harness();
  final RxBool everyone = true.obs;
  final RxBool roles = true.obs;
  final RxBool friends = true.obs;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Obx(() => PawEveryoneButton(
            shown: everyone.value,
            onTap: () => everyone.toggle(),
          )),
      Obx(() => pawMembersLayerOn(
                everyone: everyone.value,
                roles: roles.value,
                friends: friends.value)
          ? const Text('MEMBRES', key: ValueKey<String>('members_layer'))
          : const SizedBox.shrink()),
    ]);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('4.4 · bouton rose « tout le monde »', () {
    test('règle du calque : éteint = aucun membre, quelles que soient les pastilles', () {
      for (final r in [true, false]) {
        for (final f in [true, false]) {
          expect(pawMembersLayerOn(everyone: false, roles: r, friends: f), isFalse);
          expect(pawMembersLayerOn(everyone: true, roles: r, friends: f), r || f);
        }
      }
    });

    test('réglage du compte : absent = visible ; false retenu', () {
      expect(pawEveryoneFromLayers(const {}), isTrue);
      expect(pawEveryoneFromLayers(const {'members': true}), isTrue);
      expect(pawEveryoneFromLayers(const {'everyone': false}), isFalse);
      expect(pawEveryoneFromLayers(const {'everyone': true}), isTrue);
      expect(kPawEveryoneLayerKey, 'everyone');
    });

    test('barre de droite : id, ordre et migration 602 inchangés', () {
      expect(kPawCapsuleDefaultOrder,
          ['satellite', 'everyone', 'feed', 'balade', 'eye']);
      expect(normalizeCapsuleOrder(['everyone', 'eye']), ['everyone', 'eye']);
      final spec = pawCapsuleSlotOf('everyone')!;
      expect(spec.labelKey, 'map_members_show');
      expect(spec.helpKey, 'h587_b_members');
    });

    test('mêmes clés et mêmes textes que le site, 9 langues', () {
      final dir = Directory('../website/src/lib/i18n/generated');
      expect(dir.existsSync(), isTrue, reason: 'textes du site introuvables');
      for (final l in kLangs) {
        final site = jsonDecode(File('${dir.path}/$l.json').readAsStringSync())
            as Map<String, dynamic>;
        for (final k in ['map_members_show', 'map_members_hide', 'h587_b_members']) {
          expect(pawmap607I18n[l]![k], isNotEmpty, reason: '$l $k');
          expect(pawmap607I18n[l]![k], site[k], reason: '$l $k ≠ site');
        }
      }
    });

    for (final b in Brightness.values) {
      testWidgets('un appui masque, un appui réaffiche, état lisible ($b)', (t) async {
        _size(t);
        final h = _Harness();
        await t.pumpWidget(_app(h, b: b));
        await t.pump();
        expect(find.byKey(const ValueKey<String>('members_layer')), findsOneWidget);
        expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
        expect(find.bySemanticsLabel('Masquer les membres'), findsOneWidget);
        // Allumé.
        bool active() =>
            t.widget<PawCapsuleButton>(find.byType(PawCapsuleButton)).active;
        expect(active(), isTrue, reason: 'allumé = membres visibles');

        await t.tap(find.byKey(const ValueKey<String>('capsule_everyone')));
        await t.pump(const Duration(milliseconds: 300));
        expect(h.everyone.value, isFalse);
        expect(find.byKey(const ValueKey<String>('members_layer')), findsNothing);
        expect(find.byIcon(Icons.group_off_rounded), findsOneWidget);
        expect(find.bySemanticsLabel('Afficher les membres'), findsOneWidget);
        expect(active(), isFalse, reason: 'éteint');

        await t.tap(find.byKey(const ValueKey<String>('capsule_everyone')));
        await t.pump(const Duration(milliseconds: 300));
        expect(h.everyone.value, isTrue);
        expect(find.byKey(const ValueKey<String>('members_layer')), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('libellé traduit dans les 9 langues (jamais une clé brute)', (t) async {
      _size(t);
      await t.pumpWidget(_app(PawEveryoneButton(shown: false, onTap: () {})));
      await t.pump();
      for (final l in kLangs) {
        Get.locale = Locale(l);
        for (final shown in [true, false]) {
          final k = pawEveryoneLabelKey(shown);
          expect(k.tr, pawmap607I18n[l]![k], reason: '$l $k');
          expect(k.tr, isNot(k), reason: '$l clé brute');
        }
        expect('h587_b_members'.tr, pawmap607I18n[l]!['h587_b_members'], reason: l);
      }
      Get.locale = const Locale('fr');
    });
  });

  group('4.3 · « dès » avec un tarif semaine / mois seul (GIRMA)', () {
    testWidgets('écran invité : « Dès 100 €/sem », jamais « 100 € » nu', (t) async {
      _size(t);
      final out = <String, String>{};
      for (final l in ['en', 'fr']) {
        Get.locale = Locale(l);
        await t.pumpWidget(_app(const SizedBox(), lang: l));
        await t.pump();
        out[l] = guestFromPriceText({...girmaJson, '_role': 'sitter'});
      }
      expect(out['fr'], '100 €/sem');
      expect(out['en'], '100 €/wk');
      // Mois seul ; un tarif heure passe devant ; promeneur ; rien.
      out['m'] = guestFromPriceText(
          {'_role': 'sitter', 'currency': 'EUR', 'monthlyRate': 350});
      out['h'] = guestFromPriceText(
          {'_role': 'sitter', 'currency': 'EUR', 'hourlyRate': 15, 'weeklyRate': 100});
      out['w'] = guestFromPriceText(
          {'_role': 'walker', 'currency': 'EUR', 'weeklyRate': 100});
      out['0'] = guestFromPriceText({'_role': 'sitter', 'currency': 'EUR'});
      expect(out['m'], '350 €/mois');
      expect(out['h'], '15 €', reason: 'un tarif heure passe devant, inchangé');
      expect(out['w'], '', reason: 'un promeneur n\'a pas de tarif semaine');
      expect(out['0'], '');
    });

    testWidgets('profil public : « Réserver · dès 100 €/sem. »', (t) async {
      _size(t);
      final s = SitterModel.fromJson(girmaJson);
      final rates = PawProviderRates(
        currency: s.currency,
        role: 'sitter',
        hourly: s.hourlyRate > 0 ? s.hourlyRate : null,
        daily: s.dailyRate > 0 ? s.dailyRate : null,
        weekly: s.weeklyRate > 0 ? s.weeklyRate : null,
        monthly: s.monthlyRate > 0 ? s.monthlyRate : null,
      );
      await t.pumpWidget(_app(ProviderActionBar(
        role: 'sitter',
        rates: rates,
        onBook: () {},
        onMessage: () {},
      )));
      await t.pump();
      expect(rates.fromLabel, contains('/'));
      expect(find.textContaining('dès 100'), findsOneWidget);
      expect(find.textContaining('/sem'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('accueil propriétaire : carte GIRMA = Semaine 100 € et Mois 350 €', (t) async {
      _size(t);
      final s = SitterModel.fromJson(girmaJson);
      await t.pumpWidget(_app(SingleChildScrollView(
          child: SitterCard(sitter: s, onSendRequest: () {}))));
      await t.pump();
      expect(find.text('card_tariff_week'.tr), findsOneWidget);
      expect(find.text('card_tariff_month'.tr), findsOneWidget);
      expect(find.textContaining('100'), findsWidgets);
      expect(find.textContaining('350'), findsWidgets);
      expect(find.text('card_tariff_day'.tr), findsNothing,
          reason: 'jamais présenté comme un prix au jour');
      expect(t.takeException(), isNull);
    });
  });
}
