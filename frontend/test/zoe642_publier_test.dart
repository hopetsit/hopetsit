// 642 (ZOE) — défaut 1 du contrôle 641 : le bouton « Publier mon annonce » de
// la carte « première annonce » passait encore SOUS le menu flottant au repos
// sur les petits écrans (360×640 et 320×568). Il doit être entièrement visible
// et tapable au repos sur les 6 tailles, dans les 9 langues.
//
// Pire cas Android : barre d'état 32 dp, barre système 48 dp. Le haut du menu
// est celui qu'annonce `pawTabBarUsefulHeight` (jamais un chiffre en dur).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/pet_owner/home/home_screen.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';

import 'home640_harness.dart';
import 'lotd_harness.dart';

const ValueKey<String> kCta = ValueKey<String>('owner_first_post_cta');
const ValueKey<String> kPinned = ValueKey<String>('owner_first_post_cta_pinned');

const List<Size> kPhones = <Size>[
  Size(320, 568),
  Size(360, 640),
  Size(360, 800),
  Size(390, 844),
  Size(393, 852),
  Size(412, 915),
];

const List<Locale> kLocales = <Locale>[
  Locale('fr', 'FR'),
  Locale('en', 'US'),
  Locale('es', 'ES'),
  Locale('de', 'DE'),
  Locale('it', 'IT'),
  Locale('pt', 'PT'),
  Locale('ko', 'KR'),
  Locale('ja', 'JP'),
  Locale('pl', 'PL'),
];

const double kStatusBar = 32;
const double kSystemBar = 48;

void _serve() {
  lotdResponder = (req) {
    final String p = req.url.path;
    if (p.endsWith('/sitters/nearby')) return <String, dynamic>{'sitters': <Map<String, dynamic>>[]};
    if (p.endsWith('/walkers/nearby')) return <String, dynamic>{'walkers': <Map<String, dynamic>>[]};
    return <String, dynamic>{
      'pets': <Map<String, dynamic>>[],
      'posts': <Map<String, dynamic>>[],
      'notifications': <Map<String, dynamic>>[],
      'blocks': <Map<String, dynamic>>[],
      'bookings': <Map<String, dynamic>>[],
      'applications': <Map<String, dynamic>>[],
      'conversations': <Map<String, dynamic>>[],
      'count': 0,
    };
  };
}

final List<int> menuTaps = <int>[];

/// L'accueil SOUS le vrai menu flottant (même montage que l'enveloppe de
/// navigation : `extendBody`, menu posé au-dessus de la barre système).
Widget _underMenu() => Scaffold(
      extendBody: true,
      body: const HomeScreen(),
      bottomNavigationBar: PawTabBar(
        currentIndex: 0,
        onTap: menuTaps.add,
        role: PawNavRole.owner,
        systemInset: kSystemBar,
        labels: const <String>['Accueil', 'Chat', 'PawMap', 'Réservations', 'Profil'],
      ),
    );

Future<void> _open(WidgetTester tester, Size phone, Locale locale, {double textScale = 1.0}) async {
  menuTaps.clear();
  tester.view.padding = const FakeViewPadding(top: kStatusBar, bottom: kSystemBar);
  tester.view.viewPadding = const FakeViewPadding(top: kStatusBar, bottom: kSystemBar);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  if (textScale != 1.0) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  lotdPhone(tester, width: phone.width, height: phone.height);
  await tester.pumpWidget(lotdApp(_underMenu(), locale: locale));
  await tester.pump(const Duration(seconds: 7)); // délai GPS (sans plugin)
  await lotdSettle(tester, frames: 8);
}

/// Le bouton « Publier » que l'utilisateur voit au repos : celui de la carte,
/// ou son double épinglé au-dessus du menu quand celui de la carte est caché.
Rect _publier(WidgetTester tester) {
  final Finder pinned = find.byKey(kPinned);
  return tester.getRect(pinned.evaluate().isNotEmpty ? pinned : find.byKey(kCta));
}

