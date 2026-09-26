// v592 — Daniel (26/09) : « quand je me connecte, il y a un mini lag qui
// clignote, qui tremble sur mon profil le temps que ça s'installe ».
//
// Ce test MESURE ce que voit l'utilisateur pendant le chargement de l'onglet
// Profil : il monte le VRAI ProfileScreen (propriétaire) avec un faux serveur
// dont chaque réponse est retenue, puis libère les réponses UNE PAR UNE, dans
// l'ordre le plus défavorable, en relevant à chaque étape :
//   · la hauteur de l'en-tête (ProfileHero) ;
//   · la position verticale du bloc « Mes profils » quand il est visible ;
//   · l'apparition d'un contenu FAUX (« Ajouter un animal » alors que la
//     personne a un animal, compteur « 0 » avant le vrai nombre).
// Un affichage stable = hauteur d'en-tête constante, aucun saut du contenu
// visible, aucun faux contenu.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/utils/profile_display_cache.dart';
import 'package:hopetsit/views/pet_sitter/profile/sitter_profile_screen.dart';
import 'package:hopetsit/views/profile/profile_screen.dart';
import 'package:hopetsit/views/profile/widgets/my_profiles_card.dart';
import 'package:hopetsit/views/profile/widgets/profile_hero.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';

import 'lotd_harness.dart';

/// Réponses retenues : le test décide quand chaque route répond.
final Map<String, Completer<void>> _gates = <String, Completer<void>>{};

const List<String> _gated = <String>[
  '/users/me/profile',
  '/users/me/benefits',
  '/pets/me',
  '/friends',
];

Map<String, dynamic> _payload(String path) {
  switch (path) {
    case '/users/me/profile':
      return <String, dynamic>{
        'profile': <String, dynamic>{
          'id': 'u-test',
          'name': 'Camille Durand',
          'email': 'camille@example.test',
          // Profil incomplet : la carte « profil complété à X % » s'affiche.
          'mobile': '',
          'address': '',
          'avatar': <String, dynamic>{'url': ''},
          'stats': <String, dynamic>{'petsCount': 1, 'bookingsCount': 2},
        },
      };
    case '/users/me/benefits':
      return <String, dynamic>{
        'premiumActive': true,
        'premiumExpiry':
            DateTime.now().add(const Duration(days: 20)).toIso8601String(),
      };
    case '/pets/me':
      return <String, dynamic>{
        'pets': <Map<String, dynamic>>[
          <String, dynamic>{
            '_id': 'p1',
            'petName': 'Rex',
            'breed': 'Golden',
            'category': 'dog',
          },
        ],
      };
    case '/friends':
      return <String, dynamic>{'friends': <dynamic>[]};
  }
  return const <String, dynamic>{};
}

/// Le client ajoute le préfixe `/api/v1` : on compare sur la fin du chemin.
String? _key(String fullPath) {
  for (final p in _gated) {
    if (fullPath.endsWith(p)) return p;
  }
  return null;
}

http.Client _gatedHttp() => MockClient((http.Request req) async {
      final path = _key(req.url.path);
      final gate = path == null ? null : _gates[path];
      if (gate != null) await gate.future;
      return http.Response(
          jsonEncode(path == null ? const <String, dynamic>{} : _payload(path)), 200,
          headers: <String, String>{'content-type': 'application/json'});
    });

/// Remplace l'ApiClient du harnais par la version « retenue » et rebranche
/// les dépôts utilisés par l'onglet Profil.
void _installGatedApi() {
  final storage = Get.find<GetStorage>();
  final api = ApiClient(httpClient: _gatedHttp(), storage: storage);
  Get.delete<ApiClient>(force: true);
  Get.put<ApiClient>(api, permanent: true);
  Get.delete<UserRepository>(force: true);
  Get.put<UserRepository>(UserRepository(api), permanent: true);
  Get.delete<PetRepository>(force: true);
  Get.put<PetRepository>(PetRepository(api), permanent: true);
  Get.delete<OwnerRepository>(force: true);
  Get.put<OwnerRepository>(OwnerRepository(api), permanent: true);
}

class _Frame {
  _Frame(this.heroHeight, this.cardY, this.cardVisible, this.addPetShown,
      this.benefitsText);
  final double heroHeight;
  final double? cardY;
  final bool cardVisible;
  final bool addPetShown;
  final bool benefitsText;
  @override
  String toString() =>
      'hero=$heroHeight cardY=$cardY visible=$cardVisible addPet=$addPetShown premium=$benefitsText';
}

/// Opacité effective d'un widget = produit des Opacity/FadeTransition parents.
double _effectiveOpacity(WidgetTester tester, Finder f) {
  double o = 1;
  final element = tester.element(f);
  element.visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    if (w is Opacity) o *= w.opacity;
    if (w is AnimatedOpacity) o *= w.opacity;
    if (w is FadeTransition) o *= w.opacity.value;
    return true;
  });
  return o;
}

_Frame _snap(WidgetTester tester) {
  final hero = tester.getSize(find.byType(ProfileHero)).height;
  final card = find.byType(MyProfilesCard);
  double? y;
  bool visible = false;
  if (card.evaluate().isNotEmpty) {
    y = tester.getTopLeft(card).dy;
    visible = _effectiveOpacity(tester, card) > 0.01;
  }
  // Dans l'EN-TÊTE seulement : la page contient aussi une entrée de menu
  // « Ajouter un animal », légitime.
  bool shown(String text) {
    final f = find.descendant(
        of: find.byType(ProfileHero), matching: find.text(text));
    if (f.evaluate().isEmpty) return false;
    return _effectiveOpacity(tester, f.first) > 0.01;
  }

  return _Frame(
    hero,
    y,
    visible,
    shown('hero_add_pet'.tr),
    find
        .descendant(
            of: find.byType(ActiveBenefitsRow),
            matching: find.textContaining('hero_benefit_premium'.tr))
        .evaluate()
        .isNotEmpty,
  );
}

