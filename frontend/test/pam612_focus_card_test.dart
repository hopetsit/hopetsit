// 612 (PAM) — capture 3 (« Cam Chet… », « Jeune chi… ») et capture 11
// (« En balade · 167… ») : la fiche rapide, posée entre les deux barres
// (66 dp de chaque côté), n'écrit plus le nom, le rang ni l'état coupés.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_focus_card.dart';
import 'package:hopetsit/widgets/paw_rank611.dart';

import 'lotd_harness.dart';

bool _clipped(WidgetTester t, String text) {
  final f = find.text(text, skipOffstage: false);
  if (f.evaluate().isEmpty) return true;
  final rp = t.renderObject<RenderParagraph>(f.first);
  return rp.didExceedMaxLines;
}

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));
  for (final w in const [375.0, 393.0]) {
    for (final dark in const [false, true]) {
      testWidgets('${w.toInt()} px ${dark ? 'sombre' : 'clair'} : nom, rang et état entiers', (t) async {
        t.view.physicalSize = Size(w * 2, 1700);
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        await t.pumpWidget(lotdApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.fromLTRB(66, 40, 66, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: PawFocusCard(
                  info: PawFocusInfo(
                    key: 'cam',
                    name: 'Cam Chetmou',
                    role: 'owner',
                    info: 'En balade · 167 m · 18 min',
                    live: true,
                    rank: const PawRank611(key: 'young_dog', level: 2, pointsEarned: 170),
                    onOpen: () {},
                  ),
                  onClose: () {},
                ),
              ),
            ),
          ),
          brightness: dark ? Brightness.dark : Brightness.light,
        ));
        await t.pump(const Duration(milliseconds: 400));
        expect(_clipped(t, 'Cam Chetmou'), isFalse);
        expect(_clipped(t, 'Jeune chien'), isFalse);
        expect(_clipped(t, 'En balade · 167 m · 18 min'), isFalse);
        expect(find.byKey(const ValueKey<String>('pawmap_focus_open')), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
