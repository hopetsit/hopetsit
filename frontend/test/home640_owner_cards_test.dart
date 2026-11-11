// 640 (PAM) — Lot 1 : les deux grandes cartes « Garde » / « Promenade » de
// l'accueil propriétaire (maquette de Daniel). APPARENCE SEULEMENT : mêmes
// clés, mêmes actions, même règle compact / grand.
//
//   1. composant `OwnerServiceCards640` : présence, hauteurs égales, toute la
//      carte tactile, 320 / 360 / 402 dp × échelle de texte 1,0 / 1,3 / 2,0 ×
//      9 langues, sans débordement ni texte coupé ;
//   2. VRAI écran `HomeScreen` (faux serveur du harnais lot D, données
//      fictives) : un tap ouvre `PublishReservationRequestScreen` avec la bonne
//      valeur de `initialServiceType` ; compact dès qu'une annonce existe ;
//   3. images de preuve (si `HOME640_SHOTS` est posé).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/pet_owner/home/home_screen.dart';
import 'package:hopetsit/views/pet_owner/home/widgets/owner_home3110.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/views/shared/widgets/home640_kit.dart';

import 'home640_harness.dart';
import 'lotd_harness.dart';

const ValueKey<String> kSitting = ValueKey<String>('owner_card_sitting');
const ValueKey<String> kWalking = ValueKey<String>('owner_card_walking');

const List<Locale> kLocales = <Locale>[
  Locale('en', 'US'),
  Locale('fr', 'FR'),
  Locale('es', 'ES'),
  Locale('de', 'DE'),
  Locale('it', 'IT'),
  Locale('pt', 'PT'),
  Locale('ko', 'KR'),
  Locale('ja', 'JP'),
  Locale('pl', 'PL'),
];

void _size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

class _Calls {
  final List<String> log = <String>[];
}

/// Les cartes dans la même marge que l'écran (20 dp de chaque côté).
Widget _host(
  _Calls c, {
  required bool compact,
  double scale = 1.0,
  Locale locale = const Locale('fr', 'FR'),
  GlobalKey? shot,
}) {
  Widget body = Builder(
    builder: (BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      child: OwnerServiceCards640(
        compact: compact,
        sittingTitle: 'pamb3110_card_sitting'.tr,
        walkingTitle: 'pamb3110_card_walking'.tr,
        sittingSubtitle: 'ownerhome571_action_sitting'.tr,
        walkingSubtitle: 'ownerhome571_action_walking'.tr,
        onSitting: () => c.log.add('sitting'),
        onWalking: () => c.log.add('walking'),
      ),
    ),
  );
  if (shot != null) {
    body = home640Boundary(shot, ColoredBox(color: const Color(0xFFFAF6F3), child: body));
  }
  return GetMaterialApp(
    translations: AppTranslations(),
    locale: locale,
    fallbackLocale: const Locale('en', 'US'),
    debugShowCheckedModeBanner: false,
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      backgroundColor: const Color(0xFFFAF6F3),
      body: Align(alignment: Alignment.topCenter, child: body),
    ),
  );
}

/// Aucun texte des cartes n'est coupé (ni « … », ni lignes en trop).
void _expectNoClippedText(WidgetTester tester, String reason) {
  for (final ValueKey<String> k in <ValueKey<String>>[kSitting, kWalking]) {
    final Rect card = tester.getRect(find.byKey(k));
    final Finder texts = find.descendant(of: find.byKey(k), matching: find.byType(RichText));
    for (final Element e in texts.evaluate()) {
      final RenderParagraph p = e.renderObject! as RenderParagraph;
      if (p.text.toPlainText().trim().isEmpty) continue;
      expect(p.didExceedMaxLines, isFalse, reason: '$reason — coupé : « ${p.text.toPlainText()} »');
      final Rect r = MatrixUtils.transformRect(p.getTransformTo(null), Offset.zero & p.size);
      expect(r.left, greaterThanOrEqualTo(card.left - 0.5), reason: reason);
      expect(r.right, lessThanOrEqualTo(card.right + 0.5), reason: reason);
      expect(r.top, greaterThanOrEqualTo(card.top - 0.5), reason: reason);
      expect(r.bottom, lessThanOrEqualTo(card.bottom + 0.5), reason: reason);
    }
  }
}

