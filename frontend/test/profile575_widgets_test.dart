// v575 — Daniel : « "À propos de moi" et "Langue" doivent être pareils, même
// style, sur les 3 profils — moderne et HD ».
//
// Les deux blocs sont maintenant DEUX widgets partagés
// (`lib/views/profile/widgets/profile_about_fields.dart`) montés à l'identique
// par les 3 écrans « Modifier le profil ». Ce test les monte SEULS :
//   · sur un écran de 320 dp (le plus étroit visé) ;
//   · en clair ET en sombre ;
//   · avec les 3 couleurs d'accent (propriétaire, gardien, promeneur) ;
//   · en allemand et en polonais (libellés les plus longs) ;
// et vérifie qu'aucun débordement n'est levé, que le compteur de caractères et
// l'aide « au moins 20 caractères » apparaissent, et que « Langues parlées »
// ne s'appelle plus « Langue » (la confusion avec « Langue de l'app »).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/v565/profile575_i18n.dart';
import 'package:hopetsit/views/profile/widgets/profile_about_fields.dart';

const Color _kOwner = Color(0xFFC92A12);
const Color _kSitter = Color(0xFF2563EB);
const Color _kWalker = Color(0xFF16A34A);
const List<Color> _kAccents = [_kOwner, _kSitter, _kWalker];

class _T extends Translations {
  @override
  Map<String, Map<String, String>> get keys => profile575I18n;
}

// Clés utilisées par les widgets mais définies dans d'autres paquets.
final Map<String, Map<String, String>> _extra = {
  'fr': {'label_about_me': 'À propos de moi', 'hint_bio': 'Parle de toi'},
  'de': {'label_about_me': 'Über mich', 'hint_bio': 'Erzähl von dir'},
  'pl': {'label_about_me': 'O mnie', 'hint_bio': 'Opowiedz o sobie'},
  'en': {'label_about_me': 'About me', 'hint_bio': 'Tell us about you'},
};

class _TAll extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final out = <String, Map<String, String>>{};
    for (final lang in profile575I18n.keys) {
      out[lang] = {
        ...profile575I18n[lang]!,
        ...(_extra[lang] ?? _extra['en']!),
      };
    }
    return out;
  }
}

Widget _harness(Widget child, {String lang = 'fr', Brightness brightness = Brightness.light}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      translations: _TAll(),
      locale: Locale(lang),
      fallbackLocale: const Locale('en'),
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        ),
      ),
    ),
  );
}

void _sizeTo320(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(Get.reset);

  group('ProfileAboutField (bloc « À propos de moi »)', () {
    testWidgets('même rendu pour les 3 accents, clair et sombre, sans débordement',
        (tester) async {
      _sizeTo320(tester);
      for (final accent in _kAccents) {
        for (final brightness in Brightness.values) {
          final c = TextEditingController(text: 'Bonjour');
          addTearDown(c.dispose);
          await tester.pumpWidget(_harness(
            ProfileAboutField(controller: c, accent: accent),
            brightness: brightness,
          ));
          await tester.pump(const Duration(milliseconds: 50));
          expect(find.byKey(const ValueKey<String>('profile_about_field')), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('affiche le compteur et l’aide « au moins 20 caractères »', (tester) async {
      _sizeTo320(tester);
      final c = TextEditingController(text: 'Bonjour');
      addTearDown(c.dispose);
      await tester.pumpWidget(_harness(ProfileAboutField(controller: c, accent: _kOwner)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('7/600'), findsOneWidget);
      expect(find.textContaining('20'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('le compteur suit la saisie', (tester) async {
      _sizeTo320(tester);
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_harness(ProfileAboutField(controller: c, accent: _kWalker)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('0/600'), findsOneWidget);
      c.text = 'abcde';
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('5/600'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('allemand et polonais tiennent sur 320 dp', (tester) async {
      _sizeTo320(tester);
      for (final lang in ['de', 'pl']) {
        final c = TextEditingController(text: 'Test');
        addTearDown(c.dispose);
        await tester.pumpWidget(_harness(
          ProfileAboutField(controller: c, accent: _kSitter),
          lang: lang,
        ));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: lang);
      }
    });
  });

  group('ProfileLanguageField (bloc « Langues parlées »)', () {
    testWidgets('s’appelle « Langues parlées », pas « Langue »', (tester) async {
      _sizeTo320(tester);
      final selected = <String>[].obs;
      addTearDown(selected.close);
      await tester.pumpWidget(_harness(
        ProfileLanguageField(selected: selected, accent: _kOwner),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Langues parlées'), findsOneWidget);
      // Le libellé du réglage d'affichage ne doit PAS apparaître ici.
      expect(find.text("Langue de l’app"), findsNothing);
      expect(find.text('Choisis tes langues'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('résume les langues choisies, 3 accents, clair et sombre', (tester) async {
      _sizeTo320(tester);
      for (final accent in _kAccents) {
        for (final brightness in Brightness.values) {
          final selected = <String>['Français', 'English'].obs;
          addTearDown(selected.close);
          await tester.pumpWidget(_harness(
            ProfileLanguageField(selected: selected, accent: accent),
            brightness: brightness,
          ));
          await tester.pump(const Duration(milliseconds: 50));
          expect(find.textContaining('Français'), findsOneWidget);
          expect(find.byKey(const ValueKey<String>('profile_language_row')), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('allemand et polonais tiennent sur 320 dp', (tester) async {
      _sizeTo320(tester);
      for (final lang in ['de', 'pl']) {
        final selected = <String>['Français', 'Nederlands', 'Português'].obs;
        addTearDown(selected.close);
        await tester.pumpWidget(_harness(
          ProfileLanguageField(selected: selected, accent: _kWalker),
          lang: lang,
        ));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: lang);
      }
    });

    testWidgets('chaque langue de la liste a son drapeau', (tester) async {
      for (final l in ProfileLanguageField.languages) {
        expect(ProfileLanguageField.flagOf(l[1]), isNotEmpty, reason: l[1]);
      }
      expect(ProfileLanguageField.flagOf('Klingon'), isEmpty);
    });
  });

  group('paquet i18n', () {
    test('les 9 langues portent exactement les mêmes clés', () {
      const langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
      expect(profile575I18n.keys.toSet(), langs.toSet());
      final reference = profile575I18n['en']!.keys.toSet();
      for (final l in langs) {
        expect(profile575I18n[l]!.keys.toSet(), reference, reason: l);
        for (final entry in profile575I18n[l]!.entries) {
          expect(entry.value.trim(), isNotEmpty, reason: '$l/${entry.key}');
        }
      }
    });

    test('le placeholder {min} est présent dans les 9 langues', () {
      for (final l in profile575I18n.keys) {
        expect(profile575I18n[l]!['about_helper'], contains('{min}'), reason: l);
      }
    });
  });
}
