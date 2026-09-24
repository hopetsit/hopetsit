// v585 (lot D) — pilote `flutter drive` pour les tests d'intégration qui
// prennent des CAPTURES D'ÉCRAN (`binding.takeScreenshot(nom)`) sur le
// simulateur iPhone et l'émulateur Android :
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/ecrans_lotd_test.dart -d <udid|emulator-5554> \
//     --dart-define=CAPTURES=/chemin/du/dossier
//
// Chaque capture est écrite dans le dossier passé par `--dart-define=CAPTURES`
// (défaut : `build/captures_lotd`), sous `<nom>.png`.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  const String dir = String.fromEnvironment('CAPTURES', defaultValue: 'build/captures_lotd');
  await Directory(dir).create(recursive: true);
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final File f = File('$dir/$name.png');
      await f.writeAsBytes(bytes);
      // ignore: avoid_print
      print('[CAPTURE] ${f.path} (${bytes.length} octets)');
      return true;
    },
  );
}
