// v592 (26/09) — PLANCHE HD des épingles de la PawMap, à l'identique du site
// (Daniel : « je veux le vrai HD, les halos jolis comme sur le web, les
// bulles, tout doit être HD, et que tout fonctionne par couleur »).
//
// Une seule image, dessinée à 3× par le MÊME peintre que la carte
// (`PawMapPinPainter` via `renderPinImage`), avec des photos de test
// GÉNÉRÉES (aucun réseau) : membres 1 / 2 / 3 rôles, amis (anneau rose,
// « Vu il y a »), moi, Premium, PawBoost (4 phases de la respiration), en
// ligne, suivi en direct, groupes (membres, lieux, PawSpots), PawSpot normal
// et doré, bulles de prix, étiquettes de prénom, demandes.
//
// Régénérer après un changement VOULU :
//   flutter test test/pawmap_pins592_golden_test.dart --update-goldens
// puis REGARDER test/goldens/pawmap592/planche_3x.png.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

/// Police d'icônes Material + Roboto du SDK (comme lotc_pawmap_pins).
Future<void> _loadSdkFonts() async {
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
  if (dir == null) return;
  for (final e in {
    'MaterialIcons': '${dir.path}/MaterialIcons-Regular.otf',
    'Roboto': '${dir.path}/Roboto-Bold.ttf',
  }.entries) {
    final f = File(e.value);
    if (!f.existsSync()) continue;
    final bytes = await f.readAsBytes();
    await (FontLoader(e.key)
          ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer))))
        .load();
  }
}

/// Photo de test PORTRAIT (3:4, pour vérifier le recadrage « cover ») :
/// fond en dégradé, visage, cheveux, épaules. Aucune donnée réelle.
Future<ui.Image> _fakePhoto(Color bgA, Color bgB, Color hair, Color shirt) {
  const w = 300.0, h = 400.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
            const Offset(0, 0), const Offset(w, h), [bgA, bgB]));
  // épaules
  c.drawOval(const Rect.fromLTWH(40, 290, 220, 200), Paint()..color = shirt);
  // cou + visage
  const skin = Color(0xFFE9B48E);
  c.drawRect(const Rect.fromLTWH(128, 230, 44, 70), Paint()..color = skin);
  c.drawOval(const Rect.fromLTWH(95, 120, 110, 140), Paint()..color = skin);
  // cheveux
  c.drawArc(const Rect.fromLTWH(88, 105, 124, 120), math.pi, math.pi, true,
      Paint()..color = hair);
  // yeux + sourire
  final eye = Paint()..color = const Color(0xFF3B2416);
  c.drawCircle(const Offset(130, 190), 6, eye);
  c.drawCircle(const Offset(170, 190), 6, eye);
  c.drawArc(
      const Rect.fromLTWH(128, 205, 44, 26),
      0.2,
      math.pi - 0.4,
      false,
      Paint()
        ..color = const Color(0xFFB23A48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round);
  return rec.endRecording().toImage(w.toInt(), h.toInt());
}

typedef _Pin = (String, double, double, void Function(Canvas));

