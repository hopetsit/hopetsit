// 613 (PAM, 06/10/2026) — §8 de PROCHAIN_BUILD_613 : « Comprendre la PawMap »,
// section « Les rangs » : texte COUPÉ. Ce test ÉCHOUE si un seul texte de la
// section (nom du rang, seuil, titres, explications) est tronqué ou déborde,
// dans les 9 langues, à 375 px, en police normale ET grande police (iOS).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:hopetsit/widgets/paw_rank611.dart';

import 'lotd_harness.dart';

const _langs = <(String, String)>[
  ('fr', 'FR'), ('en', 'US'), ('es', 'ES'), ('de', 'DE'), ('it', 'IT'),
  ('pt', 'PT'), ('ko', 'KR'), ('ja', 'JP'), ('pl', 'PL'),
];

List<String> truncatedIn(WidgetTester t) {
  final keys = <Key>[
    for (final k in kPawRankKeys611) ValueKey<String>('help612_rank_$k'),
    const ValueKey<String>('help611_ranks'),
    const ValueKey<String>('help607_pawpoints'),
  ];
  final out = <String>[];
  for (final k in keys) {
    final f = find.byKey(k, skipOffstage: false);
    if (f.evaluate().isEmpty) {
      out.add('absent $k');
      continue;
    }
    void visit(Element e) {
      final ro = e.renderObject;
      if (ro is RenderParagraph && e.widget is RichText) {
        final txt = (e.widget as RichText).text.toPlainText();
        if (ro.didExceedMaxLines) out.add('coupé: « $txt »');
        // largeur réelle du texte > largeur donnée (débordement sans « … »)
        final tp = TextPainter(
          text: (e.widget as RichText).text,
          textDirection: TextDirection.ltr,
          textScaler: (e.widget as RichText).textScaler,
          maxLines: (e.widget as RichText).maxLines,
        )..layout(maxWidth: ro.size.width + 0.5);
        if (tp.didExceedMaxLines) out.add('déborde: « $txt »');
      }
      e.visitChildren(visit);
    }
    for (final e in f.evaluate()) {
      visit(e);
    }
  }
  return out;
}

void main() {
  for (final scale in const [1.0, 1.35]) {
    for (final (lang, cc) in _langs) {
      testWidgets('375 px, $lang, police ×$scale : aucun texte des rangs coupé', (t) async {
        t.view.physicalSize = const Size(375 * 3, 2400);
        t.view.devicePixelRatio = 3;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await t.pumpWidget(lotdApp(const PawMapHelpScreen(role: 'owner'), locale: Locale(lang, cc)));
        await t.pump(const Duration(milliseconds: 100));
        final bad = truncatedIn(t);
        expect(bad, isEmpty, reason: '$lang ×$scale : ${bad.join(' | ')}');
      });
    }
  }
}
