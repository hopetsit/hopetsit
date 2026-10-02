// 607 (ZOE, 02/10/2026) — page PawPoints alimentée par le catalogue UNIQUE
// (fixture = sortie réelle de buildCatalog607 du serveur). 9 langues, 375 et 768 px,
// pop-up de confirmation avant échange, message d'erreur jamais brut.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/views/boost/pawspot_leaderboard_screen.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';

import 'lotd_harness.dart';

const _langs = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
final Map<String, dynamic> _cat =
    jsonDecode(File('test/fixtures/catalog607.json').readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> _me(int spendable) => <String, dynamic>{
      'lifetime': 2400, 'spendable': spendable, 'contributions': 3, 'spotsLiked': 5, 'bonusPct': 0,
      'level': (_cat['levels'] as List).first, 'nextLevel': (_cat['levels'] as List)[1],
      'levels': _cat['levels'], 'earnRules': const [], 'claimedRewardKeys': const ['perk_gold_frame'],
      'history': const [
        {'key': 'walkCompleted', 'points': 15, 'credited': 15, 'at': '2026-10-02T08:00:00Z'},
      ],
      'catalogVersion': 607,
    };

Future<void> _open(WidgetTester t, {double width = 375, String lang = 'fr', int spendable = 1600, Brightness brightness = Brightness.light}) async {
  t.view.physicalSize = Size(width * 2, 1600 * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  lotdResponder = (req) {
    final p = req.url.path;
    if (p.endsWith('/pawpoints/catalog')) return _cat;
    if (p.endsWith('/pawpoints/me')) return _me(spendable);
    if (p.endsWith('/pawpoints/checkin')) return <String, dynamic>{'ok': true, 'awarded': const []};
    if (p.contains('/pawpoints/redeem/')) {
      return <String, dynamic>{'ok': true, 'newBalance': 1100, 'applied': 'fulfilled', 'grantedUntil': '2026-10-03T08:00:00Z'};
    }
    return const <String, dynamic>{};
  };
  await t.pumpWidget(lotdApp(
    Scaffold(body: SingleChildScrollView(child: PawPointsRewardsList(myPoints: spendable))),
    locale: Locale(lang),
    brightness: brightness,
  ));
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

String _tx(Map m, String lang) => ((m['texts'] as Map)[lang] ?? '').toString();

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));

  test('message d\'erreur : jamais le texte brut', () {
    expect(pawPoints607ErrorKey(ApiException('x', statusCode: 400)), 'pp607_error');
    expect(pawPoints607ErrorKey(ApiException('x', statusCode: 409)), 'pp607_btn_used');
    expect(pawPoints607ErrorKey(ApiException('x', statusCode: 410)), 'pp607_retired');
    expect(pawPoints607ErrorKey(ApiException('x', statusCode: 500)), 'pp607_error');
    expect(pawPoints607ErrorKey(Exception('réseau')), 'pp607_error');
  });

  for (final width in const [320.0, 375.0, 768.0]) {
    for (final lang in _langs) {
     for (final b in Brightness.values) {
      testWidgets('${width.toInt()} px $lang ${b.name} : récompenses, gains, paliers du catalogue, sans débordement', (t) async {
        await _open(t, width: width, lang: lang, brightness: b);
        final c = _cat['catalog607'] as Map<String, dynamic>;
        for (final r in (c['rewards'] as List).cast<Map>()) {
          expect(find.byKey(ValueKey<String>('pp607_reward_${r['id']}')), findsOneWidget, reason: '${r['id']}');
          expect(find.text(_tx(r, lang)), findsOneWidget, reason: '${r['id']} $lang');
        }
        for (final e in (c['earn'] as List).cast<Map>()) {
          expect(find.text(_tx(e, lang)), findsWidgets, reason: '${e['key']} $lang');
        }
        // Aucune ancienne réduction affichée.
        expect(find.textContaining(RegExp(r'[-−]\s?\d+\s?%')), findsNothing);
        expect(t.takeException(), isNull);
      });
     }
    }
  }

  testWidgets('échange : pop-up de confirmation, Annuler = rien envoyé, Échanger = POST', (t) async {
    await _open(t);
    final btn = find.byKey(const ValueKey<String>('pp607_redeem_perk_boost_24h'));
    await t.ensureVisible(btn);
    await t.tap(btn);
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
        expect(find.textContaining('Échanger 500 PawPoints contre'), findsOneWidget);
    await t.tap(find.text('Annuler').last);
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(lotdRequests.where((r) => r.path.contains('/redeem/')), isEmpty);
    await t.ensureVisible(btn);
    await t.tap(btn);
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Échanger')).last);
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    final posts = lotdRequests.where((r) => r.method == 'POST' && r.path.endsWith('/pawpoints/redeem/perk_boost_24h'));
    expect(posts, hasLength(1));
    expect(find.textContaining("C'est fait"), findsOneWidget);
    // Laisser le message se refermer (animation finie) avant la fin du test.
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
  });

  testWidgets('boutons : déjà obtenu (1 fois), points manquants, check-in appelé', (t) async {
    await _open(t, spendable: 1600);
    // Cadre doré déjà obtenu → bouton désactivé « Déjà obtenu ».
    final frame = t.widget<PawButton>(find.byKey(const ValueKey<String>('pp607_redeem_perk_gold_frame')));
    expect(frame.enabled, isFalse);
    expect(find.descendant(of: find.byKey(const ValueKey<String>('pp607_redeem_perk_gold_frame')), matching: find.text('Déjà utilisé')), findsOneWidget);
    // 4 000 pts avec 1 600 → « Encore 2400 pts ».
    expect(find.text('pp607_btn_missing'.trParams({'pts': pawPoints607Num(2400)})), findsOneWidget);
    // 3 j PawFollow (1 500) : renouvelable, actif.
    final pf = t.widget<PawButton>(find.byKey(const ValueKey<String>('pp607_redeem_sub_days_pf_3')));
    expect(pf.enabled, isTrue);
    expect(lotdRequests.where((r) => r.method == 'POST' && r.path.endsWith('/pawpoints/checkin')), hasLength(1));
    // Historique : « Mes derniers gains ».
    expect(find.text('Mes derniers gains'), findsOneWidget);
  });

  testWidgets('ordre des blocs = page du site : solde → gagner → échanger → collection → phrase', (t) async {
    await _open(t);
    double y(Finder f) => t.getTopLeft(f).dy;
    final balance = y(find.byKey(const ValueKey<String>('pp607_balance')));
    final earn = y(find.text('Comment gagner des PawPoints'));
    final exchange = y(find.text('Échanger mes PawPoints'));
    final coll = y(find.byKey(const ValueKey<String>('pp607_collection')));
    final note = y(find.byKey(const ValueKey<String>('pp607_note_activityOnly')));
    expect(balance < earn && earn < exchange && exchange < coll && coll < note, isTrue,
        reason: '$balance $earn $exchange $coll $note');
    final c = _cat['catalog607'] as Map<String, dynamic>;
    expect(find.text(((c['notes'] as Map)['activityOnly'] as Map)['fr'] as String), findsOneWidget);
  });
}
