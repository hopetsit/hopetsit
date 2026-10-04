// 611 (PAM, 04/10/2026) — décision BOB : UN SEUL système de rangs. Les 7
// anciens niveaux (Explorateur… Paw Legend, bonus +5 à +15 %) ne sortent plus
// nulle part. L'écran PawPoints est rendu avec le VRAI catalogue que sert le
// serveur 611 (fixture générée depuis pawPointsService / ranks611) : on y voit
// les 5 rangs, la carte « Mon rang », et aucun ancien nom ni pourcentage.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/boost/pawspot_leaderboard_screen.dart';
import 'package:hopetsit/widgets/paw_rank611.dart';

class _FakeApi implements ApiClient {
  _FakeApi(this.catalog, {this.cam36 = false});
  final Map<String, dynamic> catalog;
  /// C — capture de Daniel : 36 points, réponse /me SANS `rank` (forme lue par
  /// l'app 610 déjà installée) mais catalogue du serveur 611.
  final bool cam36;
  @override
  Future<dynamic> get(String endpoint,
      {Map<String, dynamic>? queryParameters,
      Map<String, String>? headers,
      bool requiresAuth = false}) async {
    if (endpoint == '/pawpoints/catalog') return catalog;
    if (endpoint == '/pawpoints/me' && cam36) {
      return <String, dynamic>{'lifetime': 36, 'spendable': 36, 'points': 36, 'bonusPct': 0,
        'levels': catalog['levels'], 'history': [], 'claimedRewardKeys': []};
    }
    if (endpoint == '/pawpoints/me') {
      return <String, dynamic>{
        'lifetime': 200, 'spendable': 200, 'points': 200,
        'level': (catalog['levels'] as List)[1], 'nextLevel': (catalog['levels'] as List)[2],
        'levels': catalog['levels'], 'bonusPct': 0,
        'rank': {'key': 'young_dog', 'level': 2, 'pointsEarned': 200, 'nextAt': 800, 'nextKey': 'adult_dog'},
        'rankSeenLevel': 2, 'history': [], 'claimedRewardKeys': [],
      };
    }
    if (endpoint == '/pawpoints/history') {
      return <String, dynamic>{
        'items': [
          {'key': 'plushCaught', 'points': 20, 'at': '2026-10-04T17:34:00.000Z'},
          {'key': 'correctReport', 'points': 1, 'at': '2026-10-04T12:00:00.000Z'},
          {'key': 'spotCreated', 'points': 10, 'at': '2026-10-03T09:00:00.000Z'},
        ],
        'beforeJournal': 5, 'lifetime': 36,
      };
    }
    return <String, dynamic>{};
  }

