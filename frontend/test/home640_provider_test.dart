// 640 (PAM) — Lot 2 : accueils GARDIEN (bleu) et PROMENEUR (vert) dans le
// style des maquettes de Daniel. APPARENCE SEULEMENT : mêmes blocs, mêmes
// clés, mêmes actions.
//
// VRAI écran `SitterHomescreen` sur le faux serveur du harnais lot D (aucun
// réseau, données fictives, centre en pleine mer -35.2 / -30.4) :
//   1. hero : bandeau d'état habillé, silhouette + patte en filigrane pour le
//      promeneur seulement, boutons fusée / cloche / « Changer » toujours là ;
//   2. « Ramène tes clients » : « Partager » plein en dégradé du rôle ;
//   3. carte d'annonce boostée / non boostée : ruban, pastille contour,
//      panneau de l'animal, bouton d'offre toujours présent ;
//   4. états vides : « aucune demande à moins de 200 km » + « c'est calme » ;
//   5. 320 dp : aucune exception de mise en page ;
//   6. images de preuve (si `HOME640_SHOTS` est posé).
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/pet_sitter/home/sitter_homescreen.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_post_card.dart';
import 'package:hopetsit/views/pet_sitter/widgets/post_card_kit.dart';
import 'package:hopetsit/views/shared/widgets/home640_kit.dart';
import 'package:hopetsit/views/shared/widgets/home_hero3110.dart';
import 'package:hopetsit/views/shared/widgets/provider_home3110.dart';
import 'package:hopetsit/services/my_link607.dart';

import 'home640_harness.dart';
import 'lotd_harness.dart';

const double kLat = -35.2;
const double kLng = -30.4;

({double lat, double lng}) eastKm(double km) =>
    (lat: kLat, lng: kLng + km / (111.32 * math.cos(kLat * math.pi / 180)));

Finder _k(String key) => find.byKey(ValueKey<String>(key));

Map<String, dynamic> _post(
  String id,
  double km, {
  String service = 'pet_sitting',
  bool boosted = false,
  String pet = 'Rex',
  String sex = 'male',
}) {
  final p = eastKm(km);
  return <String, dynamic>{
    'id': id,
    'postType': 'text',
    'body': 'Annonce $id',
    'startDate': '2026-12-10T09:00:00.000Z',
    'endDate': '2026-12-12T18:00:00.000Z',
    'serviceTypes': <String>[service],
    'location': <String, dynamic>{'city': 'Zone test', 'lat': p.lat, 'lng': p.lng},
    'createdAt': '2026-11-09T08:00:00.000Z',
    'owner': <String, dynamic>{'id': 'o-$id', 'name': 'Proprio $id', 'email': '', 'avatar': ''},
    if (boosted) 'isOwnerBoosted': true,
    if (boosted) 'ownerBoostTier': 'gold',
    'pets': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'pet-$id',
        'petName': pet,
        'avatar': '',
        'photos': <String>[],
        'breed': 'Berger fictif',
        'age': 3,
        'sex': sex,
      },
    ],
  };
}

Future<void> _profile(String role) async {
  await GetStorage().write(StorageKeys.userProfile, <String, dynamic>{
    'id': 'u-test',
    '_id': 'u-test',
    'name': 'Camille Durand',
    'email': 'camille@example.test',
    'role': role,
    'city': 'Zone test',
    'location': <String, dynamic>{'city': 'Zone test', 'country': 'Test', 'lat': kLat, 'lng': kLng},
  });
}

