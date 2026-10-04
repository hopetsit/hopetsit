// 610 (PAM, 04/10/2026) — Daniel (capture « Ma balade · 59 min · 1 personne
// te suit ») : « quand je clique sur "1 te suit", il ne me dit pas QUI me
// suit ». Feuille « En direct » : une ligne par personne (photo, « Cam te
// suit », « depuis 12 min ») ; 0 / 1 / 3 suiveurs ; ancien serveur = nombre.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_live_sheet.dart';

class _FakeApi implements ApiClient {
  @override
  Future<dynamic> get(String endpoint,
          {Map<String, dynamic>? queryParameters,
          Map<String, String>? headers,
          bool requiresAuth = false}) async =>
      <String, dynamic>{};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

LiveMapService _walking(int count, List<PawFollower610> who) {
  final live = LiveMapService();
  live.broadcasting.value = true;
  live.sessionStartedAt.value = DateTime.now().subtract(const Duration(minutes: 59));
  live.myFollowers.value = count;
  live.followerList.assignAll(who);
  live.followerNames.assignAll(who.map((f) => f.name));
  return live;
}

PawFollower610 _f(String id, String name, int minAgo) => PawFollower610(
      id: id,
      name: name,
      role: 'owner',
      since: DateTime.now().subtract(Duration(minutes: minAgo)),
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    final dir = Directory.systemTemp.createTempSync('pam610f');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
  });
  setUp(() {
    Get.testMode = true;
    Get.reset();
    Get.put<ApiClient>(_FakeApi());
  });

  testWidgets('0 suiveur : aucune ligne « te suit »', (t) async {
    await t.pumpWidget(_app(PawLiveSheet(live: _walking(0, const []))));
    await t.pump();
    expect(find.byKey(const ValueKey<String>('live_sheet_followers_title')), findsNothing);
    expect(
        find.byWidgetPredicate((w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('live_sheet_follower_')),
        findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('1 suiveur : « Cam te suit · depuis 12 min » ; appui = sa fiche / la carte', (t) async {
    PawFollower610? opened;
    await t.pumpWidget(_app(PawLiveSheet(
      live: _walking(1, [_f('c1', 'Cam', 12)]),
      onOpenFollower: (f) => opened = f,
    )));
    await t.pump();
    expect(find.text('Ils te suivent'), findsOneWidget);
    expect(find.text('Cam te suit'), findsOneWidget);
    expect(find.text('depuis 12 min'), findsOneWidget);
    await t.tap(find.text('Cam te suit'));
    await t.pump();
    expect(opened?.id, 'c1');
  });

  testWidgets('3 suiveurs : trois lignes, chacun son prénom', (t) async {
    await t.pumpWidget(_app(PawLiveSheet(
      live: _walking(3, [_f('a', 'Ana', 30), _f('b', 'Bo', 5), _f('c', 'Cy M.', 1)]),
    )));
    await t.pump();
    for (final n in ['Ana', 'Bo', 'Cy M.']) {
      expect(find.text('$n te suit'), findsOneWidget);
    }
    expect(find.text('depuis 30 min'), findsOneWidget);
    expect(find.text('depuis 1 min'), findsOneWidget);
  });

  testWidgets('ancien serveur (aucun nom) : le nombre seul reste affiché', (t) async {
    await t.pumpWidget(_app(PawLiveSheet(live: _walking(2, const []))));
    await t.pump();
    expect(find.text('Ils te suivent'), findsNothing);
    expect(find.textContaining('2'), findsWidgets);
  });

  testWidgets('pastille « 1 te suit » de la pilule : l\'appui ouvre QUI me suit', (t) async {
    var opened = 0;
    var pill = 0;
    await t.pumpWidget(_app(PawMapDirectPill(
      live: true,
      startedAt: DateTime.now(),
      followers: 1,
      onTap: () => pill++,
      onFollowersTap: () => opened++,
    )));
    await t.pump();
    await t.tap(find.byKey(const ValueKey<String>('pawmap_direct_followers')));
    await t.pump();
    expect(opened, 1);
    expect(pill, 0, reason: 'la pilule (arrêt du direct) n\'est pas touchée');
  });

  test('lecture tolérante : doublons et entrées sans nom écartés', () {
    final l = parseFollowerList610([
      {'id': 'a', 'name': 'Ana', 'since': '2026-10-04T13:00:00.000Z'},
      {'id': 'a', 'name': 'Ana'},
      {'id': 'b', 'name': ''},
      'x',
    ]);
    expect(l.map((f) => f.id), ['a']);
    expect(parseFollowerList610(null), isEmpty);
  });
}
