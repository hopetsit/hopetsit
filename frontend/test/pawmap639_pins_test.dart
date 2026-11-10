// 639 (PAM) — pastilles v2 de la PawMap : géométrie, ancre, halos, point vert
// « disponible aujourd'hui », cache, seuil de regroupement, légende, i18n et
// ligne « nourriture » de la feuille de demande.
// Tout est rejoué sur les VRAIS peintres et les VRAIES fonctions de la carte.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/v565/demande639_i18n.dart';
import 'package:hopetsit/localization/v565/pawmap639_i18n.dart';
import 'package:hopetsit/views/map/widgets/pawmap_cluster626.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';

const List<String> _langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const List<double> _densities = [2.0, 2.5, 2.625, 3.0];

class _T extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        for (final l in _langs)
          l: {
            ...demande639I18n[l] ?? const <String, String>{},
            ...pawmap639I18n[l]!,
          },
      };
}

Widget _harness(Widget child) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: _T(),
        locale: const Locale('fr'),
        fallbackLocale: const Locale('en'),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

Widget _request({bool? food}) => PawMapRequestSheet(
      ownerName: 'Marc',
      ownerAvatar: '',
      walking: false,
      city: 'Zone test',
      distanceLabel: '1,2 km',
      dateLabel: 'Du 1 oct. au 3 oct.',
      budgetLabel: '30 €',
      body: 'Garde de Rex',
      mine: false,
      approx: true,
      viewerRole: 'sitter',
      proposeState: PawProposeState.idle,
      onPropose: () {},
      onOpenMine: () {},
      onOwnerProfile: () {},
      foodProvided: food,
    );

/// Image de la pastille comme le fait le cache (échelle puis arrondi au
/// pixel supérieur) et centre de la boîte des pixels de la couleur du disque.
Future<({double x, double y, int n, int w, int h})> _discCentroid(
    PawPinSpec639 s, double sc, Color disc) async {
  final sz = pawPinBitmap639(s);
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.scale(sc, sc);
  paintPin639(c, s);
  final w = (sz.width * sc).ceil(), h = (sz.height * sc).ceil();
  final img = await rec.endRecording().toImage(w, h);
  final ByteData data =
      (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
  final int r0 = (disc.r * 255).round(),
      g0 = (disc.g * 255).round(),
      b0 = (disc.b * 255).round();
  // Boîte englobante des pixels du disque (l'icône blanche troue le disque
  // de façon non symétrique : on ne prend donc pas le centre de gravité).
  int x0 = w, x1 = -1, y0 = h, y1 = -1;
  var n = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      if (data.getUint8(i + 3) == 255 &&
          (data.getUint8(i) - r0).abs() <= 2 &&
          (data.getUint8(i + 1) - g0).abs() <= 2 &&
          (data.getUint8(i + 2) - b0).abs() <= 2) {
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
        n++;
      }
    }
  }
  return (x: (x0 + x1 + 1) / 2, y: (y0 + y1 + 1) / 2, n: n, w: w, h: h);
}