  @override
  Future<dynamic> post(String endpoint,
          {Map<String, dynamic>? queryParameters,
          Object? body,
          Map<String, String>? headers,
          bool requiresAuth = false}) async =>
      <String, dynamic>{'ok': true, 'awarded': []};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    final dir = Directory.systemTemp.createTempSync('pm611lv');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (_) async => dir.path);
  });

  for (final lang in const ['fr', 'en', 'ja']) {
    testWidgets('écran PawPoints ($lang) : 5 rangs, aucun ancien niveau', (t) async {
      Get.testMode = true;
      Get.reset();
      PawRankService611.instance.resetForTests();
      final cat = jsonDecode(File('test/fixtures/pawpoints_catalog611.json').readAsStringSync())
          as Map<String, dynamic>;
      Get.put<ApiClient>(_FakeApi(cat));
      t.view.physicalSize = const Size(750, 4000);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, __) => GetMaterialApp(
          translations: AppTranslations(),
          locale: Locale(lang),
          home: const Scaffold(body: SingleChildScrollView(child: PawPointsRewardsList())),
        ),
      ));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      final texts = t
          .widgetList<Text>(find.byType(Text, skipOffstage: false))
          .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
          .join('\n');
      final rich = t
          .widgetList<RichText>(find.byType(RichText, skipOffstage: false))
          .map((w) => w.text.toPlainText())
          .join('\n');
      final all = '$texts\n$rich';
      expect(all, isNot(matches(RegExp(
          r'Explorateur|Explorer|Contributeur|Contributor|Ambassadeur|Ambassador|PawMaster|Légendaire|Legendary|Paw Legend|エクスプローラー|\+5 ?%|\+10 ?%|\+15 ?%'))));
      expect(find.byKey(const ValueKey<String>('paw_rank_progress'), skipOffstage: false), findsOneWidget);
      final names = {
        'fr': ['Chiot', 'Jeune chien', 'Chien adulte', 'Chef de meute', 'Légende'],
        'en': ['Puppy', 'Young dog', 'Grown dog', 'Pack leader', 'Legend'],
        'ja': ['子犬', '若犬', '成犬', '群れのリーダー', 'レジェンド'],
      }[lang]!;
      for (final n in names) {
        expect(all, contains(n), reason: '$lang : $n');
      }
      // 611 (B) — « D'où viennent mes points » : gains en clair + passé sans trace
      expect(find.byKey(const ValueKey<String>('hist611_section'), skipOffstage: false), findsOneWidget);
      if (lang == 'fr') {
        for (final w in ['Peluche attrapée', 'Signalement confirmé', 'Spot ajouté', '+20', '+1', '+10', 'Points gagnés avant le 04/10 : 5']) {
          expect(all, contains(w), reason: w);
        }
        // C — « Encore N points pour Jeune chien » côté rang, jamais « Explorateur »
        expect(all, contains('Encore 600 points pour Chien adulte'));
      }
    });
  }

  testWidgets('C. 36 points (capture de Daniel) : « Jeune chien », plus jamais « Explorateur »', (t) async {
    Get.testMode = true;
    Get.reset();
    PawRankService611.instance.resetForTests();
    final cat = jsonDecode(File('test/fixtures/pawpoints_catalog611.json').readAsStringSync())
        as Map<String, dynamic>;
    Get.put<ApiClient>(_FakeApi(cat, cam36: true));
    t.view.physicalSize = const Size(750, 4000);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        home: const Scaffold(body: SingleChildScrollView(child: PawPointsRewardsList())),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    final all = t.widgetList<RichText>(find.byType(RichText, skipOffstage: false))
        .map((w) => w.text.toPlainText()).join('\n');
    expect(all, isNot(contains('Explorateur')));
    expect(all, contains('Chiot'));
    expect(all, contains('114'));
    expect(all, contains('Jeune chien'));
  });

  test('E. clés des anciens niveaux : retirées des traductions ET jamais appelées par le code', () {
    const removed = <String>[
      'pawspot_badge_explorer', 'pawspot_badge_expert', 'pawspot_badge_ambassador', 'pawspot_badge_pawmaster',
      'pawspot567_badge_contributor', 'pawspot567_badge_legend', 'pawspot567_badge_paw_legend',
      'pawpoints_perk_badge', 'pawpoints_perk_chests', 'pawpoints_perk_map', 'pawpoints_perk_bonus5',
      'pawpoints_perk_bonus10', 'pawpoints_perk_boost', 'pawpoints_perk_frame', 'pawpoints_perk_status',
      'pawpoints_perk_crown', 'pawpoints_perk_ultimate', 'pawpoints_legend_title', 'pawpoints_legend_sub',
      'pawpoints_legend_remaining', 'pawspot_next_badge',
    ];
    final keys = AppTranslations().keys;
    for (final lang in keys.keys) {
      for (final k in removed) {
        expect(keys[lang]!.containsKey(k), isFalse, reason: '$lang $k');
      }
    }
    final code = Directory('lib').listSync(recursive: true).whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('/localization/'))
        .map((f) => f.readAsStringSync()).join('\n');
    for (final k in removed) {
      expect(code.contains("'$k'"), isFalse, reason: k);
    }
    // aucun ancien nom affichable dans les traductions françaises de l'app
    final fr = keys['fr'] ?? keys['fr_FR'] ?? const <String, String>{};
    expect(fr.values.where((v) => RegExp(r'Explorateur|PawMaster|Paw Legend|Ambassadeur').hasMatch(v)), isEmpty);
  });
}
