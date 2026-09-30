// v605 (30/09) — Daniel : « certains profils qui ont les prix mais pas de
// photo de profil : leur bulle de prix ne sort pas ». Ce test rejoue, avec le
// VRAI peintre des épingles, les deux chemins d'un membre SANS photo :
//   · un seul rôle → rond de membre (`paintMemberDot`, `_memberIcon`) ;
//   · plusieurs rôles → rond photo sans image (`paintPhotoDot(avatar: null)`).
// Il vérifie que la bulle simple (gardien bleu, promeneur vert) et la bulle
// DUO (bleu + vert) sont dessinées ET entières dans le bitmap (rien de coupé
// au bord gauche / droit). Avant la v605, le rond de membre gardait une
// largeur fixe de 90 dp : la bulle duo (≈ 110 dp) sortait rognée.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/pawmap_person.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

const double ms = PawMapLegend.memberSize;

class _Px {
  final Uint8List px;
  final int w, h;
  _Px(this.px, this.w, this.h);
  int alpha(int x, int y) => px[(y * w + x) * 4 + 3];

  /// Pixels opaques « bleu gardien » / « vert promeneur » dans les [rows]
  /// premières lignes (la zone de la bulle, au-dessus du rond).
  (int blue, int green) bubbleColors(int rows) {
    var b = 0, g = 0;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final r = px[i], gg = px[i + 1], bb = px[i + 2], a = px[i + 3];
        if (a < 230) continue;
        if (bb > 150 && bb > r + 60 && bb > gg + 20) b++;
        if (gg > 100 && gg > r + 30 && gg > bb + 30) g++;
      }
    }
    return (b, g);
  }

  /// Opacité max sur les colonnes de bord (gauche/droite) de la zone bulle.
  int edgeAlpha(int rows) {
    var m = 0;
    for (var y = 0; y < rows; y++) {
      for (final x in [0, 1, w - 2, w - 1]) {
        final a = alpha(x, y);
        if (a > m) m = a;
      }
    }
    return m;
  }
}

Future<_Px> _render(WidgetTester t, double w, double h, void Function(Canvas) paint) async {
  final img = await t.runAsync(() async {
    await ensurePawPinFonts();
    return renderPinImage(w, h, paint, scale: 1);
  });
  final bd = await t.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.rawRgba));
  return _Px(bd!.buffer.asUint8List(), img!.width, img.height);
}

/// Comme `_memberIcon` (paw_map_screen.dart) : rond de membre sans photo.
Future<_Px> _memberDot(WidgetTester t, String role, String bubble) {
  final w = PawMapPinPainter.memberBitmapWidth(ms, priceBubble: bubble);
  final dx = (w - PawMapPinPainter.memberBitmapSize(ms)) / 2;
  final h = PawMapPinPainter.memberBitmapSize(ms, withLabel: true, withBubble: true);
  return _render(t, w, h, (c) {
    c.save();
    c.translate(dx, 0);
    PawMapPinPainter.paintMemberDot(c,
        role: role, size: ms, priceLabel: 'emilie', priceBubble: bubble);
    c.restore();
  });
}

/// Comme `_photoIcon` (multi-rôles sans photo : avatar null → glyphe).
Future<_Px> _photoDotNoAvatar(WidgetTester t, String bubble, String priceRole) {
  const m = PawMapPinPainter.photoMarginGlow;
  final baseW = PawMapPinPainter.photoBitmapSize(ms, margin: m);
  final bubbleW = PawMapPinPainter.priceBubbleWidth(bubble) + 8;
  final labelW = PawMapPinPainter.photoLabelWidth('frederic');
  final w = [baseW, bubbleW, labelW].reduce((a, b) => a > b ? a : b);
  final h = PawMapPinPainter.photoBitmapSize(ms, withLabel: true, margin: m) +
      PawMapPinPainter.priceBubbleZone;
  return _render(t, w, h, (c) {
    c.save();
    c.translate((w - baseW) / 2, 0);
    PawMapPinPainter.paintPhotoDot(c,
        avatar: null,
        ringColor: PawMapLegend.walker,
        ringColors: const [PawMapLegend.owner, PawMapLegend.walker],
        size: ms,
        label: 'frederic',
        priceBubble: bubble,
        priceRole: priceRole,
        margin: m);
    c.restore();
  });
}

