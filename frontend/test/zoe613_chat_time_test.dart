// 613 §9 (ZOE, 07/10/2026) — vu sur l'émulateur Android (APK release) :
// message reçu à 1 h 36 (Paris) affiché « Hier » dans la liste des
// conversations : la date du serveur (UTC, 23 h 36 la veille) était comparée
// telle quelle au jour LOCAL. Les heures du chat suivent l'heure locale.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/chat_shared/chat_time.dart';

void main() {
  testWidgets('date UTC du serveur → heure et jour LOCAUX', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    final nowLocal = DateTime.now();
    final fromServer = DateTime.parse(nowLocal.toUtc().toIso8601String()); // « …Z », isUtc
    expect(fromServer.isUtc, isTrue);
    // Un message de maintenant : l'heure LOCALE, jamais « Hier ».
    expect(chatListTime(ctx, fromServer), chatClock(ctx, nowLocal));
    expect(chatClock(ctx, fromServer), chatClock(ctx, nowLocal),
        reason: 'heure affichée = heure locale, pas l’heure UTC');
    expect(chatSameDay(fromServer, nowLocal), isTrue);
    // Hier (local) reste « Hier ».
    final yesterday = DateTime.parse(nowLocal.subtract(const Duration(days: 1)).toUtc().toIso8601String());
    expect(chatListTime(ctx, yesterday), 'cs_yesterday');
  });
}
