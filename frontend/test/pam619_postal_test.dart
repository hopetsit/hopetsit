// 619 (PAM, 23/10/2026 — ordre de Daniel « code postal = position ») :
//   · inscription : le code postal est OBLIGATOIRE juste sous la ville, pour
//     les 3 rôles (3 à 10 caractères utiles), et part dans `postalCode` ;
//   · « Modifier le profil » : la réponse du serveur donne la position, le
//     profil local et la PawMap suivent (`applyMovedPosition2310`) ;
//   · « Publier ma demande » : sans GPS précis, le code postal est demandé
//     et envoyé avec le pays ; avec « Ma position », rien ne change ;
//   · textes dans les 9 langues ; clavier numérique pour les pays à chiffres.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/controllers/sign_up_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/localization/v565/postal2310_i18n.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/utils/postal_code2310.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/city_location_picker.dart';

import 'lotd_harness.dart';

SignUpController _ctrl(String userType) => SignUpController(
    userType: userType, authRepository: Get.find<AuthRepository>());

class _FakeLocation implements LocationService {
  _FakeLocation(this.data);
  final Map<String, dynamic>? data;
  @override
  String lastFailure = '';
  @override
  Future<Map<String, dynamic>?> getUserLocationWithCity() async => data;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('pam619');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => <String, dynamic>{
        'appName': 'HoPetSit', 'packageName': 'test', 'version': '0', 'buildNumber': '0',
      },
    );
    await GetStorage.init();
    Get.put<AuthRepository>(AuthRepository(ApiClient()));
  });

  group('règle commune', () {
    test('nettoyage comme le serveur, 3 à 10 caractères utiles', () {
      expect(cleanPostalCode2310(' 75 011 '), '75011');
      expect(cleanPostalCode2310('sw1a 1aa'), 'SW1A1AA');
      expect(cleanPostalCode2310('1200-109'), '1200109');
      expect(isPostalCodeValid2310(''), isFalse);
      expect(isPostalCodeValid2310('75'), isFalse);
      expect(isPostalCodeValid2310('750'), isTrue);
      expect(isPostalCodeValid2310('75011'), isTrue);
      expect(isPostalCodeValid2310('ABCDEFGHIJK'), isTrue, reason: 'coupé à 10');
    });

    test('clavier numérique pour les pays à chiffres, texte sinon', () {
      for (final c in <String>['FR', 'US', 'ES', 'DE', 'IT', 'PT', 'PL', 'KR', 'JP', '']) {
        expect(postalKeyboardFor2310(c), TextInputType.number, reason: c);
      }
      for (final c in <String>['GB', 'CA', 'NL', 'IE']) {
        expect(postalKeyboardFor2310(c), TextInputType.text, reason: c);
      }
    });

    test('textes présents dans les 9 langues, jamais vides', () {
      const langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
      final keys = postal2310I18n['en']!.keys.toSet();
      expect(keys.length, 7);
      for (final l in langs) {
        expect(postal2310I18n[l]?.keys.toSet(), keys, reason: l);
        expect(postal2310I18n[l]!.values.every((v) => v.trim().isNotEmpty), isTrue, reason: l);
      }
    });
  });

  group('inscription : code postal obligatoire sous la ville, 3 rôles', () {
    for (final role in <String>['pet_owner', 'pet_sitter', 'pet_walker']) {
      test(role, () {
        final c = _ctrl(role);
        markCityPicked610(c.cityController, 'Paris');
        c.cityController.text = 'Paris';
        if (role == 'pet_owner') c.selectedServices.add('walk');
        c.acceptedAnimals.add('dog');
        if (role == 'pet_sitter') c.selectedServices.add('boarding');
        expect(c.validateStep(1), 'postal2310_required', reason: 'vide');
        c.postalCodeController.text = '75';
        expect(c.validateStep(1), 'postal2310_required', reason: 'trop court');
        c.postalCodeController.text = '75011';
        expect(c.validateStep(1), isNull);
        c.postalCodeController.text = 'SW1A 1AA';
        expect(c.validateStep(1), isNull, reason: 'lettres acceptées (GB)');
      });
    }
  });

  group('position renvoyée par le serveur → profil local + PawMap', () {
    test('lecture de la réponse (GeoJSON et lat/lng plats)', () {
      final a = positionFromProfileResponse2310(<String, dynamic>{
        'role': 'owner',
        'user': {'location': {'type': 'Point', 'coordinates': [2.3765, 48.8594], 'city': 'Paris'}},
      });
      expect([a.lat, a.lng, a.city], [48.8594, 2.3765, 'Paris']);
      final b = positionFromProfileResponse2310(<String, dynamic>{
        'location': {'lat': -35.2, 'lng': -30.4}, 'city': 'Zone test',
      });
      expect([b.lat, b.lng, b.city], [-35.2, -30.4, 'Zone test']);
      final c = positionFromProfileResponse2310(<String, dynamic>{'user': {'city': 'X'}});
      expect(c.lat, isNull);
    });

    test('applyMovedPosition2310 : profil local, dernier centre oublié, signal carte', () async {
      final box = GetStorage();
      await box.write(StorageKeys.userProfile, <String, dynamic>{'id': 'u1', 'city': 'Paris'});
      await box.write('pawmap_last_center', <String, dynamic>{'lat': 1.0, 'lng': 2.0, 'zoom': 10.0});
      final before = pawMapProfileMoved619.value;
      final ok = applyMovedPosition2310((lat: 48.8594, lng: 2.3765, city: 'Paris 11e'), '75 011');
      expect(ok, isTrue);
      final p = box.read(StorageKeys.userProfile) as Map;
      expect((p['location'] as Map)['coordinates'], [2.3765, 48.8594]);
      expect(p['postalCode'], '75011');
      expect(p['city'], 'Paris 11e');
      expect(box.read('pawmap_last_center'), isNull, reason: 'la carte s\'ouvrira sur le nouveau point');
      expect(pawMapProfileMoved619.value, before + 1);
      expect(pawMapProfileMovedTo619.value?.latitude, 48.8594);
      // sans position : rien n'est touché
      expect(applyMovedPosition2310((lat: null, lng: null, city: ''), '75011'), isFalse);
      expect(pawMapProfileMoved619.value, before + 1);
    });
  });

  group('publier ma demande', () {
    setUp(() async {
      // Harnais lot D : dépôts, stockage, rôle propriétaire (profil 75011, FR).
      await lotdSetUp(role: 'owner');
      final p = Map<String, dynamic>.from(
          GetStorage().read(StorageKeys.userProfile) as Map);
      p['country'] = 'FR';
      await GetStorage().write(StorageKeys.userProfile, p);
    });
    tearDown(() async {
      await Get.deleteAll(force: true);
      Get.reset();
    });

    test('ville choisie dans la liste : code postal demandé, pré-rempli depuis le profil, pays FR', () {
      final c = Get.put(PublishReservationRequestController(locationService: _FakeLocation(null)));
      expect(c.postalCodeController.text, '75011', reason: 'pré-rempli depuis le profil');
      markCityPicked610(c.cityController, 'Paris');
      c.cityController.text = 'Paris';
      expect(c.stepCityDone, isTrue);
      expect(c.needsPostal, isTrue);
      expect(c.postalDone, isTrue);
      expect(c.ownerCountry, 'FR');
      c.postalCodeController.text = '7';
      expect(c.postalDone, isFalse);
      c.postalCodeController.text = '';
      expect(c.postalDone, isFalse);
    });

    test('« Ma position » (GPS précis) : le code postal n\'est pas demandé', () async {
      final c = Get.put(PublishReservationRequestController(
          locationService: _FakeLocation(<String, dynamic>{
        'city': 'Zone test', 'latitude': -35.0, 'longitude': -30.0,
      })));
      c.cityController.clear();
      await c.detectLocation();
      expect(c.gpsPrecise.value, isTrue);
      expect(c.stepCityDone, isTrue);
      expect(c.needsPostal, isFalse);
      expect(c.postalDone, isTrue);
      // ville retouchée à la main → plus de GPS précis
      c.cityController.text = 'Ailleurs';
      expect(c.gpsPrecise.value, isFalse);
      expect(c.userLat.value, isNull);
    });
  });
}
