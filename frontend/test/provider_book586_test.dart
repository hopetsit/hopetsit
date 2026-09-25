// v586 (point 8 de Daniel) — la fiche d'un GARDIEN ou d'un PROMENEUR montre
// TOUJOURS « Réserver · dès X » en premier + « Message », quel que soit le
// rôle du spectateur ; seule exception : sa propre fiche (tous ses profils).
// Spectateur gardien / promeneur : Réserver → dialogue « Tu réserves avec ton
// profil propriétaire » → Continuer → bascule vers le profil propriétaire →
// même écran de réservation pré-rempli.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/services/self_profiles_service.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:hopetsit/views/service_provider/walker_detail_screen.dart';
import 'package:hopetsit/views/service_provider/widgets/book_as_owner.dart';
import 'package:get_storage/get_storage.dart';

import 'lotd_harness.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(super.a, super.s, super.u);
  int switches = 0;
  String? target;
  @override
  Future<void> switchRole({String? targetRole}) async {
    switches++;
    target = targetRole;
    userRole.value = targetRole;
  }
}

const _sitterJson = <String, dynamic>{
  'sitter': <String, dynamic>{'id': 's-lea', 'name': 'Léa Martin', 'dailyRate': 35, 'currency': 'EUR'},
};
const _walkerJson = <String, dynamic>{
  'walker': <String, dynamic>{
    'id': 'w-tom',
    'name': 'Tom Leroy',
    'currency': 'EUR',
    'walkRates': <Map<String, dynamic>>[
      <String, dynamic>{'durationMinutes': 60, 'basePrice': 15, 'enabled': true},
    ],
  },
};

Future<_FakeAuth> _setUp(String viewerRole) async {
  await lotdSetUp(role: viewerRole);
  SelfProfiles.setIds(const <String>[]);
  lotdResponder = (req) {
    final p = req.url.path;
    if (p.endsWith('/sitters/s-lea') || p.endsWith('/sitters/u-test') || p.endsWith('/sitters/s-self')) {
      return _sitterJson;
    }
    if (p.contains('/walkers/')) return _walkerJson;
    return const <String, dynamic>{};
  };
  await Get.delete<AuthController>(force: true);
  final auth = _FakeAuth(Get.find<AuthRepository>(), GetStorage(), Get.find<UserRepository>());
  Get.put<AuthController>(auth, permanent: true);
  auth.userRole.value = viewerRole;
  return auth;
}

Widget _screen(String providerRole, {String id = ''}) => providerRole == 'walker'
    ? WalkerDetailScreen(walkerId: id.isEmpty ? 'w-tom' : id)
    : ServiceProviderDetailScreen(sitterId: id.isEmpty ? 's-lea' : id, status: 'available');

final _book = find.byKey(const ValueKey<String>('provider_book'));
final _msg = find.byKey(const ValueKey<String>('provider_message'));

