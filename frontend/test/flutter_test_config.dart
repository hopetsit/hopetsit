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
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  // Les graisses EMBARQUÉES (`assets/fonts/`, lot D) : Inter 400-900,
  // Poppins 400/500/600/700/800, Manrope 800, Sora 500-800 (PawMap), Fredoka
  // 400-700 (entrée) — google_fonts les charge depuis les assets, sans réseau.
  // Noto (PDF des factures) n'est pas demandée ici.
  for (final w in <FontWeight>[FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800]) {
    GoogleFonts.poppins(fontWeight: w);
  }
  for (final w in <FontWeight>[FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800, FontWeight.w900]) {
    GoogleFonts.inter(fontWeight: w);
  }
  GoogleFonts.manrope(fontWeight: FontWeight.w800);
  for (final w in <FontWeight>[FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800]) {
    GoogleFonts.sora(fontWeight: w);
  }
  for (final w in <FontWeight>[FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700]) {
    GoogleFonts.fredoka(fontWeight: w);
  }
  try {
    await GoogleFonts.pendingFonts();
  } catch (_) {
    // Une police absente n'empêche pas les tests : ils mesurent alors avec
    // la police de test, comme avant le lot D.
  }
  // 607 (ZOE) — tests instables : `LiveMapService` (et d'autres services)
  // écrivent dans GetStorage sans attendre la fin de l'écriture. Selon l'ORDRE
  // des tests, l'écriture partait (a) sans dossier → MissingPluginException
  // path_provider, ou (b) pendant l'écriture du test précédent →
  // « FileSystemException: An async operation is currently pending ». Le test
  // échouait alors APRÈS sa fin, au hasard de l'ordre et de la charge.
  // (a) un dossier temporaire par fichier de test (un fichier qui pose son
  //     propre dossier garde le sien) ; (b) après chaque test, on attend que
  //     les écritures en file soient terminées avant le test suivant.
  final storageDir = Directory.systemTemp.createTempSync('hps_test_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => storageDir.path);
  tearDown(() async {
    try {
      final box = GetStorage();
      await box.initStorage.timeout(const Duration(seconds: 2));
      await box.save().timeout(const Duration(seconds: 2));
    } catch (_) {/* stockage indisponible pour ce test : rien à attendre */}
  });
  await testMain();
}
