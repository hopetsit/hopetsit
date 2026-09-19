// v569 — dégagement bas UNIQUE pour toute l'app (boutons collés en bas,
// feuilles modales, barres d'action).
//
// Deux pièges constatés sur le Samsung de Daniel :
//  1. `showModalBottomSheet(useSafeArea: true)` enveloppe la feuille dans
//     `SafeArea(bottom: false)` : le BAS n'est JAMAIS protégé par Flutter,
//     c'est au contenu de la feuille d'ajouter l'inset.
//  2. Selon l'écran, Android annonce un inset bas de 0 alors que la barre à
//     3 boutons (48 px) recouvre le contenu.
// Règle : iOS = inset réel (home indicator) ; Android = jamais moins de 48 px.
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// Inset bas à AJOUTER sous le dernier élément d'une feuille modale ou d'une
/// barre collée en bas, quand aucun `SafeArea(bottom: true)` ne l'entoure.
double appBottomInset(BuildContext context) {
  final mq = MediaQuery.of(context);
  final raw = math.max(mq.viewPadding.bottom, mq.padding.bottom);
  if (!kIsWeb && Platform.isAndroid) return math.max(raw, 48.0);
  return raw;
}

/// Même chose quand un `SafeArea(bottom: true)` entoure DÉJÀ le contenu : ne
/// renvoie que le complément manquant (0 sur iOS).
double appBottomInsetInsideSafeArea(BuildContext context) {
  final applied = MediaQuery.of(context).padding.bottom;
  if (!kIsWeb && Platform.isAndroid) return math.max(0.0, 48.0 - applied);
  return 0.0;
}