// ── vrai écran ───────────────────────────────────────────────────────────
const double kLat = -35.2;
const double kLng = -30.4;

Future<void> _ownerProfile() async {
  await GetStorage().write(StorageKeys.userProfile, <String, dynamic>{
    'id': 'u-test',
    '_id': 'u-test',
    'name': 'Camille Durand',
    'email': 'camille@example.test',
    'role': 'owner',
    'city': 'Zone test',
    'location': <String, dynamic>{'city': 'Zone test', 'country': 'Test', 'lat': kLat, 'lng': kLng},
  });
}

Map<String, dynamic> _myPost(String id) => <String, dynamic>{
      'id': id,
      'postType': 'text',
      'body': 'Annonce $id',
      'startDate': '2026-12-10T09:00:00.000Z',
      'endDate': '2026-12-12T18:00:00.000Z',
      'serviceTypes': <String>['pet_sitting'],
      'location': <String, dynamic>{'city': 'Zone test', 'lat': kLat, 'lng': kLng + 0.01 * math.pi},
      'createdAt': '2026-11-09T08:00:00.000Z',
      'owner': <String, dynamic>{'id': 'u-test', 'name': 'Camille Durand', 'email': '', 'avatar': ''},
    };

void _serve({List<Map<String, dynamic>> posts = const <Map<String, dynamic>>[]}) {
  lotdResponder = (req) {
    final String p = req.url.path;
    if (p.endsWith('/sitters/nearby')) return <String, dynamic>{'sitters': <Map<String, dynamic>>[]};
    if (p.endsWith('/walkers/nearby')) return <String, dynamic>{'walkers': <Map<String, dynamic>>[]};
    if (p.endsWith('/posts') || p.endsWith('/posts/media') || p.endsWith('/posts/requests')) {
      return <String, dynamic>{'posts': posts};
    }
    // Tout le reste : une réponse vide mais bien formée (aucun bandeau
    // d'erreur sur les images de preuve).
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

Future<void> _openHome(WidgetTester tester, {GlobalKey? shot, double width = 393, double height = 852}) async {
  lotdPhone(tester, width: width, height: height);
  final Widget app = lotdApp(const HomeScreen());
  await tester.pumpWidget(shot == null ? app : home640Boundary(shot, app));
  await tester.pump(const Duration(seconds: 7)); // délai GPS (sans plugin)
  await lotdSettle(tester, frames: 8);
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await home640LoadIconFont();
  });

  group('cartes propriétaire 640 — composant', () {
    testWidgets('grandes : tout présent, même hauteur, toute la carte tactile', (tester) async {
      _size(tester, 402, 400);
      final _Calls c = _Calls();
      await tester.pumpWidget(_host(c, compact: false));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(kOwnerHomeCards640, isTrue);

      expect(find.byKey(kSitting), findsOneWidget);
      expect(find.byKey(kWalking), findsOneWidget);
      expect(find.text('Garde'), findsOneWidget);
      expect(find.text('Promenade'), findsOneWidget);
      expect(find.text('ownerhome571_action_sitting'.tr), findsOneWidget);
      expect(find.text('ownerhome571_action_walking'.tr), findsOneWidget);
      // Décors : une silhouette par carte, une flèche par carte.
      expect(find.byType(HomeSilhouette640), findsNWidgets(2));
      expect(find.byIcon(Icons.north_east_rounded), findsNWidgets(2));

      final Rect a = tester.getRect(find.byKey(kSitting));
      final Rect b = tester.getRect(find.byKey(kWalking));
      expect(a.height, b.height);
      expect(a.width, b.width);
      expect(a.top, b.top);
      expect(a.left, 20);
      expect(b.right, 402 - 20);
      expect(b.left - a.right, 12);
      expect(a.height, greaterThanOrEqualTo(124));
      expect(a.height, lessThanOrEqualTo(134)); // 641 : cartes moins hautes
      _expectNoClippedText(tester, 'grandes 402');

      // Toute la carte est tactile : les 4 coins + le centre + le décor.
      for (final Offset o in <Offset>[
        a.topLeft + const Offset(14, 14),
        a.topRight + const Offset(-14, 14),
        a.bottomLeft + const Offset(14, -14),
        a.bottomRight + const Offset(-14, -14),
        a.center,
      ]) {
        await tester.tapAt(o);
      }
      expect(c.log, List<String>.filled(5, 'sitting'));
      c.log.clear();
      for (final Offset o in <Offset>[
        b.topLeft + const Offset(14, 14),
        b.topRight + const Offset(-14, 14),
        b.bottomLeft + const Offset(14, -14),
        b.bottomRight + const Offset(-14, -14),
        b.center,
      ]) {
        await tester.tapAt(o);
      }
      expect(c.log, List<String>.filled(5, 'walking'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('compactes : même clés, mêmes actions, hauteur inchangée (76 dp, comme le 31/10)',
        (tester) async {
      _size(tester, 402, 400);
      final _Calls c = _Calls();
      await tester.pumpWidget(_host(c, compact: true));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      final Rect a = tester.getRect(find.byKey(kSitting));
      final Rect b = tester.getRect(find.byKey(kWalking));
      expect(a.height, kOwnerCardCompactHeight640);
      expect(b.height, kOwnerCardCompactHeight640);
      expect(find.text('Garde'), findsOneWidget);
      expect(find.text('Promenade'), findsOneWidget);
      // Les sous-titres ne figurent pas en compact (comme avant) — ils restent
      // lus par les lecteurs d'écran.
      expect(find.text('ownerhome571_action_sitting'.tr), findsNothing);
      await tester.tap(find.byKey(kSitting));
      await tester.tap(find.byKey(kWalking));
      expect(c.log, <String>['sitting', 'walking']);
      _expectNoClippedText(tester, 'compactes 402');
      await tester.pump(const Duration(milliseconds: 400));

      // Référence : la carte compacte du 31/10 a la même hauteur.
      await tester.pumpWidget(GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr', 'FR'),
        // Comme dans l'écran : dans une liste (hauteur libre).
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(20),
                child: ServiceCards3110(
                  compact: true,
                  sittingSubtitle: 'x',
                  walkingSubtitle: 'y',
                  onSitting: () {},
                  onWalking: () {},
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getRect(find.byKey(kSitting)).height, kOwnerCardCompactHeight640);
    });

    testWidgets('320 / 360 / 402 dp × échelle 1,0 / 1,3 / 2,0 × 9 langues : aucun débordement, '
        'aucun texte coupé, même taille de texte dans les deux cartes', (tester) async {
      final _Calls c = _Calls();
      final Set<String> titles = <String>{};
      for (final double w in <double>[320, 360, 402]) {
        _size(tester, w, 500);
        for (final double scale in <double>[1.0, 1.3, 2.0]) {
          for (final bool compact in <bool>[false, true]) {
            for (final Locale loc in kLocales) {
              final String why = 'largeur $w échelle $scale compact $compact ${loc.languageCode}';
              Get.locale = loc; // la langue change vraiment (vérifié juste après)
              await tester.pumpWidget(_host(c, compact: compact, scale: scale, locale: loc));
              await tester.pump(const Duration(milliseconds: 30));
              expect(tester.takeException(), isNull, reason: why);
              expect(Get.locale?.languageCode, loc.languageCode, reason: why);
              final Rect a = tester.getRect(find.byKey(kSitting));
              final Rect b = tester.getRect(find.byKey(kWalking));
              expect(a.height, b.height, reason: why);
              expect(a.left, greaterThanOrEqualTo(20), reason: why);
              expect(b.right, lessThanOrEqualTo(w - 20), reason: why);
              _expectNoClippedText(tester, why);
              expect(find.text('pamb3110_card_sitting'.tr), findsOneWidget, reason: why);
              expect(find.text('pamb3110_card_walking'.tr), findsOneWidget, reason: why);
              if (!compact) {
                expect(find.text('ownerhome571_action_sitting'.tr), findsOneWidget, reason: why);
                expect(find.text('ownerhome571_action_walking'.tr), findsOneWidget, reason: why);
              }
              // Titre présent, et même taille de police dans les deux cartes.
              final Text ta = tester.widget<Text>(find.descendant(
                  of: find.byKey(kSitting), matching: find.text('pamb3110_card_sitting'.tr)));
              final Text tb = tester.widget<Text>(find.descendant(
                  of: find.byKey(kWalking), matching: find.text('pamb3110_card_walking'.tr)));
              expect(ta.style!.fontSize, tb.style!.fontSize, reason: why);
              expect(ta.style!.fontSize, greaterThanOrEqualTo(10.5), reason: why);
              if (!compact) {
                final Text sa = tester.widget<Text>(find.descendant(
                    of: find.byKey(kSitting), matching: find.text('ownerhome571_action_sitting'.tr)));
                expect(sa.style!.fontSize, greaterThanOrEqualTo(10.5), reason: why);
                expect(sa.maxLines, 2);
              }
              titles.add('pamb3110_card_sitting'.tr);
            }
          }
        }
      }
      // Les 9 langues ont bien été rendues (au moins 6 libellés distincts).
      expect(titles.length, greaterThanOrEqualTo(6), reason: '$titles');
    });

    testWidgets('image de preuve : les deux silhouettes en grand', (tester) async {
      _size(tester, 640, 260);
      final GlobalKey k = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: home640Boundary(
          k,
          Row(children: <Widget>[
            Expanded(
              child: Container(
                color: const Color(0xFF2457C5),
                alignment: Alignment.center,
                child: const HomeSilhouette640(deco: HomeDeco640.dogAndCat, height: 180, opacity: 0.9),
              ),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFF1F9A4B),
                alignment: Alignment.center,
                child: const HomeSilhouette640(deco: HomeDeco640.dogOnLeash, height: 180, opacity: 0.9),
              ),
            ),
          ]),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await home640Shot(tester, k, 'silhouettes', pixelRatio: 1.5);
    });

    testWidgets('images de preuve du composant (320 dp, échelle 1,3)', (tester) async {
      _size(tester, 320, 260);
      final GlobalKey k = GlobalKey();
      await tester.pumpWidget(_host(_Calls(), compact: false, scale: 1.3, shot: k));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await home640Shot(tester, k, 'owner_cartes_320_x1_3', pixelRatio: 3);
    });
  });

  group('cartes propriétaire 640 — vrai écran d\'accueil', () {
    setUp(() async {
      await lotdSetUp(role: 'owner');
      await _ownerProfile();
      const geo = MethodChannel('flutter.baseflow.com/geolocator');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(geo, (MethodCall c) async => throw MissingPluginException(c.method));
    });

    testWidgets('sans annonce : grandes cartes ; tap → PublishReservationRequestScreen '
        'avec pet_sitting puis dog_walking', (tester) async {
      _serve();
      final GlobalKey shot = GlobalKey();
      await _openHome(tester, shot: shot);
      expect(tester.takeException(), isNull);
      expect(find.byType(OwnerServiceCards640), findsOneWidget);
      expect(find.byType(ServiceCards3110), findsNothing);
      expect(tester.widget<OwnerServiceCards640>(find.byType(OwnerServiceCards640)).compact, isFalse);
      expect(tester.getRect(find.byKey(kSitting)).height, greaterThanOrEqualTo(124));
      await home640Shot(tester, shot, 'owner_cartes');

      await tester.tap(find.byKey(kSitting));
      await lotdSettle(tester, frames: 6);
      expect(find.byType(PublishReservationRequestScreen), findsOneWidget);
      expect(
        tester.widget<PublishReservationRequestScreen>(find.byType(PublishReservationRequestScreen)).initialServiceType,
        'pet_sitting',
      );
      Get.back<void>();
      await lotdSettle(tester, frames: 6);
      expect(find.byType(PublishReservationRequestScreen), findsNothing);

      await tester.tap(find.byKey(kWalking));
      await lotdSettle(tester, frames: 6);
      expect(find.byType(PublishReservationRequestScreen), findsOneWidget);
      expect(
        tester.widget<PublishReservationRequestScreen>(find.byType(PublishReservationRequestScreen)).initialServiceType,
        'dog_walking',
      );
      Get.back<void>();
      await lotdSettle(tester, frames: 6);
      tester.takeException(); // l'écran de publication n'est pas l'objet de ce test
    });

    // 641 — retour testeur (captures du 10/11) : au repos, le bouton « Publier
    // mon annonce » de la carte « première annonce » passait SOUS le menu
    // flottant. Pire cas Android : barre d'état 32 dp, dégagement bas 48 dp,
    // menu = 76 dp (marge 6 + barre 70) au-dessus du dégagement.
    for (final Size phone in const <Size>[Size(360, 740), Size(360, 800), Size(393, 852), Size(412, 915)]) {
      testWidgets('641 — sans annonce, Publier visible au repos au-dessus du menu '
          '(${phone.width.toInt()}×${phone.height.toInt()})', (tester) async {
        _serve();
        tester.view.padding = const FakeViewPadding(top: 32, bottom: 48);
        tester.view.viewPadding = const FakeViewPadding(top: 32, bottom: 48);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        await _openHome(tester, width: phone.width, height: phone.height);
        expect(tester.takeException(), isNull);
        final Rect cta = tester.getRect(find.byKey(const ValueKey<String>('owner_first_post_cta')));
        final Rect card = tester.getRect(find.byKey(kSitting));
        final double menuTop = phone.height - 48 - 76;
        // ignore: avoid_print
        print('M641 ${phone.width.toInt()}x${phone.height.toInt()} carte=$card cta=$cta menuTop=$menuTop');
        expect(card.height, lessThanOrEqualTo(134));
        expect(cta.bottom, lessThanOrEqualTo(menuTop),
            reason: 'le bouton Publier doit rester au-dessus du menu au repos');
      });
    }

    testWidgets('avec une annonce à moi : cartes compactes, mêmes actions', (tester) async {
      _serve(posts: <Map<String, dynamic>>[_myPost('a1')]);
      final GlobalKey shot = GlobalKey();
      await _openHome(tester, shot: shot);
      expect(tester.takeException(), isNull);
      expect(tester.widget<OwnerServiceCards640>(find.byType(OwnerServiceCards640)).compact, isTrue);
      expect(tester.getRect(find.byKey(kSitting)).height, kOwnerCardCompactHeight640);
      await home640Shot(tester, shot, 'owner_compact');

      await tester.tap(find.byKey(kWalking));
      await lotdSettle(tester, frames: 6);
      expect(
        tester.widget<PublishReservationRequestScreen>(find.byType(PublishReservationRequestScreen)).initialServiceType,
        'dog_walking',
      );
      Get.back<void>();
      await lotdSettle(tester, frames: 6);
      tester.takeException();
    });

    testWidgets('vrai écran à 320 dp et échelle de texte 1,3 : aucun débordement', (tester) async {
      _serve();
      lotdPhone(tester, width: 320, height: 700);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(lotdApp(const HomeScreen()));
      await tester.pump(const Duration(seconds: 7));
      await lotdSettle(tester, frames: 8);
      expect(tester.takeException(), isNull);
      expect(find.byKey(kSitting), findsOneWidget);
      _expectNoClippedText(tester, 'vrai écran 320 ×1,3');
    });
  });
}
