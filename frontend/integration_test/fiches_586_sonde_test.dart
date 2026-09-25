// v586 — points 8 et 9 sur appareil, connecté (compte de test) : fiche d'un
// gardien et d'un promeneur (Réserver EN PREMIER + Message, pour les 3 rôles ;
// en gardien / promeneur, « Réserver » ouvre le dialogue « Tu réserves avec
// ton profil propriétaire » — on répond ANNULER : aucune bascule, aucune
// réservation), et fiche d'un propriétaire vue par un prestataire (carte
// « Demandes en cours » si la route serveur répond, sinon « Message »).
// Les fiches ouvertes sont des membres PUBLICS lus sur /friends/members/world
// (lecture seule).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/views/service_provider/owner_profile_view_screen.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:hopetsit/views/service_provider/walker_detail_screen.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:integration_test/integration_test.dart';

import 'sonde_586_common.dart';

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  b.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(sondeSetUp);

  testWidgets('586 fiches ($kRole)', (t) async {
    await loginAndEnter(t);
    final api = Get.find<ApiClient>();
    final res = await api.get('/friends/members/world', requiresAuth: true);
    final members = (res is Map && res['members'] is List)
        ? (res['members'] as List).whereType<Map>().toList()
        : <Map>[];
    Map? first(String role) =>
        members.firstWhereOrNull((m) => (m['role'] ?? '').toString() == role);
    final sitter = first('sitter'), walker = first('walker'), owner = first('owner');
    say('membres=${members.length} gardien=${sitter != null} promeneur=${walker != null} proprietaire=${owner != null}');

    Future<void> checkProvider(String kind, Widget screen) async {
      Get.to(() => screen);
      final book = find.byKey(const ValueKey('provider_book'));
      await waitFor(t, () => book.evaluate().isNotEmpty, seconds: 25);
      await hold(t, 1500);
      final msg = find.byKey(const ValueKey('provider_message'));
      final okBar = book.evaluate().isNotEmpty && msg.evaluate().isNotEmpty;
      ok('fiche $kind : Reserver + Message', okBar);
      if (okBar) {
        ok('fiche $kind : Reserver EN PREMIER',
            t.getCenter(book.first).dx < t.getCenter(msg.first).dx);
      }
      await shot(t, 'fiche_${kind}_barre');
      if (book.evaluate().isNotEmpty) {
        await realTap(t, book, why: 'Reserver $kind');
        await hold(t, 1500);
        if (kRole != 'owner') {
          final cancel = find.byType(AppDialogSecondaryButton);
          ok('fiche $kind : dialogue « profil proprietaire »', cancel.evaluate().isNotEmpty);
          await shot(t, 'fiche_${kind}_dialogue');
          if (cancel.evaluate().isNotEmpty) await realTap(t, cancel, why: 'Annuler');
        } else {
          await shot(t, 'fiche_${kind}_reservation');
          Get.back(); // écran de demande refermé sans rien envoyer
          await hold(t, 1200);
        }
      }
      Get.back();
      await hold(t, 1500);
    }

    if (sitter != null) {
      await checkProvider('gardien',
          ServiceProviderDetailScreen(sitterId: '${sitter['id']}', status: 'available'));
    }
    if (walker != null) {
      await checkProvider('promeneur', WalkerDetailScreen(walkerId: '${walker['id']}'));
    }
    if (owner != null && kRole != 'owner') {
      Get.to(() => OwnerProfileViewScreen(
            ownerId: '${owner['id']}',
            ownerName: '${owner['name'] ?? ''}',
            ownerAvatar: '${owner['avatar'] ?? ''}',
          ));
      await hold(t, 5000);
      final card = find.byKey(const ValueKey('owner_requests_card'));
      final msg = find.byKey(const ValueKey('owner_profile_message'));
      say('fiche proprietaire : demandes=${card.evaluate().isNotEmpty} message=${msg.evaluate().isNotEmpty}');
      ok('fiche proprietaire : demandes OU Message', card.evaluate().isNotEmpty || msg.evaluate().isNotEmpty);
      await shot(t, 'fiche_proprietaire');
      Get.back();
      await hold(t, 1200);
    }
    await sondeTearDown(t);
  });
}
