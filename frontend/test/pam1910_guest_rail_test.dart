// PAM 19/10/2026 — garde-fou : sur la PawMap, un INVITÉ qui appuie sur
// « Chat » ou « Photo du spot » doit voir la feuille « Crée ton compte »
// (SignupWallSheet), pas la liste des messages avec l'erreur brute
// « Missing auth token… » ni l'appareil photo (envoi refusé sans compte).
// Constat au simulateur (parcours pam1210_rail_test, invité, Paris).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rail PawMap : Chat et Photo protégés pour l’invité', () {
    final src =
        File('lib/views/map/paw_map_screen.dart').readAsStringSync();
    final start = src.indexOf('void _onRailTap(String id) {');
    expect(start, greaterThan(0), reason: '_onRailTap introuvable');
    final sw = src.indexOf('switch (id)', start);
    final head = src.substring(start, sw);
    expect(head.contains('!_viewerLoggedIn'), isTrue,
        reason: 'la porte invité doit passer AVANT le switch');
    expect(head.contains("id == 'chat'"), isTrue);
    expect(head.contains("id == 'photo'"), isTrue);
    expect(head.contains('SignupWallSheet.show('), isTrue);
  });
}
