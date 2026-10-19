// 618 (PAM, 19/10/2026) — sonde SIMULATEUR du build 618 : rendu iOS réel des
// nouveautés avec les réponses du contrat serveur (aucun compte, aucun appel
// réseau) : carte de capture « +500 ×2 Premium = 1000 », pins du classement,
// collection du mois (avant le 01/11 et en cours) et message de fin.
// Le runner capture l'écran à chaque ligne « [SHOT] nom ».
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/map/widgets/pawmap_catch613.dart';
import 'package:hopetsit/views/map/widgets/pawmap_plush607.dart';
import 'package:hopetsit/widgets/paw_pins618.dart';
import 'package:hopetsit/widgets/paw_rank611.dart';
import 'package:integration_test/integration_test.dart';

Map<String, dynamic> _col(Map<String, dynamic> monthly) => {
      'total': 7,
      'counts': {'teddy': 2, 'bunny': 1, 'kitty': 1, 'puppy': 2, 'fox': 1},
      'golden': 1,
      'streak': 3,
      'badges': ['collector'],
      'monthly': monthly,
      'monthlyBadges': const [],
      'items': const [],
    };

Map<String, dynamic> _nov(List<String> caught) => {
      'key': '2026-11',
      'theme': 'autumn',
      'label': 'Automne',
      'labels': {'fr': 'Automne'},
      'color': '#C2571A',
      'caughtTypes': caught,
      'complete': caught.length == 5,
      'bonusPoints': 500,
      'startsAt': '2026-10-31T23:00:00.000Z',
      'endsAt': '2026-11-30T23:00:00.000Z',
    };

Widget _page(Widget body, {Brightness b = Brightness.light}) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        translations: AppTranslations(),
        locale: const Locale('fr'),
        theme: ThemeData(brightness: b, scaffoldBackgroundColor: b == Brightness.dark ? const Color(0xFF17141F) : const Color(0xFFFFF7F2)),
        home: Scaffold(body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: body))),
      ),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sonde 618', (t) async {
    PawCatchCelebration.silentForTests = true;
    // 1. Capture doublée par Premium + pins.
    await t.pumpWidget(_page(Column(children: [
      const SizedBox(height: 150),
      const PawLeaderboardMeRow611(me: {
        'position': 1,
        'pointsEarned': 3240,
        'rank': {'key': 'pack_leader', 'level': 4, 'pointsEarned': 3240, 'nextAt': 10000, 'nextKey': 'legend'},
        'pins': {'podium': 1, 'firstPackLeader': true},
      }),
      const SizedBox(height: 12),
      const PawPinsRow618(pins: PawPins618(podium: 1, firstPackLeader: true)),
      const SizedBox(height: 8),
      const PawPinsRow618(pins: PawPins618(podium: 2)),
      const SizedBox(height: 8),
      const PawPinsRow618(pins: PawPins618(podium: 3)),
      SizedBox(
        height: 220,
        child: Stack(children: [
          PawCatchFx613(
            win: const PawPlushWin(points: 1000, premiumDoubled: true, type: 'fox', collector: true),
            confetti: false,
            cardFor: const Duration(seconds: 30),
          ),
        ]),
      ),
    ])));
    await t.pump(const Duration(milliseconds: 900));
    expect(find.text('+500 ×2 Premium = 1000'), findsOneWidget);
    debugPrint('[SONDE-R] x2 et pins affichés');
    debugPrint('[SHOT] 01_x2_pins');
    await Future<void>.delayed(const Duration(seconds: 3));

    // 2. Collection d'origine complète, avant le 01/11.
    await t.pumpWidget(_page(PawPlushCollectionSection(
      key: const ValueKey('avant'),
      load: () async => _col(_nov(const [])),
      now: () => DateTime.utc(2026, 10, 19, 20),
    )));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Collection complète ! Prochaine collection : celle de novembre, dès le 1er'), findsOneWidget);
    debugPrint('[SONDE-R] message de fin + carte novembre 0/5');
    debugPrint('[SHOT] 02_avant_novembre');
    await Future<void>.delayed(const Duration(seconds: 3));

    // 3. Novembre en cours, 3/5, mode sombre.
    await t.pumpWidget(_page(
      PawPlushCollectionSection(
        key: const ValueKey('pendant'),
        load: () async => _col(_nov(const ['teddy', 'kitty', 'fox'])),
        now: () => DateTime.utc(2026, 11, 20, 9),
      ),
      b: Brightness.dark,
    ));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('3/5'), findsOneWidget);
    debugPrint('[SONDE-R] novembre 3/5 sombre');
    debugPrint('[SHOT] 03_novembre_sombre');
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(t.takeException(), isNull);
  });
}