void _serve(List<Map<String, dynamic>> posts, {required String role}) {
  lotdResponder = (req) {
    if (req.url.path.endsWith('/posts/requests')) {
      return <String, dynamic>{'posts': posts};
    }
    // Lien public fictif du prestataire : carte « Ramène tes clients ».
    if (req.url.path.endsWith('/public/providers/me/link')) {
      return <String, dynamic>{
        'slug': 'camille-d-zone-test',
        'url': 'https://www.hopetsit.com/s/camille-d-zone-test',
        'role': role,
        'city': 'Zone test',
        'isPioneer': false,
        'bookingsCount': 0,
        'posterPath': '/public/providers/camille-d-zone-test/poster.pdf',
      };
    }
    // Tout le reste : vide mais bien formé (aucun bandeau d'erreur).
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

Future<void> _open(
  WidgetTester tester, {
  GlobalKey? shot,
  double width = 393,
  double height = 852,
}) async {
  lotdPhone(tester, width: width, height: height);
  // Fenêtre haute, échelle d'un vrai téléphone (voir `home640App`).
  final Widget app = home640App(
    const SitterHomescreen(),
    designHeight: width < 393 ? height * 852 / 568 : height,
  );
  await tester.pumpWidget(shot == null ? app : home640Boundary(shot, app));
  await lotdSettle(tester, frames: 8);
}

/// Le dégradé du bouton « Partager ».
LinearGradient? _shareGradient(WidgetTester tester) {
  final Finder ink = find.descendant(of: _k('neo607_home_share'), matching: find.byType(Ink));
  if (ink.evaluate().isEmpty) return null;
  final Decoration? d = tester.widget<Ink>(ink.first).decoration;
  return d is BoxDecoration ? d.gradient as LinearGradient? : null;
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await home640LoadIconFont();
  });

  for (final String role in <String>['sitter', 'walker']) {
    final bool walker = role == 'walker';
    final String service = walker ? 'dog_walking' : 'pet_sitting';
    final HomeTokens3110 tokens = HomeTokens3110.forRole(role);

    group('accueil $role 640', () {
      setUp(() async {
        resetMyLinkCache607();
        await lotdSetUp(role: role);
        await _profile(role);
      });

      testWidgets('hero, « Ramène tes clients », rayon, carte boostée / non boostée', (tester) async {
        _serve(<Map<String, dynamic>>[
          _post('b1', 4, service: service, boosted: true, pet: 'Rex'),
          _post('n2', 6, service: service, pet: 'Luna', sex: 'female'),
        ], role: role);
        final GlobalKey shot = GlobalKey();
        // Écran haut : tout l'accueil tient sur l'image de preuve.
        await _open(tester, shot: shot, height: 2300);
        expect(tester.takeException(), isNull);
        expect(kProviderHome640, isTrue);

        // 1. Hero : bandeau d'état EXISTANT, habillé ; boutons inchangés.
        expect(_k('home_hero_status'), findsOneWidget);
        expect(find.byType(HeroStatusBlock640), findsOneWidget);
        expect(find.text('quick_action_title_provider'.tr), findsOneWidget);
        expect(
          find.text(walker ? 'pamb3110_status_sub_walker'.tr : 'pamb3110_status_sub_sitter'.tr),
          findsOneWidget,
        );
        expect(_k('home_hero_rocket'), findsOneWidget);
        expect(_k('home_hero_bell'), findsOneWidget);
        expect(_k('home_hero_change_city'), findsOneWidget);
        // 641 — silhouette du bandeau pour les DEUX rôles (gardien : chien et
        // chat ; promeneur : chien en laisse). Patte en filigrane : promeneur seul.
        expect(_k('home640_status_deco'), findsOneWidget);
        expect(
          tester.widget<HomeSilhouette640>(_k('home640_status_deco')).deco,
          walker ? HomeDeco640.dogOnLeash : HomeDeco640.dogAndCat,
        );
        expect(_k('home640_hero_paw'), walker ? findsOneWidget : findsNothing);
        if (walker) {
          // La patte n'est jamais tactile : la fusée et la cloche reçoivent
          // bien le tap (aucun décor au-dessus d'elles pour le test de tap).
          expect(
            find.ancestor(of: _k('home640_hero_paw'), matching: find.byType(IgnorePointer)),
            findsWidgets,
          );
          expect(_k('home_hero_rocket').hitTestable(), findsOneWidget);
          expect(_k('home_hero_bell').hitTestable(), findsOneWidget);
        }

        // 2. « Ramène tes clients » : mêmes deux boutons ; « Partager » en
        //    dégradé du rôle, « Affiche QR » clair.
        expect(_k('neo607_home_share'), findsOneWidget);
        expect(_k('neo607_home_more'), findsOneWidget);
        final LinearGradient? g = _shareGradient(tester);
        expect(g, isNotNull);
        expect(g!.colors, <Color>[tokens.heroStart, tokens.heroEnd]);
        final Iterable<PillButton3110> pills = tester.widgetList<PillButton3110>(find.byType(PillButton3110));
        expect(pills.where((p) => p.filled).length, 1);
        expect(pills.where((p) => !p.filled).length, greaterThanOrEqualTo(1));

        // 3. Rayon : curseur et valeur inchangés.
        expect(_k('around_me_radius_slider'), findsOneWidget);
        expect(_k('around_me_radius_value'), findsOneWidget);

        // 4. Cartes d'annonce : 2, dont UNE boostée.
        expect(find.byType(PetPostCard), findsNWidgets(2));
        expect(find.text('post_boost_active'.tr), findsOneWidget);
        final List<PetPostCard> cards = tester.widgetList<PetPostCard>(find.byType(PetPostCard)).toList();
        expect(cards.where((c) => c.isOwnerBoosted).length, 1);
        // Le bouton d'offre est toujours branché sur chaque carte.
        expect(cards.every((c) => c.onSendRequest != null), isTrue);
        // Pastille de service en contour, panneau de l'animal sur chaque carte.
        final Iterable<PostTypeChip> chips = tester.widgetList<PostTypeChip>(find.byType(PostTypeChip));
        expect(chips, isNotEmpty);
        expect(chips.every((c) => c.outlined), isTrue);
        expect(find.byType(PostPetPanel640), findsNWidgets(2));
        expect(_k('post640_pet_photo'), findsNWidgets(2));
        expect(find.text('Rex'), findsWidgets);
        expect(find.text('Luna'), findsWidgets);
        expect(find.text('pet_sex_male'.tr), findsWidgets);
        expect(find.text('pet_sex_female'.tr), findsWidgets);
        // Le panneau de l'animal porte la couleur de rôle de la carte
        // (gardien #2563EB, promeneur #16A34A : celles de la carte existante).
        final Color cardAccent = walker ? const Color(0xFF16A34A) : const Color(0xFF2563EB);
        expect(
          tester.widgetList<PostPetPanel640>(find.byType(PostPetPanel640)).every((p) => p.accent == cardAccent),
          isTrue,
          reason: 'accent du panneau = couleur du rôle',
        );

        await home640Precache(tester);
        await home640Shot(tester, shot, '${role}_accueil');
        // Carte boostée seule (recadrée sur la vraie carte du vrai écran).
        final Finder boosted = find.byWidgetPredicate((w) => w is PetPostCard && w.isOwnerBoosted);
        final Rect r = tester.getRect(boosted);
        await home640Shot(
          tester,
          shot,
          walker ? 'carte_annonce_boost_walker' : 'carte_annonce_boost',
          crop: r.inflate(14),
        );
        await tester.pump(const Duration(seconds: 1));
      });

      testWidgets('états vides : « aucune demande à moins de 200 km » + « c\'est calme »', (tester) async {
        _serve(<Map<String, dynamic>>[
          _post('loin', 450, service: service),
          _post('busan', 11254, service: service),
        ], role: role);
        final GlobalKey shot = GlobalKey();
        await _open(tester, shot: shot, height: 1500);
        expect(tester.takeException(), isNull);
        expect(_k('home617_too_far'), findsOneWidget);
        expect(_k('home640_too_far_tile'), findsOneWidget);
        expect(find.byIcon(Icons.near_me_disabled_rounded), findsOneWidget);
        expect(find.textContaining('200 km'), findsWidgets);
        expect(find.text('bob617_nothing_within_max_sub'.tr), findsOneWidget);
        expect(_k('provider_quiet_card'), findsOneWidget);
        expect(_k('home_empty_refresh'), findsOneWidget);
        expect(_k('home_empty_profile'), findsOneWidget);
        expect(find.byType(PetPostCard), findsNothing);
        await home640Precache(tester);
        await home640Shot(tester, shot, '${role}_vide');
        await tester.pump(const Duration(seconds: 1));
      });

      testWidgets('320 dp : aucune exception (annonces puis état vide)', (tester) async {
        _serve(<Map<String, dynamic>>[
          _post('b1', 4, service: service, boosted: true, pet: 'Maximilien-Alexandre'),
          _post('n2', 6, service: service, pet: 'Luna', sex: 'female'),
        ], role: role);
        await _open(tester, width: 320, height: 2600);
        expect(tester.takeException(), isNull);
        expect(find.byType(PetPostCard), findsNWidgets(2));
        expect(_k('home_hero_status'), findsOneWidget);
        // Aucun bloc ne sort de l'écran.
        for (final String key in <String>['home_hero_status', 'neo607_home_share', 'neo607_home_more']) {
          final Rect r = tester.getRect(_k(key));
          expect(r.left, greaterThanOrEqualTo(0), reason: key);
          expect(r.right, lessThanOrEqualTo(320), reason: key);
        }
        for (final Element e in find.byType(PetPostCard).evaluate()) {
          final RenderBox b = e.renderObject! as RenderBox;
          final Offset o = b.localToGlobal(Offset.zero);
          expect(o.dx, greaterThanOrEqualTo(0));
          expect(o.dx + b.size.width, lessThanOrEqualTo(320));
        }
        await tester.pump(const Duration(seconds: 1));
      });

      testWidgets('320 dp : état vide sans exception', (tester) async {
        _serve(<Map<String, dynamic>>[_post('loin', 450, service: service)], role: role);
        await _open(tester, width: 320, height: 1500);
        expect(tester.takeException(), isNull);
        expect(_k('home617_too_far'), findsOneWidget);
        expect(_k('provider_quiet_card'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
      });
    });
  }

  testWidgets('image de preuve : panneau de l\'animal avec une photo', (tester) async {
    await tester.runAsync(() => lotdSetUp(role: 'sitter'));
    lotdPhone(tester, width: 393, height: 260);
    final GlobalKey shot = GlobalKey();
    // Photo fictive du dépôt, lue en mémoire (aucun réseau).
    final ImageProvider photo = MemoryImage(File('assets/images/dummy-dog.png').readAsBytesSync());
    // `home640App` (et non `lotdApp`) : la hauteur de conception suit la
    // fenêtre, sinon les `.h` du panneau sont écrasés (260 / 852).
    await tester.pumpWidget(home640App(
      designHeight: 260,
      home640Boundary(
        shot,
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: PostPetPanel640(
                name: 'Rex',
                accent: const Color(0xFF2563EB),
                meta: 'Berger fictif • 3 ans',
                sexLabel: 'Mâle',
                photo: photo,
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(_k('post640_pet_photo'), findsOneWidget);
    await home640Precache(tester);
    await home640Shot(tester, shot, 'panneau_animal_photo');
  });
}
