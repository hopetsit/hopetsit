// v584 (révision PawMap du 25/09, point 2) — GARDE-FOU « une seule carte ».
// Daniel : « on avait dit UNE carte, il y a toujours les deux ». Ce test lit
// la SOURCE de l'écran et échoue si un second `GoogleMap(`, un second rail,
// le mode « Agrandir / Réduire » ou le bandeau violet de suivi réapparaissent.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/views/map/paw_map_screen.dart').readAsStringSync();

  int count(String needle) => needle.allMatches(src).length;

  test('exactement UNE GoogleMap dans l\'écran PawMap', () {
    expect(count('return GoogleMap('), 1, reason: 'une seule carte native');
    expect(count('_buildGoogleMap(),'), 1, reason: 'posée une seule fois dans la Stack');
  });

  test('exactement UN rail gauche et UNE capsule droite', () {
    expect(count('PawMapRail('), 1, reason: 'un seul rail');
    expect(count('_buildMapControlsStack(),'), 1, reason: 'une seule capsule + / − / position');
  });

  test('plus aucun mode « Agrandir / Réduire », dock ni bouton Retour de grande carte', () {
    expect(src.contains('_buildExpandPill'), isFalse);
    expect(src.contains('_buildExpandedBackButton'), isFalse);
    expect(src.contains('_buildMapDock('), isFalse);
    expect(src.contains('pawMapExpanded.value = true'), isFalse);
    expect(src.contains('_mapExpanded'), isFalse);
    expect(src.contains("'pawmap_expand_short'"), isFalse);
  });

  test('plus de bandeau violet « Suivi en direct » en haut : une pilule + une feuille', () {
    expect(src.contains('_buildFollowingBanner'), isFalse);
    expect(src.contains('_buildFollowPill()'), isTrue);
    expect(src.contains('PawMapFollowSheet('), isTrue);
  });

  test('plus aucune pastille d\'état posée sur les commandes du haut (point 12)', () {
    expect(src.contains('PawMapFriendsOnlyPill('), isFalse);
    expect(src.contains('_buildLiveBroadcastBanner'), isFalse);
    expect(src.contains('_buildSheetStatusRow('), isTrue);
  });

  test('la couche « proches » n\'est plus réservée aux abonnés (point 1)', () {
    expect(src.contains('final bool nearbyVisible ='), isFalse);
  });

  test('un rond « en direct » exige un partage actif (point 4)', () {
    expect(src.contains('if (pos.liveState == FriendLiveState.seen) continue;'), isTrue);
  });
}
