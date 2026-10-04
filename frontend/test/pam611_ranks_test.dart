// 611 (PAM, 04/10/2026) — RANGS façon Waze (idée de Cam, décision BOB) :
// Chiot → Jeune chien → Chien adulte → Chef de meute → Légende, calculés par
// le serveur sur les PawPoints GAGNÉS depuis toujours. Ce fichier rejoue :
//   1. lecture du rang serveur (forme {key, level, pointsEarned, nextAt}) ;
//   2. pastille (9 langues, ko/ja naturels), clair ET sombre sans gris ;
//   3. barre « encore N points pour Chien adulte » (écran PawPoints) ;
//   4. message de passage de rang : UNE fois, noté au serveur ;
//   5. fiche d'une personne sur la PawMap (carte focus + fiche membre) ;
//   6. ligne « Les rangs » dans « Comprendre la PawMap ».
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/ranks611_i18n.dart';
import 'package:hopetsit/localization/v565/pawmap611_i18n.dart';
import 'package:hopetsit/views/map/widgets/pawmap_focus_card.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:hopetsit/widgets/paw_rank611.dart';


class _FakeApi implements ApiClient {
  _FakeApi(this.me);
  Map<String, dynamic> me;
  final List<String> posts = <String>[];
  final List<Object?> bodies = <Object?>[];

  @override
  Future<dynamic> get(String endpoint,
      {Map<String, dynamic>? queryParameters,
      Map<String, String>? headers,
      bool requiresAuth = false}) async {
    if (endpoint == '/pawpoints/me') return me;
    return <String, dynamic>{};
  }

  @override
  Future<dynamic> post(String endpoint,
      {Map<String, dynamic>? queryParameters,
      Object? body,
      Map<String, String>? headers,
      bool requiresAuth = false}) async {
    posts.add(endpoint);
    bodies.add(body);
    return <String, dynamic>{'ok': true};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child, {Locale locale = const Locale('fr'), ThemeMode mode = ThemeMode.light}) =>
    ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: locale,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: mode,
        home: Scaffold(body: Center(child: child)),
      ),
    );

const _young = <String, dynamic>{
  'key': 'young_dog', 'level': 2, 'pointsEarned': 150, 'nextAt': 800, 'nextKey': 'adult_dog',
};

