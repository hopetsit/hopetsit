// v575 — l'ancien contenu était le test modèle « Counter » généré par Flutter :
// il montait `MyApp` sans les liaisons GetX et échouait depuis toujours, ce qui
// masquait les vrais échecs dans `flutter test`. Remplacé par un contrôle utile :
// le numéro de version de secours de l'app doit suivre celui du pubspec.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la version de secours de ApiClient suit le pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)!.group(1)!;
    final apiClient = File('lib/data/network/api_client.dart').readAsStringSync();
    expect(apiClient.contains("'$version'"), isTrue,
        reason: '_fallbackAppVersion doit valoir $version');
  });
}
