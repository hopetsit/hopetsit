// v585 — suite : bugs 9 (menus déroulants gris), 14 (Mes amis), 15 (Mes
// abonnements sur la carte), i18n des nouvelles clés (9 langues).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/utils/paw_menu_theme.dart';
import 'package:hopetsit/views/map/widgets/pawmap_subscriptions_section.dart';
import 'package:hopetsit/views/profile/widgets/edit_profile_widgets.dart';

Widget _app(Widget home, {bool dark = false}) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        fallbackLocale: const Locale('en'),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          brightness: Brightness.light,
          useMaterial3: true,
          canvasColor: PawMenuColors.paperLight,
          popupMenuTheme: PawMenuThemes(dark: false).popup,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          canvasColor: PawMenuColors.paperDark,
          popupMenuTheme: PawMenuThemes(dark: true).popup,
        ),
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: home)),
      ),
    );

bool _isGrey(Color c) {
  final r = (c.r * 255).round(), g = (c.g * 255).round(), b = (c.b * 255).round();
  final spread = [r, g, b].reduce((a, x) => a > x ? a : x) - [r, g, b].reduce((a, x) => a < x ? a : x);
  return spread < 12 && r > 40 && r < 235; // gris neutre (ni blanc, ni noir)
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(Get.reset);

  group('bug 9 — menu des devises (Mes tarifs) : jamais gris', () {
    for (final dark in [false, true]) {
      testWidgets(dark ? 'sombre : encre foncée chaude' : 'clair : blanc chaud', (tester) async {
        String? v = 'EUR';
        await tester.pumpWidget(_app(
            StatefulBuilder(
              builder: (ctx, setS) => ProfileDropdownField<String>(
                label: 'Devise',
                value: v,
                accent: const Color(0xFF2563EB),
                items: const [
                  DropdownMenuItem(value: 'EUR', child: Text('€ Euro')),
                  DropdownMenuItem(value: 'USD', child: Text('\$ Dollar')),
                  DropdownMenuItem(value: 'GBP', child: Text('£ Livre')),
                ],
                onChanged: (x) => setS(() => v = x),
              ),
            ),
            dark: dark));
        await tester.pump();
        await tester.tap(find.text('€ Euro'));
        await tester.pumpAndSettle();
        // Le fond du menu ouvert (peint par le _DropdownMenuPainter).
        final painters = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((c) => c.painter)
            .where((p) => p != null && p.runtimeType.toString() == '_DropdownMenuPainter')
            .toList();
        expect(painters, isNotEmpty);
        final Color bg = (painters.first as dynamic).color as Color;
        expect(bg, dark ? PawMenuColors.paperDark : PawMenuColors.paperLight);
        expect(_isGrey(bg), isFalse);
        // La valeur choisie est cochée.
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        await tester.tap(find.text('\$ Dollar').last);
        await tester.pumpAndSettle();
        expect(v, 'USD');
      });
    }
  });

  group('bug 15 — Mes abonnements sur la carte', () {
    testWidgets('3 lignes ; possédé = interrupteur ; non possédé = Découvrir', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_app(PawMapSubscriptionsSection(lines: [
        PawMapSubscriptionLine(id: 'follow', name: 'PawFollow', subtitle: 'a', icon: Icons.podcasts_rounded,
            color: const Color(0xFF7C3AED), owned: true, on: true,
            onToggle: () => calls.add('follow'), onDiscover: () => calls.add('follow?')),
        PawMapSubscriptionLine(id: 'spot', name: 'PawSpot', subtitle: 'b', icon: Icons.stars_rounded,
            color: const Color(0xFFE8920A), owned: true, on: false,
            onToggle: () => calls.add('spot'), onDiscover: () {}),
        PawMapSubscriptionLine(id: 'premium', name: 'PawPremium', subtitle: 'c', icon: Icons.workspace_premium_rounded,
            color: const Color(0xFFC9971C), owned: false, on: false,
            onToggle: () {}, onDiscover: () => calls.add('premium?')),
      ])));
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('pawmap_sub_switch_follow')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('pawmap_sub_switch_spot')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('pawmap_sub_switch_premium')), findsNothing,
          reason: 'jamais un interrupteur mort');
      await tester.tap(find.byKey(const ValueKey<String>('pawmap_sub_switch_follow')));
      await tester.tap(find.byKey(const ValueKey<String>('pawmap_sub_switch_spot')));
      await tester.tap(find.byKey(const ValueKey<String>('pawmap_sub_discover_premium')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(calls, ['follow', 'spot', 'premium?']);
    });
    test('la feuille de la PawMap porte la section et les 2 boutons dédiés (source)', () {
      final src = File('lib/views/map/paw_map_screen.dart').readAsStringSync();
      expect(src.contains("'pawmap585_subs_title'.tr"), isTrue);
      expect(src.contains("ValueKey<String>('pawmap_btn_friends')"), isTrue);
      expect(src.contains("ValueKey<String>('pawmap_btn_subs')"), isTrue);
      expect(src.contains('PawMapSubscriptionsSection('), isTrue);
    });
  });

  group('bug 14 — Mes amis dans le Profil des 3 rôles', () {
    test('la ligne est dans la catégorie Compte, commune aux 3 rôles, et ouvre FriendsScreen', () {
      final src = File('lib/views/profile/widgets/profile_categories.dart').readAsStringSync();
      final account = src.substring(src.indexOf('Widget _account('), src.indexOf('Widget _account(') + 1200);
      expect(account.contains('_friendsRow()'), isTrue, reason: 'en tête de Compte, sans condition de rôle');
      expect(src.contains("Get.to(() => const FriendsScreen())"), isTrue);
      expect(src.contains("FriendsScreen(initialIndex: 3)"), isTrue, reason: 'PawFamily');
    });
  });

  test('i18n 585 : les nouvelles clés existent dans les 9 langues', () {
    final all = AppTranslations().keys;
    final fr = all['fr_FR']!;
    final keys = fr.keys.where((k) => k.startsWith('pawmap585_') || k.startsWith('profile585_')).toList();
    expect(keys.length, greaterThanOrEqualTo(13));
    for (final loc in all.keys) {
      for (final k in keys) {
        expect(all[loc]!.containsKey(k), isTrue, reason: '$loc manque $k');
      }
    }
  });
}
