// 619 (PAM, 23/10/2026 — ordre de Daniel « code postal = position ») — sonde
// SIMULATEUR : rendu iOS réel du champ « Code postal » (inscription 3 rôles,
// « Modifier le profil » 3 rôles clair + sombre, « Publier ma demande »), dans
// le harnais lot D (faux HTTP, aucun compte, aucun réseau, aucune vraie ville :
// profil « Zone test » en zone fictive). Le runner capture l'écran à chaque
// ligne « [SHOT] nom ».
//
//   flutter test integration_test/pam619_postal_sonde_test.dart -d <udid>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/controllers/sign_up_controller.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/auth/signup_wizard_screen.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/edit_sitter_profile_screen.dart';
import 'package:hopetsit/views/pet_walker/profile/edit_walker_profile_screen.dart';
import 'package:hopetsit/views/profile/edit_owner_profile_screen.dart';
import 'package:hopetsit/widgets/city_location_picker.dart';
import 'package:integration_test/integration_test.dart';

import '../test/lotd_harness.dart';

Future<void> _pause(WidgetTester t, int frames) async {
  for (int i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _shot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 200));
  debugPrint('[SHOT] $name');
  await Future<void>.delayed(const Duration(seconds: 3));
}

Future<void> _scrollTo(WidgetTester t, Finder f) async {
  final scrollable = find.byType(Scrollable).first;
  try {
    await t.scrollUntilVisible(f, 160, scrollable: scrollable);
  } catch (_) {/* déjà visible ou non défilable */}
  await _pause(t, 2);
}

Map<String, dynamic> _profile(String role) => <String, dynamic>{
      'id': 'u-test',
      '_id': 'u-test',
      'name': 'Camille Durand',
      'firstName': 'Camille',
      'lastName': 'Durand',
      'email': 'camille@example.test',
      'mobile': '612345678',
      'countryCode': '+33',
      'country': 'FR',
      'city': 'Zone test',
      'postalCode': '75011',
      'address': '',
      'avatar': <String, dynamic>{'url': ''},
      'role': role,
      'location': <String, dynamic>{
        'type': 'Point',
        'coordinates': <double>[-30.4, -35.2],
        'city': 'Zone test',
      },
      'language': 'Français',
      'bio': '',
      'currency': 'EUR',
      'service': <String>[],
      'acceptedPetTypes': <String>['dog'],
      'experienceTags': <String>[],
      'coverageRadiusKm': 10,
      'walkRates': <Map<String, dynamic>>[],
    };