Future<List<_Frame>> _runTimeline(WidgetTester tester) async {
  final frames = <_Frame>[];
  await tester.pumpWidget(lotdApp(const ProfileScreen()));
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
  await tester.pump();
  frames.add(_snap(tester));
  // Ordre de libération le plus défavorable : l'en-tête d'abord, le profil
  // (qui fait apparaître la carte de complétion) en dernier.
  for (final path in <String>['/users/me/benefits', '/pets/me', '/friends', '/users/me/profile']) {
    _gates[path]!.complete();
    // Le client HTTP passe par de vraies attentes (hors horloge simulée).
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      frames.add(_snap(tester));
    }
  }
  await lotdSettle(tester, frames: 6);
  frames.add(_snap(tester));
  return frames;
}

void main() {
  setUp(() async {
    await lotdSetUp(role: 'owner');
    _installGatedApi();
    _gates
      ..clear()
      ..addEntries(_gated.map((p) => MapEntry(p, Completer<void>())));
    ActiveBenefitsRow.debugResetCache();
  });

  tearDown(() {
    for (final g in _gates.values) {
      if (!g.isCompleted) g.complete();
    }
  });

  testWidgets('1re connexion (aucun cache) : en-tête de hauteur fixe, '
      'aucun saut visible, aucun faux contenu', (tester) async {
    lotdPhone(tester);
    final frames = await _runTimeline(tester);
    // ignore: avoid_print
    for (final f in frames) {
      debugPrint('[592] $f');
    }
    final heroHeights = frames.map((f) => f.heroHeight).toSet();
    expect(heroHeights.length, 1,
        reason: 'la hauteur de l\'en-tête a changé : $heroHeights');

    // Sauts du contenu VISIBLE : même bloc, visible avant ET après, à une
    // autre hauteur.
    int jumps = 0;
    for (int i = 1; i < frames.length; i++) {
      final a = frames[i - 1], b = frames[i];
      if (a.cardVisible && b.cardVisible && a.cardY != null && b.cardY != null &&
          (a.cardY! - b.cardY!).abs() > 0.5) {
        jumps++;
      }
    }
    expect(jumps, 0, reason: 'le contenu visible a sauté $jumps fois');

    // Faux contenu : « Ajouter un animal » ne doit jamais s'afficher alors que
    // la personne a un animal.
    expect(frames.any((f) => f.addPetShown), isFalse,
        reason: '« Ajouter un animal » affiché avant que les animaux arrivent');
    expect(frames.last.benefitsText, isTrue);
    expect(frames.last.cardVisible, isTrue);
    // L'animal arrivé est bien affiché dans l'en-tête.
    expect(
        find.descendant(
            of: find.byType(ProfileHero), matching: find.textContaining('Rex')),
        findsOneWidget);
  });

  testWidgets('retour sur l\'app (profil en cache) : contenu visible '
      'immédiatement, sans repasser par l\'attente', (tester) async {
    lotdPhone(tester);
    // Le passage précédent a laissé le profil en cache pour CE compte.
    ProfileDisplayCache.write(
      GetStorage(),
      role: 'owner',
      userId: 'u-test',
      data: (_payload('/users/me/profile')['profile'] as Map<String, dynamic>),
    );
    await tester.pumpWidget(lotdApp(const ProfileScreen()));
    await tester.pump();
    final first = _snap(tester);
    expect(first.cardVisible, isTrue,
        reason: 'avec un cache, le contenu doit être là dès la 1re image');
    expect(Get.find<ProfileController>().profile.value, isNotNull);
    final y0 = first.cardY;
    for (final g in _gates.values) {
      g.complete();
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await lotdSettle(tester, frames: 8);
    final last = _snap(tester);
    expect(last.cardY, y0, reason: 'le contenu a bougé après la réponse serveur');
    expect(last.heroHeight, first.heroHeight);
  });

  testWidgets('gardien : nom connu dès la 1re image, en-tête de hauteur '
      'fixe', (tester) async {
    lotdPhone(tester);
    // Le harnais touche au disque (GetStorage) : hors horloge simulée.
    await tester.runAsync(() => lotdSetUp(role: 'sitter'));
    _installGatedApi();
    ActiveBenefitsRow.debugResetCache();
    await tester.pumpWidget(lotdApp(const SitterProfileScreen()));
    await tester.pump();
    // Avant : le libellé du rôle s'affichait à la place du nom jusqu'à la
    // réponse du serveur.
    expect(
        find.descendant(
            of: find.byType(ProfileHero), matching: find.text('Camille Durand')),
        findsOneWidget);
    final h0 = tester.getSize(find.byType(ProfileHero)).height;
    for (final g in _gates.values) {
      g.complete();
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await lotdSettle(tester, frames: 8);
    expect(tester.getSize(find.byType(ProfileHero)).height, h0);
  });

  test('le cache d\'un AUTRE compte n\'est jamais affiché', () async {
    await lotdSetUp(role: 'owner');
    final s = GetStorage();
    ProfileDisplayCache.write(s,
        role: 'owner', userId: 'someone-else', data: <String, dynamic>{'name': 'X'});
    expect(ProfileDisplayCache.read(s, role: 'owner', userId: 'u-test'), isNull);
    expect(ProfileDisplayCache.read(s, role: 'sitter', userId: 'someone-else'),
        isNull);
    expect(ProfileDisplayCache.read(s, role: 'owner', userId: 'someone-else'),
        isNotNull);
  });
}
