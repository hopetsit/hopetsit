// v585 (lot D) — configuration COMMUNE de tous les tests (`flutter test`
// l'exécute autour de chaque fichier de test).
//
// Depuis que Poppins Regular / Bold sont EMBARQUÉES (`assets/fonts/`),
// google_fonts les trouve dans les assets et les charge de façon asynchrone
// AU MILIEU d'un test : la police change entre la mise en page et le dessin
// (assertion `debugSize == size` vue dans profiles573). On demande donc les
// graisses utilisées par l'app AVANT le premier test et on attend qu'elles
// soient chargées : rendu stable, mesures avec la vraie police.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  // Regular (400) et Bold (700) sont dans les assets ; les autres graisses ne
  // sont pas demandées ici (sans asset, google_fonts n'a rien à charger et
  // la police par défaut prend le relais, comme avant).
  for (final w in <FontWeight>[FontWeight.w400, FontWeight.w700]) {
    GoogleFonts.poppins(fontWeight: w);
  }
  try {
    await GoogleFonts.pendingFonts();
  } catch (_) {
    // Une police absente n'empêche pas les tests : ils mesurent alors avec
    // la police de test, comme avant le lot D.
  }
  await testMain();
}
