// v23.1.362 — l'emoji PawSpot DORÉ officiel en WIDGET réutilisable.
// v561 — Daniel : « change l'icône de PawSpot » → nouvelle pièce dorée
// (pin + patte sur fond carte, visuel fourni le 12/09), servie depuis
// assets/images/pawspot_coin.png (256 px, fond transparent). Même classe et
// même paramètre `size` → boutique, carte boost et sheets l'utilisent sans
// changement.

import 'package:flutter/material.dart';

class GoldenPawCoin extends StatelessWidget {
  const GoldenPawCoin({super.key, this.size = 48});

  final double size;

  static const String asset = 'assets/images/pawspot_coin.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
