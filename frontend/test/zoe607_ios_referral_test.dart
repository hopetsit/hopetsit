// 607 (ZOE, 01/10/2026) — décision de Daniel : codes de PARRAINAGE masqués sur
// iPhone/iPad, même règle que les codes promo du 606 (Apple 3.1.1). Un code de
// parrainage débloque -10 % sur PawFollow/PawFamily pour le parrain.
//
// Ce qui est prouvé ici :
//   · la règle [referralCodesAllowed] : faux sur iOS, vrai sur Android ;
//   · écran « Parrainage » : sur iOS, aucun appel serveur, aucun code affiché,
//     aucun bouton Partager ; sur Android, code + partage comme avant ;
//   · chaque point d'entrée (profil, inscription classique, assistant
//     d'inscription, envoi du code au serveur) passe par la garde ;
//   · l'invitation d'AMIS (/invite?from=…) n'est PAS touchée : elle ne porte
//     aucun code de parrainage.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/ios_store_rules606.dart';
import 'package:hopetsit/views/profile/my_referrals_screen.dart';

class _FakeApi implements ApiClient {
  final List<String> gets = <String>[];

  @override
  Future<dynamic> get(String endpoint,
      {Map<String, dynamic>? queryParameters,
      Map<String, String>? headers,
      bool requiresAuth = false}) async {
    gets.add(endpoint);
    return <String, dynamic>{
      'code': 'ZOE607AB',
      'referrals': <dynamic>[],
      'availableDiscounts': 0,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(home: child),
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    final dir = Directory.systemTemp.createTempSync('zoe607');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
  });
  late _FakeApi api;
  setUp(() {
    Get.testMode = true;
    Get.reset();
    api = _FakeApi();
    Get.put<ApiClient>(api);
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('règle referralCodesAllowed', () {
    test('iOS → aucun code de parrainage', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(referralCodesAllowed(), isFalse);
      debugDefaultTargetPlatformOverride = null;
    });
    test('Android → inchangé', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(referralCodesAllowed(), isTrue);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('écran Parrainage', () {
    testWidgets('iOS : aucun appel serveur, aucun code, aucun partage',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(_app(const MyReferralsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.gets, isEmpty);
      expect(find.text('referrals_unavailable'), findsOneWidget);
      expect(find.text('ZOE607AB'), findsNothing);
      expect(find.text('referrals_share'), findsNothing);
      expect(find.text('referrals_how_it_works'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android : code et bouton Partager comme avant', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(_app(const MyReferralsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.gets, contains('/users/me/referrals'));
      expect(find.text('ZOE607AB'), findsOneWidget);
      expect(find.text('referrals_share'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('chaque entrée du code de parrainage est gardée (lecture du code)', () {
    const entries = <String, String>{
      'lib/views/profile/widgets/profile_categories.dart':
          "title: 'referrals_title'.tr",
      'lib/views/auth/sign_up_screen.dart': 'controller.referralCodeController',
      'lib/views/auth/signup_wizard_screen.dart': 'c.referralCodeController',
      'lib/controllers/sign_up_controller.dart':
          "'referralCode': referralCodeController",
    };
    entries.forEach((file, pattern) {
      test(file, () {
        final lines = File(file).readAsLinesSync();
        final idx = <int>[];
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains(pattern)) idx.add(i);
        }
        expect(idx, isNotEmpty, reason: 'entrée introuvable : $pattern');
        for (final i in idx) {
          final from = i - 8 < 0 ? 0 : i - 8;
          final window = lines.sublist(from, i + 1).join('\n');
          expect(window.contains('referralCodesAllowed()'), isTrue,
              reason: '$file:${i + 1} non gardé');
        }
      });
    });

    test('aucun autre usage du champ ou de l\'écran Parrainage non recensé', () {
      final known = {
        'lib/controllers/sign_up_controller.dart',
        'lib/views/auth/sign_up_screen.dart',
        'lib/views/auth/signup_wizard_screen.dart',
        'lib/views/profile/widgets/profile_categories.dart',
        'lib/views/profile/my_referrals_screen.dart',
        'lib/routes/app_pages.dart', // route nommée : l'écran se garde lui-même
      };
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final src = f.readAsStringSync();
        if ((src.contains('referralCodeController') ||
                src.contains('MyReferralsScreen(') ||
                src.contains("'/users/me/referrals'")) &&
            !known.contains(f.path)) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty);
    });

    test('l\'invitation d\'amis ne porte aucun code de parrainage', () {
      final src =
          File('lib/views/friends/tabs/friends_ui.dart').readAsStringSync();
      expect(src.contains("https://hopetsit.com/invite?from="), isTrue);
      expect(src.contains('referral'), isFalse);
      expect(src.contains('signup?ref='), isFalse);
    });
  });
}
