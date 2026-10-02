// 607 (ZOE, 02/10/2026) — bug vu sur le simulateur iPhone : après une
// désinstallation / réinstallation, iOS garde le jeton dans le trousseau →
// l'app démarre connectée, mais `user_profile` a disparu de GetStorage et
// AUCUN appel au profil n'était fait (accueil « Utilisateur », profil « Gardien »
// sans nom ni photo). Le test rejoue cet état : jeton présent, profil local absent.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/utils/storage_keys.dart';

import 'lotd_harness.dart';

Map<String, dynamic> _serverProfile() => <String, dynamic>{
      'profile': <String, dynamic>{
        'id': 'sitter-607',
        'name': 'Camille Durand',
        'email': 'camille@example.test',
        'role': 'sitter',
        'avatar': <String, dynamic>{'url': 'https://example.test/a.jpg'},
      },
    };

void main() {
  setUp(() async {
    await lotdSetUp(role: 'sitter');
    lotdResponder = (req) {
      if (req.url.path.endsWith('/users/me/profile')) return _serverProfile();
      if (req.url.path.endsWith('/users/me/roles')) return <String, dynamic>{'roles': ['sitter']};
      return const <String, dynamic>{};
    };
    // État après réinstallation : jeton présent, profil local effacé.
    await Get.find<GetStorage>().remove(StorageKeys.userProfile);
    lotdRequests.clear();
  });

  test('jeton présent + profil local absent → profil chargé et écrit (id, nom, rôle, photo)', () async {
    final auth = Get.find<AuthController>();
    await auth.refreshAvailableRoles();
    // laisser finir l'appel lancé sans attente
    for (var i = 0; i < 20 && Get.find<GetStorage>().read(StorageKeys.userProfile) == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(lotdRequests.where((r) => r.path.endsWith('/users/me/profile')), isNotEmpty,
        reason: 'aucun appel au profil (le bug)');
    final p = Map<String, dynamic>.from(Get.find<GetStorage>().read(StorageKeys.userProfile) as Map);
    expect(p['id'], 'sitter-607');
    expect(p['name'], 'Camille Durand');
    expect(p['role'], 'sitter');
    expect((p['avatar'] as Map)['url'], 'https://example.test/a.jpg');
  });

  test('retour au premier plan : profil rechargé s\'il manque encore', () async {
    final auth = Get.find<AuthController>();
    auth.didChangeAppLifecycleState(AppLifecycleState.resumed);
    for (var i = 0; i < 20 && Get.find<GetStorage>().read(StorageKeys.userProfile) == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(Get.find<GetStorage>().read(StorageKeys.userProfile), isNotNull);
  });

  test('profil local complet : aucun appel en plus', () async {
    await Get.find<GetStorage>().write(StorageKeys.userProfile, <String, dynamic>{'id': 'x', 'name': 'Déjà là'});
    lotdRequests.clear();
    final done = await Get.find<AuthController>().ensureSessionProfile();
    expect(done, isFalse);
    expect(lotdRequests.where((r) => r.path.endsWith('/users/me/profile')), isEmpty);
  });
}
