// v576 — Daniel : « Langues parlées : quand on ajoute des langues, il n'y a ni
// bouton valider ni retour ».
//
// La feuille (`ProfileLanguageField._openPicker`) s'ouvrait avec une simple
// poignée décorative : sur Android, rien n'indiquait comment sortir, et aucun
// bouton ne concluait la sélection. Ce test monte la feuille en vrai et
// vérifie qu'on peut : sélectionner, valider (bouton principal), fermer (croix
// ou poignée), et que la sélection SURVIT à la fermeture.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:hopetsit/localization/v565/fixes576_i18n.dart';
import 'package:hopetsit/localization/v565/profile575_i18n.dart';
import 'package:hopetsit/views/profile/widgets/profile_about_fields.dart';

const Color _kWalker = Color(0xFF16A34A);

class _T extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final out = <String, Map<String, String>>{};
    for (final lang in profile575I18n.keys) {
      out[lang] = <String, String>{
        ...profile575I18n[lang]!,
        ...(fixes576I18n[lang] ?? fixes576I18n['en']!),
        'common_close': lang == 'fr' ? 'Fermer' : 'Close',
      };
    }
    return out;
  }
}

Widget _harness(Widget child, {String lang = 'fr'}) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: _T(),
        locale: Locale(lang),
        fallbackLocale: const Locale('en'),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        ),
      ),
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(Get.reset);

  testWidgets('la feuille offre « Valider » ET une fermeture', (tester) async {
    final selected = <String>[].obs;
    var joined = '';

    await tester.pumpWidget(_harness(ProfileLanguageField(
      selected: selected,
      accent: _kWalker,
      onChanged: (v) => joined = v,
    )));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const ValueKey<String>('profile_language_row')));
    await tester.pumpAndSettle();

    // Les trois éléments qui manquaient.
    expect(find.byKey(const ValueKey<String>('profile_language_validate')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('profile_language_close')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('profile_language_handle')), findsOneWidget);
    expect(find.text('Valider'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Je choisis deux langues.
    await tester.tap(find.text('Français'));
    await tester.pump();
    await tester.tap(find.text('English'));
    await tester.pump();
    expect(selected, ['Français', 'English']);

    // « Valider » ferme la feuille et publie la valeur pour l'API.
    await tester.tap(find.byKey(const ValueKey<String>('profile_language_validate')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('profile_language_validate')), findsNothing);
    expect(joined, 'Français, English');

    // La sélection est CONSERVÉE et affichée sur la rangée.
    expect(selected, ['Français', 'English']);
    expect(find.textContaining('Français'), findsWidgets);
  });

  testWidgets('la croix ferme sans perdre la sélection', (tester) async {
    final selected = <String>['Français'].obs;

    await tester.pumpWidget(_harness(ProfileLanguageField(
      selected: selected,
      accent: _kWalker,
    )));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const ValueKey<String>('profile_language_row')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('profile_language_close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('profile_language_close')), findsNothing);
    expect(selected, ['Français', 'English']);
  });

  testWidgets('écran étroit (320 dp) : aucun débordement', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final selected = <String>[].obs;
    await tester.pumpWidget(_harness(
      ProfileLanguageField(selected: selected, accent: _kWalker),
      lang: 'pl',
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const ValueKey<String>('profile_language_row')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