void main() {
  // Zone de la bulle : au-dessus du haut du rond (bulle + marge du rond).
  // Bord : ≤ 16/255 (6 %) = queue floue de l'ombre, invisible ; une bulle
  // rognée donne 255 au bord.
  const zone = 32 + 22; // priceBubbleZone + memberMargin
  final photoZone = (32 + PawMapPinPainter.photoMarginGlow).round();

  group('données : une personne sans photo a bien un texte de bulle', () {
    String fmt(String c, double p) => '${p.round()} ${c == 'USD' ? r'$' : '€'}';
    for (final avatar in <Object?>[null, '']) {
      test('avatar ${avatar == null ? 'null' : "''"} · gardien seul', () {
        final b = pawMapPersonPriceBubble(
          pawMapExpandRoles({'id': 'a', '_role': 'sitter', 'avatar': avatar, 'priceFrom': 15, 'currency': 'EUR'}),
          shows: (_) => true, shownRoles: const {'sitter', 'walker', 'owner'}, format: fmt);
        expect(b, isNotNull);
        expect(b!.text, '15 €');
        expect(b.role, 'sitter');
      });
      test('avatar ${avatar == null ? 'null' : "''"} · gardien + promeneur = duo', () {
        final b = pawMapPersonPriceBubble(
          pawMapExpandRoles({
            'id': 'a', '_role': 'sitter', 'avatar': avatar,
            'roles': [
              {'id': 'a', 'role': 'sitter', 'priceFrom': 20, 'currency': 'EUR'},
              {'id': 'b', 'role': 'walker', 'priceFrom': 12, 'currency': 'EUR'},
            ],
          }),
          shows: (_) => true, shownRoles: const {'sitter', 'walker', 'owner'}, format: fmt);
        expect(b, isNotNull);
        expect(b!.text, '20 €|12 €');
        expect(b.role, 'duo');
      });
    }
    test('tarif à la semaine seulement : priceFrom 0 côté serveur → aucune bulle', () {
      // Cas réel prod (GIRMA, 30/09) : dailyRate 0, weeklyRate 100 — la route
      // /friends/members/world renvoie priceFrom 0. L'app ne peut pas inventer
      // un prix : c'est au serveur de le fournir (voir rapport PAM).
      final b = pawMapPersonPriceBubble(
        pawMapExpandRoles({'id': 'g', '_role': 'sitter', 'avatar': '', 'priceFrom': 0}),
        shows: (_) => true, shownRoles: const {'sitter'}, format: fmt);
      expect(b, isNull);
    });
  });

  group('peintre : rond de membre SANS photo (un rôle)', () {
    testWidgets('bulle gardien « 15 € » dessinée (bleu), entière', (t) async {
      final p = await _memberDot(t, 'sitter', '15 €');
      final (b, g) = p.bubbleColors(zone);
      expect(b, greaterThan(150), reason: 'bulle bleue attendue au-dessus du rond');
      expect(g, lessThan(10));
      expect(p.edgeAlpha(zone), lessThanOrEqualTo(16), reason: 'bulle coupée au bord');
    });
    testWidgets(r'bulle promeneur « $10 » dessinée (vert), entière', (t) async {
      final p = await _memberDot(t, 'walker', r'$10');
      final (b, g) = p.bubbleColors(zone);
      expect(g, greaterThan(150), reason: 'bulle verte attendue au-dessus du rond');
      expect(p.edgeAlpha(zone), lessThanOrEqualTo(16), reason: 'bulle coupée au bord');
    });
    testWidgets('bulle DUO « 20 €|12 € » : bleu ET vert, entière (plus rognée)', (t) async {
      final p = await _memberDot(t, 'sitter', '20 €|12 €');
      final (b, g) = p.bubbleColors(zone);
      expect(b, greaterThan(150));
      expect(g, greaterThan(150));
      expect(p.edgeAlpha(zone), lessThanOrEqualTo(16),
          reason: 'bulle duo rognée : le bitmap du rond de membre ne suit pas sa largeur');
    });
    testWidgets('prix long « 1 250 € » : entier', (t) async {
      final p = await _memberDot(t, 'sitter', '1 250 €');
      expect(p.bubbleColors(zone).$1, greaterThan(150));
      expect(p.edgeAlpha(zone), lessThanOrEqualTo(16));
    });
  });

  group('peintre : rond multi-rôles SANS photo (avatar null)', () {
    testWidgets('bulle promeneur « 10 € » dessinée', (t) async {
      final p = await _photoDotNoAvatar(t, '10 €', 'walker');
      expect(p.bubbleColors(photoZone).$2, greaterThan(150));
      expect(p.edgeAlpha(photoZone), lessThanOrEqualTo(16));
    });
    testWidgets('bulle DUO dessinée, entière', (t) async {
      final p = await _photoDotNoAvatar(t, '20 €|12 €', 'duo');
      final (b, g) = p.bubbleColors(photoZone);
      expect(b, greaterThan(150));
      expect(g, greaterThan(150));
      expect(p.edgeAlpha(photoZone), lessThanOrEqualTo(16));
    });
  });
}
