// 643 (17/11/2026) — Daniel : « la flèche de la barre de droite dans la PawMap
// doit s'ouvrir plus facilement ».
//
// Mesuré avant correction (même montage que l'écran : rangée à 12 px des
// bords) : barre ouverte, cible 30 × 48 ; barre RANGÉE, la languette glissait
// hors de la boîte de la rangée → seuls 18 px sur 30 répondaient, le centre de
// la languette visible et sa moitié côté bord donnaient sur la carte.
//
// Ce test rejoue le montage de `paw_map_screen.dart` (rangée bord à bord,
// rail à gauche, capsule à droite, carte dessous, rond « Balade » dessous).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';

import 'lotd_harness.dart';

class _Etat {
  bool rail = false, capsule = false;
  int basculesRail = 0, basculesCapsule = 0, carte = 0, balade = 0;
  final Map<String, int> boutons = <String, int>{};
}

Widget _bouton(_Etat e, String id) => GestureDetector(
      key: ValueKey<String>(id),
      behavior: HitTestBehavior.opaque,
      onTap: () => e.boutons[id] = (e.boutons[id] ?? 0) + 1,
      child: const SizedBox(width: 46, height: 46),
    );

/// Une barre comme dans l'app : boutons de 46 empilés (zoom +, zoom −, ma
/// position… côté capsule), verre de 52 de large.
Widget _barre(_Etat e, String prefixe, int n) => SizedBox(
      width: 52,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < n; i++)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _bouton(e, '$prefixe$i')),
      ]),
    );

Widget _ecran(_Etat e, {int nRail = 6, int nCapsule = 6}) => Scaffold(
      body: StatefulBuilder(
        builder: (ctx, set) => Stack(children: [
          // La carte : tout appui qui « traverse » arrive ici.
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey<String>('carte'),
              behavior: HitTestBehavior.opaque,
              onTap: () => e.carte++,
              onPanStart: (_) => e.carte++,
            ),
          ),
          // Le rond « Balade » sous la capsule, et la patte centrale du menu.
          Positioned(
            right: 12, bottom: 96,
            child: GestureDetector(
              key: const ValueKey<String>('balade'),
              behavior: HitTestBehavior.opaque,
              onTap: () => e.balade++,
              child: const SizedBox(width: 52, height: 52),
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 20,
            child: Center(child: _bouton(e, 'patte')),
          ),
          // La rangée des deux barres, montée comme dans l'écran (643).
          Positioned(
            left: 0, right: 0, bottom: 160,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              PawCollapsibleBar(
                left: true,
                collapsed: e.rail,
                tint: const Color(0xFFC92A12),
                edgeGap: 12.w,
                tabBottom: 18.h,
                onToggle: () => set(() { e.rail = !e.rail; e.basculesRail++; }),
                child: _barre(e, 'rail', nRail),
              ),
              const Spacer(),
              PawCollapsibleBar(
                left: false,
                collapsed: e.capsule,
                tint: const Color(0xFFC92A12),
                edgeGap: 12.w,
                tabBottom: 18.h,
                onToggle: () => set(() { e.capsule = !e.capsule; e.basculesCapsule++; }),
                child: _barre(e, 'cap', nCapsule),
              ),
            ]),
          ),
        ]),
      ),
    );

Future<void> _pose(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 260));
}

Finder _pastille(bool left) => find.descendant(
    of: find.byWidgetPredicate((w) => w is PawBarCollapseTab && w.left == left),
    matching: find.byKey(const ValueKey<String>('pawmap_bar_tab_fill')));