void main() {
  group('639 — géométrie et ancre des pastilles v2', () {
    final specs = <String, PawPinSpec639>{
      'seule': PawPinSpec639(roles: const ['owner']),
      'duo': PawPinSpec639(roles: const ['owner', 'sitter']),
      'trio': PawPinSpec639(roles: const ['owner', 'sitter', 'walker']),
      'premium': PawPinSpec639(roles: const ['sitter'], premium: true),
      'dispo': PawPinSpec639(roles: const ['walker'], available: true),
      'boost': PawPinSpec639(roles: const ['walker'], halo: PawHalo639.boost),
      'follow': PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.follow),
      'ami': PawPinSpec639(roles: const ['owner'], halo: PawHalo639.friend),
      'ami étiquette': PawPinSpec639(
          roles: const ['owner'], halo: PawHalo639.friend, caption: 'Vu il y a 5 j'),
      'sélection': PawPinSpec639(roles: const ['sitter'], selected: true, scale: 1.18),
      'trio sélection':
          PawPinSpec639(roles: const ['owner', 'sitter', 'walker'], selected: true, scale: 1.18),
    };

    test('taille en points entiers pairs, centre entier', () {
      specs.forEach((name, s) {
        final l = pawPinLayout639(s);
        expect(l.w, l.w.roundToDouble(), reason: name);
        expect(l.h, l.h.roundToDouble(), reason: name);
        expect(l.w.round().isEven, isTrue, reason: '$name largeur paire');
        expect(l.h.round().isEven, isTrue, reason: '$name hauteur paire');
        expect(l.cx, l.w / 2, reason: '$name centre horizontal');
        expect(l.cy, l.cy.roundToDouble(), reason: name);
      });
    });

    test('ancre = centre du disque, au pixel, aux densités 2 / 2,5 / 2,625 / 3', () {
      for (final sc in _densities) {
        specs.forEach((name, s) {
          final l = pawPinLayout639(s);
          final a = pawPinAnchor639(s, renderScale: sc);
          final pw = (l.w * sc).ceil(), ph = (l.h * sc).ceil();
          expect(a.dx * pw, closeTo(l.cx * sc, 1e-9), reason: '$name @$sc x');
          expect(a.dy * ph, closeTo(l.cy * sc, 1e-9), reason: '$name @$sc y');
          expect(a.dx, inInclusiveRange(0, 1));
          expect(a.dy, inInclusiveRange(0, 1));
        });
      }
    });

    test('le disque est RÉELLEMENT dessiné sur l\'ancre (image mesurée)', () async {
      // Pastille propriétaire seule : le centre de la boîte des pixels du
      // disque plein = le centre du disque (à un pixel d'écran près).
      for (final sc in _densities) {
        for (final s in [
          PawPinSpec639(roles: const ['owner']),
          PawPinSpec639(roles: const ['owner'], halo: PawHalo639.follow),
          PawPinSpec639(roles: const ['owner'], selected: true, scale: 1.18),
        ]) {
          final m = await _discCentroid(s, sc, PawPin639.role('owner'));
          final a = pawPinAnchor639(s, renderScale: sc);
          expect(m.n, greaterThan(200), reason: 'disque trouvé @$sc');
          expect(m.x, closeTo(a.dx * m.w, 1.0), reason: '${s.key} @$sc x');
          // La pointe de sélection (même couleur, sous le disque) allonge la
          // boîte vers le bas : on ne juge la verticale que sans elle.
          if (!s.tip) {
            expect(m.y, closeTo(a.dy * m.h, 1.0), reason: '${s.key} @$sc y');
          }
        }
      }
    });

    test('onde PawFollow : même taille et même ancre à toutes les images', () {
      final base = PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.follow);
      final sz = pawPinBitmap639(base);
      final an = pawPinAnchor639(base, renderScale: 3);
      for (var i = 0; i < kPawWaveSteps639; i++) {
        final s = PawPinSpec639(
            roles: const ['sitter'], halo: PawHalo639.follow, wave: i);
        expect(pawPinBitmap639(s), sz, reason: 'image $i');
        expect(pawPinAnchor639(s, renderScale: 3), an, reason: 'image $i');
      }
    });

    test('pas d\'onde hors halo PawFollow (reduce motion = wave -1)', () {
      expect(PawPinSpec639(roles: const ['sitter'], wave: 3).wave, -1);
      expect(
          PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.boost, wave: 3)
              .wave,
          -1);
      expect(
          PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.follow, wave: -1)
              .wave,
          -1);
      expect(
          PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.follow, wave: 8)
              .wave,
          8 % kPawWaveSteps639);
    });

    test('groupes et bulle : ancre exacte aux 4 densités', () {
      const segs = <PawPriceSeg639>[
        (role: 'sitter', amount: '18 €', unit: '/j'),
        (role: 'walker', amount: '9 €', unit: '/h'),
      ];
      for (final sc in _densities) {
        for (final label in [null, '25 €']) {
          final l = pawClusterLayout639(labelPrefix: 'dès', labelPrice: label);
          final a = pawClusterAnchor639(
              labelPrefix: 'dès', labelPrice: label, renderScale: sc);
          expect(a.dx * (l.w * sc).ceil(), closeTo(l.cx * sc, 1e-9));
          expect(a.dy * (l.h * sc).ceil(), closeTo(l.cy * sc, 1e-9));
        }
        for (final dx in [0.0, -30.0, 22.5]) {
          final sz = pawBubbleBitmap639(segs);
          final a = pawBubbleAnchor639(segs, dx, renderScale: sc);
          expect(a.dx * (sz.width * sc).ceil(),
              closeTo((sz.width / 2 + dx) * sc, 1e-9));
          expect(a.dy * (sz.height * sc).ceil(), closeTo(sz.height * sc, 1e-9));
        }
      }
    });

    test('pastille 32 pt, halo 43 pt (constantes de la maquette)', () {
      expect(kPawPinDiscR639 * 2, 32);
      expect(kPawPinHaloR639 * 2, 43);
      expect(pawPinBox639().width, 34);
      expect(pawPinBox639(halo: true).width, 44);
    });
  });

  group('639 — halos : un seul, priorité inchangée', () {
    test('suivi en direct > PawBoost > PawFollow > Ami', () {
      expect(pawHalo639(boosted: false), PawHalo639.none);
      expect(pawHalo639(boosted: false, isFriend: true), PawHalo639.friend);
      expect(pawHalo639(boosted: false, pawFollow: true, isFriend: true),
          PawHalo639.follow);
      expect(pawHalo639(boosted: true, pawFollow: true, isFriend: true),
          PawHalo639.boost);
      expect(
          pawHalo639(boosted: true, followed: true, pawFollow: true, isFriend: true),
          PawHalo639.follow);
    });

    test('rôles : connus, sans doublon, ordre fixe, jamais vide', () {
      expect(pawPinRoles639(const ['walker', 'owner', 'walker', 'zzz']),
          ['owner', 'walker']);
      expect(pawPinRoles639(const ['walker', 'sitter', 'owner']),
          ['owner', 'sitter', 'walker']);
      expect(pawPinRoles639(const <String>[]), ['owner']);
    });
  });

  group('639 — point vert « disponible aujourd\'hui »', () {
    test('seulement si le serveur envoie availableDot === true', () {
      const roles = ['sitter'];
      expect(pawAvailableDot639({'availableDot': true}, roles), isTrue);
      expect(pawAvailableDot639({'availableDot': false}, roles), isFalse);
      expect(pawAvailableDot639(<String, dynamic>{}, roles), isFalse,
          reason: 'champ absent (ancien serveur)');
      expect(pawAvailableDot639({'availableDot': 'true'}, roles), isFalse);
      expect(pawAvailableDot639({'availableDot': 1}, roles), isFalse);
      expect(pawAvailableDot639({'availableDot': null}, roles), isFalse);
    });

    test('jamais dessiné à partir de availableToday', () {
      expect(pawAvailableDot639({'availableToday': true}, const ['sitter']), isFalse);
      expect(
          pawAvailableDot639(
              {'availableToday': true, 'availableDot': false}, const ['walker']),
          isFalse);
    });

    test('seulement gardiens et promeneurs', () {
      expect(pawAvailableDot639({'availableDot': true}, const ['owner']), isFalse);
      expect(pawAvailableDot639({'availableDot': true}, const ['walker']), isTrue);
      expect(pawAvailableDot639({'availableDot': true}, const ['owner', 'sitter']),
          isTrue);
      // Le peintre refuse aussi le point sur un propriétaire seul.
      expect(PawPinSpec639(roles: const ['owner'], available: true).available,
          isFalse);
      expect(PawPinSpec639(roles: const ['sitter'], available: true).available,
          isTrue);
    });

    test('8 pt, bas-gauche décalé de -1 ; multi-rôle : hors des mini-pastilles', () {
      // Seule : centre (-13 ; 13) = bord bas-gauche du disque de 16, décalé.
      expect(pawAvailableDotAt639(false), const Offset(-13, 13));
      final at = pawAvailableDotAt639(true);
      for (final n in [2, 3]) {
        for (var i = 0; i < n; i++) {
          final mini = Offset((i - (n - 1) / 2) * 15, 17);
          // point 4 + liseré 1,5 ; mini-pastille 8 (ombre comprise).
          expect((at - mini).distance, greaterThanOrEqualTo(4 + 1.5 + 8),
              reason: '$n rôles, mini $i');
        }
      }
      // Et il reste accroché au disque (16 pt).
      expect(at.distance, lessThanOrEqualTo(16 + 4));
    });

    test('le point vert est RÉELLEMENT peint, et absent sinon', () async {
      Future<int> green(PawPinSpec639 s) async {
        final sz = pawPinBitmap639(s);
        final rec = ui.PictureRecorder();
        final c = Canvas(rec)..scale(3, 3);
        paintPin639(c, s);
        final w = (sz.width * 3).ceil(), h = (sz.height * 3).ceil();
        final img = await rec.endRecording().toImage(w, h);
        final d = (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
        var n = 0;
        for (var i = 0; i < w * h * 4; i += 4) {
          if (d.getUint8(i + 3) == 255 &&
              (d.getUint8(i) - 0x1f).abs() <= 2 &&
              (d.getUint8(i + 1) - 0xe0).abs() <= 2 &&
              (d.getUint8(i + 2) - 0x74).abs() <= 2) {
            n++;
          }
        }
        return n;
      }

      // Disque de 8 pt à l'échelle 3 = 24 px de diamètre → ~452 px.
      final on = await green(PawPinSpec639(roles: const ['sitter'], available: true));
      expect(on, inInclusiveRange(380, 470));
      expect(await green(PawPinSpec639(roles: const ['sitter'])), 0);
      expect(
          await green(PawPinSpec639(roles: const ['owner'], available: true)), 0);
      final multi = await green(
          PawPinSpec639(roles: const ['owner', 'sitter', 'walker'], available: true));
      expect(multi, inInclusiveRange(380, 470));
    });
  });

  group('639 — étiquette d\'un ami', () {
    test('multi-rôle : l\'étiquette passe sous les mini-pastilles', () {
      // Mini-pastilles : centre y = 17, rayon 8 → bas à 25 pt.
      expect(pawPinCaptionR639(true), greaterThanOrEqualTo(25));
      expect(pawPinCaptionR639(false), kPawPinHaloR639 + 0.5);
      expect(pawPinCaptionR639(true, above: true), kPawPinHaloR639 + 0.5);
    });
  });

  group('639 — cache : une image par état, jamais deux pour le même', () {
    test('clé identique pour deux descriptions égales', () {
      final a = PawPinSpec639(
          roles: const ['sitter', 'walker'], premium: true, halo: PawHalo639.boost);
      final b = PawPinSpec639(
          roles: const ['sitter', 'walker'], premium: true, halo: PawHalo639.boost);
      expect(a.key, b.key);
      // L'échelle est arrondie au centième : 1,1799 et 1,18 = même image.
      expect(PawPinSpec639(roles: const ['sitter'], scale: 1.1799).key,
          PawPinSpec639(roles: const ['sitter'], scale: 1.18).key);
    });

    test('clé différente dès qu\'un état visible change', () {
      final keys = <String>{
        PawPinSpec639(roles: const ['sitter']).key,
        PawPinSpec639(roles: const ['walker']).key,
        PawPinSpec639(roles: const ['sitter', 'walker']).key,
        PawPinSpec639(roles: const ['sitter'], premium: true).key,
        PawPinSpec639(roles: const ['sitter'], available: true).key,
        PawPinSpec639(roles: const ['sitter'], live: true).key,
        PawPinSpec639(roles: const ['sitter'], selected: true).key,
        PawPinSpec639(roles: const ['sitter'], scale: 1.18).key,
        PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.boost).key,
        PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.follow).key,
        PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.follow, wave: 2).key,
        PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.friend).key,
        PawPinSpec639(
            roles: const ['sitter'], halo: PawHalo639.friend, caption: 'Vu hier').key,
        PawPinSpec639(
                roles: const ['sitter'],
                halo: PawHalo639.friend,
                caption: 'Vu hier',
                captionAbove: true)
            .key,
      };
      expect(keys.length, 14);
    });

    test('pré-rendu : 7 combinaisons de rôles × (sans / avec couronne) = 14', () {
      expect(kPawPrewarmRoles639.length, 7);
      final keys = <String>{
        for (final r in kPawPrewarmRoles639)
          for (final p in const [false, true])
            PawPinSpec639(roles: r, premium: p).key,
      };
      expect(keys.length, 14);
    });

    test('pastille v2 plus légère que l\'ancien rond (surface de l\'image)', () {
      // Ancien rond 2610 : (25 + 22) × 2 = 94 pt de côté.
      final s = pawPinBitmap639(PawPinSpec639(roles: const ['sitter']));
      expect(s.width * s.height, lessThan(94 * 94 / 4));
    });
  });

  group('639 — regroupement', () {
    test('seuil des membres réduit en proportion : 56 × 32 / 50 → 36 pt', () {
      expect(kPawMemberMergePx639, 36);
      expect((56 * 32 / 50).ceil(), 36);
      // Deux pastilles de 32 pt à 36 pt l'une de l'autre ne se touchent pas.
      expect(kPawMemberMergePx639, greaterThan(2 * kPawPinDiscR639));
    });

    test('groupe : 32 pt, pilule « dès X » sous le compteur', () {
      final plain = pawClusterBitmap639();
      final label = pawClusterBitmap639(labelPrefix: 'dès', labelPrice: '25 €');
      expect(label.height, greaterThan(plain.height));
      expect(label.width, greaterThanOrEqualTo(plain.width));
      expect(pawClusterLabelW639(labelPrefix: 'dès', labelPrice: '25 €'),
          greaterThan(pawClusterLabelW639(labelPrefix: '', labelPrice: '25 €')));
    });
  });

  group('639 — légende et traductions', () {
    test('paquet pawmap639I18n : 9 langues, aucune clé manquante ni vide', () {
      expect(pawmap639I18n.keys.toSet(), _langs.toSet());
      final ref = pawmap639I18n['fr']!.keys.toSet();
      expect(ref, {'pawmap639_legend_available'});
      for (final l in _langs) {
        expect(pawmap639I18n[l]!.keys.toSet(), ref, reason: l);
        for (final v in pawmap639I18n[l]!.values) {
          expect(v.trim(), isNotEmpty, reason: l);
        }
      }
      expect(pawmap639I18n['fr']!['pawmap639_legend_available'],
          'Disponible aujourd\'hui');
    });

    testWidgets('la légende porte la ligne « Disponible aujourd\'hui »',
        (tester) async {
      late List<PawLegendEntry> entries;
      await tester.pumpWidget(_harness(Builder(builder: (_) {
        entries = pawLegendEntries();
        return const SizedBox();
      })));
      final keys = [for (final e in entries) e.key];
      expect(keys, contains('available'));
      expect(keys.indexOf('available'), keys.indexOf('verified') + 1);
      final e = entries.firstWhere((e) => e.key == 'available');
      expect(e.label, 'Disponible aujourd\'hui');
      // Le dessin de la ligne ne plante pas.
      final rec = ui.PictureRecorder();
      e.paint(Canvas(rec));
      rec.endRecording();
    });
  });

  group('639 — feuille de demande : ligne « nourriture »', () {
    testWidgets('fournie → « Nourriture fournie »', (tester) async {
      await tester.pumpWidget(_harness(_request(food: true)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('pawmap_request_food639')), findsOneWidget);
      expect(find.text('Nourriture fournie'), findsOneWidget);
    });

    testWidgets('à prévoir → « Nourriture à prévoir »', (tester) async {
      await tester.pumpWidget(_harness(_request(food: false)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('pawmap_request_food639')), findsOneWidget);
      expect(find.text('Nourriture à prévoir'), findsOneWidget);
    });

    testWidgets('non précisé (null) → aucune ligne', (tester) async {
      await tester.pumpWidget(_harness(_request()));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('pawmap_request_food639')), findsNothing);
      expect(find.textContaining('Nourriture'), findsNothing);
    });
  });

  test('639 — interrupteur de retour arrière présent et actif par défaut', () {
    expect(kPawPins639, isTrue);
    expect(math.max(1, kPawWaveSteps639), 6);
    expect(Uint8List(0), isEmpty);
  });
}