/// Haut du menu, patte centrale comprise (hauteur annoncée par le menu).
double _menuTop(Size phone) => phone.height - pawTabBarTotalHeight(kSystemBar);

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await home640LoadIconFont();
  });

  setUp(() async {
    await lotdSetUp(role: 'owner');
    await GetStorage().write(StorageKeys.userProfile, <String, dynamic>{
      'id': 'u-test',
      '_id': 'u-test',
      'name': 'Camille Durand',
      'email': 'camille@example.test',
      'role': 'owner',
      'city': 'Zone test',
      'location': <String, dynamic>{'city': 'Zone test', 'country': 'Test', 'lat': -35.2, 'lng': -30.4},
    });
    const geo = MethodChannel('flutter.baseflow.com/geolocator');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geo, (MethodCall c) async => throw MissingPluginException(c.method));
  });

  for (final Size phone in kPhones) {
    final String name = '${phone.width.toInt()}×${phone.height.toInt()}';
    for (final Locale loc in kLocales) {
      testWidgets('642 — Publier entièrement visible au repos au-dessus du menu ($name, ${loc.languageCode})',
          (tester) async {
        _serve();
        await _open(tester, phone, loc);
        expect(tester.takeException(), isNull);
        expect(Get.locale?.languageCode, loc.languageCode);
        final Rect cta = _publier(tester);
        final double menuTop = _menuTop(phone);
        // ignore: avoid_print
        print('Z642 $name ${loc.languageCode} épinglé=${find.byKey(kPinned).evaluate().isNotEmpty} '
            'cta=${cta.top.toStringAsFixed(1)}→${cta.bottom.toStringAsFixed(1)} '
            'menuTop=$menuTop marge=${(menuTop - cta.bottom).toStringAsFixed(1)}');
        expect(cta.height, greaterThanOrEqualTo(44), reason: 'cible tactile');
        expect(cta.left, greaterThanOrEqualTo(0));
        expect(cta.right, lessThanOrEqualTo(phone.width));
        expect(cta.top, greaterThanOrEqualTo(kStatusBar));
        expect(cta.bottom, lessThanOrEqualTo(menuTop),
            reason: 'le bouton Publier doit rester entièrement au-dessus du menu au repos');
        // Le libellé du bouton n'est pas coupé.
        final Finder pinned = find.byKey(kPinned);
        final Finder btn = pinned.evaluate().isNotEmpty ? pinned : find.byKey(kCta);
        for (final Element e in find.descendant(of: btn, matching: find.byType(RichText)).evaluate()) {
          final RenderParagraph p = e.renderObject! as RenderParagraph;
          if (p.text.toPlainText().trim().length < 2) continue; // icône
          expect(p.text.toPlainText(), 'ownerhome571_first_cta'.tr);
          expect(p.didExceedMaxLines, isFalse, reason: 'libellé coupé : ${p.text.toPlainText()}');
        }
      });
    }

    testWidgets('642 — Publier tapable au repos sous le vrai menu ($name) : centre, bas, coins', (tester) async {
      _serve();
      await _open(tester, phone, const Locale('fr', 'FR'));
      final Rect cta = _publier(tester);
      expect(cta.bottom, lessThanOrEqualTo(_menuTop(phone)));
      for (final Offset o in <Offset>[
        cta.center, // sous la patte centrale si le bouton était trop bas
        Offset(cta.center.dx, cta.bottom - 3),
        Offset(cta.left + 24, cta.center.dy),
        Offset(cta.right - 24, cta.center.dy),
      ]) {
        await tester.tapAt(o);
        await lotdSettle(tester, frames: 6);
        expect(menuTaps, isEmpty, reason: 'le tap $o est parti dans le menu');
        expect(find.byType(PublishReservationRequestScreen), findsOneWidget, reason: 'tap $o');
        Get.back<void>();
        await lotdSettle(tester, frames: 6);
        tester.takeException(); // l'écran de publication n'est pas l'objet de ce test
      }
    });
  }

  testWidgets('642 — petit écran : en défilant, le bouton de la carte devient visible et le double s\'efface',
      (tester) async {
    _serve();
    const Size phone = Size(360, 640);
    await _open(tester, phone, const Locale('fr', 'FR'));
    expect(find.byKey(kPinned), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await lotdSettle(tester, frames: 4);
    expect(find.byKey(kPinned), findsNothing);
    final Rect cta = tester.getRect(find.byKey(kCta));
    expect(cta.top, greaterThanOrEqualTo(kStatusBar));
    expect(cta.bottom, lessThanOrEqualTo(_menuTop(phone)));
    // Retour en haut : le double revient.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await lotdSettle(tester, frames: 4);
    expect(find.byKey(kPinned), findsOneWidget);
  });

  // Gros caractères sur petit écran : le bouton reste visible, entier, tapable.
  for (final Size phone in const <Size>[Size(320, 568), Size(360, 640)]) {
    for (final double scale in const <double>[1.3, 1.6]) {
      for (final Locale loc in kLocales) {
        testWidgets('642 — Publier visible au repos, gros caractères ×$scale '
            '(${phone.width.toInt()}×${phone.height.toInt()}, ${loc.languageCode})', (tester) async {
          _serve();
          await _open(tester, phone, loc, textScale: scale);
          expect(tester.takeException(), isNull);
          final Rect cta = _publier(tester);
          expect(cta.top, greaterThanOrEqualTo(kStatusBar));
          expect(cta.bottom, lessThanOrEqualTo(_menuTop(phone)));
          expect(cta.height, greaterThanOrEqualTo(44));
          final Finder pinned = find.byKey(kPinned);
          final Finder btn = pinned.evaluate().isNotEmpty ? pinned : find.byKey(kCta);
          final Finder label = find.descendant(of: btn, matching: find.text('ownerhome571_first_cta'.tr));
          expect(label, findsOneWidget);
          final Rect lr = tester.getRect(label);
          expect(lr.left, greaterThanOrEqualTo(cta.left));
          expect(lr.right, lessThanOrEqualTo(cta.right));
          await tester.tapAt(cta.center);
          await lotdSettle(tester, frames: 6);
          expect(menuTaps, isEmpty);
          expect(find.byType(PublishReservationRequestScreen), findsOneWidget);
          Get.back<void>();
          await lotdSettle(tester, frames: 6);
          tester.takeException();
        });
      }
    }
  }

  testWidgets('642 — grand écran : aucun double, le bouton de la carte suffit', (tester) async {
    _serve();
    await _open(tester, const Size(393, 852), const Locale('fr', 'FR'));
    expect(find.byKey(kPinned), findsNothing);
    expect(find.byKey(kCta), findsOneWidget);
  });
}