Finder _cible(bool left, bool collapsed) => find.byKey(ValueKey<String>(
    '${left ? 'pawmap_rail' : 'pawmap_capsule'}_${collapsed ? 'show' : 'hide'}'));

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));

  for (final taille in const [Size(393, 852), Size(320, 568), Size(430, 932)]) {
    final nom = '${taille.width.toInt()}×${taille.height.toInt()}';

    testWidgets('$nom — apparence inchangée : la pastille est au même endroit qu\'avant',
        (t) async {
      lotdPhone(t, width: taille.width, height: taille.height);
      final e = _Etat();
      await t.pumpWidget(lotdApp(_ecran(e)));
      await _pose(t);
      final w = taille.width;
      final cap = t.getRect(find.byKey(const ValueKey('cap5')));
      // Barre à 12 du bord, comme avant (rangée à 12 + barre).
      expect(t.getRect(find.byKey(const ValueKey('cap0'))).right, closeTo(w - 12.w - 3, 0.6));
      expect(t.getRect(find.byKey(const ValueKey('rail0'))).left, closeTo(12.w + 3, 0.6));
      // Pastille ouverte : centrée dans sa case de 30 collée à la barre,
      // centre à 18 + 24 du bas de la barre (v589).
      final barRight = w - 12.w, barLeft = barRight - 52;
      final p = t.getRect(_pastille(false));
      expect(p.width, closeTo(22.w, 0.01));
      expect(p.height, closeTo(36.h, 0.01));
      expect(p.center.dx, closeTo(barLeft - 15.w, 0.01));
      expect(p.center.dy, closeTo(cap.bottom + 2 - 18.h - 24.h, 0.01));
      final pr = t.getRect(_pastille(true));
      expect(pr.center.dx, closeTo(12.w + 52 + 15.w, 0.01));
      expect(pr.center.dy, closeTo(p.center.dy, 0.01));
      // Rangée : languette de 24 × 44 collée au bord de l'écran.
      await t.tap(_cible(false, false));
      await t.tap(_cible(true, false));
      await _pose(t);
      final c = t.getRect(_pastille(false));
      expect(c.right, closeTo(w, 0.01));
      expect(c.width, closeTo(24.w, 0.01));
      expect(c.height, closeTo(44.h, 0.01));
      expect(c.center.dy, closeTo(p.center.dy, 0.01));
      expect(t.getRect(_pastille(true)).left, closeTo(0, 0.01));
    });

    testWidgets('$nom — cible tactile ≥ 48 × 56, centrée en hauteur sur la flèche, ouverte ET rangée',
        (t) async {
      lotdPhone(t, width: taille.width, height: taille.height);
      final e = _Etat();
      await t.pumpWidget(lotdApp(_ecran(e)));
      await _pose(t);
      for (final rangee in [false, true]) {
        for (final left in [true, false]) {
          final z = t.getRect(_cible(left, rangee));
          final p = t.getRect(_pastille(left));
          expect(z.width >= 48 - 0.01, isTrue, reason: 'largeur $z');
          expect(z.height >= 56 - 0.01, isTrue, reason: 'hauteur $z');
          expect(z.center.dy, closeTo(p.center.dy, 0.01));
          expect(z.left <= p.left && z.right >= p.right, isTrue, reason: '$z / $p');
          expect(z.left >= -0.01 && z.right <= taille.width + 0.01, isTrue,
              reason: 'cible dans l\'écran : $z');
        }
        if (!rangee) {
          await t.tap(_cible(true, false));
          await t.tap(_cible(false, false));
          await _pose(t);
        }
      }
    });

    testWidgets('$nom — un appui à 20 px du centre de la flèche range puis rouvre, sans toucher la carte',
        (t) async {
      lotdPhone(t, width: taille.width, height: taille.height);
      final e = _Etat();
      await t.pumpWidget(lotdApp(_ecran(e)));
      await _pose(t);
      var attendu = 0;
      for (final rangee in [false, true]) {
        // Ouverte : 20 px vers la carte, vers le haut, vers le bas (côté barre,
        // ce sont les boutons de la barre : ils gardent la main).
        // Rangée : la languette touche le bord ; 20 px vers la carte, haut, bas,
        // et tout au bord de l'écran.
        final c = t.getRect(_pastille(false)).center;
        final points = <Offset>[
          c,
          c + const Offset(-20, 0),
          c + const Offset(0, -20),
          c + const Offset(0, 20),
          c + const Offset(-14, -14),
          c + const Offset(-14, 14),
          if (rangee) Offset(taille.width - 1, c.dy),
          if (rangee) Offset(taille.width - 1, c.dy - 20),
          if (rangee) Offset(taille.width - 1, c.dy + 20),
        ];
        for (final pt in points) {
          await t.tapAt(pt);
          await _pose(t);
          attendu++;
          expect(e.basculesCapsule, attendu, reason: 'appui en $pt (rangée=$rangee)');
          // On remet la barre dans l'état testé.
          await t.tap(_cible(false, !rangee));
          await _pose(t);
          attendu++;
          expect(e.basculesCapsule, attendu);
        }
        if (!rangee) {
          await t.tap(_cible(false, false));
          await _pose(t);
          attendu++;
        }
      }
      expect(e.carte, 0, reason: 'aucun appui n\'a traversé vers la carte');
      expect(e.basculesRail, 0);
      expect(e.balade, 0);
      expect(e.boutons, isEmpty, reason: 'aucun bouton voisin déclenché : ${e.boutons}');
    });

    testWidgets('$nom — même chose pour la flèche de la barre de GAUCHE', (t) async {
      lotdPhone(t, width: taille.width, height: taille.height);
      final e = _Etat();
      await t.pumpWidget(lotdApp(_ecran(e)));
      await _pose(t);
      var attendu = 0;
      for (final rangee in [false, true]) {
        final c = t.getRect(_pastille(true)).center;
        for (final pt in <Offset>[
          c + const Offset(20, 0),
          c + const Offset(0, -20),
          c + const Offset(0, 20),
          if (rangee) Offset(1, c.dy),
        ]) {
          await t.tapAt(pt);
          await _pose(t);
          attendu++;
          expect(e.basculesRail, attendu, reason: 'appui en $pt (rangée=$rangee)');
          await t.tap(_cible(true, !rangee));
          await _pose(t);
          attendu++;
        }
        if (!rangee) {
          await t.tap(_cible(true, false));
          await _pose(t);
          attendu++;
        }
      }
      expect(e.carte, 0);
      expect(e.basculesCapsule, 0);
      expect(e.boutons, isEmpty);
    });

    testWidgets('$nom — un doigt qui glisse sur la flèche bascule la barre (une fois), la carte ne bouge pas',
        (t) async {
      lotdPhone(t, width: taille.width, height: taille.height);
      final e = _Etat();
      await t.pumpWidget(lotdApp(_ecran(e)));
      await _pose(t);
      await t.dragFrom(t.getRect(_pastille(false)).center, const Offset(30, 0));
      await _pose(t);
      expect(e.capsule, isTrue);
      expect(e.basculesCapsule, 1);
      await t.dragFrom(t.getRect(_pastille(false)).center, const Offset(-40, 0));
      await _pose(t);
      expect(e.capsule, isFalse);
      expect(e.basculesCapsule, 2);
      expect(e.carte, 0);
    });

    testWidgets('$nom — les voisins gardent leurs appuis (boutons des deux barres, Balade, patte, carte)',
        (t) async {
      lotdPhone(t, width: taille.width, height: taille.height);
      final e = _Etat();
      await t.pumpWidget(lotdApp(_ecran(e)));
      await _pose(t);
      final ids = <String>[
        for (var i = 0; i < 6; i++) 'cap$i',
        for (var i = 0; i < 6; i++) 'rail$i',
        'patte',
      ];
      for (final id in ids) {
        final r = t.getRect(find.byKey(ValueKey<String>(id)));
        // Centre + les 4 coins (2 px à l'intérieur) : rien ne les recouvre.
        for (final pt in [
          r.center,
          r.topLeft + const Offset(2, 2),
          r.topRight + const Offset(-2, 2),
          r.bottomLeft + const Offset(2, -2),
          r.bottomRight + const Offset(-2, -2),
        ]) {
          await t.tapAt(pt);
        }
        expect(e.boutons[id], 5, reason: '$id reçoit ses 5 appuis');
      }
      await t.tapAt(t.getRect(find.byKey(const ValueKey('balade'))).center);
      expect(e.balade, 1);
      expect(e.basculesRail + e.basculesCapsule, 0);
      // La cible de la flèche ne recouvre aucun voisin.
      for (final left in [true, false]) {
        final z = t.getRect(_cible(left, false));
        for (final id in [...ids, 'balade']) {
          expect(z.overlaps(t.getRect(find.byKey(ValueKey<String>(id)))), isFalse,
              reason: 'la cible ${left ? 'gauche' : 'droite'} $z recouvre $id');
        }
      }
      // La carte reste libre entre les deux barres, juste à côté des cibles.
      final zr = t.getRect(_cible(false, false));
      await t.tapAt(Offset(zr.left - 3, zr.center.dy));
      await t.tapAt(Offset(zr.center.dx, zr.top - 3));
      await t.tapAt(Offset(taille.width / 2, zr.center.dy));
      expect(e.carte, 3);
      // Barres rangées : la carte reprend toute la place des barres, et le
      // rond Balade (sous la languette) garde ses appuis.
      await t.tap(_cible(false, false));
      await t.tap(_cible(true, false));
      await _pose(t);
      final zc = t.getRect(_cible(false, true));
      expect(zc.overlaps(t.getRect(find.byKey(const ValueKey('balade')))), isFalse);
      await t.tapAt(t.getRect(find.byKey(const ValueKey('balade'))).center);
      expect(e.balade, 2);
      await t.tapAt(Offset(zc.left - 3, zc.center.dy));
      expect(e.carte, 4);
    });
  }

  testWidgets('barre très courte (1 bouton) : la flèche garde sa cible entière', (t) async {
    lotdPhone(t);
    final e = _Etat();
    await t.pumpWidget(lotdApp(_ecran(e, nRail: 1, nCapsule: 1)));
    await _pose(t);
    for (final left in [true, false]) {
      final z = t.getRect(_cible(left, false));
      await t.tapAt(z.topLeft + const Offset(1, 1));
      await _pose(t);
      await t.tapAt(t.getRect(_cible(left, true)).bottomRight - const Offset(1, 1));
      await _pose(t);
    }
    expect(e.basculesRail, 2);
    expect(e.basculesCapsule, 2);
    expect(e.carte, 0);
  });

  test('rectangle visible : marge du bord et dépassement tactile retirés', () {
    const box = Rect.fromLTWH(281, 400, 112, 300); // 18 + 30 + 52 + 12
    expect(PawBarCollapseTab.hitSlop >= 18, isTrue);
    final v = PawCollapsibleBar.visualRect(box, left: false, edgeGap: 12);
    expect(v.right, 381);
    expect(v.left, 281 + PawBarCollapseTab.hitSlop);
    final g = PawCollapsibleBar.visualRect(
        const Rect.fromLTWH(0, 400, 112, 300), left: true, edgeGap: 12);
    expect(g.left, 12);
    expect(g.right, 112 - PawBarCollapseTab.hitSlop);
    expect(PawCollapsibleBar.visualRect(Rect.zero, left: true, edgeGap: 12), Rect.zero);
  });
}