void _respondProfiles(String role) {
  lotdResponder = (req) {
    final path = req.url.path;
    if (path.contains('/walkers/me/rates')) {
      return <String, dynamic>{'walkRates': <Map<String, dynamic>>[]};
    }
    if (path.contains('/users/me/profile')) {
      return <String, dynamic>{'profile': _profile(role), 'user': _profile(role), 'role': role};
    }
    if (path.contains('/walkers/me') || path.contains('/sitters/')) {
      return _profile(role);
    }
    return <String, dynamic>{};
  };
}

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Rendu continu à l'écran (sinon « Test starting… » reste affiché, captures noires).
  b.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('sonde 619 — code postal', (t) async {
    // ── 1. Inscription, étape « ville », 3 rôles ──
    for (final role in <String>['pet_owner', 'pet_sitter', 'pet_walker']) {
      await lotdSetUp(role: role == 'pet_owner' ? 'owner' : role == 'pet_sitter' ? 'sitter' : 'walker');
      final c = Get.put(
        SignUpController(userType: role, authRepository: Get.find<AuthRepository>()),
        tag: role,
        permanent: true,
      );
      // Ville déjà choisie (zone fictive) : pas de détection GPS au simulateur.
      c.cityController.text = 'Zone test';
      markCityPicked610(c.cityController, 'Zone test');
      c.userCity.value = 'Zone test';
      c.userLatitude.value = -35.2;
      c.userLongitude.value = -30.4;
      c.selectedCountry.value = 'FR';
      c.currentStep.value = 1;
      await t.pumpWidget(lotdApp(SignupWizardScreen(userType: role)));
      await _pause(t, 3);
      final field = find.byKey(const Key('postal2310_block'));
      expect(field, findsOneWidget, reason: '$role : champ code postal présent');
      await _scrollTo(t, field);
      await _shot(t, '01_inscription_${role.replaceFirst('pet_', '')}_champ');
      // « Suivant » sans code postal → avertissement.
      final next = find.text('common_next'.tr);
      if (next.evaluate().isNotEmpty) {
        await _scrollTo(t, next.first);
        await t.tap(next.first);
        await _pause(t, 2);
        expect(find.textContaining('code postal'), findsWidgets, reason: '$role : avertissement affiché');
        await _shot(t, '02_inscription_${role.replaceFirst('pet_', '')}_obligatoire');
      }
      expect(t.takeException(), isNull);
      await Get.deleteAll(force: true);
      Get.reset();
    }

    // ── 2. « Modifier le profil », 3 rôles (propriétaire aussi en sombre) ──
    final screens = <(String, Widget Function(), Brightness)>[
      ('owner', () => const EditOwnerProfileScreen(), Brightness.light),
      ('owner_sombre', () => const EditOwnerProfileScreen(), Brightness.dark),
      ('sitter', () => const EditSitterProfileScreen(), Brightness.light),
      ('walker', () => const EditWalkerProfileScreen(), Brightness.light),
    ];
    for (final s in screens) {
      final role = s.$1.split('_').first;
      await lotdSetUp(role: role);
      _respondProfiles(role);
      Get.put(ThemeController(), permanent: true);
      await t.pumpWidget(lotdApp(s.$2(), brightness: s.$3));
      await _pause(t, 6);
      final field = find.byKey(const Key('postal2310_field'), skipOffstage: false);
      expect(field, findsOneWidget, reason: '${s.$1} : champ code postal présent');
      await _scrollTo(t, field);
      await _shot(t, '03_profil_${s.$1}');
      expect(t.takeException(), isNull);
      await Get.deleteAll(force: true);
      Get.reset();
    }

    // ── 3. « Publier ma demande » : ville choisie dans la liste → code postal ──
    await lotdSetUp(role: 'owner');
    final p = Map<String, dynamic>.from(GetStorage().read(StorageKeys.userProfile) as Map);
    p['country'] = 'FR';
    p['city'] = 'Zone test';
    await GetStorage().write(StorageKeys.userProfile, p);
    await t.pumpWidget(lotdApp(const Scaffold(body: SizedBox.shrink())));
    await _pause(t, 1);
    Get.to(() => const PublishReservationRequestScreen(initialServiceType: 'pet_sitting'));
    await _pause(t, 4);
    final pc = Get.find<PublishReservationRequestController>();
    pc.cityController.text = 'Zone test';
    markCityPicked610(pc.cityController, 'Zone test');
    pc.gpsPrecise.value = false;
    await _pause(t, 2);
    final reqField = find.byKey(const Key('postal2310_request_field'), skipOffstage: false);
    expect(reqField, findsOneWidget, reason: 'demande : champ code postal demandé sans GPS précis');
    await _scrollTo(t, reqField);
    await _shot(t, '04_demande_champ_prerempli');
    pc.postalCodeController.clear();
    await _pause(t, 2);
    await _shot(t, '05_demande_champ_vide_il_manque');
    // « Ma position » (GPS précis) : le champ disparaît.
    pc.userLat.value = -35.2;
    pc.userLng.value = -30.4;
    pc.gpsPrecise.value = true;
    await _pause(t, 2);
    expect(find.byKey(const Key('postal2310_request_field'), skipOffstage: false), findsNothing,
        reason: 'GPS précis : rien ne change, pas de code postal demandé');
    await _shot(t, '06_demande_gps_precis_sans_champ');
    expect(t.takeException(), isNull);
  });
}
