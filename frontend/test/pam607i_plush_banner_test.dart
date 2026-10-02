// 607 (PAM, 02/10/2026) — BOB : « aucune bannière +20 PawPoints vue ». La
// pastille de capture reste 5 s (≥ 3 s demandé), vibre, et aucune autre
// pastille ne la remplace pendant ce temps (l'autre attend son tour).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/views/map/widgets/pawmap_signal.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('capture : 5 s visibles, vibration, jamais remplacée', (t) async {
    final haptics = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      if (c.method == 'HapticFeedback.vibrate') haptics.add('${c.arguments}');
      return null;
    });
    late BuildContext ctx;
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        home: Scaffold(body: Builder(builder: (c) {
          ctx = c;
          return const SizedBox.expand();
        })),
      ),
    ));
    PawSignal.show(ctx, PawSignalKind.plush, '+20 PawPoints ! 🧸');
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('+20 PawPoints ! 🧸'), findsOneWidget);
    expect(haptics, contains('HapticFeedbackType.heavyImpact'));
    // une autre pastille arrive pendant la capture : elle attend
    PawSignal.show(ctx, PawSignalKind.live, 'Direct activé');
    await t.pump(const Duration(seconds: 3));
    expect(find.text('+20 PawPoints ! 🧸'), findsOneWidget, reason: 'toujours là à 3,4 s');
    expect(find.text('Direct activé'), findsNothing);
    await t.pump(const Duration(milliseconds: 1400));
    expect(find.text('+20 PawPoints ! 🧸'), findsOneWidget, reason: 'toujours là à 4,8 s');
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('+20 PawPoints ! 🧸'), findsNothing);
    expect(find.text('Direct activé'), findsOneWidget, reason: 'affichée après');
    await t.pump(const Duration(seconds: 3));
    PawSignal.hide();
  });
}
