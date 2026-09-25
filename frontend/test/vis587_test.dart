// v587 — Daniel : « ces 2 options doivent être claires ». Partout où l'on
// choisit « Qui me voit sur la carte », chaque option a un TITRE et une
// PHRASE explicite (vis587_i18n), en français et en japonais, à 320 px :
//   · feuille « Qui me voit » de la PawMap ;
//   · Profil › Préférences ;
//   · œil de la capsule (libellé d'accessibilité / infobulle).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/localization/v565/vis587_i18n.dart';
import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:hopetsit/views/profile/widgets/profile_settings_tabs.dart';

import 'lotd_harness.dart';

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));

  for (final lang in const ['fr', 'ja']) {
    final locale = lang == 'fr' ? const Locale('fr', 'FR') : const Locale('ja', 'JP');
    final v = vis587I18n[lang]!;

    testWidgets('$lang : feuille « Qui me voit » = 3 titres + 3 phrases + où / direct', (t) async {
      lotdPhone(t, width: 320, height: 800);
      await t.pumpWidget(lotdApp(
        Scaffold(
          body: SingleChildScrollView(
            child: PawMapVisibilitySheet(state: 'friends', saving: false, onChanged: (_) {}),
          ),
        ),
        locale: locale,
      ));
      await lotdSettle(t);
      expect(t.takeException(), isNull);
      expect(find.text(v['vis587_title']!), findsOneWidget);
      for (final k in ['all', 'friends', 'hidden']) {
        expect(find.text(v['vis587_${k}_t']!), findsOneWidget, reason: k);
        expect(find.text(v['vis587_${k}_d']!), findsOneWidget, reason: k);
      }
      expect(find.text('${v['vis587_live']}\n${v['vis587_where']}'), findsOneWidget);
    });

    testWidgets('$lang : Profil › Préférences = titre + phrase pour chaque option', (t) async {
      lotdPhone(t, width: 320, height: 1400);
      await t.pumpWidget(lotdApp(
        Scaffold(
          body: SingleChildScrollView(
            child: ProfilePreferencesTab(
              accent: const Color(0xFFC92A12),
              prefs: const ProfilePreferences(),
              onSave: (_) async {},
              onLanguage: () {},
            ),
          ),
        ),
        locale: locale,
      ));
      await lotdSettle(t);
      expect(t.takeException(), isNull);
      for (final k in ['all', 'friends', 'hidden']) {
        final row = find.byKey(ValueKey<String>('pref_vis_explain_$k'));
        expect(row, findsOneWidget, reason: k);
        final txt = (t.widget<Padding>(row).child as Text).textSpan!.toPlainText();
        expect(txt, '${v['vis587_${k}_t']} — ${v['vis587_${k}_d']}');
        // la pilule porte le titre complet (plus « Tous » seul)
        expect(find.text(v['vis587_${k}_t']!), findsWidgets);
      }
    });

    testWidgets('$lang : œil de la capsule = titre + phrase pour les lecteurs d\'écran', (t) async {
      lotdPhone(t, width: 320, height: 600);
      await t.pumpWidget(lotdApp(
        Scaffold(body: Center(child: PawCapsuleEyeButton(state: 'hidden', onTap: () {}))),
        locale: locale,
      ));
      await lotdSettle(t);
      final tip = t.widget<Tooltip>(find.byType(Tooltip).first);
      expect(tip.message, '${v['vis587_hidden_t']} — ${v['vis587_hidden_d']}');
    });
  }
}
