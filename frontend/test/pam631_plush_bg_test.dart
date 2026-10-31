// 631 (PAM) — vocal de Daniel 14 h 22 : peluche attrapée téléphone verrouillé →
// retour sans écran (vibration + son + notification locale) ET fête gardée pour
// le déverrouillage. Ici : la fête part en attente ET le retour hors écran est
// déclenché, exactement une fois ; au premier plan, rien ne change (613).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_catch613.dart';
import 'package:hopetsit/views/map/widgets/pawmap_plush607.dart';

void main() {
  testWidgets('arrière-plan : fête gardée + retour hors écran (1 fois)', (t) async {
    PawCatchCelebration.silentForTests = true;
    final calls = <int>[];
    PawCatchCelebration.backgroundNotifierForTests = (w) async => calls.add(w.points);
    PawCatchCelebration.backgroundFeedbackCount631 = 0;
    await t.pumpWidget(Builder(builder: (ctx) {
      PawCatchCelebration.deliver(ctx, PawPlushWin(points: 20),
          lifecycle: AppLifecycleState.paused);
      PawCatchCelebration.deliver(ctx, PawPlushWin(points: 30),
          lifecycle: AppLifecycleState.inactive);
      return const SizedBox();
    }));
    expect(PawCatchCelebration.pendingCountForTests(), 2,
        reason: 'la fête rejoue au déverrouillage');
    expect(calls, <int>[20, 30], reason: 'une notification par peluche');
    expect(PawCatchCelebration.backgroundFeedbackCount631, 2);
    PawCatchCelebration.backgroundNotifierForTests = null;
  });

  testWidgets('premier plan : aucun retour hors écran', (t) async {
    PawCatchCelebration.silentForTests = true;
    PawCatchCelebration.backgroundFeedbackCount631 = 0;
    var hooked = 0;
    PawCatchCelebration.backgroundNotifierForTests = (_) async => hooked++;
    await t.pumpWidget(Builder(builder: (ctx) {
      PawCatchCelebration.deliver(ctx, PawPlushWin(points: 20),
          lifecycle: AppLifecycleState.resumed);
      return const SizedBox();
    }));
    expect(hooked, 0);
    expect(PawCatchCelebration.backgroundFeedbackCount631, 0);
    PawCatchCelebration.backgroundNotifierForTests = null;
  });
}
