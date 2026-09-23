// ZOE 23/09 — l'écran « Changer le mot de passe » (propriétaire ET
// pet-sitter) affichait ses erreurs de saisie en anglais dans toutes les
// langues : les validateurs de `ChangePasswordController` renvoyaient des
// phrases anglaises en dur, sans `.tr`. Ce test garde la traduction.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/change_password_controller.dart';
import 'package:hopetsit/localization/app_translations.dart';

void main() {
  setUp(() {
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr', 'FR');
  });

  test('les erreurs du changement de mot de passe sont traduites', () {
    final c = ChangePasswordController(userType: 'pet_owner');
    expect(c.validateNewPassword(''), 'Veuillez entrer un mot de passe');
    expect(c.validateNewPassword('abc'),
        'Le mot de passe doit contenir au moins 8 caractères');
    expect(c.validateNewPassword('abcdefgh'), isNull);
    expect(c.validateConfirmPassword(''),
        'Veuillez confirmer votre mot de passe');
    c.newPasswordController.text = 'abcdefgh';
    expect(c.validateConfirmPassword('autre123'),
        'Les mots de passe ne correspondent pas');
    expect(c.validateConfirmPassword('abcdefgh'), isNull);
  });

  // ZOE 23/09 — le test historique (i18n_test) ne couvre ni ko, ni ja, ni pl :
  // 74 messages manquaient au polonais sans que rien ne rougisse.
  test('les 9 langues ont toutes les clés anglaises', () {
    final all = AppTranslations().keys;
    final en = all['en_US']!.keys.toSet();
    for (final loc in all.keys) {
      final missing = en.difference(all[loc]!.keys.toSet());
      expect(missing, isEmpty,
          reason: '$loc : ${missing.length} clés manquantes, dont ${missing.take(5).join(" | ")}');
    }
    expect(all.length, 9);
  });
}