void main() {
  setUpAll(_loadSdkFonts);

  late ui.Image photoA, photoB, photoC;

  const double ms = PawMapLegend.memberSize;
  const double fs = PawMapLegend.friendSize;
  const double me = PawMapLegend.meSize;
  final pm = PawMapPinPainter.memberBitmapSize(ms);
  final pp = PawMapPinPainter.photoBitmapSize(ms);
  final pf = PawMapPinPainter.photoBitmapSize(fs);

  List<List<_Pin>> rows() => [
        // A — membres sans photo
        [
          ('Propriétaire', pm, pm, (c) => PawMapPinPainter.paintMemberDot(c, role: 'owner')),
          ('Gardien', pm, pm, (c) => PawMapPinPainter.paintMemberDot(c, role: 'sitter')),
          ('Promeneur', pm, pm, (c) => PawMapPinPainter.paintMemberDot(c, role: 'walker')),
          ('Premium · vérifié · en ligne', pm, pm,
              (c) => PawMapPinPainter.paintMemberDot(c,
                  role: 'sitter', crown: true, verified: true, online: true)),
          ('PawBoost', pm, pm,
              (c) => PawMapPinPainter.paintMemberDot(c, role: 'walker', boostPhase: 0.25)),
          (
            'Prénom + bulle',
            pm,
            PawMapPinPainter.memberBitmapSize(ms, withLabel: true, withBubble: true),
            (c) => PawMapPinPainter.paintMemberDot(c,
                role: 'sitter', priceLabel: 'Melina', priceBubble: '25 €', online: true)
          ),
          (
            'Demande propr. (bulle)',
            pm,
            PawMapPinPainter.memberBitmapSize(ms, withLabel: true, withBubble: true),
            (c) => PawMapPinPainter.paintMemberDot(c,
                role: 'owner', priceLabel: 'Hugo', priceBubble: '30 €')
          ),
        ],
        // B — membres avec photo
        [
          ('Photo 1 rôle · en ligne', pp, pp,
              (c) => PawMapPinPainter.paintPhotoDot(c,
                  avatar: photoA, ringColor: PawMapLegend.sitter, size: ms,
                  online: true, fallbackTint: PawMapLegend.sitter)),
          ('2 rôles', pp, pp,
              (c) => PawMapPinPainter.paintPhotoDot(c,
                  avatar: photoB, ringColor: PawMapLegend.sitter, size: ms,
                  ringColors: const [PawMapLegend.sitter, PawMapLegend.walker],
                  online: true, fallbackTint: PawMapLegend.sitter)),
          ('3 rôles', pp, pp,
              (c) => PawMapPinPainter.paintPhotoDot(c,
                  avatar: photoC, ringColor: PawMapLegend.owner, size: ms,
                  ringColors: const [PawMapLegend.owner, PawMapLegend.sitter, PawMapLegend.walker],
                  fallbackTint: PawMapLegend.owner)),
          ('Premium', pp, pp,
              (c) => PawMapPinPainter.paintPhotoDot(c,
                  avatar: photoA, ringColor: PawMapLegend.walker, size: ms,
                  crown: true, crownSize: PawMapLegend.crownMember,
                  fallbackTint: PawMapLegend.walker)),
          ('PawBoost', pp, pp,
              (c) => PawMapPinPainter.paintPhotoDot(c,
                  avatar: photoB, ringColor: PawMapLegend.sitter, size: ms,
                  boostPhase: 0.25, fallbackTint: PawMapLegend.sitter)),
          (
            'Prénom + bulle prix',
            pp,
            PawMapPinPainter.photoBitmapSize(ms, withLabel: true) + PawMapPinPainter.priceBubbleZone,
            (c) => PawMapPinPainter.paintPhotoDot(c,
                avatar: photoC, ringColor: PawMapLegend.walker, size: ms,
                label: 'Melina', priceBubble: '18 €', priceRole: 'walker',
                online: true, fallbackTint: PawMapLegend.walker)
          ),
          ('Sans photo', pp, pp,
              (c) => PawMapPinPainter.paintPhotoDot(c,
                  avatar: null, ringColor: PawMapLegend.walker, size: ms,
                  fallbackIcon: Icons.directions_walk_rounded,
                  fallbackTint: PawMapLegend.walker)),
        ],
        // C — amis et moi
        [
          (
            'Ami · Vu il y a',
            pf,
            PawMapPinPainter.photoBitmapSize(fs, withLabel: true),
            (c) => PawMapPinPainter.paintPhotoDot(c,
                avatar: photoA, ringColor: PawMapLegend.friend, size: fs,
                crown: true, online: true, label: 'Vu il y a 5 j',
                fallbackTint: PawMapLegend.sitter)
          ),
          ('Ami 2 rôles', pf, pf,
              (c) => PawMapPinPainter.paintPhotoDot(c,
                  avatar: photoB, ringColor: PawMapLegend.friend, size: fs,
                  ringColors: const [PawMapLegend.sitter, PawMapLegend.walker],
                  online: true, fallbackTint: PawMapLegend.sitter)),
          (
            'Ami suivi en direct',
            pf,
            PawMapPinPainter.photoBitmapSize(fs, withLabel: true),
            (c) => PawMapPinPainter.paintPhotoDot(c,
                avatar: photoC, ringColor: PawMapLegend.friend, size: fs,
                online: true, followPhase: 0.25, label: 'Léa',
                fallbackTint: PawMapLegend.walker)
          ),
          (
            'Ami signal perdu',
            pf,
            PawMapPinPainter.photoBitmapSize(fs, withLabel: true),
            (c) => PawMapPinPainter.paintPhotoDot(c,
                avatar: photoA, ringColor: PawMapLegend.friend, size: fs,
                dimmed: true, label: 'Signal perdu',
                fallbackTint: PawMapLegend.owner)
          ),
          (
            'Moi (Premium)',
            PawMapPinPainter.photoBitmapSize(me),
            PawMapPinPainter.photoBitmapSize(me, withLabel: true),
            (c) => PawMapPinPainter.paintPhotoDot(c,
                avatar: photoB, ringColor: PawMapLegend.owner, size: me,
                label: 'Moi', crown: true, crownSize: PawMapLegend.crownMe,
                fallbackTint: PawMapLegend.owner)
          ),
          (
            'Moi · amis seulement',
            PawMapPinPainter.photoBitmapSize(me),
            PawMapPinPainter.photoBitmapSize(me, withLabel: true),
            (c) => PawMapPinPainter.paintPhotoDot(c,
                avatar: null, ringColor: PawMapLegend.sitter, size: me,
                label: 'Moi', dashedRing: true, eyeOff: true,
                fallbackIcon: Icons.home_rounded,
                fallbackTint: PawMapLegend.sitter)
          ),
          (
            'Moi boosté',
            PawMapPinPainter.photoBitmapSize(me),
            PawMapPinPainter.photoBitmapSize(me, withLabel: true),
            (c) => PawMapPinPainter.paintPhotoDot(c,
                avatar: photoC, ringColor: PawMapLegend.walker, size: me,
                label: 'Moi', boostPhase: 0.25,
                fallbackTint: PawMapLegend.walker)
          ),
        ],
        // D — groupes
        [
          for (final (label, n, counts, friend) in const [
            ('Groupe · propr.', 5, {'owner': 3, 'sitter': 1, 'walker': 1}, false),
            ('Groupe · gardiens + ami', 12, {'owner': 2, 'sitter': 7, 'walker': 3}, true),
            ('Groupe · promeneurs', 120, {'owner': 10, 'sitter': 20, 'walker': 90}, false),
          ])
            (
              label,
              PawMapPinPainter.memberClusterWidth(n) + 12,
              PawMapLegend.memberClusterHeight + 12,
              (c) => PawMapPinPainter.paintMemberCluster(c, n,
                  roleCounts: counts, hasFriend: friend)
            ),
          ('Groupe de lieux', PawMapPinPainter.squareClusterBitmapSize(),
              PawMapPinPainter.squareClusterBitmapSize(),
              (c) => PawMapPinPainter.paintSquareCluster(c, 8,
                  tone: PawMapLegend.placeColor('park'))),
          ('Lieux 150', PawMapPinPainter.squareClusterBitmapSize(),
              PawMapPinPainter.squareClusterBitmapSize(),
              (c) => PawMapPinPainter.paintSquareCluster(c, 150,
                  tone: PawMapLegend.placeColor('vet'))),
          ('Groupe PawSpots', PawMapPinPainter.squareClusterBitmapSize(),
              PawMapPinPainter.squareClusterBitmapSize(),
              (c) => PawMapPinPainter.paintSquareCluster(c, 4,
                  tone: PawMapLegend.gold, black: true)),
          ('PawSpots 120', PawMapPinPainter.squareClusterBitmapSize(),
              PawMapPinPainter.squareClusterBitmapSize(),
              (c) => PawMapPinPainter.paintSquareCluster(c, 120,
                  tone: PawMapLegend.gold, black: true)),
        ],
        // E — lieux, PawSpots, demandes
        [
          ('PawSpot', PawMapPinPainter.dropBitmapWidth(PawMapLegend.spotSize),
              PawMapPinPainter.dropHeight(PawMapLegend.spotSize),
              (c) => PawMapPinPainter.paintPawSpotDrop(c, type: 'swimming')),
          ('PawSpot doré', PawMapPinPainter.dropBitmapWidth(PawMapLegend.spotGoldSize),
              PawMapPinPainter.dropHeight(PawMapLegend.spotGoldSize),
              (c) => PawMapPinPainter.paintPawSpotDrop(c, type: 'path_walk', golden: true)),
          for (final cat in const ['vet', 'park', 'shop'])
            (
              'Lieu $cat',
              PawMapPinPainter.dropBitmapWidth(PawMapLegend.placeSize),
              PawMapPinPainter.dropHeight(PawMapLegend.placeSize),
              (c) => PawMapPinPainter.paintPlaceDrop(c, category: cat)
            ),
          ('Demande 25 €', PawMapPinPainter.requestBubbleBitmapWidth(priceLabel: '25 €'),
              PawMapPinPainter.requestBubbleBitmapHeight(),
              (c) => PawMapPinPainter.paintRequestBubble(c, priceLabel: '25 €', walking: false)),
          ('Ma demande', PawMapPinPainter.requestBubbleBitmapWidth(mineLabel: 'Ma demande'),
              PawMapPinPainter.requestBubbleBitmapHeight(),
              (c) => PawMapPinPainter.paintRequestBubble(c, walking: true, mineLabel: 'Ma demande')),
        ],
      ];

  // F — fond sombre : la respiration PawBoost (4 phases) + suivi violet.
  List<_Pin> darkRow() => [
        for (final ph in const [0.0, 0.25, 0.5, 0.75])
          ('Boost phase $ph', pp, pp,
              (c) => PawMapPinPainter.paintPhotoDot(c,
                  avatar: photoA, ringColor: PawMapLegend.sitter, size: ms,
                  boostPhase: ph, fallbackTint: PawMapLegend.sitter)),
        ('Suivi 0,25', pf, pf,
            (c) => PawMapPinPainter.paintPhotoDot(c,
                avatar: photoB, ringColor: PawMapLegend.friend, size: fs,
                followPhase: 0.25, online: true, fallbackTint: PawMapLegend.walker)),
        ('Famille PawFollow', pf, pf,
            (c) => PawMapPinPainter.paintPhotoDot(c,
                avatar: photoC, ringColor: PawMapLegend.friend, size: fs,
                pawFollowGlow: true, online: true, fallbackTint: PawMapLegend.owner)),
        ('Membre boost (sans photo)', pm, pm,
            (c) => PawMapPinPainter.paintMemberDot(c, role: 'owner', boostPhase: 0.25)),
      ];

  const double cellW = 128, cellH = 150, pad = 14, titleH = 26;
  const cream = Color(0xFFF0EBE1);
  const night = Color(0xFF231C2B);

  void paintBoard(Canvas c, List<List<_Pin>> light, List<_Pin> dark) {
    const cols = 7;
    final w = cols * cellW + 2 * pad;
    final allRows = [...light, dark];
    final h = allRows.length * (cellH + titleH) + 2 * pad;
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = cream);
    final nightTop = pad + light.length * (cellH + titleH);
    c.drawRect(Rect.fromLTWH(0, nightTop, w, h - nightTop), Paint()..color = night);
    for (var ri = 0; ri < allRows.length; ri++) {
      final row = allRows[ri];
      final isDark = ri == allRows.length - 1;
      for (var ci = 0; ci < row.length; ci++) {
        final (label, pw, ph, paint) = row[ci];
        final x0 = pad + ci * cellW;
        final y0 = pad + ri * (cellH + titleH);
        c.save();
        c.translate(x0 + (cellW - pw) / 2, y0 + (cellH - ph) / 2);
        paint(c);
        c.restore();
        final tp = TextPainter(
          text: TextSpan(
              text: label,
              style: TextStyle(
                  fontFamily: kPawPinInter,
                  fontFamilyFallback: const ['Roboto'],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFF6F1EE) : PawMapLegend.ink)),
          textDirection: TextDirection.ltr,
          maxLines: 2,
          textAlign: TextAlign.center,
        )..layout(maxWidth: cellW - 8);
        tp.paint(c, Offset(x0 + (cellW - tp.width) / 2, y0 + cellH + 2));
      }
    }
  }

  testWidgets('planche HD 3× (fidèle au site)', (tester) async {
    ui.Image? board;
    await tester.runAsync(() async {
      await ensurePawPinFonts();
      photoA = await _fakePhoto(const Color(0xFF7FB3E8), const Color(0xFF2C5DA8),
          const Color(0xFF4A2A18), const Color(0xFF1F7A37));
      photoB = await _fakePhoto(const Color(0xFFF7C59F), const Color(0xFFD9534F),
          const Color(0xFF1A1210), const Color(0xFF2458C9));
      photoC = await _fakePhoto(const Color(0xFFB8E0C2), const Color(0xFF3E8E5A),
          const Color(0xFFC48A3A), const Color(0xFFD6377F));
      final light = rows();
      final dark = darkRow();
      const cols = 7;
      final w = cols * cellW + 2 * pad;
      final h = (light.length + 1) * (cellH + titleH) + 2 * pad;
      board = await renderPinImage(w, h, (c) => paintBoard(c, light, dark),
          scale: 3);
    });
    expect(board, isNotNull);
    expect(board!.width, (7 * cellW + 2 * pad) * 3);
    await expectLater(board!, matchesGoldenFile('goldens/pawmap592/planche_3x.png'));
  });

  test('ancres : centre du rond, pointe des gouttes', () {
    expect(PawMapPinPainter.memberAnchorY(ms), closeTo(0.5, 1e-9));
    expect(PawMapPinPainter.photoAnchorY(fs), closeTo(0.5, 1e-9));
    final hb = PawMapPinPainter.memberBitmapSize(ms, withLabel: true, withBubble: true);
    expect(PawMapPinPainter.memberAnchorY(ms, withLabel: true, withBubble: true),
        closeTo((PawMapPinPainter.priceBubbleZone + PawMapPinPainter.memberMargin + ms / 2) / hb, 1e-9));
  });

  test('orange FONCÉ partout (Daniel 26/09) : aucun orange clair', () {
    final (a, b) = PawMapLegend.ringGradient(PawMapLegend.owner);
    expect(a, const Color(0xFFC92A12));
    expect(b, const Color(0xFF9E1F0B));
    final (pa, pb) = PawMapPinPainter.priceBubbleColors('owner');
    expect(pa, const Color(0xFFC92A12));
    expect(pb, const Color(0xFF9E1F0B));
    expect(PawMapLegend.roleDark('owner'), const Color(0xFF9E1F0B));
  });

  testWidgets('les halos s’éteignent DANS le bitmap (jamais coupés net)',
      (tester) async {
    await tester.runAsync(() async {
      await ensurePawPinFonts();
      final cases = <(String, double, double, void Function(Canvas))>[
        for (final ph in const [0.0, 0.25, 0.5, 0.75])
          ('boost $ph', pp, pp,
              (c) => PawMapPinPainter.paintPhotoDot(c,
                  avatar: null, ringColor: PawMapLegend.sitter, size: ms,
                  boostPhase: ph, fallbackTint: PawMapLegend.sitter)),
        ('suivi', pf, pf,
            (c) => PawMapPinPainter.paintPhotoDot(c,
                avatar: null, ringColor: PawMapLegend.friend, size: fs,
                followPhase: 0.25)),
        ('membre boost', pm, pm,
            (c) => PawMapPinPainter.paintMemberDot(c, role: 'walker', boostPhase: 0.25)),
        ('3 rôles', pp, pp,
            (c) => PawMapPinPainter.paintPhotoDot(c,
                avatar: null, ringColor: PawMapLegend.owner, size: ms,
                ringColors: const [PawMapLegend.owner, PawMapLegend.sitter, PawMapLegend.walker])),
        ('PawSpot doré', PawMapPinPainter.dropBitmapWidth(PawMapLegend.spotGoldSize),
            PawMapPinPainter.dropHeight(PawMapLegend.spotGoldSize),
            (c) => PawMapPinPainter.paintPawSpotDrop(c, type: 'x', golden: true)),
        ('groupe PawSpots', PawMapPinPainter.squareClusterBitmapSize(),
            PawMapPinPainter.squareClusterBitmapSize(),
            (c) => PawMapPinPainter.paintSquareCluster(c, 4, tone: PawMapLegend.gold, black: true)),
      ];
      for (final (name, w, h, paint) in cases) {
        final img = await renderPinImage(w, h, paint, scale: 3);
        final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        int maxEdge = 0;
        for (var x = 0; x < img.width; x++) {
          for (final y in [0, img.height - 1]) {
            maxEdge = math.max(maxEdge, data.getUint8((y * img.width + x) * 4 + 3));
          }
        }
        for (var y = 0; y < img.height; y++) {
          for (final x in [0, img.width - 1]) {
            maxEdge = math.max(maxEdge, data.getUint8((y * img.width + x) * 4 + 3));
          }
        }
        expect(maxEdge, lessThanOrEqualTo(6), reason: '$name : bord coupé (alpha $maxEdge)');
        img.dispose();
      }
    });
  });
}
