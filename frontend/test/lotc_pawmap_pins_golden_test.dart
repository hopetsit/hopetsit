// v584 — lot C du chantier du 24/09 : IMAGES DE RÉFÉRENCE des épingles de la
// légende (idée 11 de PAM, validée par Daniel) : un build qui casse la légende
// par erreur (forme, couleur, couronne, lueur PawBoost, anneau rose, œil
// barré…) échoue ici AVANT publication.
//
// Chaque épingle est dessinée par le MÊME peintre que la carte
// (`PawMapPinPainter`, via `renderPinPng`) puis comparée pixel à pixel à
// `test/goldens/pawmap/<clé>.png`. Pour régénérer après un changement VOULU de
// la légende : `flutter test test/lotc_pawmap_pins_golden_test.dart
// --update-goldens`, puis relire les images une par une.
//
// En plus des images : les couleurs FIXES de Daniel (23/09) sont verrouillées
// en clair, et quelques mesures (tailles de la légende, ancres).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

/// Les icônes Material et les chiffres des épingles sont des GLYPHES peints
/// sur le canvas : sans police, le harnais de test dessine des rectangles.
/// On charge la police d'icônes du SDK Flutter et Roboto (mêmes fichiers sur
/// toutes les machines qui ont ce SDK) — les images de référence montrent
/// donc les vraies icônes.
Future<void> _loadFonts() async {
  // Le binaire de test vit sous …/flutter/bin/cache/artifacts/engine/… : on
  // remonte jusqu'au dossier qui contient artifacts/material_fonts.
  Directory? dir;
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    final d = Directory('$root/bin/cache/artifacts/material_fonts');
    if (d.existsSync()) dir = d;
  }
  var cur = File(Platform.resolvedExecutable).parent;
  while (dir == null && cur.path != cur.parent.path) {
    final d = Directory('${cur.path}/artifacts/material_fonts');
    if (d.existsSync()) dir = d;
    cur = cur.parent;
  }
  if (dir == null) {
    // ignore: avoid_print
    print('polices Flutter introuvables — glyphes de test (rectangles)');
    return;
  }
  final fonts = <String, String>{
    'MaterialIcons': '${dir.path}/MaterialIcons-Regular.otf',
    'Roboto': '${dir.path}/Roboto-Bold.ttf',
  };
  for (final e in fonts.entries) {
    final f = File(e.value);
    if (!f.existsSync()) {
      // ignore: avoid_print
      print('police absente : ${e.value} — glyphes de test (rectangles)');
      continue;
    }
    final bytes = await f.readAsBytes();
    final loader = FontLoader(e.key)
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

/// Les épingles à figer (clé → largeur, hauteur, peintre).
final Map<String, (double, double, void Function(Canvas))> _pins = {
  'me_owner': (
    PawMapPinPainter.photoBitmapSize(PawMapLegend.meSize),
    PawMapPinPainter.photoBitmapSize(PawMapLegend.meSize, withLabel: true),
    (c) => PawMapPinPainter.paintPhotoDot(c,
        avatar: null,
        ringColor: PawMapLegend.owner,
        size: PawMapLegend.meSize,
        label: 'Moi',
        crown: true,
        crownSize: PawMapLegend.crownMe),
  ),
  'me_friends_only': (
    PawMapPinPainter.photoBitmapSize(PawMapLegend.meSize),
    PawMapPinPainter.photoBitmapSize(PawMapLegend.meSize, withLabel: true),
    (c) => PawMapPinPainter.paintPhotoDot(c,
        avatar: null,
        ringColor: PawMapLegend.sitter,
        size: PawMapLegend.meSize,
        label: 'Moi',
        dashedRing: true,
        eyeOff: true,
        fallbackTint: PawMapLegend.sitter),
  ),
  'friend_online': (
    PawMapPinPainter.photoBitmapSize(PawMapLegend.friendSize),
    PawMapPinPainter.photoBitmapSize(PawMapLegend.friendSize),
    (c) => PawMapPinPainter.paintPhotoDot(c,
        avatar: null,
        ringColor: PawMapLegend.friend,
        size: PawMapLegend.friendSize,
        online: true,
        crown: true,
        fallbackTint: PawMapLegend.friend),
  ),
  'member_owner': (
    PawMapPinPainter.memberBitmapSize(PawMapLegend.memberSize),
    PawMapPinPainter.memberBitmapSize(PawMapLegend.memberSize),
    (c) => PawMapPinPainter.paintMemberDot(c, role: 'owner'),
  ),
  'member_sitter_crown_verified': (
    PawMapPinPainter.memberBitmapSize(PawMapLegend.memberSize),
    PawMapPinPainter.memberBitmapSize(PawMapLegend.memberSize),
    (c) => PawMapPinPainter.paintMemberDot(c,
        role: 'sitter', crown: true, verified: true, online: true),
  ),
  'member_walker_boost': (
    PawMapPinPainter.memberBitmapSize(PawMapLegend.memberSize),
    PawMapPinPainter.memberBitmapSize(PawMapLegend.memberSize),
    (c) => PawMapPinPainter.paintMemberDot(c, role: 'walker', boostPhase: 0.25),
  ),
  'member_sitter_price': (
    PawMapPinPainter.memberBitmapSize(PawMapLegend.memberSize),
    PawMapPinPainter.memberBitmapSize(PawMapLegend.memberSize, withLabel: true),
    (c) => PawMapPinPainter.paintMemberDot(c,
        role: 'sitter', priceLabel: '25 €', selected: true),
  ),
  'member_cluster': (
    PawMapPinPainter.memberClusterWidth(12) + 12,
    PawMapLegend.memberClusterHeight + 12,
    (c) => PawMapPinPainter.paintMemberCluster(c, 12,
        roleCounts: const {'owner': 5, 'sitter': 4, 'walker': 3}),
  ),
  'place_vet': (
    PawMapPinPainter.dropBitmapWidth(PawMapLegend.placeSize),
    PawMapPinPainter.dropHeight(PawMapLegend.placeSize),
    (c) => PawMapPinPainter.paintPlaceDrop(c, category: 'vet'),
  ),
  'place_water': (
    PawMapPinPainter.dropBitmapWidth(PawMapLegend.placeSize),
    PawMapPinPainter.dropHeight(PawMapLegend.placeSize),
    (c) => PawMapPinPainter.paintPlaceDrop(c, category: 'water'),
  ),
  'place_cluster': (
    PawMapPinPainter.squareClusterBitmapSize(),
    PawMapPinPainter.squareClusterBitmapSize(),
    (c) => PawMapPinPainter.paintSquareCluster(c, 8,
        tone: PawMapLegend.placeColor('park')),
  ),
  'pawspot': (
    PawMapPinPainter.dropBitmapWidth(PawMapLegend.spotSize),
    PawMapPinPainter.dropHeight(PawMapLegend.spotSize),
    (c) => PawMapPinPainter.paintPawSpotDrop(c, type: 'swimming'),
  ),
  'pawspot_gold': (
    PawMapPinPainter.dropBitmapWidth(PawMapLegend.spotGoldSize),
    PawMapPinPainter.dropHeight(PawMapLegend.spotGoldSize),
    (c) => PawMapPinPainter.paintPawSpotDrop(c, type: 'path_walk', golden: true),
  ),
  'pawspot_cluster': (
    PawMapPinPainter.squareClusterBitmapSize(),
    PawMapPinPainter.squareClusterBitmapSize(),
    (c) => PawMapPinPainter.paintSquareCluster(c, 4,
        tone: PawMapLegend.gold, black: true),
  ),
  'request_price': (
    PawMapPinPainter.requestBubbleBitmapWidth(priceLabel: '25 €'),
    PawMapPinPainter.requestBubbleBitmapHeight(),
    (c) => PawMapPinPainter.paintRequestBubble(c,
        priceLabel: '25 €', walking: false),
  ),
  'request_walk_no_budget': (
    PawMapPinPainter.requestBubbleBitmapWidth(),
    PawMapPinPainter.requestBubbleBitmapHeight(),
    (c) => PawMapPinPainter.paintRequestBubble(c, walking: true),
  ),
  'request_mine': (
    PawMapPinPainter.requestBubbleBitmapWidth(mineLabel: 'Ma demande'),
    PawMapPinPainter.requestBubbleBitmapHeight(),
    (c) => PawMapPinPainter.paintRequestBubble(c,
        walking: false, mineLabel: 'Ma demande'),
  ),
};

void main() {
  setUpAll(_loadFonts);

  group('couleurs fixes de la légende (Daniel, 23/09/2026)', () {
    test('rôles, PawFollow, PawBoost, or, rose, encre', () {
      expect(PawMapLegend.owner, const Color(0xFFC92A12));
      expect(PawMapLegend.sitter, const Color(0xFF2563EB));
      expect(PawMapLegend.walker, const Color(0xFF16A34A));
      expect(PawMapLegend.pawFollow, const Color(0xFF7C3AED));
      expect(PawMapLegend.boost, const Color(0xFF06B6D4));
      expect(PawMapLegend.gold, const Color(0xFFF4C04A));
      expect(PawMapLegend.friend, const Color(0xFFF06AA0));
      expect(PawMapLegend.ink, const Color(0xFF17141F));
    });

    test('les couleurs de lieu ne réutilisent aucune couleur réservée', () {
      final reserved = {
        PawMapLegend.owner, PawMapLegend.sitter, PawMapLegend.walker,
        PawMapLegend.pawFollow, PawMapLegend.boost, PawMapLegend.gold,
        PawMapLegend.friend,
      };
      for (final c in const [
        'vet', 'park', 'water', 'shop', 'groomer', 'beach', 'trainer', 'hotel',
        'restaurant', 'other',
      ]) {
        final col = PawMapLegend.placeColor(c);
        expect(reserved.contains(col), isFalse, reason: c);
        // Zéro gris : saturation HSL ≥ 25 %.
        expect(HSLColor.fromColor(col).saturation, greaterThanOrEqualTo(0.25),
            reason: '$c est gris');
      }
    });

    test('tailles de la légende', () {
      expect(PawMapLegend.meSize, 56);
      expect(PawMapLegend.friendSize, 44);
      expect(PawMapLegend.memberSize, 36);
      expect(PawMapLegend.placeSize, 30);
      expect(PawMapLegend.spotSize, 32);
      expect(PawMapLegend.spotGoldSize, 40);
      expect(PawMapLegend.crownMember, 20);
      expect(PawMapLegend.crownFriend, 22);
      expect(PawMapLegend.crownMe, 24);
    });

    test('icône par rôle (daltoniens) : patte / maison / marcheur', () {
      expect(PawMapLegend.roleIcon('owner'), Icons.pets_rounded);
      expect(PawMapLegend.roleIcon('sitter'), Icons.home_rounded);
      expect(PawMapLegend.roleIcon('walker'), Icons.directions_walk_rounded);
    });
  });

  group('images de référence des épingles', () {
    for (final entry in _pins.entries) {
      testWidgets(entry.key, (tester) async {
        final (w, h, paint) = entry.value;
        // Le rendu d'image (PictureRecorder.toImage, décodage PNG) est un
        // vrai travail asynchrone du moteur : il ne s'exécute que dans
        // `runAsync` (sinon le test attend pour toujours).
        Uint8List? png;
        ui.Image? img;
        await tester.runAsync(() async {
          png = await renderPinPng(w, h, paint);
          img = await decodeAvatar(png, target: (w * 2).ceil());
        });
        expect(png, isNotNull);
        expect(png!.length, greaterThan(200), reason: 'PNG vide');
        expect(img, isNotNull, reason: 'PNG indécodable');
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFFF0EBE1), // fond de carte crème
              body: Center(
                child: RepaintBoundary(
                  key: ValueKey<String>('pin_${entry.key}'),
                  child: RawImage(image: img, width: w, height: h),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await expectLater(
          find.byKey(ValueKey<String>('pin_${entry.key}')),
          matchesGoldenFile('goldens/pawmap/${entry.key}.png'),
        );
      });
    }
  });
}