void main() {
  late _FakeAuth auth;
  tearDown(() async {
    SelfProfiles.setIds(const <String>[]);
    await Get.deleteAll(force: true);
    Get.reset();
  });

  for (final viewer in const ['owner', 'sitter', 'walker']) {
    group('spectateur $viewer', () {
      // lotdSetUp hors de la zone à temps simulé (E/S réelles).
      setUp(() async => auth = await _setUp(viewer));
      for (final provider in const ['sitter', 'walker']) {
        testWidgets('fiche $provider : Réserver EN PREMIER + Message', (tester) async {
          lotdPhone(tester, width: 375, height: 812);
          await tester.pumpWidget(lotdApp(_screen(provider)));
          await lotdSettle(tester);
          expect(tester.takeException(), isNull);
          expect(_book, findsOneWidget);
          expect(_msg, findsOneWidget);
          expect(find.textContaining('Réserver'), findsOneWidget);
          expect(find.textContaining(provider == 'walker' ? '15' : '35'), findsWidgets);
          // Réserver à gauche de Message (en premier dans la barre).
          expect(tester.getTopLeft(_book).dx, lessThan(tester.getTopLeft(_msg).dx));
        });
      }
    });
  }

  group('spectateur gardien', () {
    setUp(() async => auth = await _setUp('sitter'));

    testWidgets('sa propre fiche (profil actif) : ni Réserver ni Message', (tester) async {
      lotdPhone(tester, width: 375, height: 812);
      await tester.pumpWidget(lotdApp(_screen('sitter', id: 'u-test')));
      await lotdSettle(tester);
      expect(_book, findsNothing);
      expect(_msg, findsNothing);
      expect(find.byKey(const ValueKey<String>('provider_self_no_actions')), findsOneWidget);
    });

    for (final provider in const ['sitter', 'walker']) {
      testWidgets('fiche $provider : Réserver → dialogue propriétaire → Annuler = aucune bascule',
          (tester) async {
        lotdPhone(tester, width: 375, height: 812);
        await tester.pumpWidget(lotdApp(_screen(provider)));
        await lotdSettle(tester);
        await tester.tap(_book);
        await lotdSettle(tester);
        expect(find.text('Réserver avec ton profil propriétaire'), findsOneWidget);
        expect(find.textContaining(provider == 'walker' ? 'Tom Leroy' : 'Léa Martin'), findsWidgets);
        expect(find.text('Continuer'), findsOneWidget);
        await tester.tap(find.text('Annuler'));
        await lotdSettle(tester);
        expect(auth.switches, 0);
      });
    }
  });

  group('spectateur propriétaire', () {
    setUp(() async => auth = await _setUp('owner'));

    testWidgets('sa propre fiche vue depuis un AUTRE de ses profils : pas de Réserver', (tester) async {
      lotdPhone(tester, width: 375, height: 812);
      SelfProfiles.setIds(const <String>['u-test', 's-self']);
      await tester.pumpWidget(lotdApp(_screen('sitter', id: 's-self')));
      await lotdSettle(tester);
      expect(_book, findsNothing);
    });

    testWidgets('ids d\'un compte précédent ignorés (profil actif absent de la liste)', (tester) async {
      lotdPhone(tester, width: 375, height: 812);
      SelfProfiles.setIds(const <String>['autre-compte', 's-lea']);
      await tester.pumpWidget(lotdApp(_screen('sitter')));
      await lotdSettle(tester);
      expect(_book, findsOneWidget);
    });

    testWidgets('runAsOwner : propriétaire → pas de dialogue, écran direct', (tester) async {
      lotdPhone(tester, width: 375, height: 812);
      var opened = 0;
      await tester.pumpWidget(lotdApp(Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () => runAsOwner(ctx, providerName: 'Léa', forMessage: false, then: () => opened++),
            child: const Text('go'),
          ),
        ),
      )));
      await tester.tap(find.text('go'));
      await lotdSettle(tester);
      expect(find.text('Continuer'), findsNothing);
      expect(auth.switches, 0);
      expect(opened, 1);
    });
  });

  group('spectateur promeneur', () {
    setUp(() async => auth = await _setUp('walker'));

    testWidgets('fiche gardien : Message → dialogue « Écrire avec ton profil propriétaire »', (tester) async {
      lotdPhone(tester, width: 375, height: 812);
      await tester.pumpWidget(lotdApp(_screen('sitter')));
      await lotdSettle(tester);
      await tester.tap(_msg);
      await lotdSettle(tester);
      expect(find.text('Écrire avec ton profil propriétaire'), findsOneWidget);
    });

    testWidgets('runAsOwner : Continuer → switchRole(owner) PUIS l\'écran demandé', (tester) async {
      lotdPhone(tester, width: 375, height: 812);
      var opened = 0;
      await tester.pumpWidget(lotdApp(Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => runAsOwner(ctx, providerName: 'Léa', forMessage: false, then: () => opened++),
              child: const Text('go'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('go'));
      await lotdSettle(tester);
      expect(opened, 0);
      await tester.tap(find.text('Continuer'));
      await lotdSettle(tester);
      expect(auth.switches, 1);
      expect(auth.target, 'owner');
      expect(opened, 1);
    });
  });
}