/// Saturation HSL (règle « zéro gris » : < 25 % hors teintes chaudes = gris).
bool _isGray(Color c) {
  final hsl = HSLColor.fromColor(c);
  final h = hsl.hue;
  final warm = h >= 340 || h <= 45;
  return hsl.saturation < 0.25 && !warm && hsl.lightness > 0.04 && hsl.lightness < 0.96;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    Get.testMode = true;
    Get.reset();
    PawRankService611.instance.resetForTests();
  });

  test('1. rang serveur lu, rang illisible ignoré, progression', () {
    final r = PawRank611.fromJson(_young)!;
    expect(r.key, 'young_dog');
    expect(r.pointsToNext, 650);
    expect(r.progress, 0.0);
    final mid = PawRank611.fromJson(<String, dynamic>{
      'key': 'adult_dog', 'level': 3, 'pointsEarned': 1900, 'nextAt': 3000, 'nextKey': 'pack_leader'})!;
    expect(mid.progress, closeTo(0.5, 0.001));
    final top = PawRank611.fromJson(<String, dynamic>{'key': 'legend', 'level': 5, 'pointsEarned': 12000})!;
    expect(top.isTop, isTrue);
    expect(top.progress, 1);
    expect(PawRank611.fromJson(null), isNull);
    expect(PawRank611.fromJson(<String, dynamic>{'key': 'boss', 'level': 9}), isNull);
  });

  test('2a. 9 langues pour chaque clé (rangs + reprise du direct)', () {
    for (final pack in [ranks611I18n, pawmap611I18n]) {
      final keys = pack['fr']!.keys.toSet();
      for (final l in const ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
        expect(pack[l]!.keys.toSet(), keys, reason: l);
        for (final v in pack[l]!.values) {
          expect(v.trim(), isNotEmpty, reason: l);
        }
      }
    }
    expect(ranks611I18n['ko']!['rank611_puppy'], '강아지');
    expect(ranks611I18n['ja']!['rank611_adult_dog'], '成犬');
    // variables jamais traduites
    for (final l in ranks611I18n.keys) {
      expect(ranks611I18n[l]!['rank611_to_next'], allOf(contains('@n'), contains('@rank')), reason: l);
    }
  });

  test('2b. zéro gris : les 5 teintes, clair et sombre', () {
    for (var lv = 1; lv <= 5; lv++) {
      final st = PawRankStyle611.of(lv);
      for (final c in [st.base, st.lightBg, st.lightInk, st.darkBg, st.darkInk]) {
        expect(_isGray(c), isFalse, reason: 'rang $lv : $c');
      }
    }
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('2c. pastille « Jeune chien » (${mode.name})', (t) async {
      await t.pumpWidget(_app(PawRankPill611(rank: PawRank611.fromJson(_young)!), mode: mode));
      await t.pump();
      expect(find.text('Jeune chien'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('2d. japonais : 若犬', (t) async {
    await t.pumpWidget(_app(PawRankPill611(rank: PawRank611.fromJson(_young)!), locale: const Locale('ja')));
    await t.pump();
    expect(find.text('若犬'), findsOneWidget);
  });

  testWidgets('3. écran PawPoints : « Encore 650 points pour Chien adulte »', (t) async {
    await t.pumpWidget(_app(PawRankProgress611(rank: PawRank611.fromJson(_young)!)));
    await t.pump();
    expect(find.text('Encore 650 points pour Chien adulte'), findsOneWidget);
    await t.pumpWidget(_app(PawRankProgress611(
        rank: PawRank611.fromJson(<String, dynamic>{'key': 'legend', 'level': 5, 'pointsEarned': 12000})!)));
    await t.pump();
    expect(find.text('Tu as atteint le plus haut rang. Bravo !'), findsOneWidget);
  });

  testWidgets('4. message de passage : une seule fois, noté au serveur', (t) async {
    final api = _FakeApi(<String, dynamic>{'rank': _young, 'rankSeenLevel': 1});
    Get.put<ApiClient>(api);
    await t.pumpWidget(_app(const SizedBox()));
    await PawRankService611.instance.refresh();
    expect(api.posts, <String>['/pawpoints/rank-seen']);
    expect((api.bodies.first as Map)['level'], 2);
    await PawRankService611.instance.refresh();
    expect(api.posts.length, 1, reason: 'déjà vu : pas de 2e message');
    // déjà vu sur l'autre téléphone (serveur) : aucun message
    PawRankService611.instance.resetForTests();
    api.me = <String, dynamic>{'rank': _young, 'rankSeenLevel': 2};
    await PawRankService611.instance.refresh();
    expect(api.posts.length, 1);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('5a. carte focus d\'une personne : pastille de rang', (t) async {
    await t.pumpWidget(_app(PawFocusCard(
      info: PawFocusInfo(
        key: 'cam', name: 'Cam C.', role: 'owner', info: '1,2 km', onOpen: () {},
        rank: PawRank611.fromJson(_young),
      ),
      onClose: () {},
    )));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey<String>('pawmap_focus_rank')), findsOneWidget);
    expect(find.text('Jeune chien'), findsOneWidget);
  });

  testWidgets('5b. fiche membre de la PawMap : pastille de rang', (t) async {
    await t.pumpWidget(_app(SizedBox(
      height: 800,
      child: PawMapMemberSheet(
        member: PawMapMemberData(id: 'cam', role: 'owner', name: 'Cam C.',
            rank: PawRank611.fromJson(_young)),
        viewerRole: 'sitter',
        viewerLoggedIn: true,
        friendState: PawFriendState.idle,
        priceLabel: '',
        onBook: () {}, onProfile: () {}, onMessage: () {}, onFriend: () {},
        onDirections: () {}, onPropose: () {}, onSignup: () {},
      ),
    )));
    await t.pump();
    expect(find.byKey(const ValueKey<String>('member_rank')), findsOneWidget);
    expect(find.text('Jeune chien'), findsOneWidget);
  });

  for (final c in <List<dynamic>>[
    [{'position': 9, 'pointsEarned': 136, 'excludedReason': null, 'rank': {'key': 'puppy', 'level': 1, 'pointsEarned': 136, 'nextAt': 150, 'nextKey': 'young_dog'}}, '9e · 136 pts'],
    [{'position': null, 'pointsEarned': 136, 'excludedReason': 'staff', 'rank': {'key': 'puppy', 'level': 1, 'pointsEarned': 136, 'nextAt': 150, 'nextKey': 'young_dog'}}, 'Compte équipe : hors classement'],
    [{'position': null, 'pointsEarned': 40, 'excludedReason': 'no_city', 'rank': {'key': 'puppy', 'level': 1, 'pointsEarned': 40, 'nextAt': 150, 'nextKey': 'young_dog'}}, 'Ajoute ta ville pour apparaître dans « Ma ville »'],
  ]) {
    testWidgets('I. ligne épinglée « Toi » : ${c[1]}', (t) async {
      await t.pumpWidget(_app(PawLeaderboardMeRow611(me: Map<String, dynamic>.from(c[0] as Map))));
      await t.pump();
      expect(find.text('Toi'), findsOneWidget);
      expect(find.text(c[1] as String), findsOneWidget);
      expect(find.text('Chiot'), findsOneWidget);
    });
  }
}
