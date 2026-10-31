// 631 (PAM-A) — montage du bouton « Balade rapide » (PAM-C) dans la PawMap :
// posé à CÔTÉ de la barre du bord choisi, jamais dessus ni sur « Publier ».
// Mesuré ici aux deux tailles demandées par BOB : 402×874 et 375×667.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart' show pawQuickWalkSideInset631;
import 'package:hopetsit/widgets/paw_tab_bar.dart' show kPawTabBarPillHeight, kPawTabBarBottomMargin;
import 'package:hopetsit/widgets/quick_walk_button_3110.dart';

/// Rectangle du bouton en coordonnées écran (origine en haut à gauche).
Rect _button(Size screen, {required double bottomInset, required bool left, required double railWidth}) {
  final inset = pawQuickWalkSideInset631(railWidth: railWidth, screenWidth: screen.width);
  final bottom = bottomInset + kQuickWalkAboveBar3110;
  final top = screen.height - bottom - kQuickWalkSize3110;
  final x = left ? inset : screen.width - inset - kQuickWalkSize3110;
  return Rect.fromLTWH(x, top, kQuickWalkSize3110, kQuickWalkSize3110);
}

/// Barre du bord (mesure 622 : ~50 pt de large, alignée sur le menu, 12 d'air),
/// bas = menu (pilule 70 + marge 6 + inset) + 12, hauteur 420.
Rect _rail(Size screen, {required double bottomInset, required bool left, double width = 50}) {
  final bottom = bottomInset + kPawTabBarPillHeight + kPawTabBarBottomMargin + 12;
  final top = screen.height - bottom - 420;
  final x = left ? 12.0 : screen.width - 12 - width;
  return Rect.fromLTWH(x, top, width, 420);
}

void main() {
  test('inset : à côté de la barre, marge seule quand repliée / non mesurée', () {
    expect(pawQuickWalkSideInset631(railWidth: 0), 16);
    expect(pawQuickWalkSideInset631(railWidth: 3), 16);
    expect(pawQuickWalkSideInset631(railWidth: 50), 74);
    expect(pawQuickWalkSideInset631(railWidth: 400, screenWidth: 375), 125, reason: 'jamais au-delà du tiers');
  });

  for (final screen in const [Size(402, 874), Size(375, 667)]) {
    for (final bottomInset in const [34.0, 0.0]) {
      test('${screen.width.toInt()}×${screen.height.toInt()} inset $bottomInset : aucun chevauchement avec la barre, au-dessus du menu', () {
        for (final left in [false, true]) {
          final b = _button(screen, bottomInset: bottomInset, left: left, railWidth: 50);
          final r = _rail(screen, bottomInset: bottomInset, left: left);
          expect(b.overlaps(r), isFalse, reason: 'bouton $b sur la barre $r (gauche=$left)');
          final menuTop = screen.height - bottomInset - kPawTabBarBottomMargin - kPawTabBarPillHeight;
          expect(b.bottom <= menuTop - 12, isTrue, reason: 'au-dessus de la barre d\'onglets');
          expect(b.left >= 0 && b.right <= screen.width, isTrue);
          // La patte centrale du menu (±44 autour du centre) reste libre.
          final paw = Rect.fromCenter(center: Offset(screen.width / 2, menuTop), width: 88, height: 88);
          expect(b.overlaps(paw), isFalse, reason: 'la patte du menu reste libre');
        }
      });
    }
  }
}
