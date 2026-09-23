// v583 NEO — inscription : logique des étapes et textes ajoutés.
//
// Ce que ces tests garantissent :
//   · propriétaire : depuis le retrait de l'étape vide « Vos animaux », la
//     ville et le service sont exigés à la 2e étape (index 1), plus à la 3e ;
//     les étapes suivantes ne bloquent pas ;
//   · gardien : la ville reste exigée à l'index 1 et un tarif à l'index 3
//     (parcours prestataire inchangé) ;
//   · la question « notifications » existe dans les 9 langues.
// (Un test d'affichage de l'assistant n'est pas fiable ici : la police de test
// et l'absence de Google Fonts hors ligne faussent la mise en page.)
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/sign_up_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/localization/v565/neo583_i18n.dart';
import 'package:hopetsit/repositories/auth_repository.dart';

SignUpController _ctrl(String userType) =>
    SignUpController(userType: userType, authRepository: Get.find<AuthRepository>());

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('neo583');
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

  test('propriétaire : ville et service exigés à la 2e étape (index 1)', () {
    final c = _ctrl('pet_owner');
    expect(c.validateStep(1), 'signup_error_city_required');
    c.cityController.text = 'Paris';
    expect(c.validateStep(1), 'signup_error_service_required');
    c.selectedServices.add('walk');
    expect(c.validateStep(1), isNull);
    // Les étapes « préférences » et « récapitulatif » ne bloquent pas.
    final vide = _ctrl('pet_owner');
    expect(vide.validateStep(2), isNull);
    expect(vide.validateStep(3), isNull);
  });

  test('gardien : parcours inchangé (ville à l\'index 1, tarif à l\'index 3)', () {
    final c = _ctrl('pet_sitter');
    expect(c.validateStep(1), 'signup_error_city_required');
    expect(c.validateStep(3), 'signup_error_rate_required');
    c.ratePerDayController.text = '25';
    expect(c.validateStep(3), isNull);
  });

  test('question « notifications » présente dans les 9 langues', () {
    const langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
    final keys = neo583I18n['en']!.keys.toSet();
    expect(keys.length, 5);
    for (final l in langs) {
      expect(neo583I18n[l]?.keys.toSet(), keys, reason: l);
      expect(neo583I18n[l]!.values.every((v) => v.trim().isNotEmpty), isTrue,
          reason: l);
    }
  });
}
